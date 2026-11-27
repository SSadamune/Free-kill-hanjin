local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"

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
  return amount
end

local function modifiedAmount(player, amount, nature)
  if nature == fk.NormalDamage or amount <= 0 then return amount end
  if Cost.effectable(player, "qiao__peace_spell_skill") then return 0 end
  if nature == fk.FireDamage and Cost.effectable(player, "qiao__vine_skill") then return amount + 1 end
  return amount
end

-- Forecast only the current damage and its first propagation. Equipment and
-- active modifiers are public. Optional prevention and rescue are uncertain.
function M.assess(ai, target, amount, nature, options)
  options = options or Util.DummyTable
  local partner = options.partner
  local result = { friends = 0, enemies = 0, unknown = 0, enemyDying = 0, unsafe = false }
  result.direct = options.ignoreTargetArmor and amount or modifiedAmount(target, amount, nature)
  local mayPropagate = not options.alreadyChained and target.chained and Fk:canChain(nature)
  result.propagates = false
  local function record(player, damage)
    if damage <= 0 then return end
    local dying = damage >= player.hp + player.shield
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
  record(target, result.direct)
  if mayPropagate and result.direct > 0 then
    for _, other in ipairs(ai.room:getPresentPlayers()) do
      if other ~= target and other:isAlive() and not other:isRemoved() and other.chained then
        result.propagates = true
        record(other, modifiedAmount(other, result.direct, nature))
      end
    end
  end
  return result
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
