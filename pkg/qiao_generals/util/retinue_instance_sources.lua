-- 实体翼从位置 → 实例登记的同步接线。
--
-- 目标：正式取得实体主/副位置的翼从时，由一个稳定 origin=entity 实例承载；
-- 普通士兵不是翼从；同一兵种两个位置算两份；重复明置/属性刷新不重复添加；
-- 位置变化/移除只撤对应实体实例，额外 origin=granted/shared 实例保留。
--
-- 正式入口：模式创建后（或 GameStart 前）调用 M.ensureRule(room)，只对
-- qiao_heg_mode 安装 #qiao_retinue_instance_sources 规则技能并做一次全量
-- 同步。之后 GeneralShown/Hidden、AfterPropertyChange、GeneralRemoved、
-- GeneralTransformed 与 Exchange 完成监听都会幂等同步。不要在其他模式安装。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Z = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_retinues"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"

local M = {}

M.RULE_SKILL = "#qiao_retinue_instance_sources"
M.EXCHANGE_TAG = "qiao_retinue_exchange_in_progress"

local mapping = {}

local function isQiaoRoom(room)
  if room == nil or type(room.getSettings) ~= "function" then return false end
  local mode = room:getSettings("gameMode")
  if mode == nil and type(room.settings) == "table" then
    mode = room.settings.gameMode
  end
  return Modes.isHanjin(mode)
end

local function isExchanging(room)
  return room ~= nil and room:getTag(M.EXCHANGE_TAG) == true
end

--- 显式登记兵种 → 唯一翼从技能定义。正式接入登记新翼从时调用；未登记时
--- 回退到该翼从武将的唯一技能（现有正式翼从均为一技能）。
--- @param general string 翼从兵种武将名
--- @param skillName? string
--- @return string? skillName
function M.registerRetinue(general, skillName)
  assert(type(general) == "string" and Commander.isRetinue(general),
    "retinue_instance_sources: not a retinue general: " .. tostring(general))
  if skillName == nil then
    local g = Fk.generals[general]
    local names = g and g:getSkillNameList() or {}
    if #names == 1 then skillName = names[1] end
  end
  assert(type(skillName) == "string" and Fk.skills[skillName] ~= nil,
    "retinue_instance_sources: missing retinue skill for " .. general)
  assert(Fk.skills[skillName]:isPlayerSkill(), "Retinue skill must be a player skill: " .. skillName)
  mapping[general] = skillName
  return skillName
end

--- @param general string
--- @return string?
function M.skillFor(general)
  if mapping[general] ~= nil then return mapping[general] end
  if not Commander.isRetinue(general) then return nil end
  local g = Fk.generals[general]
  local names = g and g:getSkillNameList() or {}
  if #names == 1 then
    mapping[general] = names[1]
    return names[1]
  end
  return nil
end

local function positionGeneral(player, isDeputy)
  return isDeputy and player.deputyGeneral or player.general
end

--- 同步一个实体位置；普通士兵/暗置/非翼从撤掉该位置实体实例。
--- @param player ServerPlayer
--- @param isDeputy boolean
--- @param force? boolean 交换迁移内部强制同步
--- @return boolean hasEntity
function M.syncPosition(player, isDeputy, force)
  if player == nil or player.room == nil then return false end
  if not force and isExchanging(player.room) then return false end
  local general = positionGeneral(player, isDeputy)
  -- 暗置/重明置的中间态：实际记录仍是翼从兵种时，不能因公开名为
  -- “anjiang”而删除实体；等待 GeneralRevealed/稳定属性事件再同步。
  if general == nil or general == "" or general == "anjiang" then
    local hidden = player:getMark(isDeputy and "__heg_deputy" or "__heg_general")
    if type(hidden) == "string" and Commander.isRetinue(hidden) then return false end
    -- 重明置的 changeHero 中间态可能尚未恢复 general / __heg_*；已有实体
    -- 身份时不能按空公开位置删除，等待 GeneralRevealed/稳定属性事件。
    if #R.entityInstances(player, isDeputy) > 0 then return false end
  end
  local skillName = type(general) == "string" and M.skillFor(general) or nil
  if skillName == nil then
    R.removeEntity(player, isDeputy)
    return false
  end
  R.syncEntity(player, isDeputy, general, skillName)
  return true
end

--- @param player ServerPlayer
--- @param force? boolean
function M.syncPlayer(player, force)
  if player == nil or player.room == nil then return end
  if not force and isExchanging(player.room) then return end
  M.syncPosition(player, false, force)
  M.syncPosition(player, true, force)
end

--- @param room Room
--- @param force? boolean
function M.syncRoom(room, force)
  if room == nil then return end
  if not force and isExchanging(room) then return end
  for _, player in ipairs(room.players) do M.syncPlayer(player, force) end
end

