-- SPDX-License-Identifier: GPL-3.0-or-later
local HegUtil = require "packages.hegemony.util"
local M = {}

local function isRideSubtype(subtype)
  return subtype == Card.SubtypeOffensiveRide or subtype == Card.SubtypeDefensiveRide
end

function M.isRideCard(card)
  if not card or card.type ~= Card.TypeEquip then return false end
  return isRideSubtype(card.sub_type) or table.find(card.subtypes or {}, isRideSubtype) ~= nil
end

local function rideCount(player)
  local count = 0
  for _, id in ipairs(player:getCardIds(Player.Equip)) do
    if M.isRideCard(player:getVirtualEquip(id) or Fk:getCardById(id)) then
      count = count + 1
    end
  end
  return count
end

local function sixDragons(player)
  -- 国战工具用已公开的建国角色区分野心家。
  local kingdom = HegUtil.getKingdom(player)
  if kingdom == "unknown" then return -1, 1 end
  local count = rideCount(player)
  if kingdom and kingdom ~= "" then
    for _, other in ipairs(Fk:currentRoom().players) do
      if other.id ~= player.id and not other.dead and not other:isRemoved()
        and HegUtil.getKingdom(other) == kingdom then
        count = count + rideCount(other)
      end
    end
  end
  return -count, count
end

local adjustments = {
  qiao__liulongcanjia_skill = sixDragons,
  qiao__feiyun_gaihai_skill = function(player)
    if player.chained then return 0, 2 end
    return -2, 0
  end,
  qiao__linxiao_yuyu_skill = function()
    return -1, 1
  end,
}

function M.correct(skillName, from, to)
  local adjustment = adjustments[skillName]
  local outgoing, incoming = 0, 0
  if from:hasSkill(skillName) then outgoing = adjustment(from) end
  if to:hasSkill(skillName) then incoming = select(2, adjustment(to)) end
  return outgoing + incoming
end

local function equipmentAdjustment(player, card)
  for _, skill in ipairs(card:getEquipSkills(player)) do
    if player:hasSkill(skill) then
      local adjustment = adjustments[skill.name]
      if adjustment then return adjustment(player) end
      local skeleton = skill:getSkeleton()
      -- 普通坐骑沿用本体的单方向距离状态技。
      if skeleton and table.find(skeleton.effects, function(effect) return effect:isInstanceOf(DistanceSkill) end) then
        if card.sub_type == Card.SubtypeOffensiveRide then return -1, 0 end
        return 0, 1
      end
    end
  end
  return 0, 0
end

function M.labels(players)
  local labels = {}
  for _, player in ipairs(players) do
    for _, id in ipairs(player:getCardIds(Player.Equip)) do
      local card = player:getVirtualEquip(id) or Fk:getCardById(id)
      if M.isRideCard(card) then
        local outgoing, incoming = equipmentAdjustment(player, card)
        local label
        if incoming > 0 and outgoing == -incoming then
          label = "±" .. incoming
        elseif incoming > 0 then
          label = "+" .. incoming
        elseif outgoing < 0 then
          label = tostring(outgoing)
        else
          label = "0"
        end
        labels[tostring(id)] = label
      end
    end
  end
  return labels
end

return M
