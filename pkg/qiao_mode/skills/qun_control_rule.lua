-- 群势力标准包：QUN018 邹氏·祸水的回合内禁明置房间规则。
--
-- 安装方式：仅由 mode.lua 在 logic:start 时 `room:addSkill("qiao__qun_control_rule")`
-- 接入（接线由负责人完成）。**不设 `global = true`**：引擎
-- Engine:addSkill 会把 `global` 技能放进 Fk.global_trigger
-- （lua/core/engine.lua:47-56），GameLogic:prepareGlobalSkills 又会把其中每个
-- 触发技加进**所有模式、所有房间**的触发表（ltk/server/gamelogic.lua:80-84）。
-- 本技能是汉晋房间的局部来源维护，不能走这条全局注入路径，否则会污染
-- 非汉晋房间的触发顺序与请求回复。文档/接线声明与本文件保持一致。
--
-- 不进入技能发动流程：
--   * 只登记 can_refresh / on_refresh，不写 can_trigger / on_cost / on_use。
--     因此 SkillSkeleton 会把 triggerable 设为 Util.FalseFunc
--     （ltk/core/skill_skeleton.lua:350-353），不会走 TriggerSkill:doCost、
--     room:useSkill/SkillEffect，不写技能发动历史、不参与玩家触发选择、
--     不消费任何请求回复。
--   * 维护发生在 TriggerEvent:exec 的 refresh 循环
--     （ltk/core/trigger_event.lua:88-96），该循环在同一事件的所有 trigger 之前
--     执行。因此 TurnStart 的禁明置状态一定早于 heg_rule 的回合开始明置询问
--     （后者是 TurnStart trigger，priority 100）；引擎的 clearHistory 又先于
--     TurnStart（server/events/gameflow.lua:265），旧 -turn 标记已清除。
--
-- 只监听会改变“来源或有效状态”的事件：
--   * TurnStart / TurnEnd：回合归属变化，重建/清理本模块自己的来源；
--   * GeneralShown / GeneralRevealed / GeneralHidden：仅当明置/暗置的武将牌
--     确实带有来源技能时才维护，其他角色的明置不触发维护；
--   * EventLoseSkill：仅当真正失去来源技能时维护；
--   * Death：持有者死亡时撤销来源；
--   * AfterPropertyChange：仅换将（general/deputyGeneral 变化）时维护。
--   snapshot 再按“当前回合角色 + 每名持有者存活/明置 + 实际禁明置标记”比较，
--   相同则直接返回，不做任何标记或 tag 写入。
--
-- 规则语义：祸水持有者自己的回合内，其他角色不能明置其武将牌。中途明置
-- 后即时生效；持有者暗置或失去祸水时撤销当前来源；TurnEnd 只清理本模块
-- 自己的来源，不改其他技能写入的 RevealProhibited；只写禁明置标记，不拦截
-- 死亡时“翻至正面”（那不是明置）。
local Q = require "packages.qiao.pkg.qiao_generals.util.qun_control"

local skill = fk.CreateSkill {
  name = Q.RULE_SKILL,
  tags = { Skill.Compulsory },
}

--- 上次维护后的状态快照。名称不含 -turn，避免被回合清理连带删除。
local SIG_TAG = "qiao_qun_control_signature"

--- 这张武将牌是否带有本模块的来源技能。
local function generalProvides(name)
  if type(name) ~= "string" then return false end
  local general = Fk.generals[name]
  if general == nil then return false end
  local skills = general:getSkillNameList(true)
  for _, provider in ipairs(Q.REVEAL_PROVIDERS) do
    if table.contains(skills, provider) then return true end
  end
  return false
end

--- 明置数据为 {m=..., d=...}，暗置数据为武将牌名字符串。
local function generalEventRelevant(data)
  if type(data) == "string" then return generalProvides(data) end
  if type(data) == "table" then
    return generalProvides(data.m) or generalProvides(data.d)
  end
  return false
end

--- EventLoseSkill 的 data.skill 可能是技能对象或技能名。
local function lostProviderSkill(data)
  local lost = type(data) == "table" and data.skill or nil
  local name = type(lost) == "table" and lost.name or lost
  return table.contains(Q.REVEAL_PROVIDERS, name)
end

