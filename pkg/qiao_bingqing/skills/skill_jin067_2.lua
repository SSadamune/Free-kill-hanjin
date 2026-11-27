local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local E = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"
local skill = fk.CreateSkill { name = "qiao__skill_jin067_2" }
skill:addEffect(fk.AfterCardTargetDeclared, {
  can_trigger = function(self, event, target, p, data)
    return target == p and p:hasSkill(skill.name) and data.card.trueName == "slash" and p:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
  end,
  on_cost = function(self, event, target, p) return S.invoke(p, skill.name) end,
  on_use = function(self, event, target, p, data)
    local n = S.boardCards(p)
    if n > 0 then
      for _, to in ipairs(S.choose(p, E.candidates(p.room, data), skill.name, n, true)) do
        if E.isCandidate(p.room, data, to) then data:addTarget(to) end
      end
    end
    local seen = {}
    for _, to in ipairs(data.tos) do
      local count = S.boardCards(to)
      if seen[count] then return end
      seen[count] = true
    end
    if #data.tos > 0 then p:drawCards(#data.tos, skill.name) end
  end,
})
return skill
