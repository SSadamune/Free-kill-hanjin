-- JIN014 文鸯 · 夺气
--
-- 规则基线：docs/rules/generals/jin014-wenyang.md。
-- 限定技：每个回合结束时（fk.TurnEnd，不是结束阶段），若当前回合角色没有
-- 手牌，文鸯可以获得一个额外的回合。额外回合通过正式的 gainAnExtraTurn
-- 延迟队列调度，不手工递归调用阶段流程；每个回合结束时都按当时的手牌重新
-- 检查，不使用此前空手快照。
local skill = fk.CreateSkill {
  name = "qiao__skill_jin014_2",
  tags = { Skill.Limited },
}

skill:addEffect(fk.TurnEnd, {
  anim_type = "support",
  -- 每个回合结束时检查，当前回合角色可能不是文鸯，故使用全局触发。
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and not target.dead and not player.dead
      and player:hasSkill(skill.name)
      and player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
      and target:isKongcheng()
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin014_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    -- 延迟到当前回合结束后，由房间的额外回合队列正式开启。
    player:gainAnExtraTurn(true, skill.name)
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin014_2-invoke"] = "夺气：当前回合角色没有手牌，你可以获得一个额外的回合",
}

return skill
