local M = {}
local timeout = 10 * 1000 * 1000 -- os.getms returns microseconds in FreeKill.
local instructionsPerCheck = 10000
local exceeded = {}

local function traceback(err)
  if err == exceeded then return err end
  return debug.traceback(tostring(err), 2)
end

function M.run(reply, ai)
  local started = os.getms()
  local previous, mask, count = debug.gethook()
  local timedOut = false

  -- Lua cannot restore a hook installed by native code. Leave such hooks
  -- intact and still discard late replies when the native call returns.
  if previous and type(previous) ~= "function" then
    local ok, result = xpcall(reply, traceback, ai)
    return ok, result, os.getms() - started >= timeout
  end

  local interval = instructionsPerCheck
  if previous and count > 0 then interval = math.min(interval, count) end
  local previousInstructions = 0
  local function check(event, line)
    if event == "count" then
      if os.getms() - started >= timeout then
        timedOut = true
        error(exceeded, 0)
      end
      if not previous or count == 0 then return end
      previousInstructions = previousInstructions + interval
      if previousInstructions < count then return end
      previousInstructions = previousInstructions - count
    end
    if previous then previous(event, line) end
  end

  local ok, result = xpcall(function()
    debug.sethook(check, mask or "", interval)
    return reply(ai)
  end, traceback)
  if previous then
    debug.sethook(previous, mask, count)
  else
    debug.sethook()
  end
  return ok, result, timedOut or os.getms() - started >= timeout
end

return M
