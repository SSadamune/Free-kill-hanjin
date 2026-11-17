-- Reusable real-ClientPlayer room for request/button checks.
local AbstractRoom = require "ltk.core.room.abstract_room"

local M = {}

function M.run(current, fn)
  local ClientPlayer = require "ltk.client.clientplayer"
  local clients = {}
  for _, original in ipairs(current.players) do
    local copy = ClientPlayer:new(original._splayer)
    for key, value in pairs(original) do
      if key ~= "room" and key ~= "class" and key ~= "serverplayer" then copy[key] = value end
    end
    local cards = {}
    for area, ids in pairs(copy.player_cards or {}) do cards[area] = table.simpleClone(ids) end
    copy.player_cards = cards
    -- 客户端持有自己的 mark 表；用例只显式同步公开 mark，避免写入泄漏回服务端。
    local marks = {}
    for name, value in pairs(original.mark or {}) do marks[name] = value end
    copy.mark = marks
    table.insert(clients, copy)
  end
  for index, player in ipairs(clients) do player.next = clients[index % #clients + 1] end
  local forbidden = {
    getTag = true, setTag = true, general_pile = true, disabled_generals = true,
    void = true, logic = true,
  }
  local clientRoom = setmetatable(
    {
      players = clients, alive_players = clients, current = clients[1],
      -- 客户端语义的锁视查询：不广播、不写服务端缓存。
      filterCard = AbstractRoom.filterCard,
      filtered_cards = {},
      isInstanceOf = function(_, cls) return cls == AbstractRoom end,
    },
    { __index = function(_, key)
      if forbidden[key] then
        error("client room accessed server-only field: " .. tostring(key), 2)
      end
      return current[key]
    end })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = xpcall(function() fn(clients, clientRoom) end, debug.traceback)
  Fk.currentRoom = originalRoom
  if not ok then error(err, 0) end
  return clients, clientRoom
end

return M
