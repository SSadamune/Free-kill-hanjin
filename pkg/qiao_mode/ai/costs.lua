local Adaptation = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local Personality = require "packages.qiao.pkg.qiao_mode.ai.personality"
local Slash = require "packages.qiao.pkg.qiao_mode.ai.slash_supply"

local M = {}

local pindianSkills = {
  "qiao__skill_han008_1", "qiao__skill_han010_1", "qiao__skill_han013_1", "qiao__skill_han017_1",
  "qiao__skill_han017_2", "qiao__skill_jin008_2", "qiao__skill_qun015_1", "qiao__skill_shu015_2",
  "qiao__skill_wei013_1", "qiao__skill_wu010_2", "qiao__skill_wu012_1", "qiao__skill_wu012_2",
}

local adaptationPoints = {
  draw = 2, damage = 2, execute_both = 2, thunder_damage = 2,
  discard_target_equip = 2, disresponsive = 1, add_target = 1,
  remove_target = 1, obtain_response_card = 1, ignore_times = 1,
}

function M.effectable(player, name)
  local skill = Fk.skills[name]
  return skill and player:hasSkill(name) and skill:isEffectable(player)
end

function M.zhaxiangTrade(player)
  return player.hp >= 3 and M.effectable(player, "qiao__skill_wu004_2")
end

local function copies(ai, card)
  local selected = (ai.command == "AskForUseActiveSkill" or ai.command == "PlayCard")
    and ai:getSelectedCards() or {}
  return #table.filter(ai.player:getCardIds("h"), function(id)
    return not table.contains(selected, id) and Fk:getCardById(id).trueName == card.trueName
  end)
end

local function baseValue(ai, card)
  if card.trueName == "peach" then return 9 end
  if card.trueName == "nullification" then return 7 end
  if card.trueName == "analeptic" then return 5 end
  if card.trueName == "jink" then return copies(ai, card) > 1 and 3 or 6 end
  if card.trueName == "slash" then
    if copies(ai, card) <= 1 then return 4 end
    local capacity = Slash.cardCapacity(ai, card)
    return capacity and capacity > 1 and 3.5 or 2
  end
  if card.type == Card.TypeEquip then
    return ai.player:hasEmptyEquipSlot(card.sub_type) and 4 or 1
  end
  if card.name == "qiao__foresight" or card.name == "qiao__strengthen_state" then return 6 end
  if card.name == "qiao__lightning" or card.name == "qiao__lure_tiger" then return 1 end
  return 3
end

local function adaptationBonus(ai, card)
  local player, room = ai.player, ai.room
  local bonus = 0
  for _, entry in ipairs((card.extra_data or {}).qiao_adaptation or {}) do
    local condition = entry.condition
    local satisfied
    if condition == "kongchao" then
      satisfied = player:getHandcardNum() == 1
    elseif condition == "fujia" and entry.effect ~= "ignore_times" then
      local remaining = player:getHandcardNum() - 1
      satisfied = table.every(room:getPresentPlayers(), function(other)
        return other == player or remaining >= other:getHandcardNum()
      end)
    else
      satisfied = Adaptation.conditionSatisfied(room, player, condition)
    end
    if satisfied then bonus = bonus + (adaptationPoints[entry.effect] or 0) end
  end
  return math.min(bonus, 3)
end

function M.value(ai, id)
  local card, player = Fk:getCardById(id), ai.player
  local area = ai.room:getCardArea(id)
  local owner = ai.room:getCardOwner(id)
  local bonus = (not owner or owner == player) and Personality.cardBonus(ai, card) or 0
  if area == Card.PlayerEquip then return 6 + bonus end
  local result = baseValue(ai, card) + bonus
  if owner and owner ~= player then return result end
  if card.type == Card.TypeEquip then
    if M.effectable(player, "qiao__skill_wu008_2") then result = result + 1.5 end
    if M.effectable(player, "qiao__skill_wu015a_2") then result = result + 1 end
  elseif card.type == Card.TypeTrick and not card:isConverted() and not card:isRuleVirtual()
    and M.effectable(player, "qiao__skill_shu007_1") then
    result = result + 1.5
  end
  if card.number >= 9 and table.find(pindianSkills, function(skill) return M.effectable(player, skill) end) then
    result = result + 0.25 * (card.number - 8)
  end
  if owner == player and area == Card.PlayerHand then result = result + adaptationBonus(ai, card) end
  return result
end

function M.cheapest(ai, accepts)
  local best, bestValue
  for _, id in ipairs(ai:getEnabledCards()) do
    if not accepts or accepts(id) then
      local value = M.value(ai, id)
      if not bestValue or value < bestValue or (value == bestValue and id < best) then
        best, bestValue = id, value
      end
    end
  end
  return best, bestValue
end

function M.select(ai, count, budget, accepts)
  for _ = 1, count do
    local best, bestValue = M.cheapest(ai, accepts)
    if not best or (budget and bestValue > budget) then return false end
    if budget then budget = budget - bestValue end
    ai:selectCard(best, true)
  end
  return true
end

-- Only a genuine discard gets Xiaoji credit. Transfers, view-as materials
-- and recasts still use the normal value. Credit one equipment per selection.
function M.discard(ai, count, budget, replacement)
  local player, room = ai.player, ai.room
  local function equipped(id) return room:getCardArea(id) == Card.PlayerEquip end
  local active = M.effectable(player, "qiao__skill_wu008_2") and not player:isHandAreaSealed()
  for _ = 1, count do
    local best, price
    local limit = budget
    if active and not table.find(ai:getSelectedCards(), equipped) then
      best, price = M.cheapest(ai, function(id) return not equipped(id) end)
      local gear, gearPrice = M.cheapest(ai, equipped)
      if gear then
        local draw = room.current == player and 3 or 6
        gearPrice = math.max(0, gearPrice - draw)
        -- For a replacement effect such as Zhiheng, the fallback is the
        -- ordinary hand card it would replace or the value of a new draw.
        local breakEven = price or (replacement and 3 or math.huge)
        local equipmentLimit = budget and budget + (replacement and 1 or 0)
        if gearPrice < breakEven and (not equipmentLimit or gearPrice <= equipmentLimit) then
          best, price, limit = gear, gearPrice, equipmentLimit
        end
      end
    elseif active and replacement then
      best, price = M.cheapest(ai, function(id) return not equipped(id) end)
    else
      best, price = M.cheapest(ai)
    end
    if not best or (limit and price > limit) then return false end
    if budget then budget = budget - price end
    ai:selectCard(best, true)
  end
  return true
end

return M
