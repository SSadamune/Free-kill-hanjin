local M = {}

local profiles = { "aggressive", "conservative", "supportive", "draw" }
local roomSerial = 0

function M.assign(room)
  roomSerial = roomSerial + 1
  -- A separate random stream leaves the room's draws and selections alone.
  local modulus = 2147483647
  local state = (math.floor(os.getms()) + 65537 * roomSerial) % (modulus - 1) + 1
  for _, player in ipairs(room.players) do
    state = (48271 * state) % modulus
    player.ai.personality = profiles[state % #profiles + 1]
  end
end

M.standardOrder = { "draw", "setup", "support", "disrupt", "damage", "delayed" }
local aggressive = { "draw", "disrupt", "damage", "setup", "support", "delayed" }
local conservative = { "setup", "support", "draw", "disrupt", "damage", "delayed" }
local supportive = { "draw", "support", "setup", "disrupt", "damage", "delayed" }
local draw = { "draw", "setup", "support", "cheap_recast", "disrupt", "damage", "delayed" }

function M.hasAlly(ai)
  return table.find(ai.room:getPresentPlayers(), function(player)
    return player ~= ai.player and ai:isFriend(player)
  end) ~= nil
end

function M.playOrder(ai)
  if ai.personality == "aggressive" and ai.player.hp > 1 then return aggressive end
  if ai.personality == "conservative" and ai.player.hp <= 2 then return conservative end
  if ai.personality == "supportive" and M.hasAlly(ai) then return supportive end
  if ai.personality == "draw" then return draw end
  return M.standardOrder
end

return M
