-- JIN002 司马师 · 夷灭
--
-- 规则基线：docs/rules/generals/jin002-simashi.md。
-- 限定技：当你对体力值大于等于你的角色造成伤害时，可以令当前伤害值翻倍。
-- 比较在伤害事件确定时进行；取消不消耗限定机会，发动后才记入 HistoryGame。
local skill = fk.CreateSkill {
  name = "qiao__skill_jin002_2",
  tags = { Skill.Limited },
}

skill:addEffect(fk.DamageCaused, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return data ~= nil and data.from == player and data.to ~= nil
      and (data.damage or 0) > 0
      and player:hasSkill(skill.name) and not player.dead
      and player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
      and data.to.hp >= player.hp
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin002_2-invoke::" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    data:changeDamage(data.damage)
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin002_2-invoke"] = "夷灭：你可以令对 %dest 造成的此伤害翻倍",
}

return skill
