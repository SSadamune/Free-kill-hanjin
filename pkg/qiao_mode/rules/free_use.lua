-- 自由用牌请求（“可以使用一张牌”）的公共入口。
--
-- 与响应窗口不同，自由用牌没有可响应的牌：请求必须声明
-- extra_data.not_passive，锁定引擎 ReqUseCard:cardFeasible 才不会把【闪】
-- 【无懈可击】等被动牌当成可选牌。Room:askToUseCard 只返回待执行
-- UseCardData，服务端拿到返回值后仍须按本次请求复核：pattern、被动牌、禁止
-- 与目标都可能是伪造或已失效的。复核失败按放弃处理，不产生用牌。
--
-- 普通转化牌由服务端 handleUseCardReply 用对应 view_as 构造；此请求返回时
-- Fk.currentResponsePattern 已清空，效果型虚拟牌也未必来自 ViewAsSkill，因此
-- 不在这里重新按客户端按钮条件筛来源。只保留不受执行端影响的被动/禁止/
-- canUse/目标复核；汉晋“只能当”转化仍走既有 only_as 来源复核。
--
-- 目标复核复用 card_use_targets 的选择阶段入口，保留固定目标（桃、无中、
-- 装备、AOE）与合法转化牌的原有目标规则；不在这里另写一套目标算法。
local OnlyAs = require "packages.qiao.pkg.qiao_mode.rules.only_as"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local M = {}

--- 复核一张自由用牌请求返回的待执行使用数据。
---@param room Room
---@param player ServerPlayer
---@param use UseCardDataSpec
---@param pattern string
---@param extra_data table
---@return boolean, string?
function M.validate(room, player, use, pattern, extra_data)
  if use == nil or use.card == nil or player == nil then return false, "missing-use" end
  local card = use.card
  if use.from ~= player then return false, "wrong-user" end
  if pattern ~= nil and not card:matchVSPattern(pattern) then return false, "use-pattern" end
  -- 自由用牌不是响应窗口：即使请求方伪造了 extra_data，服务端也不接受被动牌。
  if card.is_passive or use.toCard ~= nil then return false, "passive-card" end
  if player:prohibitUse(card) or OnlyAs.isForbidden(player, card) then
    return false, "prohibited-card"
  end

  if card:isVirtual() and card:getMark(OnlyAs.CARD_MARK) ~= 0 then
    -- 汉晋“只能当”转化牌：来源、转换目标、pattern、禁止与目标由既有
    -- validateUse 全套复核，并写下本次服务端验证记录。普通 view_as 或效果型
    -- 虚拟牌没有这类服务端来源记录，不在此另做来源/按钮条件复筛。
    local ok, reason = OnlyAs.validateUse(room, player, use, {
      mode = "use",
      pattern = pattern,
      extra_data = extra_data,
    })
    if not ok then return false, reason or "illegal-conversion" end
    return true
  end

  if not player:canUse(card, extra_data) then return false, "cannot-use" end
  -- 选择阶段的目标规则：固定目标牌允许显式空列表（由引擎补全），显式提交时
  -- 必须与固定/可选目标集合一致；普通牌按实际 CardSkill 的 targetFilter、
  -- 数量与 feasible 复核。
  return C.validateTargets(room, player, use, nil, "selection", {
    extra_data = extra_data,
  })
end

--- 询问玩家自由使用一张牌。返回值仍是待执行数据，由调用方执行一次。
---@param player ServerPlayer
---@param params AskToUseCardParams
---@return UseCardDataSpec?
function M.askToUseCard(player, params)
  assert(OnlyAs.isServer(player and player.room),
    "Free-use requests are server-only")
  params = params or {}
  local ask = table.simpleClone(params)
  ask.pattern = params.pattern or "."
  ask.extra_data = params.extra_data and table.simpleClone(params.extra_data) or {}
  ask.extra_data.not_passive = true
  local use = player.room:askToUseCard(player, ask)
  if use == nil or use.card == nil then return nil end
  local ok = M.validate(player.room, player, use, ask.pattern, ask.extra_data)
  if not ok then return nil end
  return use
end

return M
