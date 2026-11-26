-- 六势力变包模式级静态规则：承接已建立持续/延时效果，不依赖来源技能后续是否仍在。
-- 包含：除奸（无距离/无次数与阶段末伤害）、心疾（单人鏖战同步）、约俭（手牌上限初值与弃牌末摸牌）、
-- 武督（公开手牌与实际回合末清除）、凶算（回合末复原限定技）、左慈「魂」离场清理。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local H = require "packages.hegemony.util"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"
local Visibility = require "packages.qiao.pkg.qiao_mode.rules.card_visibility"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Sources = require "packages.qiao.pkg.qiao_mode.rules.skill_sources"
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"

local skill = fk.CreateSkill { name = "qiao__bian_rules" }

local CHUJIAN_TARGET = "qiao_han023_chujian-phase"
local CHUJIAN_DELAY = "qiao_han023_chujian_delay-phase"
local YUEJIAN_MARK = "qiao_wei022_yuejian-turn"
local XIONGSUAN_TAG = "qiao_qun022a_xiongsuan_pending"

local function inQiao(room)
  return room ~= nil and type(room.getSettings) == "function" and Modes.inRoom(room)
end

local function isSlash(card)
  return card ~= nil and card.trueName == "slash"
end

local function hasChujianTarget(from, to)
  if from == nil or to == nil then return false end
  local list = from:getMark(CHUJIAN_TARGET)
  return type(list) == "table" and table.contains(list, to.id)
end

-- 1. 除奸：本出牌阶段对伍琼&种辑使用【杀】无距离与次数限制，且仅对除奸目标出杀不计入次数。
skill:addEffect("targetmod", {
  bypass_distances = function(self, player, card_skill, card, to)
    return isSlash(card) and hasChujianTarget(player, to)
  end,
  bypass_times = function(self, player, card_skill, scope, card, to)
    return scope == Player.HistoryPhase and isSlash(card) and hasChujianTarget(player, to)
  end,
})

skill:addEffect(fk.PreCardUse, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if target ~= player or not isSlash(data.card) or not data.tos or #data.tos == 0 then return false end
    local list = player:getMark(CHUJIAN_TARGET)
    if type(list) ~= "table" or #list == 0 then return false end
    return table.every(data.tos, function(to) return table.contains(list, to.id) end)
  end,
  on_refresh = function(self, event, target, player, data)
    data.extraUse = true
  end,
})

skill:addEffect(fk.EventPhaseEnd, {
  global = true,
  is_delay_effect = true,
  mute = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.phase ~= Player.Play then return false end
    local pending = player:getMark(CHUJIAN_DELAY)
    return type(pending) == "table" and #pending > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local pending = player:getMark(CHUJIAN_DELAY)
    room:setPlayerMark(player, CHUJIAN_DELAY, 0)
    if type(pending) ~= "table" then return end
    for _, sourceId in ipairs(pending) do
      local source = room:getPlayerById(sourceId)
      if source ~= nil and RemovedTargets.isPresent(source) and RemovedTargets.isPresent(player) then
        room:damage {
          from = source,
          to = player,
          damage = 1,
          skillName = "qiao__skill_han023_1",
        }
      end
    end
  end,
})

-- 2. 心疾：单人鏖战状态随明暗置、获得/失去技能、死亡与回合同步。
-- 用 hasShownSkill(..., true) 区分“将牌仍明置但技能暂时无效”与“暗置或真正失去来源”：
-- 临时无效期间保留来源登记（由 only_as 动态暂停），恢复有效时即可立即恢复个人鏖战。
local function syncXinji(room, player)
  if not inQiao(room) or player == nil then return end
  local hasShownSource = not player.dead and player:hasShownSkill("qiao__skill_han023_2", true)
  BattleRoyal.syncPersonal(room, player, "qiao__skill_han023_2", hasShownSource)
end

local xinjiSyncSpec = {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and inQiao(player.room)
  end,
  on_refresh = function(self, event, target, player)
    syncXinji(player.room, player)
  end,
}

