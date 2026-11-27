local M = {}

function M.cardNameLength(card)
  if card.trueName == "slash" then return 1 end
  local name = Fk:translate(card.name, "zh_CN")
  return utf8.len(name) or #name
end

-- With a resolving use, include that use. Otherwise project the next one.
function M.useIndex(player, current, resolving)
  local turn = current and current:findParent(GameEvent.Turn, true)
  local startId = turn and turn.id or 0
  local lastId = resolving and current.id or math.huge
  local ids, count = {}, 0
  local events = player.room.logic.event_recorder[GameEvent.UseCard] or {}
  for _, event in ipairs(events) do
    if event.id > startId and event.id <= lastId and event.data and event.data.from == player and not ids[event.id] then
      ids[event.id] = true
      count = count + 1
    end
  end
  return count + (ids[lastId] and 0 or 1)
end

return M
