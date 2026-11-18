-- 移出游戏（引擎 PlayerRemoved 标记）的统一规则层。
--
-- 【调虎离山】等效果只建立带 "-turn" 后缀的 PlayerRemoved 标记；引擎已用该
-- 标记处理距离、座次与下家。本规则补齐其余“视为不存在”的主要牌与技能交互：
-- 不能使用牌、不是牌的合法目标、体力值不会改变，并在回合结束时移回。
--
-- 接入：mode.lua 于 logic:start 执行
--   self.room:addSkill("qiao__removed_player_rule")
-- 触发技需要 global 才能作为房间级规则接收事件，因此在回调内按 gameMode 守卫，
-- 不影响其他模式。
local H = require "packages.hegemony.util"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
-- 大小势力/玉玺公共查询适配：本文件由 qiao_mode 技能目录在客户端与服务端
-- 一并加载，因此这里安装一次即可覆盖两端；mode.lua 另有正式接线兜底。
local KingdomSize = require "packages.qiao.pkg.qiao_mode.rules.kingdom_size"
KingdomSize.install()

-- 引擎原生前置守卫：移出期间技能对本人不可发动。ActiveSkill/ViewAsSkill 的
-- canUse 与默认 TriggerSkill 的 hasSkill 都经过 Skill:isEffectable；牌技能仍由
-- prohibit_use 拦截，且本函数对 CardSkill 保持原行为。
local Skill = require "ltk.core.skill"
if not Skill.__qiao_removed_guard then
  Skill.__qiao_removed_guard = true
  local originalIsEffectable = Skill.isEffectable
  function Skill:isEffectable(player)
    local room = Fk:currentRoom()
    if RemovedTargets.inMode(room) and RemovedTargets.isRemoved(player) then
      return false
    end
    return originalIsEffectable(self, player)
  end
end

local skill = fk.CreateSkill { name = "qiao__removed_player_rule" }

local REMOVED_TURN = MarkEnum.PlayerRemoved .. "-turn"
local REMOVED_UI = "@@lure_tiger-turn"

local inQiaoMode = RemovedTargets.inMode
local isRemoved = RemovedTargets.isRemoved

-- 不能使用牌；不能打出牌；不能成为牌的目标；不能被要求为助战等效果弃牌。
skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    return isRemoved(player)
  end,
  prohibit_response = function(self, player, card)
    return isRemoved(player)
  end,
  is_prohibited = function(self, from, to, card)
    return isRemoved(to)
  end,
  prohibit_discard = function(self, player, card)
    return isRemoved(player)
  end,
})

local function preventHpChange(event, prevent)
  skill:addEffect(event, {
    global = true,
    mute = true,
    can_refresh = function(self, event, target, player)
      return target == player and inQiaoMode(player.room) and isRemoved(player)
    end,
    on_refresh = function(self, event, target, player, data)
      prevent(data)
    end,
  })
end

preventHpChange(fk.PreHpLost, function(data) data:preventHpLost() end)
preventHpChange(fk.PreHpRecover, function(data) data:preventRecover() end)
preventHpChange(fk.DamageInflicted, function(data) data:preventDamage() end)

-- 兜底：直接 changeHp 的路径未必经过 PreHpLost / PreHpRecover。
skill:addEffect(fk.BeforeHpChanged, {
  global = true,
  mute = true,
  can_refresh = function(self, event, target, player)
    return target == player and inQiaoMode(player.room) and isRemoved(player)
  end,
  on_refresh = function(self, event, target, player, data)
    data.num = 0
    data.shield_lost = 0
    data.prevented = true
  end,
})

-- 已绕过常规触发入口的直接技能执行，仍由 SkillEffect 兜底。
-- 全局规则与牌技能分别走自己的入口。
skill:addEffect(fk.SkillEffect, {
  global = true,
  mute = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and inQiaoMode(player.room) and isRemoved(player)
      and data ~= nil and data.skill ~= nil
      and not data.skill.cardSkill and not data.skill.global
  end,
  on_refresh = function(self, event, target, player, data)
    data.prevented = true
  end,
})

local function hasTurnRemoved(room)
  for _, p in ipairs(room.players) do
    if p:getMark(REMOVED_TURN) > 0 then return true end
  end
  return false
end

-- 回合结束时的移回：priority -1 晚于默认 TurnEnd 技能和【敕令】(0)。
-- 引擎随后才 clearHistory(Player.HistoryTurn)；破军等牌的移回由 Turn exit
-- 函数执行，仍在本步之后。
skill:addEffect(fk.TurnEnd, {
  global = true,
  mute = true,
  priority = -1,
  can_trigger = function(self, event, target, player)
    local room = player.room
    return target == player and inQiaoMode(room) and hasTurnRemoved(room)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    local room = player.room
    for _, p in ipairs(room.players) do
      if p:getMark(REMOVED_TURN) > 0 then
        room:setPlayerMark(p, REMOVED_TURN, 0)
        room:setPlayerMark(p, REMOVED_UI, 0)
        -- 若还有其他移出标记，角色本轮仍未移回。
        if not p.dead and not p:isRemoved() then
          room.logic:trigger(H.PlayerRemoved, p, { who = p })
        end
      end
    end
  end,
})

return skill
