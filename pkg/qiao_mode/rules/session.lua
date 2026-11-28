-- The engine owns SessionData on the native Room, so it survives games but not rooms.
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local M = {}
local key = "qiao_faction_ban_v1"

local function clear(room)
  if type(room.room.getSessionData) ~= "function" or type(room.room.setSessionData) ~= "function" then return end
  local data = room:getSessionData()
  if data[key] == nil then return end
  data[key] = nil
  room:setSessionData(data)
end

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
  if not room.current or not Modes.inRoom(room) or room:getTag("qiao_locked_start_rejected") then
    return clear(room)
  end
  local data = room:getSessionData()
  local kingdoms = {}
  for _, p in ipairs(winners or {}) do
    if p and table.contains(Ban.kingdoms, p.kingdom) then
      table.insertIfNeed(kingdoms, p.kingdom)
    end
  end
  local banned = room:getTag("qiao_rotation_banned_kingdoms") or room:getBanner("qiao_banned_kingdoms") or {}
  data[key] = { version = 1, winners = kingdoms, banned = table.simpleClone(banned) }
  room:setSessionData(data)
end

function M.clearForeignGame(room)
  if not Modes.inRoom(room) then clear(room) end
end

local installed = false

function M.installServer()
  if installed then return end
  installed = true
  local base = Fk.Base.ServerRoomBase
  local gameOver = base.gameOver
  function base:gameOver(winners)
    -- 调度器可在房间主协程之外收尾，此时引擎不会派发 GameFinished。
    -- 先删旧记录。正常终局进入 GameFinished 后会按本局结果写回。
    if not self.game_finished then clear(self) end
    return gameOver(self, winners)
  end
end

return M
