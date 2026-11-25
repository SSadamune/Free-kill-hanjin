-- 六势力变包模式级静态规则：承接已建立持续/延时效果，不依赖来源技能后续是否仍在。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"
local Visibility = require "packages.qiao.pkg.qiao_mode.rules.card_visibility"

local skill = fk.CreateSkill { name = "qiao__bian_rules" }

local CHUJIAN_TARGET = "qiao_han023_chujian-phase"
local CHUJIAN_DELAY = "qiao_han023_chujian_delay-phase"

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

Fk:loadTranslationTable {
  ["qiao__bian_rules"] = "变包规则",
  ["@qiao_jin018_wudu"] = "武督明牌",
}

return skill
