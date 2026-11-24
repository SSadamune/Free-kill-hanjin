local M = {}
local incomingExchanges = setmetatable({}, { __mode = "k" })

--- 容量检查可用于选牌时预计腾出的原装备，也可用于实际落栏。
function M.canReceive(player, card, outgoing)
  local function hasRoom(subtype)
    local equips = player:getEquipments(subtype)
    local remaining = #equips - (table.contains(equips, outgoing) and 1 or 0)
    return #player:getAvailableEquipSlots(subtype) > remaining
  end
  if Fk.packages.qiao_cards.qiao_cards.isDualMount(card) then
    return hasRoom(Card.SubtypeOffensiveRide) and hasRoom(Card.SubtypeDefensiveRide)
  end
  return hasRoom(card.sub_type)
end

-- 每张牌单独结算能否落入对方装备区。未落栏且仍在处理区的牌由交换清理。
function M.moveIncoming(room, moves)
  if #moves == 0 then return end
  local previous = incomingExchanges[room]
  local cards = {}
  for _, move in ipairs(moves) do cards[move.ids[1]] = move.skillName end
  incomingExchanges[room] = cards
  local ok, err = pcall(room.moveCards, room, table.unpack(moves))
  incomingExchanges[room] = previous
  if not ok then error(err, 0) end
end

function M.installServer(logic)
  local trigger = logic.trigger
  function logic:trigger(event, target, data, refreshOnly)
    local broken, detail = trigger(self, event, target, data, refreshOnly)
    local room = self.room
    local cards = incomingExchanges[room]
    if event == fk.BeforeCardsMove and cards then
      -- 等普通触发和所有延后 refresh 完成。接下来引擎才会应用这一批移动。
      room:cancelMove(data, nil, function(move, info)
        local skillName = cards[info.cardId]
        if not skillName or skillName ~= move.skillName or info.fromArea ~= Card.Processing
          or move.toArea ~= Card.PlayerEquip or move.moveReason ~= fk.ReasonExchange then return false end
        local to = move.to
        return not to or not to:isAlive() or to:isRemoved()
          or room:getCardArea(info.cardId) ~= Card.Processing
          or not M.canReceive(to, info.virtualEquip or Fk:getCardById(info.cardId))
      end)
    end
    return broken, detail
  end
end

return M
