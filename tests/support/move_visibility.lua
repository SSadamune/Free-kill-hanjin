-- 调用时牌仍在本次移动的目的区域。用客户端生成移动动画和战报时的同一判定逐席核对。
return function(id, fromArea, toArea, expectedViewers)
  local room, viewers = FkTest.room, nil
  FkTest.runInRoom(function()
    room.logic:getEventsByRule(GameEvent.MoveCards, 1, function(event)
      for _, move in ipairs(event.data) do
        if move.toArea == toArea and table.find(move.moveInfo, function(info)
          return info.cardId == id and info.fromArea == fromArea
        end) then
          viewers = table.filter(room.players, function(p) return p:cardVisible(id, move) end)
          return true
        end
      end
    end, 0)
  end)
  lu.assertEquals(room:getCardArea(id), toArea)
  lu.assertNotNil(viewers, "没有找到该实体牌从指定来源区到目的区的移动")
  for _, seat in ipairs(room.players) do
    lu.assertEquals(table.contains(viewers, seat), table.contains(expectedViewers, seat),
      ("座位 %d 对牌 %d 的可见性错误"):format(seat.seat, id))
  end
end
