-- 汉晋鏖战接管。
--
-- 进入时机沿用国战：回合开始满足条件、第一次洗牌设置以及其它技能调用
-- HegUtil.enterBattleRoyalMode 的情况。汉晋房间始终安装“桃只能当杀/闪”的
-- 汉晋来源，不再让上游 battle_royal& / new_battle_royal& 施加桃当酒等用途。
-- 两个进入入口共用房间开关，上游技能的清理也只作用于本房间。
local O = require "packages.qiao.pkg.qiao_mode.rules.only_as"
local Variants = require "packages.qiao.pkg.qiao_mode.rules.variants"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local H = require "packages.hegemony.util"

local M = {}

M.TAG = "BattleRoyalMode"
M.SKILL = "qiao_battle_royal&"
M.EVENT_SKILL = "#new_battle_royal_event&"
M.UPSTREAM_SKILLS = { "battle_royal&", "new_battle_royal&" }
M.SOURCE_DEF = "battle_royal"
M.SOURCE_PREFIX = "battle_royal:"
M.PERSONAL_TAG = "qiao_personal_battle_royal"
M.PERSONAL_PREFIX = "battle_royal_personal:"
M.settingKey = "qiao_locked_battle_royal"

local function enabled(room)
  return room:getSettings("gameMode") ~= Modes.locked or room:getSettings(M.settingKey) == true
end

function M.install()
  if M._installed then return end
  M._installed = true
  local upstreamEnter = H.enterBattleRoyalMode
  H.enterBattleRoyalMode = function(room)
    if enabled(room) then return upstreamEnter(room) end
  end
end

function M.entered(room)
  return room ~= nil and room:getTag(M.TAG) == true
end

function M.hasPersonal(room, player)
  if room == nil or player == nil or type(room.getTag) ~= "function" then return false end
  local reg = room:getTag(M.PERSONAL_TAG)
  local mine = type(reg) == "table" and reg[player.id] or nil
  if type(mine) ~= "table" then return false end
  for sourceKey in pairs(mine) do
    if Fk.skills[sourceKey] == nil or player:hasShownSkill(sourceKey) then
      return true
    end
  end
  return false
end

function M.inBattleRoyal(room, player)
  return M.entered(room) or M.hasPersonal(room, player)
end

--- 同步单个角色的个人鏖战来源（如伍琼&种辑【心疾】），不影响场上其他角色。
function M.syncPersonal(room, player, sourceKey, active)
  if room == nil or player == nil or type(room.getTag) ~= "function" then return end
  assert(type(sourceKey) == "string" and sourceKey ~= "", "Personal battle royal needs a source key")
  local reg = room:getTag(M.PERSONAL_TAG) or {}
  local mine = reg[player.id] or {}
  local uid = M.PERSONAL_PREFIX .. sourceKey .. ":" .. tostring(player.id)
  if active and not player.dead then
    mine[sourceKey] = true
    reg[player.id] = mine
    room:setTag(M.PERSONAL_TAG, reg)
    if not player:hasSkill(M.SKILL, true, true) then
      room:handleAddLoseSkills(player, M.SKILL, nil, false, true)
    end
    O.addSource(room, {
      id = uid,
      def = M.SOURCE_DEF,
      holder = player,
      skill = Fk.skills[sourceKey] and sourceKey or nil,
      duration = "game",
      reason = sourceKey,
    })
  else
    mine[sourceKey] = nil
    if next(mine) == nil then reg[player.id] = nil else reg[player.id] = mine end
    room:setTag(M.PERSONAL_TAG, reg)
    O.removeSource(room, uid)
    if not M.entered(room) and not M.hasPersonal(room, player)
      and player:hasSkill(M.SKILL, true, true) then
      room:handleAddLoseSkills(player, "-" .. M.SKILL, nil, false, true)
    end
  end
end

local function isUpstream(name)
  return table.contains(M.UPSTREAM_SKILLS, name)
end

--- 删除上游残留的 prohibit 状态技。状态技不会随玩家技能移除而自动消失。
local function cleanupStatusSkills(room)
  for _, list in pairs(room.status_skills or {}) do
    for i = #list, 1, -1 do
      local skeleton = list[i]:getSkeleton()
      if skeleton ~= nil and isUpstream(skeleton.name) then
        table.remove(list, i)
      end
    end
  end