for _, ev in ipairs({
  fk.GeneralRevealed, fk.GeneralHidden, fk.GeneralShown,
  fk.EventAcquireSkill, fk.EventLoseSkill, fk.Death, fk.TurnStart,
}) do
  skill:addEffect(ev, xinjiSyncSpec)
end

-- 3. 约俭：修改本回合手牌上限初值为体力上限；弃牌阶段结束时未弃牌摸 1 张。
skill:addEffect("maxcards", {
  fixed_func = function(self, player)
    if player ~= nil and player:getMark(YUEJIAN_MARK) > 0 then
      return player.maxHp
    end
  end,
})

skill:addEffect(fk.EventPhaseEnd, {
  global = true,
  is_delay_effect = true,
  mute = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.phase ~= Player.Discard or player.dead or player:isRemoved() then
      return false
    end
    if player:getMark(YUEJIAN_MARK) <= 0 then return false end
    local discarded = false
    player.room.logic:getEventsOfScope(GameEvent.MoveCards, 1, function(e)
      for _, move in ipairs(e.data or {}) do
        -- 依 rulebook/terms/card-op-terms/discard.md：按弃置操作的实际执行者判断（他人弃置其牌不算其弃置牌）。
        if move.proposer == player and move.moveReason == fk.ReasonDiscard and #(move.moveInfo or {}) > 0 then
          discarded = true
          return true
        end
      end
      return false
    end, Player.HistoryPhase)
    return not discarded
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    if RemovedTargets.isPresent(player) then
      player:drawCards(1, "qiao__skill_wei022_2")
    end
  end,
})

-- 4. 武督：手牌对所有角色可见，直至目标角色实际回合结束时清除（叠置跳过回合自动顺延）。
skill:addEffect("visibility", Visibility.wudu)

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and player:getMark(Visibility.WUDU_OPEN) > 0
  end,
  on_refresh = function(self, event, target, player)
    player.room:setPlayerMark(player, Visibility.WUDU_OPEN, 0)
  end,
})

-- 5. 凶算：当前回合结束时复原目标一个已发动过的明置限定技（含独立已用标记与限定翼从实例）。
local function customLimitedUsedMarks(name)
  local skel = Fk.skill_skels[name]
  if skel ~= nil and type(skel.qiao_limited_used_marks) == "table" then
    return skel.qiao_limited_used_marks
  end
  return nil
end

local function hasCustomLimitedUsed(target, name)
  local marks = customLimitedUsedMarks(name)
  if marks == nil then return false end
  for _, mark in ipairs(marks) do
    local val = target:getMark(mark)
    if type(val) == "number" and val > 0 then return true end
    if type(val) == "table" and next(val) ~= nil then return true end
    if type(val) == "string" and val ~= "" then return true end
  end
  return false
end

local function usedLimitedSkills(target)
  local choices, retinueSet = {}, {}
  if target == nil or target.dead then return choices, retinueSet end
  for _, s in ipairs(target:getAllSkills()) do
    local skel = s:getSkeleton()
    local name = skel and skel.name or s.name
    if Sources.isGeneralSkill(s, target) and not Bian.isLimitedRetinueSkill(name)
      and s:hasTag(Skill.Limited) and target:hasShownSkill(name)
      and (target:usedSkillTimes(name, Player.HistoryGame) > 0 or hasCustomLimitedUsed(target, name)) then
      table.insertIfNeed(choices, name)
    end
  end
  if #Bian.usedLimitedRetinues(target, Bian.FEIXIONG_SKILL) > 0 then
    table.insertIfNeed(choices, Bian.FEIXIONG_SKILL)
    retinueSet[Bian.FEIXIONG_SKILL] = true
  end
  return choices, retinueSet
end

