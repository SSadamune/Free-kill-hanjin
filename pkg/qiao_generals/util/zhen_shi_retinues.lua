-- 阵/势包翼从的公共判次辅助：按实例独立计次，并同步客户端可读的公开摘要。
--
-- 规则依据 docs/rules/commander-retinue.md「拥有数量与独立实例」及
-- docs/rules/zhen-shi-generals.md「实装约束」：
--   * 每份同名翼从技能独立限次，不能用 player:usedSkillTimes(skillName) 这种
--     按技能名合并的历史代替；
--   * 庐江上甲的 X 是“当前存活且未移出游戏、实际拥有该翼从的角色数”，
--     不是该角色的实例总数。
--
-- 服务端逐实例次数保存在 room tag；客户端只读公开 mark：
--   * @@qiao_retinue_public：实例总数与各技能实例数（由 retinue_instances 维护）；
--   * qiao_zhenshi_retinue_used-phase：各技能“逐实例本阶段已用次数”数组。
-- 客户端按当前 X 与这份数组计算可用次数，不用“实例总数 × X - 总用数”，
-- 因此两份实例中一份用完后被移除时，另一份不会被误灰。
-- 公开数组只含数字，不含实例 id、兵种、位置或来源；暗置生命周期仍由正式
-- 接入处理，本模块不自行广播暗实例。
--
-- 同步时机：每次 spend；以及 retinue_instances 的 grant/remove 变更通知
-- （本文件注册监听）。阶段结束由引擎清理 -phase 标记（room.lua:4182-4198）。

local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local M = {}

M.TAG = "qiao_zhenshi_retinue_phase_uses"
-- 阶段令牌：有值时表示本阶段已初始化；-phase 后缀由引擎在阶段结束清理。
M.PHASE_MARK = "qiao_zhenshi_retinue_phase-phase"
-- 公开的逐实例本阶段已用次数：技能名 -> { 实例1已用, 实例2已用, ... }。
M.USED_MARK = "qiao_zhenshi_retinue_used-phase"
-- 庐江的【杀】次数加成由独立静态规则读取公开 -phase 标记，不依赖翼从技能
-- 是否仍在；该规则只在本房间安装。
M.BONUS_SKILL = "qiao__zhen_shi_retinue_bonus"

local function isServerPlayer(player)
  return player ~= nil and player.room ~= nil and type(player.id) == "number"
end

--- 本阶段首次访问时清空上一阶段保留的逐实例计数与公开数组。
local function ensurePhase(player)
  if not isServerPlayer(player) then return end
  if player:getMark(M.PHASE_MARK) ~= 0 then return end
  local reg = player.room:getTag(M.TAG) or {}
  reg[player.id] = nil
  player.room:setTag(M.TAG, reg)
  player.room:setPlayerMark(player, M.USED_MARK, 0)
  player.room:setPlayerMark(player, M.PHASE_MARK, 1)
end

--- 按某技能当前实例重写公开的逐实例已用次数；没有实例时删除该键。
local function publishUsed(player, skillName)
  if not isServerPlayer(player) then return end
  ensurePhase(player)
  local used = player:getMark(M.USED_MARK)
  used = type(used) == "table" and table.simpleClone(used) or {}
  local list = {}
  for _, instance in ipairs(R.instancesForSkill(player, skillName)) do
    table.insert(list, M.phaseUsed(player, instance))
  end
  if #list > 0 then
    used[skillName] = list
  else
    used[skillName] = nil
  end
  player.room:setPlayerMark(player, M.USED_MARK,
    next(used) ~= nil and used or 0)
end

--- 实例增删后由 retinue_instances 的变更通知调用：刷新全部相关技能的
--- 公开数组，并删除已无实例的技能键。
function M.onInstancesChanged(player)
  if not isServerPlayer(player) then return end
  ensurePhase(player)
  local seen = {}
  for _, instance in ipairs(R.instances(player)) do
    seen[instance.skill] = true
  end
  local used = player:getMark(M.USED_MARK)
  used = type(used) == "table" and table.simpleClone(used) or {}
  for skillName in pairs(used) do
    if not seen[skillName] then used[skillName] = nil end
  end
  player.room:setPlayerMark(player, M.USED_MARK,
    next(used) ~= nil and used or 0)
  for skillName in pairs(seen) do
    publishUsed(player, skillName)
  end
end

--- 当前存活且未移出游戏、实际拥有某翼从技能的角色数（X）。
--- 同一角色多份同名实例只计 1；死亡角色不计。
--- @param room Room|ClientRoom|nil
--- @param skillName string
--- @return integer
function M.characterCount(room, skillName)
  if room == nil then return 0 end
  local count = 0
  for _, p in ipairs(room:getPresentPlayers()) do
    if p ~= nil and not p.dead and not p:isRemoved()
      and R.countForSkill(p, skillName) > 0 then
      count = count + 1
    end
  end
  return count
