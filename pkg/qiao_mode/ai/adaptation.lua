local Rules = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local ExtraTargets = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"
local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"

local M = {}

local function damageBenefit(ai, use, target, bonus, options)
  local nature = Damage.cardNature(use.card, use)
  local amount = Damage.cardAmount(use.card, use) + bonus
  local projected = Damage.assess(ai, target, amount, nature, options)
  if not Damage.worth(projected) then return end

  local resilience = target.hp + target.shield
  if bonus > 0 and projected.direct - bonus >= resilience then return 1.25 end
  if projected.direct >= resilience then return 4.5 end
  if resilience <= 2 then return 3.25 end
  return 2.25
end

local function equipmentBenefit(target, all)
  local count = #target:getCardIds("e")
  if count == 0 then return end
  local defense = #target:getEquipments(Card.SubtypeArmor) > 0 and 0.5 or 0
  local refund = target:hasSkill("qiao__skill_wu008_2") and 1 or 0
  return 1.5 + (all and math.min(count, 3) or 1) + defense - refund
end

local function extraTargetBenefit(ai, use, entry, score)
  if use.card.name == "qiao__collateral" then return end
  local candidates = ExtraTargets.candidates(ai.room, use, {
    target_condition = entry.target_condition, excluded_player_id = ai.player.id,
  })
  local actor = use.from.ai
  if use.from.serverplayer:getState() == fk.Player_Robot and actor and actor.hostileScore then
    local chosen = Cards.bestCandidate(actor, candidates, function(target)
      return M.targetScore(actor, use.card, target, "#qiao_adaptation_add_target", use)
    end)
    if chosen then return score(chosen) end
    return
  end
  -- A human controls the next selection. Price the least favorable option.
  local lowest
  for _, target in ipairs(candidates) do
    local value = score(target)
    if not value then return end
    lowest = lowest and math.min(lowest, value) or value
  end
  return lowest
end

local function benefit(ai, use, entry, temporary)
  local function allowed(target)
    return ai:isEnemy(target) and (not temporary or use.from.ai:isEnemy(target))
  end
  local card, effect = use.card, entry.effect
  local options = {
    partner = temporary and use.from.ai or nil,
    -- Water Attack discards every equipped card before dealing thunder.
    ignoreTargetArmor = effect == "execute_both" and card.name == "qiao__drowning",
  }
  local function score(target)
    if not allowed(target) or table.contains(use.nullifiedTargets or {}, target) then return end
    local value
    if effect == "execute_both" and card.name == "qiao__drowning" then
      local equipment = equipmentBenefit(target, true)
      local damage = damageBenefit(ai, use, target, 0, options)
      -- The unassisted target can choose the cheaper consequence. The
      -- incremental pressure is the more expensive consequence.
      if equipment and damage then value = math.max(equipment, damage) end
    elseif effect == "execute_both" and card.name == "qiao__chasing_near" then
      if #target:getCardIds("he") >= 2 and #target:getCardIds("j") == 0 then
        value = #target:getCardIds("e") > 0 and 3 or 2.5
      end
    elseif effect == "discard_target_equip" then
      value = equipmentBenefit(target, false)
    elseif effect == "damage" and card.is_damage_card then
      value = damageBenefit(ai, use, target, 1, options)
    elseif effect == "add_target" and Cards.scoreTarget(ai, card, target, use) then
      if card.is_damage_card then
        value = damageBenefit(ai, use, target, 0, options)
        if value and (card.name == "qiao__unexpectation" or card.name == "qiao__fire_attack"
          or (card.trueName == "slash" and not target:isKongcheng())) then value = value - 0.75 end
        if card.name == "qiao__fire_attack" and use.from:isKongcheng() then return end
      else
        value = 2.5
      end
    end
    if value then return value + 2 * math.max(0, -0.4 - ai:attitude(target)) end
  end

  if effect == "add_target" then return extraTargetBenefit(ai, use, entry, score) end
  local total = 0
  for _, target in ipairs(use.tos) do
    local value = score(target)
    if not value then return end
    total = total + value
  end
  return total
end

function M.support(ai, extra)
  local use, entry = Rules.supportContext(extra)
  if not use then return end
  local temporary = not ai:isFriend(use.from)
  if temporary and (ai:attitude(use.from) <= 0 or not use.from.ai or not use.from.ai.hostileScore) then return end
  local value = benefit(ai, use, entry, temporary)
  if not value or (temporary and value < 3.5) then return end
  value = ai:supportScore(use.from, value)

  local lowReserve = ai.player.hp <= 1 or ai.player:getHandcardNum() <= 2
  local margin = (lowReserve and 1.5 or 0.5) + (temporary and 1.5 or 0)
  local budget = (lowReserve and 2 or 4) - (temporary and 1 or 0)
  return Cost.select(ai, 1, budget, function(id) return value > Cost.value(ai, id) + margin end)
end

function M.targetScore(ai, card, target, prompt, use)
  if prompt == "#qiao_adaptation_remove_target" then
    if Cards.isHarmful(card) and not ai:isEnemy(target) then
      return (ai:isFriend(target) and 30 or 15) - target.hp
    elseif card.name == "qiao__restore_heartland" then
      return ai:hostileScore(target, 1)
    end
  elseif prompt == "#qiao_adaptation_sub_target" then
    if card.name == "qiao__collateral" then return ai:hostileScore(target, 20 - target.hp) end
  elseif card.name == "qiao__collateral" then
    return ai:hostileScore(target, #target:getEquipments(Card.SubtypeWeapon))
  else
    return Cards.scoreTarget(ai, card, target, use)
  end
end

return M
