-- 汉晋鏖战接管。
--
-- 进入时机沿用国战：回合开始满足条件、第一次洗牌设置以及其它技能调用
-- HegUtil.enterBattleRoyalMode 的情况。汉晋房间始终安装“桃只能当杀/闪”的
-- 汉晋来源，不再让上游 battle_royal& / new_battle_royal& 施加桃当酒等用途。
-- 不改上游 util.lua，也不替换全局函数；只在本房间内清理上游残留技能。
local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"
local Variants = require "packages.hanjin.pkg.hanjin_mode.rules.variants"

local M = {}

M.TAG = "BattleRoyalMode"
M.EVENT_SKILL = "#new_battle_royal_event&"
M.UPSTREAM_SKILLS = { "battle_royal&", "new_battle_royal&" }
M.SOURCE_DEF = "battle_royal"
M.SOURCE_PREFIX = "battle_royal:"

function M.entered(room)
  return room ~= nil and room:getTag(M.TAG) == true
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
  if room == nil or type(room.getTag) ~= "function" then return end
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
  if M.entered(room) then return false end
  local H = require "packages.hegemony.util"
  local threshold = #room.players > 6 and 5 or 4
  if #room.alive_players >= threshold then return false end
  for _, count in pairs(H.getKingdomPlayersNum(room)) do
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
  if not M.entered(room) and room:getSettings("enterBattleRoyalOnFirstShuffle") then
    M.enter(room)
    return true
  end
  return false
end

return M
