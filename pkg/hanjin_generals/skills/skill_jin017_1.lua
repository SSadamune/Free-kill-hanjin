-- JIN017 王浑 · 总戎
-- 锁定技：只对横置目标放宽距离和次数，不标记 extraUse，不触发应变 ignore_times。
local skill = fk.CreateSkill {
  name = "hanjin__skill_jin017_1",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

skill:addEffect("targetmod", {
  bypass_distances = function(self, player, card_skill, card, to)
    return player ~= nil and to ~= nil and to.chained == true
  end,
  bypass_times = function(self, player, card_skill, card, to)
    return player ~= nil and to ~= nil and to.chained == true
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_jin017_1"] = "总戎",
  [":hanjin__skill_jin017_1"] = "锁定技，你对横置的角色使用牌无距离和次数限制。",
}

return skill
