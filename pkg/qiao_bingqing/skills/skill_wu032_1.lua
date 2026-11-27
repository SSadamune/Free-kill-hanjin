local skill = fk.CreateSkill { name = "qiao__skill_wu032_1", tags = { Skill.Compulsory } }
skill:addEffect(fk.DamageInflicted, {
  can_trigger = function(self, event, target, player)
    return target == player and player:hasSkill(skill.name) and player:getHandcardNum() == player.hp
  end,
  on_use = function(self, event, target, player, data) data:changeDamage(-1) end,
})
return skill
