local skill = fk.CreateSkill {
  name = "hanjin__breastplate_skill",
  attached_equip = "hanjin__breastplate",
}

Fk:loadTranslationTable {
  ["hanjin__breastplate_skill"] = "护心镜",
  ["#hanjin__breastplate-invoke"] = "护心镜：你可以弃置护心镜，防止此伤害",
}

skill:addEffect(fk.DamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and (data.damage > 1 or data.damage >= (player.hp + (player.shield or 0)))
  end,
  on_cost = function(self, event, target, player)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__breastplate-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    data:preventDamage()
    local cards = table.filter(player:getCardIds("e"), function(id)
      return Fk:getCardById(id).name == skill.attached_equip
    end)
    if #cards > 0 then
      player.room:moveCards({
        ids = cards,
        from = player,
        toArea = Card.DiscardPile,
        moveReason = fk.ReasonPutIntoDiscardPile,
        skillName = skill.name,
      })
    end
  end,
})

return skill
