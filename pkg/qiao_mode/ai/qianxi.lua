local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"
local SlashDefense = require "packages.qiao.pkg.qiao_mode.ai.slash_defense"
local Qianxi = require "packages.qiao.pkg.qiao_generals.util.shu019_qianxi"

local M = {}

function M.hitValue(ai, target, color, discarded)
  local player = ai.player
  if not ai:isEnemy(target) or (color ~= Card.Red and color ~= Card.Black) then return 0 end
  local event = ai.room.logic:getCurrentEvent()
  local turn = event and event:findParent(GameEvent.Turn, true)
  if turn and not player:canSkip(Player.Play) then return 0 end

  local best = 0
  for _, id in ipairs(player:getCardIds("h")) do
    local card = Fk:getCardById(id)
    if id ~= discarded and card.trueName == "slash" and player:canUseTo(card, target) then
      local before = SlashDefense.handHitChance(player, card, target)
      local after = SlashDefense.handHitChance(player, card, target, nil, color)
      if after > before then
        local result = Cards.damageOutcome(ai, card, target)
        if result and Damage.worth(result) then
          local gain = (after - before) * SlashDefense.hitFactor(player, card, target)
          best = math.max(best, Damage.value(result) * gain)
        end
      end
    end
  end
  return best
end

local function discardValue(ai, id, targets)
  local color = Fk:getCardById(id).color
  local hit = 0
  for _, target in ipairs(targets) do hit = math.max(hit, M.hitValue(ai, target, color, id)) end
  return hit - Cost.value(ai, id)
end

function M.invoke(ai)
  local player = ai.player
  if player:isHandAreaSealed() then return false end
  local targets = Qianxi.candidates(ai.room, player)
  return table.find(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id) and 3 + discardValue(ai, id, targets) > 0
  end) ~= nil
end

function M.discard(ai)
  local targets = Qianxi.candidates(ai.room, ai.player)
  local id = Requests.bestCard(ai:getEnabledCards(), function(candidate) return discardValue(ai, candidate, targets) end)
  if not id then return "" end
  ai:selectCard(id, true)
  return Requests.reply(ai)
end

return M
