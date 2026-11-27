local Hu = require "packages.qiao.pkg.qiao_bingqing.hufen"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local skill = fk.CreateSkill { name = "qiao__skill_jin066_2", tags = { Skill.DeputyPlace } }
skill:addEffect("atkrange", {
  correct_func = function(self, p) return p:hasShownSkill(skill.name) and 1 or 0 end,
})
skill:addEffect("targetmod", {
  extra_target_func = function(self, p, cardSkill, card)
    if card and table.contains(card.skillNames, skill.name) then return 1 end
  end,
})
Hu.after(skill, true, function(self, event, target, p)
  p.room:useCard(event:getCostData(self).use)
end, function(self, event, target, p)
  local use = C.selectVirtualCard(p.room, p, { name = "qiao__slash", skill_name = skill.name,
    policy = C.default({ max_targets = 2 }), cancelable = true, extra_data = { qiao_trigger_use = true } })
  if not use then return false end
  event:setCostData(self, { use = use })
  return true
end)
return skill
