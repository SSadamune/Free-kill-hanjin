local skill = fk.CreateSkill {
  name = "hanjin__wonder_map_skill",
  tags = { Skill.Compulsory },
  attached_equip = "hanjin__wonder_map",
}

Fk:loadTranslationTable {
  ["hanjin__wonder_map_skill"] = "天机图",
}

skill:addEffect(fk.AfterCardsMove, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead then return end
    for _, move in ipairs(data) do
      if move.to == player and move.toArea == Card.PlayerEquip then
        for _, info in ipairs(move.moveInfo) do
          if Fk:getCardById(info.cardId).name == skill.attached_equip then
            return Fk.skills[skill.name]:isEffectable(player)
          end
        end
      end
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local ids = {}
    for _, move in ipairs(data) do
      if move.to == player and move.toArea == Card.PlayerEquip then
        for _, info in ipairs(move.moveInfo) do
          if Fk:getCardById(info.cardId).name == skill.attached_equip then
            table.insertIfNeed(ids, info.cardId)
          end
        end
      end
    end
    local candidates = table.filter(player:getCardIds("he"), function(id)
      return not table.contains(ids, id)
    end)
    if #candidates == 0 then return end
    room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      pattern = tostring(Exppattern { id = candidates }),
      skill_name = skill.name,
      cancelable = false,
    })
  end,
})

skill:addEffect(fk.AfterCardsMove, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    if player.dead or player:getHandcardNum() > 4 then return end
    for _, move in ipairs(data) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.PlayerEquip
            and Fk:getCardById(info.cardId).name == skill.attached_equip then
            return Fk.skills[skill.name]:isEffectable(player)
          end
        end
      end
    end
  end,
  on_use = function(self, event, target, player)
    player:drawCards(5 - player:getHandcardNum(), skill.name)
  end,
})

return skill
