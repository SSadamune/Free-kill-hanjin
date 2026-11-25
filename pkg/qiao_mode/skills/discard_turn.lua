local skill = fk.CreateSkill { name = "#qiao_discard_turn" }
local banner = "qiao_discard_before_turn"

skill:addEffect(fk.TurnStart, {
  can_refresh = function(self, event, target, player)
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    room:setBanner(banner, table.simpleClone(room.discard_pile))
  end,
})

skill:addEffect(fk.AfterCardsMove, {
  can_refresh = function(self, event, target, player)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player, moves)
    local room = player.room
    local older = room:getBanner(banner)
    if not older or #older == 0 then return end
    local count = #older
    -- A card that leaves and returns during this turn counts as a new discard.
    for _, move in ipairs(moves) do
      if move.toArea ~= Card.DiscardPile then
        for _, info in ipairs(move.moveInfo) do
          if info.fromArea == Card.DiscardPile then table.removeOne(older, info.cardId) end
        end
      end
    end
    if #older ~= count then room:setBanner(banner, older) end
  end,
})

skill:addEffect(fk.AfterDrawPileShuffle, {
  can_refresh = function(self, event, target, player)
    return player.seat == 1 and player.room:getBanner(banner) ~= nil
  end,
  on_refresh = function(self, event, target, player)
    player.room:setBanner(banner, {})
  end,
})

return skill
