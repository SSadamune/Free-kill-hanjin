local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"

local Robot = SmartAI:subclass("HanjinRobot")

local function knownKingdom(kingdom)
  return type(kingdom) == "string" and kingdom ~= "" and kingdom ~= "unknown"
end

function Robot:isFriend(target)
  if not target or target.dead or target:isRemoved() then return false end
  if target == self.player then return true end
  return knownKingdom(self.player.kingdom) and self.player.kingdom ~= "wild"
    and self.player.kingdom == target.kingdom
end

function Robot:isEnemy(target)
  if not target or target == self.player or target.dead or target:isRemoved()
    or not knownKingdom(target.kingdom) then return false end
  local kingdom = self.player.kingdom
  if not knownKingdom(kingdom) then
    -- A robot knows its own selection. Its eventual reveal can also make it wild,
    -- so a matching unrevealed faction does not prove an alliance.
    kingdom = self.player:getMark("__heg_kingdom")
  end
  return knownKingdom(kingdom) and (kingdom == "wild" or kingdom ~= target.kingdom)
end

function Robot:handlePlayCard()
  return Cards.play(self)
end

local M = {}

function M.install(room)
  for _, player in ipairs(room.players) do
    player.ai = Robot:new(player)
    player.ai.room = room
  end
end

return M
