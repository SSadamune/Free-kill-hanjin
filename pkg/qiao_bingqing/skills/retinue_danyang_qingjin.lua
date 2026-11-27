local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local skill = fk.CreateSkill { name = "qiao__retinue_skill_danyang_qingjin", tags = { Skill.Compulsory } }
local mark = "qiao_danyang_active-turn"

local function unused(p, instance, to)
  local seen = p:getMark(mark) ~= 0 and p.tag.qiaoDanyangTargets or {}
  local targets = seen[instance and instance.id or "direct"]
  return not targets or not targets[to.id]
end

skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, p, data)
    return target == p and p:hasSkill(skill.name) and data.to:hasSkill(skill.name, true)
  end,
  on_trigger = function(self, event, target, p, data)
    if #R.instancesForSkill(p, skill.name) == 0 then
      if unused(p, nil, data.to) then return self:doCost(event, target, p, data) end
      return
    end
    return R.triggerEach(self, event, target, p, data, function(instance) return unused(p, instance, data.to) end)
  end,
  on_use = function(self, event, target, p, data)
    local instance = R.currentForEvent(self, event)
    local key = instance and instance.id or "direct"
    if p:getMark(mark) == 0 then
      p.tag.qiaoDanyangTargets = {}
      p.room:setPlayerMark(p, mark, 1)
    end
    local seen = p.tag.qiaoDanyangTargets
    seen[key] = seen[key] or {}
    seen[key][data.to.id] = true
    p:drawCards(1, skill.name)
  end,
})
return skill
