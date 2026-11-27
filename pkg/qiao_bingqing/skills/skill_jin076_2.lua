local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_jin076_2" }
skill:addEffect(fk.FinishJudge, {
  global = true,
  can_refresh = function(self, event, target, p, data) return p == target and data.card ~= nil end,
  on_refresh = function(self, event, target, p, data)
    local color = data.card.color
    data.qiao_tianshu = color ~= Card.NoColor and p.room:getBanner("qiao_tianshu_last") == color
    p.room:setBanner("qiao_tianshu_last", color)
  end,
  can_trigger = function(self, event, target, p, data) return data.qiao_tianshu and S.present(target) and p:hasSkill(skill.name) end,
  on_use = function(self, event, target, p) target:drawCards(1, skill.name) end,
})
return skill
