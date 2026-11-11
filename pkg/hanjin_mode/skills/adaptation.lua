local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
local skill = fk.CreateSkill { name = "#hanjin_adaptation_rule", tags = { Skill.Compulsory } }
local function eligible(target, player, data)
  return target == player and player.room:getSettings("gameMode") == "hanjin_heg_mode"
    and A.isAdaptationCard(data.card, data)
end

-- Count legality is checked before the use event and the engine counts the
-- use before AfterCardUseDeclared. Locking ignore_times at PreCardUse is the
-- only point both after formal confirmation and before addCardUseHistory.
-- The lock is not a successful adaptation, so this effect must stay silent.
skill:addEffect(fk.PreCardUse, {
  global = true, priority = -100, mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player.room:getSettings("gameMode") == "hanjin_heg_mode"
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
    return target == player and player.room:getSettings("gameMode") == "hanjin_heg_mode"
  end,
  on_refresh = function(self, event, target, player, data) A.clear(data) end,
})

local translations = {
  ["#hanjin_adaptation_rule"] = "汉晋应变",
  ["hanjin_condition_fujia"] = "富甲", ["hanjin_condition_canqu"] = "残躯",
  ["hanjin_condition_zhuzhan"] = "助战", ["hanjin_condition_kongchao"] = "空巢", ["hanjin_condition_gujun"] = "孤军",
  ["hanjin_adaptation_draw"] = "摸一张牌", ["hanjin_adaptation_damage"] = "伤害+1",
  ["hanjin_adaptation_disresponsive"] = "不可响应", ["hanjin_adaptation_execute_both"] = "执行两项",
  ["hanjin_adaptation_obtain_response_card"] = "获得响应牌",
  ["hanjin_adaptation_add_target"] = "目标+1", ["hanjin_adaptation_remove_target"] = "目标-1",
  ["hanjin_adaptation_ignore_times"] = "无视次数",
  ["#hanjin_adaptation_support"] = "助战：你可以弃置一张%arg手牌，助战 %src 的应变牌",
  ["#hanjin_adaptation_ignore"] = "选择本次无视的一项应变条件",
  ["hanjin_ignore_option"] = "第%arg项（%arg2）",
  ["#hanjin_adaptation_add_target"] = "应变：你可以增加一个合法目标",
  ["#hanjin_adaptation_remove_target"] = "应变：你可以减少一个目标",
  -- The invoke-log prefix makes the client show the text in its centered
  -- SkillInvoked popup. HTML entities keep the literal angle brackets visible.
  ["#InvokeSkillHanjinAdaptation"] = "触发&lt;%arg&gt;",
}
-- Mark names are only row labels; the condition/effect are the mark value.
for index = 1, 32 do
  translations["@hanjin_adaptation_" .. index] = "应变"
end
Fk:loadTranslationTable(translations)

return skill
