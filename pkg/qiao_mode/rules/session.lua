-- The engine owns SessionData on the native Room, so it survives games but not rooms.
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local M = {}
local key = "qiao_faction_ban_v1"

function M.consume(room)
  assert(type(room.room.getSessionData) == "function" and type(room.room.setSessionData) == "function",
    "Qiao requires the engine's room SessionData API")
  local data = room:getSessionData()
  local previous = data[key]
  data[key] = nil -- Aborted next games must not accidentally reuse older results.
  room:setSessionData(data)
  if type(previous) == "table" and previous.version == 1 then return previous end
end

function M.finish(room, winners)
  local data = room:getSessionData()
  if not Modes.inRoom(room) then
    data[key] = nil
  else
    local kingdoms = {}
    for _, p in ipairs(winners or {}) do
      if p and table.contains(Ban.kingdoms, p.kingdom) then
        table.insertIfNeed(kingdoms, p.kingdom)
      end
    end
    data[key] = { version = 1, winners = kingdoms,
      banned = table.simpleClone(room:getBanner("qiao_banned_kingdoms") or {}) }
  end
  room:setSessionData(data)
end

function M.clearForeignGame(room)
  if Modes.inRoom(room) then return end
  if type(room.room.getSessionData) ~= "function" then return end
  local data = room:getSessionData()
  if data[key] then data[key] = nil; room:setSessionData(data) end
end

return M
