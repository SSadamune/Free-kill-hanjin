local Rules = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local ExtraTargets = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"
local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"

local M = {}

local function profitable(ai, use, entry)
  local card, targets = use.card, use.tos
  if entry.effect == "execute_both" then
    if card.name == "qiao__chasing_near" then
      return #targets > 0 and table.every(targets, function(target)
        return ai:isEnemy(target) and #target:getCardIds("he") >= 2 and #target:getCardIds("j") == 0
      end)
    elseif card.name == "qiao__drowning" then
      return #targets > 0 and table.every(targets, function(target)
        return Cards.safeDamage(ai, card, target) and #target:getCardIds("e") > 0
      end)
    end
  elseif entry.effect == "add_target" and card.name ~= "qiao__collateral" then
    local candidates = ExtraTargets.candidates(ai.room, use, {
      target_condition = entry.target_condition, excluded_player_id = ai.player.id,
    })
    local helpful = function(target) return Cards.scoreTarget(ai, card, target) ~= nil end
    if use.from.serverplayer:getState() == fk.Player_Robot then
      return table.find(candidates, helpful) ~= nil
    end
    return #candidates > 0 and table.every(candidates, helpful)
  elseif entry.effect == "discard_target_equip" then
    return #targets > 0 and table.every(targets, function(target)
      return ai:isEnemy(target) and #target:getCardIds("e") > 0
    end)
  elseif entry.effect == "damage" then
    return card.is_damage_card and #targets > 0 and table.every(targets, function(target)
      return Cards.safeDamage(ai, card, target)
    end)
  end
end

function M.support(ai, extra)
  local use, entry = Rules.supportContext(extra)
  if not use or not ai:isFriend(use.from) or not profitable(ai, use, entry) then return end
  -- Keep a reserve after helping. The dashboard already requires a legal
  -- discard of the same card category for this request.
  local budget = (ai.player.hp <= 1 or ai.player:getHandcardNum() <= 2) and 1 or 2
  return Cost.select(ai, 1, budget)
end

function M.targetScore(ai, card, target, prompt)
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
    return Cards.scoreTarget(ai, card, target)
  end
end

return M
