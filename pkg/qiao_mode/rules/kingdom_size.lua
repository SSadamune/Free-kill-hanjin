-- 汉晋大小势力公共查询适配。
--
-- 只对 qiao_heg_mode 生效：
--   * 势力人数查询排除已移出游戏的角色；
--   * 存在已确定势力的【玉玺】持有者时，所有持有者所属势力均为大势力，
--     其余势力为小势力（可同时有多个持有势力）。
--
-- 保留原始 room.alive_players：汉晋胜负判定和自然野心家
-- 人数预演仍须把移出角色计入。这里只在这些查询的返回值上做局部过滤，因此
-- 其它模式以及胜负例外保持原行为。仍以 #room.players 作分母的调用方
-- （如阵法召唤阈值、battle_royal）不属于本次公共查询，另见交回说明。
local H = require "packages.hegemony.util"

local M = {}
local installed = false

local JADE_SEAL = "qiao__jade_seal"

local function isQiaoRoom(room)
  return room ~= nil and type(room.getSettings) == "function"
    and room:getSettings("gameMode") == "qiao_heg_mode"
end

--- 只读公开的实际势力；与六龙骖驾一致，不把未建国的 wild 合并。
local function kingdomOf(player)
  local kingdom = H.getKingdom(player)
  if kingdom == "wild" and (type(player.role) ~= "string" or player.role == "") then
    return "unknown"
  end
  return kingdom
end

local function hasJadeSeal(player)
  for _, id in ipairs(player:getCardIds(Player.Equip)) do
    local card = player:getVirtualEquip(id) or Fk:getCardById(id)
    if card ~= nil and (card.name == JADE_SEAL or card.trueName == "jade_seal") then
      return true
    end
  end
  return false
end

--- 返回所有存活、未移出且势力已确定的玉玺持有势力。
local function jadeKingdoms(room)
  local kingdoms, any = {}, false
  for _, player in ipairs(room.alive_players or {}) do
    if not player:isRemoved() and hasJadeSeal(player) then
      local kingdom = kingdomOf(player)
      if kingdom ~= nil and kingdom ~= "" and kingdom ~= "unknown" then
        kingdoms[kingdom] = true
        any = true
      end
    end
  end
  return kingdoms, any
end

--- 统计需要从原查询结果中扣除的移出角色数。
local function removedCounts(room, includeDead)
  local result = {}
  local list = includeDead and (room.players or {}) or (room.alive_players or {})
  for _, player in ipairs(list) do
    if player:isRemoved() then
      local kingdom = kingdomOf(player)
      if kingdom ~= nil and kingdom ~= "" and kingdom ~= "unknown" then
        result[kingdom] = (result[kingdom] or 0) + 1
      end
    end
  end
  return result
end

function M.install()
  if installed then return end
  installed = true

  local originalKingdom = H.getKingdomPlayersNum
  local originalSame = H.getSameKingdomPlayersNum
  local originalBig = H.isBigKingdomPlayer
  local originalSmall = H.isSmallKingdomPlayer

  H.getKingdomPlayersNum = function(room, includeDead)
    local result = originalKingdom(room, includeDead)
    if isQiaoRoom(room) then
      for kingdom, count in pairs(removedCounts(room, includeDead)) do
        -- 即使扣到 0 也保留键：上游存在 `mapper[kingdom] < number` 的锁定调用，
        -- 返回 nil 会直接报错；0 与原始 mapper 中已知势力的存在语义一致。
        result[kingdom] = math.max(0, (result[kingdom] or 0) - count)
      end
    end
    return result
  end

  H.getSameKingdomPlayersNum = function(room, player, kingdom, includeDead)
    local result = originalSame(room, player, kingdom, includeDead)
    if isQiaoRoom(room) then
      local key = kingdom
      if player ~= nil then key = kingdomOf(player) end
      if key ~= nil and key ~= "" and key ~= "unknown" then
        local removed = 0
        local list = includeDead and (room.players or {}) or (room.alive_players or {})
        for _, other in ipairs(list) do
          if other:isRemoved() and kingdomOf(other) == key then
            removed = removed + 1
          end
        end
        result = math.max(0, result - removed)
      end
    end
    return result
  end

  H.isBigKingdomPlayer = function(player)
    if player == nil then return originalBig(player) end
    local room = Fk:currentRoom()
    if not isQiaoRoom(room) then return originalBig(player) end
    if player:isRemoved() then return false end

    local kingdoms, any = jadeKingdoms(room)
    if not any then return originalBig(player) end

    local kingdom = kingdomOf(player)
    return kingdom ~= nil and kingdom ~= "" and kingdom ~= "unknown"
      and kingdoms[kingdom] == true
  end

  H.isSmallKingdomPlayer = function(player)
    if player == nil then return originalSmall(player) end
    local room = Fk:currentRoom()
    if not isQiaoRoom(room) then return originalSmall(player) end
    if player:isRemoved() then return false end

    local _, any = jadeKingdoms(room)
    if any then return not H.isBigKingdomPlayer(player) end
    return originalSmall(player)
  end
end

return M
