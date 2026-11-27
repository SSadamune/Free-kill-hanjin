local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_wei034_1" }
for _, timing in ipairs({ fk.CardUsing, fk.CardResponding }) do
  skill:addEffect(timing, {
    global = true,
    can_refresh = function(self, event, target, p, data) return target == p and data.responseToEvent ~= nil end,
    on_refresh = function(self, event, target, p) p.room:setPlayerMark(p, "qiao_sizhen-phase", 1) end,
  })
end
skill:addEffect(fk.EventPhaseEnd, {
  can_trigger = function(self, event, target, p) return p:hasSkill(skill.name) and p:getMark("qiao_sizhen-phase") > 0 end,
  on_cost = function(self, event, target, p)
    local wounded = table.find(S.damageHistory(p, Player.HistoryPhase), function(e) return S.allies(p, e.data.to) end)
    return S.slashCost(event, self, p, skill.name, not wounded)
  end,
  on_use = function(self, event, target, p) p.room:useCard(event:getCostData(self).use) end,
})
return skill
