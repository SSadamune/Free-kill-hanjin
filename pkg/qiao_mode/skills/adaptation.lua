local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local skill = fk.CreateSkill { name = "#qiao_adaptation_rule", tags = { Skill.Compulsory } }
local function eligible(target, player, data)
  return target == player and Modes.inRoom(player.room)
    and A.isAdaptationCard(data.card, data)
end

-- Count legality is checked before the use event and the engine counts the
-- use before AfterCardUseDeclared. Locking ignore_times at PreCardUse is the
-- only point both after formal confirmation and before addCardUseHistory.
-- The lock is not a successful adaptation, so this effect must stay silent.
skill:addEffect(fk.PreCardUse, {
  global = true, priority = -100, mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and Modes.inRoom(player.room)
      and A.hasEffectEntry(data.card, data, "ignore_times")
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data) A.lockIgnoreTimes(player.room, data) end,
})
skill:addEffect(fk.AfterCardUseDeclared, {
  global = true,
  can_refresh = function(self, event, target, player, data) return eligible(target, player, data) end,
  on_refresh = function(self, event, target, player, data) A.prepare(player.room, data) end,
})
skill:addEffect(fk.AfterCardTargetDeclared, {
  global = true, priority = -100, mute = true,
  can_trigger = function(self, event, target, player, data) return eligible(target, player, data) end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data) A.resolve(player.room, data) end,
})
skill:addEffect(fk.CardUseFinished, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and Modes.inRoom(player.room)
  end,
  on_refresh = function(self, event, target, player, data) A.clear(data) end,
})

local translations = {
  ["#qiao_adaptation_rule"] = "汉晋应变",
  ["qiao_condition_fujia"] = "富甲", ["qiao_condition_canqu"] = "残躯",
  ["qiao_condition_zhuzhan"] = "助战", ["qiao_condition_kongchao"] = "空巢", ["qiao_condition_gujun"] = "孤军",
  ["qiao_adaptation_draw"] = "摸一张牌", ["qiao_adaptation_damage"] = "伤害+1",
  ["qiao_adaptation_disresponsive"] = "不可响应", ["qiao_adaptation_execute_both"] = "执行两项",
  ["qiao_adaptation_obtain_response_card"] = "获得响应牌",
  ["qiao_adaptation_add_target"] = "目标+1", ["qiao_adaptation_remove_target"] = "目标-1",
  ["qiao_adaptation_ignore_times"] = "无视次数",
  ["qiao_adaptation_thunder_damage"] = "改为雷电伤害",
  ["qiao_adaptation_discard_target_equip"] = "弃置目标装备区里的一张牌",
  ["#qiao_adaptation_discard_equip"] = "应变：弃置目标角色装备区里的一张牌",
  ["#qiao_adaptation_support"] = "助战：你可以弃置一张%arg手牌，助战 %src 的应变牌",
  ["#qiao_adaptation_ignore"] = "选择本次无视的一项应变条件",
  ["qiao_ignore_option"] = "第%arg项（%arg2）",
  ["#qiao_adaptation_add_target"] = "应变：你可以增加一个合法目标",
  ["#qiao_adaptation_remove_target"] = "应变：你可以减少一个目标",
  -- The invoke-log prefix makes the client show the text in its centered
  -- SkillInvoked popup. HTML entities keep the literal angle brackets visible.
  ["#InvokeSkillQiaoAdaptation"] = "触发&lt;%arg&gt;",
}
-- The mark label is the condition itself; the mark value carries "· 效果".
-- This intentionally has no generic "应变" prefix or empty label/colon.
local conditionLabels = {
  fujia = "富甲", canqu = "残躯", zhuzhan = "助战", kongchao = "空巢", gujun = "孤军",
}
for index = 1, 32 do
  for condition, label in pairs(conditionLabels) do
    translations["@qiao_adaptation_" .. index .. "_" .. condition] = label
  end
end
Fk:loadTranslationTable(translations)

return skill
