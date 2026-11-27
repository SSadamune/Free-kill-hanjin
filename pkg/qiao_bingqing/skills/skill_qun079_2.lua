local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local skill = fk.CreateSkill { name = "qiao__skill_qun079_2" }
local function wounded(p)
  local room, damaged = p.room, {}
  room.logic:getActualDamageEvents(999, function(e)
    if S.present(e.data.to) then table.insertIfNeed(damaged, e.data.to) end
    return false
  end, Player.HistoryTurn)
  return damaged
end
local function partners(room, damaged, p)
  return table.filter(damaged, function(other) return other ~= p and #S.pairs(room, p, other) > 0 end)
end
skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, p, data)
    if p ~= target or data.phase ~= Player.Finish or not p:hasSkill(skill.name) then return false end
    local damaged = wounded(p)
    return table.find(damaged, function(to) return #partners(p.room, damaged, to) > 0 end)
  end,
  on_cost = function(self, event, target, p)
    local room, damaged = p.room, wounded(p)
    local firsts = table.filter(damaged, function(to) return #partners(room, damaged, to) > 0 end)
    local first = S.pick(room, p, firsts, skill.name, true)[1]
    if not first then return false end
    local second = S.pick(room, p, partners(room, damaged, first), skill.name, true)[1]
    event:setCostData(self, { first = first, second = second })
    return second ~= nil
  end,
  on_use = function(self, event, target, p)
    local cost = event:getCostData(self)
    S.exchange(p.room, p, S.pairs(p.room, cost.first, cost.second), skill.name)
  end,
})
return skill
