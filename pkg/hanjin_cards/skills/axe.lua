local skill = fk.CreateSkill {
  name = "hanjin__axe_skill",
  attached_equip = "hanjin__axe",
}

skill:addEffect(fk.CardEffectCancelledOut, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(self.name) and data.from == player
      and data.card.trueName == "slash" and not data.to.dead
      and #player:getCardIds("he") > 1
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local cards = {}
    for _, id in ipairs(player:getCardIds("he")) do
      if not player:prohibitDiscard(id)
        and not (table.contains(player:getEquipments(Card.SubtypeWeapon), id)
          and (player:getVirtualEquip(id) or Fk:getCardById(id)).name == self.attached_equip) then
        table.insert(cards, id)
      end
    end
    cards = room:askToDiscard(player, {
      min_num = 2,
      max_num = 2,
      include_equip = true,
      skill_name = self.name,
      cancelable = true,
      pattern = tostring(Exppattern { id = cards }),
      prompt = "#axe-invoke::" .. data.to.id,
      skip = true,
    })
    if #cards > 0 then
      event:setCostData(self, { cards = cards })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    player.room:throwCard(event:getCostData(self).cards, self.name, player, player)
    data.isCancellOut = false
    data.disresponsive = true
  end,
})

Fk:loadTranslationTable {
  ["hanjin__axe_skill"] = "贯石斧",
}

return skill
