-- QUN003 貂蝉 · 闭月
--
-- 规则基线：rules/standard-generals.md 群区 QUN003、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 结束阶段入口按「发动时是否空手」决定摸 1 张还是 2 张，不能先摸一张再判断。
-- 不限制结束阶段已跳过等公共流程：与其他结束阶段技能按公共时机排队。
local skill = fk.CreateSkill {
  name = "hanjin__skill_qun003_2",
}
skill.hanjinImplemented = true

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and player.phase == Player.Finish
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_qun003_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    -- 在此刻（摸牌前）确定张数：空手摸两张，否则摸一张。
    local num = player:isKongcheng() and 2 or 1
    player:drawCards(num, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_qun003_2"] = "闭月",
  [":hanjin__skill_qun003_2"] = "结束阶段，你可以摸一张牌，若你没有手牌，改为摸两张牌。",
  ["#hanjin__skill_qun003_2-invoke"] = "闭月：是否摸牌（没有手牌时摸两张）？",
}

return skill
