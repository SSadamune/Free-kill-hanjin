-- 限定技复原共用整局历史、随牌账本和独立翼从次数。候选条件由各技能决定。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"
local M = {}

local function usedMarks(name)
  local skeleton = Fk.skill_skels[name]
  return skeleton and skeleton.qiao_limited_used_marks or {}
end

local function hasInstances(player, name)
  return Bian.isLimitedRetinueSkill(name) and R.countForSkill(player, name) > 0
end

function M.hasUsed(player, name)
  if hasInstances(player, name) then return #Bian.usedLimitedRetinues(player, name) > 0 end
  if player:usedSkillTimes(name, Player.HistoryGame) > 0 then return true end
  for _, mark in ipairs(usedMarks(name)) do
    local value = player:getMark(mark)
    if type(value) == "number" and value > 0 then return true end
    if type(value) == "table" and next(value) ~= nil then return true end
    if type(value) == "string" and value ~= "" then return true end
  end
  return false
end

function M.restore(room, player, name)
  if hasInstances(player, name) then
    if not Bian.resetOneLimitedRetinue(player, name) then return end
    player:setSkillUseHistory(name, #Bian.usedLimitedRetinues(player, name), Player.HistoryGame)
  else
    player:clearSkillHistory(name, Player.HistoryGame)
    Exchange.resetSkillGameHistory(room, player, name)
    for _, mark in ipairs(usedMarks(name)) do room:setPlayerMark(player, mark, 0) end
  end
  room:updateAllLimitSkillUI(player)
end

return M
