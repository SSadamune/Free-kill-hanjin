local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Cuipo = require "packages.qiao.pkg.qiao_generals.util.cuipo"
local Reactions = require "packages.qiao.pkg.qiao_mode.ai.damage_reactions"
local WuProtection = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

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

local function modifiedAmount(hits, player, amount, nature, options)
  if amount <= 0 then return 0 end
  local ignoreArmor = options and options.ignoreTargetArmor
  if not ignoreArmor and nature ~= fk.NormalDamage and Cost.effectable(player, "qiao__peace_spell_skill") then return 0 end
  if not ignoreArmor and nature == fk.FireDamage and Cost.effectable(player, "qiao__vine_skill") then amount = amount + 1 end
  local card, source = options and options.card, options and options.source
  local gounan = "@@qiao_skill_han005_2_source-noclear"
  if card and card.name == "qiao__slash" and (player:getMark(gounan) > 0 or (source and source:getMark(gounan) > 0)) then
    amount = amount + 1
  end
  local hit = hits[player]
  if not hit or hit.damage == 0 then amount = amount + player:getMark("qiao_skill_han006_1_next_damage-turn") end
  if WuProtection.pending(player) > (hit and hit.attempts or 0) then amount = amount - 1 end
  return math.max(0, amount)
end

local function summarize(ai, hits, partner)
  local result = { friends = 0, enemies = 0, unknown = 0, enemyDying = 0, unsafe = false, balance = 0 }
  for player, hit in pairs(hits) do
    if hit.damage > 0 or hit.hpLoss > 0 then
      local lostHp = math.max(0, hit.damage - player.shield) + hit.hpLoss
      local dying = lostHp >= player.hp
      local harm = 4 + 3 * math.max(0, lostHp - 1) + (dying and 2 or 0)
      local reaction = not dying and Reactions.benefit(ai, player, hit.source, hit.damage) or 0
      if ai:isFriend(player) or (partner and partner:isFriend(player)) then
        result.friends = result.friends + 1
        result.unsafe = result.unsafe or dying
        result.balance = result.balance - harm + reaction
      elseif ai:isEnemy(player) and (not partner or partner:isEnemy(player)) then
        result.enemies = result.enemies + 1
        if dying then result.enemyDying = result.enemyDying + 1 end
        result.balance = result.balance + harm - reaction
      else
        result.unknown = result.unknown + 1
        result.unsafe = result.unsafe or dying
        result.balance = result.balance - harm - reaction
      end
    end
  end
  return result
end

local function addHit(hits, player, damage, hpLoss, source)
  local hit = hits[player] or { damage = 0, hpLoss = 0, attempts = 0 }
  hit.damage = hit.damage + damage
  hit.hpLoss = hit.hpLoss + (hpLoss or 0)
  if not hpLoss then hit.attempts = hit.attempts + 1 end
  if damage > 0 and not hit.source then hit.source = source end
  hits[player] = hit
end

local function chainedPlayers(room)
  local chained = {}
  for _, player in ipairs(room:getPresentPlayers()) do
    if player:isAlive() and not player:isRemoved() and player.chained then chained[player] = true end
  end
  return chained
end

local function spread(hits, chained, origin, amount, nature, options)
  if amount <= 0 or not chained[origin] then return false end
  chained[origin] = nil
  local propagates = false
  for other in pairs(chained) do
    local damage = modifiedAmount(hits, other, amount, nature)
    addHit(hits, other, damage, nil, options and options.source)
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
  local direct = modifiedAmount(hits, target, amount, nature, options)
  addHit(hits, target, direct, nil, options.source)
  local propagates = false
  if not options.alreadyChained and target.chained and Fk:canChain(nature) then
    propagates = spread(hits, chainedPlayers(ai.room), target, direct, nature, options)
  end
  local result = summarize(ai, hits, options.partner)
  result.direct, result.propagates = direct, propagates
  return result
end

function M.group(ai, card, targets)
  local hits = {}
  local nature, amount = M.cardNature(card), M.cardAmount(card, nil, ai.player)
  local chained = Fk:canChain(nature) and chainedPlayers(ai.room)
  local source = ai.player
  if card.trueName == "savage_assault" then
    source = table.find(ai.room:getPresentPlayers(), function(player)
      return player ~= ai.player and Cost.effectable(player, "qiao__skill_shu014_1")
    end) or source
  end
  local options = { source = source, card = card }
  local ordered = table.simpleClone(targets)
  ai.room:sortByAction(ordered)
  for _, target in ipairs(ordered) do
    local vine = nature == fk.NormalDamage and (card.trueName == "archery_attack" or card.trueName == "savage_assault")
      and Cost.effectable(target, "qiao__vine_skill")
    local immune = card.trueName == "savage_assault" and (Cost.effectable(target, "qiao__skill_shu014_1")
      or Cost.effectable(target, "qiao__skill_shu015_1"))
    if not vine and not immune then
      local direct = modifiedAmount(hits, target, amount, nature, options)
      addHit(hits, target, direct, nil, source)
      if chained then spread(hits, chained, target, direct, nature, options) end
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
            addHit(hits, target, damage, nil, source)
            if target.chained then
              for _, other in ipairs(players) do
                if other ~= target and other.chained and not ai:isEnemy(other) then addHit(hits, other, damage, nil, source) end
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
  return not result.unsafe and result.enemies > result.friends + result.unknown and result.balance > 0
end

function M.value(result)
  if result.direct <= 0 then return 0 end
  local difference = result.enemies - result.friends - result.unknown
  local points = 2 * result.direct * math.max(1, math.abs(difference))
  if M.worth(result) then return math.min(points, result.balance) + 3 * result.enemyDying end
  return -points - (result.unsafe and 100 or 0)
end

function M.effect(ai, target)
  local current = ai.room.logic:getCurrentEvent()
  local event = current and current:findParent(GameEvent.CardEffect, true)
  local effect = event and event.data
  if effect and effect.to == target then return effect end
end

local function effectSource(ai, effect)
  if effect.card.trueName == "savage_assault" then
    local event = ai.room.logic:getCurrentEvent():findParent(GameEvent.UseCard, true)
    local source = event and event.data.extra_data and event.data.extra_data.qiao__skill_shu014_1_source
    if source then return source:isAlive() and source or nil end
  end
  return effect.from
end

function M.incoming(ai, effect)
  local source = effectSource(ai, effect)
  return M.assess(ai, ai.player, M.cardAmount(effect.card, effect), M.cardNature(effect.card, effect),
    { source = source, card = effect.card }), source
end

function M.acceptIncoming(ai, effect, cost)
  local outcome, source = M.incoming(ai, effect)
  if outcome.direct == 0 or M.worth(outcome) then return true, outcome end
  if outcome.unsafe or outcome.propagates then return false, outcome end
  return Reactions.accept(ai, source, outcome.direct, cost), outcome
end

return M
