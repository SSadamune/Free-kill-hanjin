local skill = fk.CreateSkill {
  name = "qiao__wooden_ox_skill",
  attached_equip = "qiao__wooden_ox",
}

local function isOx(id)
  return Fk:getCardById(id, true).name == skill.attached_equip
end

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
    local ox = table.find(player:getCardIds("e"), isOx)
    if ox then
      local targets = table.filter(room:getPresentPlayers(), function(p)
        return p ~= player and p:canMoveCardIntoEquip(ox, false)
      end)
      if #targets > 0 then
        local tos = room:askToChoosePlayers(player, {
          cancelable = true, max_num = 1, min_num = 1,
          skill_name = self.name, targets = targets, prompt = "#wooden_ox-move",
        })
        if tos[1] and table.contains(targets, tos[1]) and not tos[1]:isRemoved()
          and room:getCardOwner(ox) == player and room:getCardArea(ox) == Card.PlayerEquip
          and tos[1]:canMoveCardIntoEquip(ox, false) then
          room:moveCardTo(ox, Card.PlayerEquip, tos[1], fk.ReasonPut, self.name,
            nil, true, player, nil)
        end
      end
    end
  end,
})

skill:addEffect(fk.AfterCardsMove, {
  -- 辎随实体木牛移动，清理在装备技能已经卸载或移动事件被终止时也应执行。
  is_delay_effect = true,
  can_refresh = function(self, event, target, player, data)
    if #player:getPile("$sa_carriage") == 0 then return false end
    for _, move in ipairs(data) do
      for _, info in ipairs(move.moveInfo) do
        if isOx(info.cardId) then
          if info.fromArea == Card.Processing then
            local room = player.room
            local move_event = room.logic:getCurrentEvent():findParent(GameEvent.MoveCards, true)
            if not (move_event and move_event.parent) then return end
            local parent_event = move_event.parent
            local move_events = room.logic:getEventsByRule(GameEvent.MoveCards, 1, function(e)
              if e.id >= move_event.id or e.parent ~= parent_event then return false end
              for _, last_move in ipairs(e.data) do
                if last_move.moveReason == fk.ReasonExchange
                  and last_move.from == player and last_move.toArea == Card.Processing
                  and table.find(last_move.moveInfo, function(last_info)
                    return last_info.cardId == info.cardId and last_info.fromArea == Card.PlayerEquip
                  end) then
                  return true
                end
              end
            end, parent_event.id)
            if #move_events > 0 then
              if move.toArea ~= Card.PlayerEquip or move.to ~= player then
                event:setCostData(self, move.toArea == Card.PlayerEquip and { to = move.to } or nil)
                return true
              end
            end
          elseif move.from == player and info.fromArea == Card.PlayerEquip
            and not (move.moveReason == fk.ReasonExchange and move.toArea == Card.Processing)
            and not (move.toArea == Card.PlayerEquip and move.to == player) then
            event:setCostData(self, move.toArea == Card.PlayerEquip and { to = move.to } or nil)
            return true
          end
        end
      end
    end
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    local cards = player:getPile("$sa_carriage")
    if event:getCostData(self) ~= nil then
      event:getCostData(self).to:addToPile("$sa_carriage", cards, false, skill.name)
    else
      room:moveCardTo(cards, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
        skill.name, nil, true)
    end
  end,
})

skill:addEffect("filter", {
  handly_cards = function(self, player)
    if player:hasSkill(self.name) then return player:getPile("$sa_carriage") end
  end,
})

Fk:loadTranslationTable {
  ["qiao__wooden_ox_skill"] = "木牛",
  ["$sa_carriage"] = "辎",
  ["#wooden_ox-move"] = "你可以将【木牛流马】移动至一名其他角色的装备区",
  ["#wooden_ox-prompt"] = "你可以将一张手牌扣置于木牛流马下",
}

return skill
