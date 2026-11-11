-- Real mode initialization. Upstream regressions use scripted input; HanJin uses
-- real Request replies and independent test content. Both pause before automatic turns.
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

function M.createRoom(options)
  options = options or {}
  local modeName = options.mode or "new_heg_mode"
  if modeName == "hanjin_heg_mode" then __dofile("../../../tests/support/hanjin_content.lua") end
  local mode = assert(Fk.game_modes[modeName], "Install hegemony first")
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

  local backend = options.backend or FkTest.createFakeRoom({ 1, 2, 3, 4, 5, 6, 7, 8 })
  -- Match the native Room API; data belongs to this backend, never to a process global.
  function backend:getSessionData() return self._session_data or "{}" end
  function backend:setSessionData(data) self._session_data = data end
  backend:getOwner()._fake_router = ClientInstance.client
  backend._settings = cbor.encode {
    gameMode = modeName, generalNum = 5, generalTimeout = 1, luckTime = 0,
    disabledPack = {}, disabledGenerals = {}, enableFreeAssign = false,
    enableDeputy = true, notBanToFourKingdoms = true,
    watchNextDeputy = false, revealAllOnStart = false,
  }
  if options.settings then
    local settings = cbor.decode(backend._settings)
    for key, value in pairs(options.settings) do settings[key] = value end
    backend._settings = cbor.encode(settings)
  end
  local room = Room:new(backend)
  room._test_disable_delay = true
  room.notify_max = 100000 -- Avoid scheduler throttling during deterministic setup.
  if not options.realSelection then
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
  end
  if options.configure then options.configure(room) end
  FkTest.room = room
  mode.logic = function() return logic end
  RoomInstance = room
  local ok, err = pcall(function() room:resume("request_timer") end)
  RoomInstance = nil
  mode.logic = originalLogic
  assert(ok, err)
  assert(room:getTag("hanjin_test_ready"), "National-war setup did not reach the test loop")
  for _, p in ipairs(room.players) do FkTest.cleanNextReplies(p) end
  return room
end

function M.initRoom() return M.createRoom() end
function M.initHanjinRoom() return M.createRoom { mode = "hanjin_heg_mode", realSelection = true } end

M.clearRoom = FkTest.clearRoom
return M
