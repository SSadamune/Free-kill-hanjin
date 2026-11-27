local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local E = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"
local skill = fk.CreateSkill { name = "qiao__skill_shu048_2" }
local FIRST = "qiao_sheyan_first-turn"
-- 记录成为目标的事实，暗置、尚未获得技能和放弃首次发动都不能重置。
skill:addEffect(fk.TargetConfirming, {
  global = true,
  can_refresh = function(self, event, target, p, data)
    return target == p and data.card:isCommonTrick() and p:getMark(FIRST) == 0
  end,
  on_refresh = function(self, event, target, p, data)
    p.room:setPlayerMark(p, FIRST, event.id)
  end,
  can_trigger = function(self, event, target, p, data)
    return target == p and p:hasSkill(skill.name) and p:getMark(FIRST) == event.id
      and (#data:getAllTargets() > 1 or #E.candidates(p.room, data.use) > 0)
  end,
  on_cost = function(self, event, target, p, data)
    local choices = E.candidates(p.room, data.use)
    local current = data:getAllTargets()
    if #current > 1 then table.insertTable(choices, current) end
    local to = S.pick(p.room, p, choices, skill.name, true)[1]
    if not to then return false end
    local subs = {}
    local rule = E.ruleFor(data.card)
    if not table.contains(current, to) and rule and rule.sub_candidates then
      local eligible = E.subCandidates(p.room, data.use, to)
      if #eligible > 0 then subs = S.pick(p.room, p, eligible, skill.name, true) end
      if #subs == 0 and (#eligible > 0 or not rule.allow_no_sub) then return false end
    end
    event:setCostData(self, { to = to, remove = table.contains(current, to), subs = subs })
    return true
  end,
  on_use = function(self, event, target, p, data)
    local cost = event:getCostData(self)
    if cost.remove then
      if #data:getAllTargets() > 1 then data:cancelTarget(cost.to) end
    elseif E.isCandidate(p.room, data.use, cost.to)
      and (#cost.subs == 0 or E.subTargetLegal(p.room, data.use, cost.to, cost.subs[1])) then
      data:addTarget(cost.to, cost.subs)
    end
  end,
})
return skill
