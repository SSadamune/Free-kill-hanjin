Testhanjin_console_timeout = {}

-- Run the real Request loop with a deterministic clock and transport.
local function runRequest(console, timeout, replyAfterWaiting)
  local oldFk, oldTime = fk, os.time
  local controller = { kicks = 0 }
  function controller:setThinking() end
  function controller:getState() return fk.Player_Online end
  function controller:emitKick() self.kicks = self.kicks + 1 end
  local backend = { timers = 0 }
  function backend:setRequestTimer() self.timers = self.timers + 1 end
  function backend:destroyRequestTimer() end
  local room = { room = backend, timeout = timeout, logic = {} }
  function room.logic:trigger() end
  function room:notifyMoveFocus() end
  function room:yield() return "request_timer" end
  local player = { id = 1, room = room, serverplayer = controller, _timewaste_count = 60 }
  local request = Request:new({ player }, "ConsoleTimeoutRegression")
  function request:_sendPacket(p) self.send_success[p.serverplayer] = true end
  local polls = 0
  function request:_checkReply()
    polls = polls + 1
    if replyAfterWaiting and polls > 1 then return { "late reply" } end
    return "__notready"
  end
  local reads = 0
  -- Stand in for the native GUI Backend pointer without writing the C++ global.
  fk = setmetatable({}, { __index = function(_, key)
    if key == "Backend" then return console and {} or nil end
    return oldFk[key]
  end })
  os.time = function()
    reads = reads + 1
    return reads == 1 and 0 or 10000
  end
  local ok, err = xpcall(function() request:ask() end, debug.traceback)
  fk, os.time = oldFk, oldTime
  if not ok then error(err) end
  return request, player, controller, backend
end

function Testhanjin_console_timeout:testUnlimitedAcceptsLateReplyWithoutTimer()
  local request, _, controller, backend = runRequest(true, -1, true)
  lu.assertEquals(request.result[1], { "late reply" })
  lu.assertEquals(request.overtimes, {})
  lu.assertEquals(backend.timers, 0)
  lu.assertEquals(controller.kicks, 0)
end

function Testhanjin_console_timeout:testFiniteConsoleTimeoutReturnsDefaultWithoutPenalty()
  local request, player, controller, backend = runRequest(true, 90, false)
  lu.assertEquals(request.result[1], "")
  lu.assertEquals(#request.overtimes, 1)
  lu.assertTrue(request.overtimes[1] == player)
  lu.assertEquals(backend.timers, 1)
  lu.assertEquals(player._timewaste_count, 0)
  lu.assertEquals(controller.kicks, 0)
end

function Testhanjin_console_timeout:testOrdinaryServerStillPenalizesEvenWithOneHuman()
  local request, player, controller, backend = runRequest(false, 90, false)
  lu.assertEquals(#request.overtimes, 1)
  lu.assertTrue(request.overtimes[1] == player)
  lu.assertEquals(backend.timers, 1)
  lu.assertEquals(controller.kicks, 1)
end

return { name = "hanjin_console_timeout" }
