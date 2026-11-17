-- 群势力标准包：QUN018 邹氏·祸水的“回合内其他角色不能明置”来源维护。
--
-- 规则基线：docs/development/implementation/generals/qun-standard.md 的 QUN018
-- 条目、docs/rules/generals/qun015-jiling.md 的同类来源写法，以及
-- docs/rules/card-use-targets.md。上游 huoshui 只在 TurnStart 往其他角色写
-- `RevealProhibited-turn` 临时标记，没有“按来源撤销”的能力：祸水在回合中途
-- 明置、随后又被暗置/失去技能时，上游标记会一直留到下一回合开始。
--
-- 本模块以“持有者 + 技能”为一条来源（uid 稳定），每条来源只写自己的
-- `RevealProhibited-turn-<uid>` 表标记；撤销时只清自己那条，不碰其他技能
-- 直接写在 `RevealProhibited` 上的禁明置记录（如上游西兵、尖安）。
-- 标记名含 `-turn`，因此仍随引擎的回合清理一并失效；本模块另在 TurnEnd
-- 主动撤销当前回合来源。
--
-- 死亡时“翻至正面”不是明置（rules/rulebook 死亡流程；ascension 的
-- flip_lord_for_death 直接 changeHero），本模块只写禁明置标记，不拦截该动作。
local H = require "packages.hegemony.util"

local M = {}

--- 房间级规则的技能名；由 mode.lua 在 logic:start 接入（见 qun_control_rule.lua）。
M.RULE_SKILL = "qiao__qun_control_rule"
--- 会提供“回合内禁明置”的来源技能。新增同类来源时在此登记即可。
M.REVEAL_PROVIDERS = { "qiao__skill_qun018_1" }
M.SOURCE_TAG = "qiao_qun_control_reveal_sources"
M.KEY_PREFIX = "RevealProhibited-turn-"
--- 禁明置的位置值：m = 主将，d = 副将。祸水禁止两者。
M.PLACES = { "m", "d" }

local function isServer(room)
  return room ~= nil and type(room.getTag) == "function"
end

--- 稳定来源 uid。同一持有者同一技能只有一条来源，重复登记是幂等更新。
function M.uid(holder, skill)
  return tostring(skill) .. ":" .. tostring(type(holder) == "table" and holder.id or holder)
end

local function keyFor(uid)
  return M.KEY_PREFIX .. uid
end

local function sourceList(room)
  if not isServer(room) then return {} end
  return room:getTag(M.SOURCE_TAG) or {}
end

local function saveSources(room, list)
  room:setTag(M.SOURCE_TAG, next(list) ~= nil and list or nil)
end

local function clearMark(room, player, uid)
  if player == nil then return end
  if player:getMark(keyFor(uid)) ~= 0 then
    room:setPlayerMark(player, keyFor(uid), 0)
  end
end

--- 该角色是否双将均明置（暗置一侧时为 anjiang）。
function M.allGeneralsRevealed(target)
  return target ~= nil
    and target.general ~= nil and target.general ~= "anjiang"
    and target.deputyGeneral ~= nil and target.deputyGeneral ~= "anjiang"
end

--- 暗置目标一张武将牌。复用上游公共入口 doHideGeneral：主副将选择、
--- `__heg_*` 记录、GeneralHidden 事件、统领能力迁移与翼从来源保留都由既有
--- 公共流程结算，本模块不重复实现，也不改动公共暗置接口。
---@return boolean 是否确实暗置了一张武将牌
function M.hideGeneral(room, player, target, skillName)
  if not isServer(room) or player == nil or target == nil then return false end
  if player.dead or target.dead or target:isRemoved() then return false end
  if not M.allGeneralsRevealed(target) then return false end
  H.doHideGeneral(room, player, target, skillName)
  return not M.allGeneralsRevealed(target)
end

--- 来源当前是否生效：持有者存活，是其本人的回合，且祸水已明置。
--- 失去技能 / 暗置武将牌后 hasShownSkill 为假，来源随之撤销。
local function sourceActive(room, holder, skill)
  if holder == nil or holder.dead or not holder:isAlive() or holder:isRemoved() then
    return false
  end
  if room:getCurrent() ~= holder then return false end
  return holder:hasShownSkill(skill) == true
end

--- 重新按来源计算禁明置标记。只写/清本模块自己的
--- `RevealProhibited-turn-<uid>`，不整体重设 `RevealProhibited`。
function M.refresh(room)
  if not isServer(room) then return end
  local list = sourceList(room)
  local current = room:getCurrent()
  local live = {}
  for _, provider in ipairs(M.REVEAL_PROVIDERS) do
    for _, holder in ipairs(room.players) do
      local uid = M.uid(holder, provider)
      live[uid] = true
      local active = current == holder and sourceActive(room, holder, provider)
      local rec = list[uid]
      if active then
        rec = rec or { uid = uid, holder = holder.id, skill = provider, applied = {} }
        list[uid] = rec
        local keep = {}
        for _, target in ipairs(room.players) do
          if target ~= holder and target:isAlive() and not target:isRemoved() then
            keep[target.id] = true
            if target:getMark(keyFor(uid)) == 0 then
              room:setPlayerMark(target, keyFor(uid), table.simpleClone(M.PLACES))
            end
          end
        end
        for pid in pairs(rec.applied or {}) do
          if not keep[pid] then clearMark(room, room:getPlayerById(pid), uid) end
        end
        rec.applied = keep
      elseif rec ~= nil then
        for pid in pairs(rec.applied or {}) do
          clearMark(room, room:getPlayerById(pid), uid)
        end
        list[uid] = nil
      end
    end
  end
  -- 不在当前登记范围内的残留来源（例如来源技能已被移除）一并清掉自己那条；
  -- 其他技能写的 RevealProhibited 标记不受影响。
  for uid, rec in pairs(list) do
    if not live[uid] then
      for pid in pairs(rec.applied or {}) do
        clearMark(room, room:getPlayerById(pid), uid)
      end
      list[uid] = nil
    end
  end
  saveSources(room, list)
end

--- 回合结束：撤销本回合登记的全部来源及其标记。
function M.expireTurn(room)
  if not isServer(room) then return end
  local list = sourceList(room)
  for uid, rec in pairs(list) do
    for pid in pairs(rec.applied or {}) do
      clearMark(room, room:getPlayerById(pid), uid)
    end
  end
  room:setTag(M.SOURCE_TAG, nil)
end

return M
