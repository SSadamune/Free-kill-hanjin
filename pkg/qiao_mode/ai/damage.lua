local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Cuipo = require "packages.qiao.pkg.qiao_generals.util.cuipo"

local M = {}

local natures = {
  qiao__fire__slash = fk.FireDamage, fire__slash = fk.FireDamage,
  qiao__thunder__slash = fk.ThunderDamage, thunder__slash = fk.ThunderDamage,
  qiao__ice__slash = fk.IceDamage, ice__slash = fk.IceDamage,
  qiao__fire_attack = fk.FireDamage, qiao__burning_camps = fk.FireDamage,
  qiao__drowning = fk.ThunderDamage,
}

function M.cardNature(card, use)
  local extra = use and use.extra_data
  return (extra and extra.qiao_damage_type) or natures[card.name] or fk.NormalDamage
end

function M.cardAmount(card, use, source)
  local amount = 1 + (use and use.additionalDamage or 0)
  source = use and use.from or source
  if source and (card.trueName == "slash" or card.trueName == "duel") then
    amount = amount + source:getMark("qiao_wei005_luoyi-turn")
    if not use and card.trueName == "slash" then amount = amount + (source.drank or 0) end
  end
  if not use and source and card.is_damage_card and source.room.current == source and source.phase == Player.Play
    and Cost.effectable(source, "qiao__skill_han014_1")
    and Cuipo.useIndex(source, source.room.logic:getCurrentEvent()) == Cuipo.cardNameLength(card) then
    amount = amount + 1
  end
  return amount
end

local function modifiedAmount(player, amount, nature)
  if nature == fk.NormalDamage or amount <= 0 then return amount end
  if Cost.effectable(player, "qiao__peace_spell_skill") then return 0 end
  if nature == fk.FireDamage and Cost.effectable(player, "qiao__vine_skill") then return amount + 1 end
  return amount
end

local function summarize(ai, hits, partner)
  local result = { friends = 0, enemies = 0, unknown = 0, enemyDying = 0, unsafe = false }
  for player, hit in pairs(hits) do
    if hit.damage > 0 or hit.hpLoss > 0 then
      local dying = math.max(0, hit.damage - player.shield) + hit.hpLoss >= player.hp
      if ai:isFriend(player) or (partner and partner:isFriend(player)) then
        result.friends = result.friends + 1
        result.unsafe = result.unsafe or dying
      elseif ai:isEnemy(player) and (not partner or partner:isEnemy(player)) then
        result.enemies = result.enemies + 1
        if dying then result.enemyDying = result.enemyDying + 1 end
      else
        result.unknown = result.unknown + 1
        result.unsafe = result.unsafe or dying
      end
    end
  end
  return result
end

local function addHit(hits, player, damage, hpLoss)
  local hit = hits[player] or { damage = 0, hpLoss = 0 }
  hit.damage = hit.damage + damage
  hit.hpLoss = hit.hpLoss + (hpLoss or 0)
  hits[player] = hit
end

local function chainedPlayers(room)
  local chained = {}
  for _, player in ipairs(room:getPresentPlayers()) do
    if player:isAlive() and not player:isRemoved() and player.chained then chained[player] = true end
  end
  return chained
end

local function spread(hits, chained, origin, amount, nature)
  if amount <= 0 or not chained[origin] then return false end
  chained[origin] = nil
  local propagates = false
  for other in pairs(chained) do
    local damage = modifiedAmount(other, amount, nature)
    addHit(hits, other, damage)
    if damage > 0 then chained[other] = nil end
    propagates = true
  end
  return propagates
end

-- Forecast only the current damage and its first propagation. Equipment and
-- active modifiers are public. Optional prevention and rescue are uncertain.
function M.assess(ai, target, amount, nature, options)
  options = options or Util.DummyTable
  local hits = {}
  local direct = options.ignoreTargetArmor and amount or modifiedAmount(target, amount, nature)
  addHit(hits, target, direct)
  local propagates = false
  if not options.alreadyChained and target.chained and Fk:canChain(nature) then
    propagates = spread(hits, chainedPlayers(ai.room), target, direct, nature)
  end
  local result = summarize(ai, hits, options.partner)
  result.direct, result.propagates = direct, propagates
  return result
end

function M.group(ai, card, targets)
  local hits = {}
  local nature, amount = M.cardNature(card), M.cardAmount(card, nil, ai.player)
  local chained = Fk:canChain(nature) and chainedPlayers(ai.room)
  local ordered = table.simpleClone(targets)
  ai.room:sortByAction(ordered)
  for _, target in ipairs(ordered) do
    local vine = nature == fk.NormalDamage and (card.trueName == "archery_attack" or card.trueName == "savage_assault")
      and Cost.effectable(target, "qiao__vine_skill")
    local immune = card.trueName == "savage_assault" and (Cost.effectable(target, "qiao__skill_shu014_1")
      or Cost.effectable(target, "qiao__skill_shu015_1"))
    if not vine and not immune then
      local direct = modifiedAmount(target, amount, nature)
      addHit(hits, target, direct)
      if chained then spread(hits, chained, target, direct, nature) end
    end
  end
  return summarize(ai, hits)
end

function M.luanwu(ai)
  local players = ai.room:getPresentPlayers()
  local hits = {}
  local slash = Fk:cloneCard("qiao__slash")
  for _, source in ipairs(players) do
    if source ~= ai.player then
      -- Only count enemy HP loss where no ordinary Slash material is public.
      -- Every other participant may choose HP loss or a Slash. Protect the
      -- weakest side against the possible attacks without inspecting hands.
      if source:isKongcheng() and #source:getCardIds("e") == 0 and #source:getHandlyIds() == 0 then
        addHit(hits, source, 0, 1)
      else
        if not ai:isEnemy(source) then addHit(hits, source, 0, 1) end
        for _, target in ipairs(players) do
          if target ~= source and not ai:isEnemy(target) and source:inMyAttackRange(target) then
            local damage = M.cardAmount(slash, nil, source)
            addHit(hits, target, damage)
            if target.chained then
              for _, other in ipairs(players) do
                if other ~= target and other.chained and not ai:isEnemy(other) then addHit(hits, other, damage) end
              end
            end
          end
        end
      end
    end
  end
  return summarize(ai, hits)
end

function M.worth(result)
  return not result.unsafe and result.enemies > result.friends + result.unknown
end

function M.value(result)
  if result.direct <= 0 then return 0 end
  local difference = result.enemies - result.friends - result.unknown
  local points = 2 * result.direct * math.max(1, math.abs(difference))
  if M.worth(result) then return points + 3 * result.enemyDying end
  return -points - (result.unsafe and 100 or 0)
end

function M.effect(ai, target)
  local current = ai.room.logic:getCurrentEvent()
  local event = current and current:findParent(GameEvent.CardEffect, true)
  local effect = event and event.data
  if effect and effect.to == target then return effect end
end

function M.acceptSlash(ai)
  local effect = M.effect(ai, ai.player)
  if not effect or not effect.card or effect.card.trueName ~= "slash" then return false end
  local nature = M.cardNature(effect.card, effect)
  if not ai.player.chained or not Fk:canChain(nature) then return false end
  local outcome = M.assess(ai, ai.player, M.cardAmount(effect.card, effect), nature)
  return M.worth(outcome) or outcome.direct == 0
end

return M
