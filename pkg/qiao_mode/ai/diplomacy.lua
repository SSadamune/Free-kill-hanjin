local Heg = require "packages.hegemony.util"

local M = {}
local enemyAttitude = -0.4

function M.knownKingdom(kingdom)
  return type(kingdom) == "string" and kingdom ~= "" and kingdom ~= "unknown" and kingdom ~= "hidden"
end

function M.publicFaction(player)
  local kingdom = player.kingdom
  if not M.knownKingdom(kingdom) then return end
  if kingdom ~= "wild" then return kingdom end
  -- The engine also stores private provisional roles in player.role. Only
  -- a publicly chosen wild country can group two wild players together.
  if player.role_shown and table.contains(Heg.wildKingdoms, player.role) then return player.role end
  return player
end

local function strength(player)
  local endurance = math.min(6, math.max(0, player.hp) + player.shield)
  return 4 + 0.5 * (endurance + math.min(5, player:getHandcardNum()) + math.min(4, #player:getCardIds("e")))
end

local function weighOpponents(ai)
  local attitudes = {}
  local own, opponents, groups = 0, {}, {}
  for _, player in ipairs(ai.room:getPresentPlayers()) do
    if ai:isFriend(player) then
      own = own + strength(player)
    elseif ai:isEnemy(player) then
      local key = M.publicFaction(player)
      groups[key] = (groups[key] or 0) + strength(player)
      opponents[player] = key
    end
  end

  local largest, second, smallest = 0, 0, math.huge
  for _, power in pairs(groups) do
    if power > largest then
      largest, second = power, largest
    else
      second = math.max(second, power)
    end
    smallest = math.min(smallest, power)
  end

  -- Require two opposing factions and a clear leader above our own faction.
  local pressure = math.min(1, (largest - math.max(own, second) - 2) / 8)
  if second == 0 or pressure <= 0 then return attitudes end

  for player, key in pairs(opponents) do
    local relative = (groups[key] - smallest) / (largest - smallest)
    attitudes[player] = enemyAttitude + pressure * (0.8 - 1.4 * relative)
  end
  return attitudes
end

function M.attitude(ai, target)
  if ai:isFriend(target) then return 1 end
  if not ai:isEnemy(target) then return 0 end
  -- SmartAI rebuilds this memory for each request. Calls outside a dashboard
  -- read the current room directly, including changes since the last request.
  local memory = ai.handler and ai.mem
  local attitudes = memory and memory.hanjinAttitudes or weighOpponents(ai)
  if memory then memory.hanjinAttitudes = attitudes end
  return attitudes[target] or enemyAttitude
end

function M.hostileScore(ai, target, tactical)
  if ai:isEnemy(target) then
    return tactical - 8 * (M.attitude(ai, target) - enemyAttitude) + M.humanBonus(ai, target)
  end
end

function M.humanBonus(ai, target)
  local state = target.serverplayer:getState()
  if target ~= ai.player and state ~= fk.Player_Robot and state ~= fk.Player_Invalid then return 0.25 end
  return 0
end

return M