--- 与 Q.refresh 判定相关的全部可见状态：
---   当前回合角色、每名持有者是否存活/是否当前回合/祸水是否明置，
---   以及每个“持有者 -> 其他角色”的实际禁明置标记是否存在。
local function snapshot(room)
  local current = room:getCurrent()
  local currentId = current and current.id or 0
  local parts = { tostring(currentId) }
  for _, provider in ipairs(Q.REVEAL_PROVIDERS) do
    for _, holder in ipairs(room.players) do
      local key = Q.KEY_PREFIX .. Q.uid(holder, provider)
      local alive = holder:isAlive() and not holder:isRemoved()
      local shown = holder:hasShownSkill(provider) == true
      local marks = {}
      for _, target in ipairs(room.players) do
        table.insert(marks, target:getMark(key) ~= 0 and "1" or "0")
      end
      table.insert(parts, string.format("%d:%s:%s:%s:%s",
        holder.id, alive and "1" or "0", currentId == holder.id and "1" or "0",
        shown and "1" or "0", table.concat(marks)))
    end
  end
  return table.concat(parts, "|")
end

--- 状态未变化时直接返回。变化时交给 Q.refresh 按来源重建，并记录维护后的状态。
local function maintain(room)
  local state = snapshot(room)
  if room:getTag(SIG_TAG) == state then return end
  Q.refresh(room)
  room:setTag(SIG_TAG, snapshot(room))
end

--- refresh 阶段每个事件只对事件目标执行一次；真正是否读写由 snapshot 决定。
local function canRefresh(self, event, target, player)
  return target == player
end

local function onRefresh(self, event, target, player)
  maintain(player.room)
end

-- 回合开始：refresh 循环先于本事件所有 trigger，明置询问开始前状态已就绪。
skill:addEffect(fk.TurnStart, {
  priority = 200,
  can_refresh = canRefresh,
  on_refresh = onRefresh,
})

-- 回合结束：只撤销本模块自己的来源，不动其他技能的 RevealProhibited。
skill:addEffect(fk.TurnEnd, {
  can_refresh = canRefresh,
  on_refresh = function(self, event, target, player)
    local room = player.room
    if room:getTag(Q.SOURCE_TAG) ~= nil then Q.expireTurn(room) end
    room:setTag(SIG_TAG, snapshot(room))
  end,
})

-- 明置/暗置：只有带来源技能的武将牌变化才维护，其他角色的明置不触发。
-- 另外保留“当前确实亮出该来源技能”的兜底，覆盖技能由非武将来源取得但已
-- 明置的既有状态（例如换将后重新挂载、测试夹具），避免漏掉撤销。
local function playerShowsProvider(player)
  for _, provider in ipairs(Q.REVEAL_PROVIDERS) do
    if player:hasShownSkill(provider) then return true end
  end
  return false
end

local function canRefreshGeneral(self, event, target, player, data)
  return target == player
    and (generalEventRelevant(data) or playerShowsProvider(player))
end

skill:addEffect(fk.GeneralShown, {
  can_refresh = canRefreshGeneral,
  on_refresh = onRefresh,
})
skill:addEffect(fk.GeneralRevealed, {
  can_refresh = canRefreshGeneral,
  on_refresh = onRefresh,
})
skill:addEffect(fk.GeneralHidden, {
  can_refresh = canRefreshGeneral,
  on_refresh = onRefresh,
})

-- 失技：只有真正失去来源技能时维护。
skill:addEffect(fk.EventLoseSkill, {
  can_refresh = function(self, event, target, player, data)
    return target == player and lostProviderSkill(data)
  end,
  on_refresh = onRefresh,
})

-- 死亡：持有者（或带标记者）离场后撤销来源。
skill:addEffect(fk.Death, {
  can_refresh = canRefresh,
  on_refresh = onRefresh,
})

-- 换将等属性变化：只有主/副将身份变化才维护；势力、性别、身份变化不触发。
skill:addEffect(fk.AfterPropertyChange, {
  can_refresh = function(self, event, target, player, data)
    if target ~= player or type(data) ~= "table" then return false end
    return data.general ~= nil or data.deputyGeneral ~= nil
  end,
  on_refresh = onRefresh,
})

Fk:loadTranslationTable {
  [Q.RULE_SKILL] = "汉晋祸水规则",
}

return skill
