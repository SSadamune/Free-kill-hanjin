local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_wei061_1" }
skill:addEffect(fk.TurnEnd, {
  can_trigger = function(self, event, target, p)
    if not p:hasSkill(skill.name) then return false end
    local n = 0
    for _, e in ipairs(S.damageHistory(p)) do
      if e.data.from and S.allies(p, e.data.from) then n = n + e.data.damage end
    end
    return n >= 2
  end,
  on_cost = function(self, event, target, p) return S.slashCost(event, self, p, skill.name) end,
  on_use = function(self, event, target, p)
    local use = event:getCostData(self).use
    local previous = {}
    for _, e in ipairs(S.damageHistory(p)) do table.insertIfNeed(previous, e.data.to.id) end
    use.extra_data = use.extra_data or {}
    use.extra_data.qiao_durui = previous
    p.room:useCard(use)
  end,
})
skill:addEffect(fk.DamageCaused, {
  is_delay_effect = true, mute = true,
  can_trigger = function(self, event, target, p, data)
    if target ~= p or not data.card or not table.contains(data.card.skillNames, skill.name) then return false end
    local use = p.room.logic:getCurrentEvent():findParent(GameEvent.UseCard)
    if not use or use.data.card ~= data.card then return false end
    local alive = table.filter((use.data.extra_data or {}).qiao_durui or {}, function(id) return S.present(p.room:getPlayerById(id)) end)
    return #alive == 1 and data.to.id == alive[1]
  end,
  on_use = function(self, event, target, p, data) data:changeDamage(1) end,
})
return skill
