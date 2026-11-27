local Hu = require "packages.qiao.pkg.qiao_bingqing.hufen"
local skill = fk.CreateSkill { name = "qiao__skill_jin066_1", tags = { Skill.MainPlace } }
skill:addEffect("maxcards", {
  correct_func = function(self, p) return p:hasShownSkill(skill.name) and 1 or 0 end,
})
Hu.after(skill, false, function(self, event, target, p) p:drawCards(1, skill.name) end)
return skill
