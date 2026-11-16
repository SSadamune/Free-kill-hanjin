-- SHU006 马超 · 马术
--
-- 规则基线：rules/standard-generals.md 蜀区 SHU006。
-- 锁定技，你计算与其他角色的距离-1。只修正距离计算，不改用牌目标条件。
local skill = fk.CreateSkill {
  name = "hanjin__skill_shu006_1",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    if from ~= nil and from:hasSkill(skill.name) then
      return -1
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_shu006_1"] = "马术",
  [":hanjin__skill_shu006_1"] = "锁定技，你计算与其他角色的距离-1。",
}

return skill
