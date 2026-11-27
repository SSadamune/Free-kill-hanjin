local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local skill = fk.CreateSkill { name = "qiao__skill_han047_1", tags = { Skill.Compulsory } }
skill:addEffect(fk.TargetConfirmed, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and target ~= player and (data.card.name == "qiao__slash" or data.card.name == "slash")
      and S.allies(player, data.from) and (target == player:getNextAlive() or target == player:getLastAlive())
  end,
  on_use = function(self, event, target, player, data)
    data.disresponsive = true
  end,
})
return skill
