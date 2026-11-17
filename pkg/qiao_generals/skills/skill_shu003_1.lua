-- SHU003 张飞 · 咆哮
--
-- 规则基线：docs/rules/standard-generals.md 蜀区 SHU003；状态型无次数限制的接口见
-- docs/rules/adaptation.md ADAPT-006。
-- 锁定技：
--   1. 使用【杀】无次数限制：属 TargetModSkill.bypass_times，只绕过上限，
--      本次使用仍按普通用牌计数；
--   2. 于一回合内使用第二张【杀】时摸一张牌。
--
-- “第二张【杀】”是全回合事实：从服务端真实 UseCard 事件历史统计本回合内
-- 使用者的【杀】使用事件（含 extraUse/无视次数的使用），不读取被 extraUse
-- 排除的用牌次数历史，也不依赖技能自身的累计标记。获得或明置咆哮晚于本回合
-- 第一张【杀】时，第二张仍按事实触发。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu003_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

--- 本回合内该角色实际使用【杀】的次数（包含当前这次使用）。
---@param player ServerPlayer
---@return integer
local function slashUseCountThisTurn(player)
  local room = player.room
  if room == nil or room.logic == nil then return 0 end
  local current = room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  -- 没有真实 Turn 事件（测试直接模拟出牌阶段）时，以游戏开始为界统计。
  local startId = turn and turn.id or 0
  local events = room.logic:getEventsByRule(GameEvent.UseCard, 999, function(event)
    local data = event.data
    return event.id > startId and data ~= nil and data.from == player
      and data.card ~= nil and data.card.trueName == "slash"
  end, startId)
  return #events
end

skill:addEffect("targetmod", {
  bypass_times = function(self, player, skill_, scope, card, to)
    return player ~= nil and player:hasSkill(skill.name) and card ~= nil
      and card.trueName == "slash" and scope == Player.HistoryPhase
  end,
})

skill:addEffect(fk.CardUsing, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
      and data.card ~= nil and data.card.trueName == "slash"
  end,
  on_use = function(self, event, target, player, data)
    if slashUseCountThisTurn(player) == 2 then
      player:drawCards(1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu003_1"] = "咆哮",
  [":qiao__skill_shu003_1"] = "锁定技，你使用【杀】无次数限制；你于一回合内使用第二张【杀】时，你摸一张牌。",
}

return skill