--- 正式入口：只对汉晋房间安装同步规则并做一次全量同步。
--- @param room Room
--- @return boolean installed
function M.ensureRule(room)
  if not isQiaoRoom(room) then return false end
  local skill = Fk.skills[M.RULE_SKILL]
  if skill == nil then return false end
  if not room:hasSkill(M.RULE_SKILL) then room:addSkill(skill) end
  M.syncRoom(room)
  return true
end

-- Exchange 模块在双方位置全部更新后才回调；先迁移实体实例 id/uses/阶段账本，
-- 再做幂等公开同步。交换中只搬 origin=entity 的这一份牌，额外/共享来源不搬。
local ok, Exchange = pcall(require,
  "packages.qiao.pkg.qiao_mode.rules.general_exchange")

--- 在 Exchange completion 中迁移实体实例。
--- 必须先一次性捕获来源实例，再逐项 remove/grant/回填 id，避免同名两位置
--- 交换时把刚搬入的实例误当来源。阶段账本按 instance id 迁移到新角色。
--- @param room Room
--- @param context table
--- @return boolean
function M.migrateExchange(room, context)
  if not isQiaoRoom(room) or context == nil then return false end
  local plans = {}
  for _, move in ipairs(context.moved or {}) do
    if move.retinue and move.from ~= nil and move.to ~= nil then
      local fromPlayer = move.from.player
      local toPlayer = move.to.player
      local fromDeputy = move.from.isDeputy == true
      local instance = table.find(R.entityInstances(fromPlayer, fromDeputy),
        function(item) return item.general == move.general end)
      if instance ~= nil then
        table.insert(plans, {
          instance = instance,
          fromPlayer = fromPlayer,
          fromDeputy = fromDeputy,
          toPlayer = toPlayer,
          toDeputy = move.to.isDeputy == true,
          general = move.general,
          skill = instance.skill,
        })
      end
    end
  end
  if #plans == 0 then
    M.syncRoom(room, true)
    return false
  end

  for _, plan in ipairs(plans) do
    local oldId = plan.instance.id
    local oldUses = plan.instance.uses or 0
    if oldId ~= nil and R.get(plan.fromPlayer, oldId) ~= nil then
      R.remove(plan.fromPlayer, oldId)
      local moved = R.grant(plan.toPlayer, {
        general = plan.general,
        skill = plan.skill,
        origin = "entity",
        position = plan.toDeputy and "deputy" or "main",
        skillLost = plan.instance.skillLost,
      })
      -- 实例身份跟牌：保留原 id 与整局 uses，不用姓名/位置作副本唯一键。
      for key,value in pairs(plan.instance) do
        if key ~= "position" and key ~= "origin" and key ~= "shared_from" then moved[key]=value end
      end
      moved.id = oldId
      moved.uses = oldUses
      if plan.fromPlayer == plan.toPlayer then
        Z.onInstancesChanged(plan.toPlayer)
      else
        Z.movePhase(plan.fromPlayer, plan.toPlayer, oldId, plan.skill)
      end
    end
  end
  M.syncRoom(room, true)
  return true
end

if ok then
  -- 翼从在牌面保留技能说明。对局由实例提供技能，避免换位或刷新时重复授技。
  Exchange.registerSkillProviderFilter(function(room, general, skillName)
    if isQiaoRoom(room) and mapping[general] == skillName then return false end
  end)
end

-- 交换中间态保护：Exchange.exchange 内部会先 setPosition，再由 Commander
-- 完成完成回调中的白兵转换；这些步骤可能触发 GeneralShown/AfterPropertyChange，
-- 若此时按新位置同步会提前删除旧实体。只在汉晋房间、仅在 exchange 调用期间
-- 设置房间 tag；完成后清掉，不是跨模式全局监听。
if ok and type(Exchange.exchange) == "function"
  and not Exchange.__qiao_retinue_guard then
  local originalExchange = Exchange.exchange
  Exchange.__qiao_retinue_guard = true
  Exchange.exchange = function(room, first, second, options)
    if not isQiaoRoom(room) then
      return originalExchange(room, first, second, options)
    end
    room:setTag(M.EXCHANGE_TAG, true)
    local okCall, a, b = pcall(originalExchange, room, first, second, options)
    room:setTag(M.EXCHANGE_TAG, nil)
    if not okCall then error(a, 0) end
    for _,player in ipairs(room.players) do R.notifyChange(player) end
    return a, b
  end
end

if ok and Exchange.addCompletionListener then
  Exchange.addCompletionListener(function(room, context)
    if not isQiaoRoom(room) then return end
    -- 只有正式入口已安装同步规则时才处理；避免在未接线的房间/套件中
    -- 自动创建实例或安装规则。
    if not room:hasSkill(M.RULE_SKILL) then return end
    M.migrateExchange(room, context)
  end)
end

return M
