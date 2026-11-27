local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local skill = fk.CreateSkill { name = "qiao__skill_wei044_2" }
local function partners(player, dying)
  return table.filter(player.room:getPresentPlayers(), function(p)
    return p ~= dying and S.allies(player, p) and #S.pairs(player.room, p, dying) > 0
  end)
end
skill:addEffect(fk.EnterDying, {
  can_trigger = function(self, event, target, player)
    return player:hasSkill(skill.name) and S.allies(player, target)
      and player:usedSkillTimes(skill.name, Player.HistoryTurn) == 0 and #partners(player, target) > 0
  end,
  on_cost = function(self, event, target, player)
    local to = S.pick(player.room, player, partners(player, target), skill.name, true)[1]
    event:setCostData(self, { to = to })
    return to ~= nil
  end,
  on_use = function(self, event, target, player)
    local to = event:getCostData(self).to
    S.exchange(player.room, to, S.pairs(player.room, to, target), skill.name, true)
  end,
})
return skill