end

--- 公开的逐实例本阶段已用次数数组；客户端可读。缺失位置按 0 处理。
--- @param player Player
--- @param skillName string
--- @return integer[]
function M.publicUsedList(player, skillName)
  local mark = player and player:getMark(M.USED_MARK)
  local list = type(mark) == "table" and mark[skillName] or nil
  local result = {}
  if type(list) == "table" then
    for index, value in ipairs(list) do
      result[index] = type(value) == "number" and value or 0
    end
  end
  return result
end

--- 公开已用总数（诊断/显示用）；客户端可读。
function M.publicUsed(player, skillName)
  local total = 0
  for _, value in ipairs(M.publicUsedList(player, skillName)) do
    total = total + value
  end
  return total
end

--- 某实例本阶段已发动次数（服务端）。
function M.phaseUsed(player, instance)
  if not isServerPlayer(player) or instance == nil then return 0 end
  ensurePhase(player)
  local reg = player.room:getTag(M.TAG) or {}
  local mine = reg[player.id] or {}
  return mine[instance.id] or 0
end

--- 本阶段仍有发动次数的实例（服务端），按登记顺序。
function M.availableInstances(player, skillName, limit)
  if not isServerPlayer(player) or limit == nil or limit <= 0 then return {} end
  ensurePhase(player)
  local result = {}
  for _, instance in ipairs(R.instancesForSkill(player, skillName)) do
    if M.phaseUsed(player, instance) < limit then
      table.insert(result, instance)
    end
  end
  return result
end

--- 服务端按逐实例计数判断；客户端按公开的逐实例已用数组与当前 X 判断。
--- 客户端路径不读 room tag、其他角色手牌或来源信息。
function M.canUse(player, skillName, limit)
  if player == nil or limit == nil or limit <= 0 then return false end
  if isServerPlayer(player) then
    return #M.availableInstances(player, skillName, limit) > 0
  end
  local total = R.countForSkill(player, skillName)
  if total <= 0 then return false end
  local used = M.publicUsedList(player, skillName)
  for index = 1, total do
    if (used[index] or 0) < limit then return true end
  end
  return false
end

--- 记录一份实例本阶段发动一次，并同步公开的逐实例已用数组；同时接实例
--- 模块的实例自身计次（R.recordUse）。
function M.spend(player, instance, skillName)
  if not isServerPlayer(player) or instance == nil then return false end
  ensurePhase(player)
  local reg = player.room:getTag(M.TAG) or {}
  local mine = reg[player.id] or {}
  mine[instance.id] = (mine[instance.id] or 0) + 1
  reg[player.id] = mine
  player.room:setTag(M.TAG, reg)
  publishUsed(player, skillName)
  R.recordUse(instance)
  return true
end

--- 交换/迁移时把某实例 id 的本阶段已用次数从原角色搬到新角色。
--- 同角色主副交换不搬 tag（同一玩家同一 id 已保留），只重建公开数组。
--- @param fromPlayer ServerPlayer
--- @param toPlayer ServerPlayer
--- @param instanceId integer
--- @param skillName string
--- @return boolean moved
function M.movePhase(fromPlayer, toPlayer, instanceId, skillName)
  if not isServerPlayer(fromPlayer) or not isServerPlayer(toPlayer) then
    return false
  end
  ensurePhase(fromPlayer)
  ensurePhase(toPlayer)
  local room = fromPlayer.room
  local reg = room:getTag(M.TAG) or {}
  local fromMine = reg[fromPlayer.id] or {}
  local count = fromMine[instanceId]
  if fromPlayer ~= toPlayer and count ~= nil and count > 0 then
    fromMine[instanceId] = nil
    reg[fromPlayer.id] = fromMine
    local toMine = reg[toPlayer.id] or {}
    toMine[instanceId] = (toMine[instanceId] or 0) + count
    reg[toPlayer.id] = toMine
    room:setTag(M.TAG, reg)
  end
  M.onInstancesChanged(fromPlayer)
  if toPlayer ~= fromPlayer then M.onInstancesChanged(toPlayer) end
  return count ~= nil and count > 0
end

--- 安装庐江【杀】次数加成的独立静态规则。只把该状态技加入当前房间，
--- 不改全局技能表、不按模式全局挂载；正式入口后续接入。
--- @param room Room
function M.ensureBonusRule(room)
  if room == nil or type(room.hasSkill) ~= "function"
    or type(room.addSkill) ~= "function" then
    return
  end
  local skill = Fk.skills[M.BONUS_SKILL]
  if skill == nil then return end
  if not room:hasSkill(M.BONUS_SKILL) then room:addSkill(skill) end
end

-- 实例增减后同步公开数组；模块不依赖本文件，监听只做公开摘要维护。
R.addChangeListener(function(player) M.onInstancesChanged(player) end)

return M
