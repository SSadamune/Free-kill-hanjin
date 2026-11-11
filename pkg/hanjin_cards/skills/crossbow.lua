local skill = fk.CreateSkill {
  name = "hanjin__crossbow_skill",
  tags = { Skill.Compulsory },
  attached_equip = "hanjin__crossbow",
}

skill:addEffect("targetmod", {
  bypass_times = function(self, player, skill, scope, card)
    if player:hasSkill(self.name) and card and card.trueName == "slash"
      and scope == Player.HistoryPhase then
      local cardIds = table.connect(Card:getIdList(card), card.fake_subcards)
      local crossbows = table.filter(player:getEquipments(Card.SubtypeWeapon), function(id)
        return Fk:getCardById(id).name == self.attached_equip
      end)
      return #crossbows == 0 or not table.every(crossbows, function(id)
        return table.contains(cardIds, id)
      end)
    end
  end,
})

skill:addEffect(fk.CardUsing, {
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(self.name) and player.phase == Player.Play
      and data.card.trueName == "slash" and not data.extraUse
      and player:usedCardTimes("slash", Player.HistoryPhase) > 1
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    room:sendLog { type = "#InvokeSkill", from = player.id, arg = "hanjin__crossbow_skill" }
  end,
})

Fk:loadTranslationTable {
  ["hanjin__crossbow_skill"] = "诸葛连弩",
}

return skill
