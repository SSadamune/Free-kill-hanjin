-- Real new_heg_mode setup. Only player input and the endless turn loop are replaced.
local M = {}
local pairsForSeats = {
  { "hs__caocao", "hs__xiahoudun" },
  { "hs__simayi", "hs__zhangliao" },
  { "hs__liubei", "hs__guanyu" },
  { "hs__zhangfei", "hs__zhaoyun" },
  { "hs__sunquan", "hs__ganning" },
  { "hs__zhouyu", "hs__huanggai" },
  { "hs__lvbu", "hs__diaochan" },
  { "hs__yuanshao", "hs__yanliangwenchou" },
}

function M.initRoom()
  local mode = assert(Fk.game_modes.new_heg_mode, "Install hegemony first")
  local originalLogic = mode.logic
  local logic = originalLogic():subclass("HanjinHegTestLogic")
  function logic:action()
    self:trigger(fk.GamePrepared)
    GameEvent.DrawInitial:create(DrawInitialData:new({ who = self.room.players })):exec()
    self.room:setTag("hanjin_test_ready", true)
    while true do
      local fn = coroutine.yield("__handleRequest")
      if not fn then break end
      fn()
    end
  end

  local backend = FkTest.createFakeRoom({ 1, 2, 3, 4, 5, 6, 7, 8 })
  backend:getOwner()._fake_router = ClientInstance.client
  backend._settings = cbor.encode {
    gameMode = "new_heg_mode", generalNum = 5, luckTime = 0,
    disabledPack = {}, disabledGenerals = {}, enableFreeAssign = false,
    enableDeputy = true, notBanToFourKingdoms = true,
    watchNextDeputy = false, revealAllOnStart = false,
  }
  local room = Room:new(backend)
  room._test_disable_delay = true
  room.notify_max = 100000 -- Avoid scheduler throttling during deterministic setup.
  function room:askToChooseIniticalGeneral(player, params)
    assert(params.isHeg and params.needDeputy, "Must use the real national-war selection flow")
    local choices, extra = {}, {}
    for seat, p in ipairs(self.players) do
      local pair = pairsForSeats[seat]
      for _, name in ipairs(pair) do assert(Fk.generals[name], "Missing general: " .. name) end
      choices[p] = table.simpleClone(pair)
      extra[p] = { kingdom = Fk.generals[pair[1]].kingdom }
    end
    return choices, extra
  end
  FkTest.room = room
  mode.logic = function() return logic end
  RoomInstance = room
  local ok, err = pcall(function() room:resume("request_timer") end)
  RoomInstance = nil
  mode.logic = originalLogic
  assert(ok, err)
  assert(room:getTag("hanjin_test_ready"), "National-war setup did not reach the test loop")
  for _, p in ipairs(room.players) do FkTest.cleanNextReplies(p) end
end

M.clearRoom = FkTest.clearRoom
return M
