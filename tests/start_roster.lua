local support = __dofile("../../../tests/support/hegemony.lua")
local selections = {
  [101] = { "qiao_heg__wu001", "qiao_heg__jin014" },
  [102] = { "qiao_heg__jin006", "qiao_heg__jin018" },
}

local function withClient(view, fn)
  local previousClient, previousSelf, previousRoom = ClientInstance, Self, RoomInstance
  ClientInstance, Self, RoomInstance = view.client, view.player, nil
  local ok, err = pcall(fn)
  view.client, view.player = ClientInstance, Self
  ClientInstance, Self, RoomInstance = previousClient, previousSelf, previousRoom
  if not ok then error(err, 0) end
end

local function dispatch(view, command, data, isRequest)
  withClient(view, function() ClientCallback(view.cpp, command, data, isRequest) end)
end

local function start(backend, views, firstGame)
  return support.createRoom {
    mode = "qiao_heg_mode", backend = backend, realSelection = true,
    settings = { enableFreeAssign = true, generalTimeout = 3 },
    configure = function(room)
      local shuffle = room.shuffleTable
      function room:shuffleTable(list)
        if list ~= self.players then return shuffle(self, list) end
        -- Return to the room with the other human first in the previous seat order.
        -- Keep a robot first in the next game's ArrangeSeats message.
        table.sort(list, function(a, b)
          if a.id > 0 and b.id > 0 then return a.id > b.id end
          return a.id < b.id
        end)
      end
      for index, id in ipairs({ 101, 102 }) do
        local view = views[id]
        local native = backend:getPlayers():at(index - 1)
        if firstGame then
          dispatch(view, "Setup", cbor.encode { id, native:getScreenName(), native:getAvatar() })
          dispatch(view, "EnterRoom", cbor.encode { 6, 15, cbor.decode(backend:settings()) })
          for _, other in ipairs(backend.players) do
            if other ~= native then
              dispatch(view, "AddPlayer", cbor.encode { other:getId(), other:getScreenName(), other:getAvatar() })
            end
          end
        end
        function native:doNotify(command, data) dispatch(view, command, data, false) end
        function native:doRequest(command, data) dispatch(view, command, data, true) end
        function native:waitForReply() return cbor.encode(selections[id]) end
      end
    end,
  }
end

Teststart_roster = {}

function Teststart_roster:testBothClientsKeepTheirOwnViewWhenTheServerRestartsWithRobots()
  local views = {}
  for id in pairs(selections) do
    local cpp = FkTest.createFakeClient()
    views[id] = { cpp = cpp, client = Client:new(cpp) }
    function cpp:notifyUI(command)
      if command == "StartGame" then
        lu.assertEquals(#ClientInstance.players, 6)
        lu.assertEquals(ClientInstance.players[1].id, id)
      end
    end
  end

  local previousRoom = FkTest.room
  local ok, err = pcall(function()
    local ids = { 101, 102, -11, -12, -13, -14 }
    local room = start(FkTest.createFakeRoom(ids), views, true)
    FkTest.runInRoom(function() room:gameOver("") end)
    for _, view in pairs(views) do
      withClient(view, ResetClientLua)
      lu.assertEquals(#view.client.players, 2)
    end

    -- The waiting room has received no new AddPlayer notifications for the bots.
    room = start(FkTest.createFakeRoom(ids), views, false)
    local checked = false
    FkTest.runInRoom(function()
      local duyu = room:getPlayerById(102)
      duyu:revealGeneral(false)
      duyu:revealGeneral(true)
      for id, view in pairs(views) do
        withClient(view, function()
          lu.assertEquals(Self.id, id)
          lu.assertEquals(view.cpp:getSelf():getId(), id)
          lu.assertEquals(table.map(ClientInstance.players, Util.IdMapper), table.map(room.players, Util.IdMapper))
          lu.assertEquals(Self:getCardIds("h"), room:getPlayerById(id):getCardIds("h"))
          lu.assertEquals(ClientInstance:getPlayerById(102).general, selections[102][1])
          lu.assertEquals(ClientInstance:getPlayerById(101).general, "anjiang")
          lu.assertEquals(Self:isFakeSkill("qiao__skill_wu001_1"), id == 101)
          lu.assertEquals(Self:hasShownSkill("qiao__skill_jin006_1"), id == 102)
        end)
      end
      checked = true
      room:gameOver("")
    end)
    lu.assertTrue(checked)
  end)
  FkTest.room = previousRoom
  if not ok then error(err, 0) end
end

return { name = "start_roster" }
