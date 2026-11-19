-- EM(WEI001) 曹操 · 建安旗的公共入口与限制。
--
-- 限制绑定“那张被暗置的武将牌”：记录角色、主/副位置和牌名；明置由
-- RevealProhibited 基础标记拦截，移除、交换、变更分别接入公共入口。
-- 记录只在受益者自己的下一个回合开始解除；君主失去旗不提前清理。
local H = require "packages.hegemony.util"

local M = {}

M.LORD = "qiao_heg__em_wei001"
M.JIANAN = "qiao__skill_em_wei001_1"
M.HUIBIAN = "qiao__skill_em_wei001_2"
M.ZONGYU = "qiao__skill_em_wei001_3"
M.BANNER = "qiao__skill_em_wei001_banner"
M.SOURCE = "qiao__skill_em_wei001_banner_source"
M.RULE = "qiao__skill_em_wei001_rule"
M.TAG = "qiao_em_wei001_restrictions"
M.TEMP = "qiao_em_wei001_temp_skills"

local function isQiaoRoom(room)
  return room ~= nil and type(room.getSettings) == "function"
    and room:getSettings("gameMode") == "qiao_heg_mode"
end

local function records(room)
  return room:getTag(M.TAG) or {}
end

function M.record(room, player)
  if room == nil or player == nil then return nil end
  return records(room)[player.id]
end

local function actual(room, player, isDeputy)
  local public = isDeputy and player.deputyGeneral or player.general
  if public ~= "anjiang" and public ~= nil and public ~= "" then return public end
  return player:getMark(isDeputy and "__heg_deputy" or "__heg_general")
end

--- 该位置上的牌是否正是被限制的牌。仅服务端公共入口使用。
function M.isPositionRestricted(room, player, isDeputy)
  if not isQiaoRoom(room) then return false end
  local rec = M.record(room, player)
  if rec == nil or rec.isDeputy ~= isDeputy then return false end
  return actual(room, player, isDeputy) == rec.general
end

function M.bind(room, player, isDeputy, generalName)
  local list = table.simpleClone(records(room))
  local mark = table.simpleClone(player:getTableMark(MarkEnum.RevealProhibited))
  local place = isDeputy and "d" or "m"
  -- 只记录本次是否新增基础标记；已有同位置禁亮来源时既不重复添加，
  -- 解除时也不删除别人的记录。
  local added = not table.contains(mark, place)
  if added then table.insert(mark, place) end
  list[player.id] = { isDeputy = isDeputy, general = generalName, added = added }
  room:setTag(M.TAG, list)
  if added then room:setPlayerMark(player, MarkEnum.RevealProhibited, mark) end
end

function M.unbind(room, player)
  local list = table.simpleClone(records(room))
  local rec = list[player.id]
  if rec == nil then return end
  list[player.id] = nil
  room:setTag(M.TAG, next(list) ~= nil and list or nil)
  if rec.added then
    local mark = table.simpleClone(player:getTableMark(MarkEnum.RevealProhibited))
    table.removeOne(mark, rec.isDeputy and "d" or "m")
    room:setPlayerMark(player, MarkEnum.RevealProhibited, mark)
  end
end

function M.addTempSkill(room, player, skillName)
  -- 已有独立同名来源时不另建本次来源，也不在到期时撤销它。
  if player:hasSkill(skillName, true, true) then return end
  room:handleAddLoseSkills(player, skillName, M.SOURCE, false, true)
  local list = table.simpleClone(room:getTag(M.TEMP) or {})
  list[player.id] = list[player.id] or {}
  table.insertIfNeed(list[player.id], skillName)
  room:setTag(M.TEMP, list)
end

--- 到期：只撤本次来源的临时技能与限制，不触碰独立同名来源。
function M.expire(room, player)
  local list = table.simpleClone(room:getTag(M.TEMP) or {})
  for _, skillName in ipairs(list[player.id] or {}) do
    room:handleAddLoseSkills(player, "-" .. skillName, M.SOURCE, false, true)
  end
  list[player.id] = nil
  room:setTag(M.TEMP, next(list) ~= nil and list or nil)
  M.unbind(room, player)
end

--- 当前持旗君主：建安已明置有效，且霸者求贤状来源存在。
function M.lord(room)
  if room == nil then return nil end
  for _, p in ipairs(room:getPresentPlayers()) do
    if not p.dead and not p:isRemoved() and p.kingdom == "wei"
      and p:hasShownSkill(M.JIANAN) and p:hasSkill(M.BANNER) then
      return p
    end
  end
  return nil
end

local installed = false
function M.install()
  if installed then return end
  installed = true
  local originalRemove = H.removeGeneral
  H.removeGeneral = function(player, isDeputy)
    local room = player and player.room
    if isQiaoRoom(room) and M.record(room, player) ~= nil
      and M.isPositionRestricted(room, player, isDeputy == true) then
      return false
    end
    return originalRemove(player, isDeputy)
  end
  local Room = require "ltk.server.room"
  local originalChange = Room.changeHero
  Room.changeHero = function(self, player, newGeneral, full, isDeputy, ...)
    if isQiaoRoom(self) and M.record(self, player) ~= nil
      and M.isPositionRestricted(self, player, isDeputy == true) then
      return false
    end
    return originalChange(self, player, newGeneral, full, isDeputy, ...)
  end
end

M.install()

return M
