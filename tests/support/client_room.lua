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

-- Run the registered client selector with the live server's request data and
-- return the reply produced by its confirm button.
function M.confirmSelection(room, player, params, ids, targets, inspect)
  local reply
  M.run(room, function(clients)
    local board = assert(Fk:getBoardGame(room:getSettings("gameMode")))
    local client = board.client_klass:new(ClientInstance.client)
    local handler = client.request_handlers.AskForUseActiveSkill:new(clients[player.seat], {
      params.skill_name, params.prompt, params.cancelable, params.extra_data,
    })
    local skill = Fk.skills[params.skill_name]
    local previous, notify = skill._extra_data, ClientInstance.notifyUI
    skill._extra_data = params.extra_data
    ClientInstance.notifyUI = function(_, command, data)
      if command == "ReplyToServer" then reply = data end
    end
    local ok, err = pcall(function()
      handler:setup()
      if inspect then inspect(handler) end
      lu.assertFalse(handler:feasible())
      for _, id in ipairs(ids) do
        lu.assertTrue(handler:cardValidity(id))
        handler:selectCard(id, { selected = true })
      end
      lu.assertEquals(handler.selected_targets, {})
      for _, target in ipairs(targets or {}) do
        lu.assertTrue(handler:targetValidity(target.id))
        handler:selectTarget(target.id, { selected = true })
      end
      lu.assertTrue(handler:feasible())
      handler:doOKButton()
      handler:_finish()
    end)
    skill._extra_data, ClientInstance.notifyUI = previous, notify
    if not ok then error(err, 0) end
  end)
  return assert(reply, "card selection did not generate a reply")
end

function M.confirmCards(room, player, params, ids)
  assert(params.skill_name == "choose_cards_skill")
  return M.confirmSelection(room, player, params, ids)
end

return M
