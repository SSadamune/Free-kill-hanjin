local skill = fk.CreateSkill {
  name = "qiao__crossbow_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__crossbow",
}

skill:addEffect("targetmod", {
  bypass_times = function(self, player, cardSkill, scope, card)
    if player:hasSkill(skill.name) and card and card.trueName == "slash"
      and scope == Player.HistoryPhase then
      local cardIds = table.connect(Card:getIdList(card), card.fake_subcards)
      local crossbows = table.filter(player:getEquipments(Card.SubtypeWeapon), function(id)
        local equip = player:getVirtualEquip(id) or Fk:getCardById(id)
        return equip.name == skill.attached_equip
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
    room:sendLog { type = "#InvokeSkill", from = player.id, arg = "qiao__crossbow_skill" }
  end,
})

Fk:loadTranslationTable {
  ["qiao__crossbow_skill"] = "诸葛连弩",
}

return skill
