-- JIN017 王浑 · 总戎
-- 锁定技：只对横置目标放宽距离和次数，不标记 extraUse，不触发应变 ignore_times。
local skill = fk.CreateSkill {
  name = "qiao__skill_jin017_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local function applies(effect, player, target)
  return target ~= nil and target.chained and player:hasSkill(effect)
end

skill:addEffect("targetmod", {
  bypass_distances = function(self, player, card_skill, card, to)
    return applies(self, player, to)
  end,
  bypass_times = function(self, player, card_skill, scope, card, to)
    return applies(self, player, to)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin017_1"] = "总戎",
  [":qiao__skill_jin017_1"] = "锁定技，你对横置的角色使用牌无距离和次数限制。",
}

return skill