skill:addEffect(fk.TurnEnd, {
  global = true,
  is_delay_effect = true,
  mute = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    local pending = player.room:getTag(XIONGSUAN_TAG)
    return type(pending) == "table" and #pending > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local pending = room:getTag(XIONGSUAN_TAG)
    room:setTag(XIONGSUAN_TAG, nil)
    if type(pending) ~= "table" then return end
    for _, rec in ipairs(pending) do
      local source = room:getPlayerById(rec.source_id)
      local dest = room:getPlayerById(rec.target_id)
      if source ~= nil and not source.dead and dest ~= nil and not dest.dead then
        local choices, retinueSet = usedLimitedSkills(dest)
        if #choices > 0 then
          local chosen = #choices == 1 and choices[1] or room:askToChoice(source, {
            choices = choices,
            skill_name = "qiao__skill_qun022a_1",
            prompt = "#qiao__skill_qun022a_1-reset::" .. dest.id,
            cancelable = false,
          })
          if chosen ~= nil and table.contains(choices, chosen) then
            if retinueSet[chosen] then
              Bian.resetOneLimitedRetinue(dest, chosen)
              dest:setSkillUseHistory(chosen, 0, Player.HistoryGame)
              room:updateAllLimitSkillUI(dest)
            else
              dest:setSkillUseHistory(chosen, 0, Player.HistoryGame)
              Exchange.resetSkillGameHistory(room, dest, chosen)
              local marks = customLimitedUsedMarks(chosen)
              if marks ~= nil then
                for _, mark in ipairs(marks) do
                  room:setPlayerMark(dest, mark, 0)
                end
              end
              room:updateAllLimitSkillUI(dest)
            end
          end
        end
      end
    end
  end,
})

-- 5b. 挠袭历史目标记录：记录每张牌曾指定过的全部目标（含随后被【谦逊】等取消的目标）。
local function recordEverTargets(use, targets)
  if use == nil then return end
  use.extra_data = use.extra_data or {}
  use.extra_data.qiao_ever_targets = use.extra_data.qiao_ever_targets or {}
  for _, p in ipairs(targets or {}) do
    if p ~= nil and p.id ~= nil then
      use.extra_data.qiao_ever_targets[p.id] = true
    end
  end
end

skill:addEffect(fk.AfterCardTargetDeclared, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and inQiao(player.room) and data ~= nil and data.tos ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    recordEverTargets(data, data.tos)
  end,
})

skill:addEffect(fk.TargetSpecifying, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and inQiao(player.room) and data ~= nil and data.use ~= nil and data.to ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    recordEverTargets(data.use, { data.to })
  end,
})

-- 6. 左慈「魂」：死亡掩埋或左慈武将牌被移除/变更离场时，剩余「魂」置入武将弃牌堆。
-- 每次出牌请求只同步池中是否仍有可用武将，不公开候选名称或暗将身份。
skill:addEffect(fk.StartPlayCard, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and inQiao(player.room)
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    local available = Bian.canDrawSoul(room)
    if room:getBanner(Bian.ZUOCI_POOL_AVAILABLE) ~= available then
      room:setBanner(Bian.ZUOCI_POOL_AVAILABLE, available)
    end
  end,
})

skill:addEffect(fk.BuryVictim, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and inQiao(player.room)
  end,
  on_refresh = function(self, event, target, player)
    Bian.discardPlayerZuociSouls(player.room, player)
  end,
})

skill:addEffect(H.GeneralRemoved, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and inQiao(player.room)
  end,
  on_refresh = function(self, event, target, player)
    Bian.cleanupDetachedZuociCards(player.room)
  end,
})

skill:addEffect(fk.EventLoseSkill, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and inQiao(player.room)
      and data ~= nil and data.skill ~= nil and data.skill.name == Bian.ZUOCI_SKILL
  end,
  on_refresh = function(self, event, target, player)
    Bian.cleanupDetachedZuociCards(player.room)
  end,
})

Fk:loadTranslationTable {
  ["qiao__bian_rules"] = "变包规则",
  ["@qiao_jin018_wudu"] = "武督明牌",
  ["#qiao__skill_qun022a_1-reset"] = "凶算：选择复原 %dest 的一个限定技",
}

return skill
