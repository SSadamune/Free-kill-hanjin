-- 汉晋普通出牌请求的主动技次数声明检查。
--
-- 限定范围：仅汉晋扩展自身的正式主主动效果（技能名即骨架名，且不是辅助主动
-- 技、转化技或牌的使用）。辅助/额外发动、翼从逐实例机制、ViewAs、牌使用与其他
-- 模式继续走各自的原有路径。
--
-- 次数来源仍是引擎记录的声明，不新增标记或计数：
--   * 效果（UsableSkill）的 max_use_time：按 usedEffectTimes 比较；
--   * 技能骨架的 max_use_time：按 usedSkillTimes 比较。
-- 两者都只在声明的同一时段（阶段/回合/轮次/本局）内判断。声明可以是数字，也
-- 可以是函数（奋钺按席面势力数、破竹按三陈复原数）。UsableSkill:getMaxUseTime
-- 的无牌路径会原样返回函数字段，因此这里直接解析函数，不拿函数与数字比较。
-- 未声明的技能不在此拦截，继续由既有 can_use/on_use 业务逻辑处理。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Array = require "packages.qiao.pkg.qiao_mode.rules.array_summon"
local M = {}

local function inMode(room)
  return room ~= nil and type(room.getSettings) == "function"
    and Modes.inRoom(room)
end

--- 声明的上限；nil 表示不限制。函数声明的调用签名与引擎骨架一致：
--- (声明所属对象, 使用者)。函数返回 nil 同样视为不限制。
local function limitAt(declarations, scope, owner, player)
  local limit = declarations and declarations[scope]
  if type(limit) == "function" then
    limit = limit(owner, player)
  end
  if type(limit) == "number" then return limit end
  return nil
end

--- 是否为本模块负责的正式主主动效果。
---@param skill Skill?
---@return boolean
function M.appliesTo(skill)
  if skill == nil or not skill:isInstanceOf(ActiveSkill) then return false end
  local skeleton = skill:getSkeleton()
  -- 主效果在 createSkill 时取得骨架名；辅助主动技使用独立名字，不在此列。
  if skeleton == nil or skeleton.name ~= skill.name then return false end
  return type(skill.name) == "string" and skill.name:startsWith("qiao__")
end

--- 该主动技在声明次数内是否已经用尽。
---@param skill Skill?
---@param player Player
---@param room? Room|Client
---@return boolean
function M.exhausted(skill, player, room)
  if player == nil then return false end
  room = room or Fk:currentRoom()
  if not inMode(room) or not M.appliesTo(skill) then return false end

  local skeleton = skill:getSkeleton()
  for scope = Player.HistoryPhase, Player.HistoryGame do
    local effectLimit = limitAt(skill.max_use_time, scope, skill, player)
    if effectLimit ~= nil
      and player:usedEffectTimes(skill.name, scope) >= effectLimit then
      return true
    end
    local skillLimit = limitAt(skeleton.max_use_time, scope, skeleton, player)
    if skillLimit ~= nil
      and player:usedSkillTimes(skeleton.name, scope) >= skillLimit then
      return true
    end
  end
  return false
end

--- 只为单个汉晋房间包装普通出牌回包入口；params 非空的其他询问保持原路径。
---@param room Room
function M.installServer(room)
  if room == nil or room.qiaoActiveSkillLimitsInstalled then return end
  room.qiaoActiveSkillLimitsInstalled = true

  local handleReply = room.handleUseCardReply
  function room:handleUseCardReply(player, data, params)
    if params == nil and type(data) == "table" and type(data.card) == "table" then
      -- 旧版赐面板用旗的名字回包，仍按标记持有者的独立消耗入口校验。
      if data.card.skill == Ci.SKILL then
        data = table.simpleClone(data)
        data.card = table.simpleClone(data.card)
        data.card.skill = Ci.CONSUME
      end
      local skill = Fk.skills[data.card.skill]
      if M.exhausted(skill, player, self) then return nil end
      if data.card.skill == Array.skill and (not skill:canUse(player)
        or #(data.card.subcards or {}) > 0 or #(data.targets or {}) > 0) then return nil end
      if data.card.skill == Ci.CONSUME and (not Ci.canChoose(player, data.interaction_data)
        or #(data.card.subcards or {}) > 0 or #(data.targets or {}) > 0) then return nil end
    end
    return handleReply(self, player, data, params)
  end
end

return M
