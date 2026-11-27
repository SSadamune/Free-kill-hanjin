local skill = fk.CreateSkill { name = "qiao__skill_wei035_2" }
skill:addEffect(fk.BeforeChainStateChange, {
  global = true,
  can_refresh = function(self, event, target, player) return target == player end,
  on_refresh = function(self, event, target, player, data) data.qiao_faen_was_chained = target.chained end,
})
for _, timing in ipairs({ fk.ChainStateChanged, fk.TurnedOver }) do
  skill:addEffect(timing, {
    can_trigger = function(self, event, target, player, data)
      return player:hasSkill(skill.name) and not target.dead and
        ((event == fk.ChainStateChanged and target.chained and not data.qiao_faen_was_chained) or (event == fk.TurnedOver and not target.faceup))
    end,
    on_cost = function(self, event, target, player)
      return player.room:askToSkillInvoke(player, { skill_name = skill.name, target = target })
    end,
    on_use = function(self, event, target) target:drawCards(1, skill.name) end,
  })
end
return skill
