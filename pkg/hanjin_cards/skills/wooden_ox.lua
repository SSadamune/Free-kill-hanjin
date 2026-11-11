local skill = fk.CreateSkill {
  name = "hanjin__wooden_ox_skill",
  attached_equip = "hanjin__wooden_ox",
}

skill:addEffect("active", {
  prompt = "#wooden_ox-prompt",
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
      and #player:getPile("$sa_carriage") < 5
  end,
  card_num = 1,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and table.contains(player.player_cards[Player.Hand], to_select)
  end,
  target_num = 0,
  on_use = function(self, room, effect)
    local player = effect.from
    player:addToPile("$sa_carriage", effect.cards[1], false, self.name)
    if player.dead then return end
    local ox = table.find(player:getCardIds("e"), function(id)
      return Fk:getCardById(id).name == self.attached_equip
    end)
    if ox then
      local targets = table.filter(room.alive_players, function(p)
        return p ~= player and p:hasEmptyEquipSlot(Card.SubtypeTreasure)
      end)
      if #targets > 0 then
        local tos = room:askToChoosePlayers(player, {
          cancelable = true, max_num = 1, min_num = 1,
          skill_name = self.name, targets = targets, prompt = "#wooden_ox-move",
        })
        if #tos > 0 then
          room:moveCardTo(ox, Card.PlayerEquip, tos[1], fk.ReasonPut, self.name,
            nil, true, player, nil)
        end
      end
    end
  end,
})

skill:addEffect(fk.AfterCardsMove, {
  mute = true,
  priority = 5,
  can_trigger = function(self, event, target, player, data)
    if player:getPile("$sa_carriage") == 0 then return false end
    for _, move in ipairs(data) do
      for _, info in ipairs(move.moveInfo) do
        if Fk:getCardById(info.cardId).name == self.attached_equip then
          if info.fromArea == Card.Processing then
            local room = player.room
            local move_event = room.logic:getCurrentEvent():findParent(GameEvent.MoveCards, true)
            if not move_event then return end
            local parent_event = move_event.parent
            local move_events = room.logic:getEventsByRule(GameEvent.MoveCards, 1, function(e)
              if e.id >= move_event.id or e.parent ~= parent_event then return false end
              for _, last_move in ipairs(e.data) do
                if last_move.moveReason == fk.ReasonExchange
                  and last_move.toArea == Card.Processing then
                  return true
                end
              end
            end, parent_event.id)
            if #move_events > 0 then
              for _, last_move in ipairs(move_events[1].data) do
                if last_move.moveReason == fk.ReasonExchange then
                  for _, last_info in ipairs(last_move.moveInfo) do
                    if Fk:getCardById(last_info.cardId).name == self.attached_equip then
                      if last_move.from == player and last_info.fromArea == Card.PlayerEquip then
                        if move.toArea == Card.PlayerEquip then
                          if move.to ~= player then
                            event:setCostData(self, { extra_data = move.to })
                            return true
                          end
                        else
                          event:setCostData(self, nil)
                          return true
                        end
                      end
                    end
                  end
                end
              end
            end
          elseif move.moveReason == fk.ReasonExchange then
            if move.from == player and info.fromArea == Card.PlayerEquip
              and move.toArea ~= Card.Processing then
              event:setCostData(self, nil)
              return true
            end
          elseif move.from == player and info.fromArea == Card.PlayerEquip then
            if move.toArea == Card.PlayerEquip then
              if move.to ~= player then
                event:setCostData(self, { extra_data = move.to })
                return true
              end
            else
              event:setCostData(self, nil)
              return true
            end
          end
        end
      end
    end
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    local room = player.room
    local cards = player:getPile("$sa_carriage")
    if event:getCostData(self) ~= nil then
      event:getCostData(self).extra_data:addToPile("$sa_carriage", cards, false, self.name)
    else
      room:moveCardTo(cards, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
        self.name, nil, true)
    end
  end,
})

skill:addEffect("filter", {
  handly_cards = function(self, player)
    if player:hasSkill(self.name) then return player:getPile("$sa_carriage") end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__wooden_ox_skill"] = "木牛",
  ["#wooden_ox-move"] = "你可以将【木牛流马】移动至一名其他角色的装备区",
  ["#wooden_ox-prompt"] = "你可以将一张手牌扣置于木牛流马下",
}

return skill