end

local function cleanupPlayer(room, player)
  local lose = {}
  for _, name in ipairs(M.UPSTREAM_SKILLS) do
    if player:hasSkill(name, true, true) then table.insert(lose, "-" .. name) end
  end
  if #lose > 0 then
    room:handleAddLoseSkills(player, lose, nil, false, true)
  end
end

--- 从本房间事件表移除一个触发技及其关联效果（仅本房间，不影响全局技能对象）。
local function removeRoomTrigger(room, name)
  local logic = room.logic
  local skill = Fk.skills[name]
  if skill == nil then return false end
  local removed = false
  for i = #logic.skills, 1, -1 do
    local entry = logic.skills[i]
    if entry == name or entry:find(name, 1, true) ~= nil then
      table.remove(logic.skills, i)
      removed = true
    end
  end
  for _, list in pairs(logic.skill_table or {}) do
    for i = #list, 1, -1 do
      local skeleton = list[i]:getSkeleton()
      if list[i] == skill or (skeleton ~= nil and skeleton.name == name) then
        table.remove(list, i)
        removed = true
      end
    end
  end
  return removed
end

local function ensureSources(room)
  for _, player in ipairs(room.alive_players) do
    room:handleAddLoseSkills(player, M.SKILL, nil, false, true)
    O.addSource(room, {
      id = M.SOURCE_PREFIX .. player.id,
      def = M.SOURCE_DEF,
      holder = player,
      duration = "game",
      reason = "battle_royal",
    })
  end
end

--- 安装/补全鏖战状态。可重复调用；已进入时只补全汉晋来源与清理残留。
function M.enter(room)
  if room == nil or type(room.getTag) ~= "function" or not enabled(room) then return end
  Variants.apply(room)
  local already = M.entered(room)
  local hadUpstream = false
  for _, player in ipairs(room.players) do
    for _, name in ipairs(M.UPSTREAM_SKILLS) do
      if player:hasSkill(name, true, true) then hadUpstream = true end
    end
  end
  if not already then
    room:setTag(M.TAG, true)
    room:doBroadcastNotify("ShowToast", Fk:translate("#EnterBattleRoyalMode"))
    room:sendLog { type = "#EnterBattleRoyalModeLog" }
  elseif hadUpstream then
    -- 其它技能直接调用 H.enterBattleRoyalMode 时，上游可能已按新鏖战发送
    -- “桃当酒”提示；这里用汉晋统一文本纠正。
    room:doBroadcastNotify("ShowToast", Fk:translate("#EnterBattleRoyalMode"))
  end
  -- 无论走哪条进入路径，横幅都使用与统一规则一致的 19 版鏖战文本。
  room:setBanner("@[:]BattleRoyalDummy", "BattleRoyalMode")
  for _, player in ipairs(room.players) do cleanupPlayer(room, player) end
  cleanupStatusSkills(room)
  if Variants.enabled(room) then
    room:addSkill(M.EVENT_SKILL)
  else
    removeRoomTrigger(room, M.EVENT_SKILL)
  end
  ensureSources(room)
  O.refresh(room)
end

--- 上游技能被添加时立即撤下，改为汉晋来源；同时补全鏖战状态。
function M.onAcquire(room, player, name)
  if not isUpstream(name) then return false end
  room:handleAddLoseSkills(player, "-" .. name, nil, false, true)
  M.enter(room)
  return true
end

function M.shouldEnter(room)
  if not enabled(room) or M.entered(room) then return false end
  local threshold = #room.players > 6 and 5 or 4
  if #room.alive_players >= threshold then return false end
  local Counts=require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"
  for _, count in pairs(Counts.physicalCounts(room)) do
    if count and count > 1 then return false end
  end
  return true
end

function M.onTurnStart(room)
  if M.shouldEnter(room) then
    M.enter(room)
    return true
  end
  return false
end

function M.onFirstShuffle(room)
  if enabled(room) and not M.entered(room) and room:getSettings("enterBattleRoyalOnFirstShuffle") then
    M.enter(room)
    return true
  end
  return false
end

return M
