local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"

local M = {}
M.ruleKey = "qiao_locked_game_rule"
M.landlord = "qiao_locked_landlord"
M.twoVsTwo = "qiao_locked_2v2"
M.humanVsAI = "qiao_locked_human_vs_ai"
M.rules = { M.landlord, M.twoVsTwo, M.humanVsAI }
M.roomSizes = { [M.landlord] = 3, [M.twoVsTwo] = 4 }
M.minPlayers = 2
M.maxPlayers = 10
local openingHandAdjustments = { -1, 0, 0, 1 }

function M.isHumanVsAI(room)
  return room and type(room.getSettings) == "function" and room:getSettings("gameMode") == Modes.locked
    and room:getSettings(M.ruleKey) == M.humanVsAI
end

function M.isLandlord(room)
  return room and room.players and #room.players == 3 and type(room.getSettings) == "function"
    and room:getSettings("gameMode") == Modes.locked and not M.isHumanVsAI(room)
end

-- Old rooms without a saved rule still derive the rule from their capacity.
function M.matchesPlayerCount(count, rule)
  if rule == nil then return count == 3 or count == 4 end
  if rule == M.humanVsAI then
    return type(count) == "number" and count % 1 == 0 and count >= M.minPlayers and count <= M.maxPlayers
  end
  return M.roomSizes[rule] ~= nil and M.roomSizes[rule] == count
end

local function humanTeams(humans, robots, shuffle)
  if #humans == 0 or #robots == 0 then return end
  local teams, groups = {}, 2
  local function assign(seats, group, split)
    if split then
      groups = 3
      if shuffle then shuffle(seats) end
    end
    local first = split and (#seats + 1) // 2 or #seats
    for i, seat in ipairs(seats) do teams[seat] = i <= first and group or 3 end
  end
  assign(humans, 1, #humans > #robots)
  assign(robots, 2, #robots >= #humans + 2)
  return teams, groups
end

local function sides(room)
  local humans, robots = {}, {}
  for seat, player in ipairs(room.players) do
    local team = player.serverplayer:getState() == fk.Player_Robot and robots or humans
    table.insert(team, seat)
  end
  return humans, robots
end

function M.hasBothSides(room)
  local humans, robots = sides(room)
  return #humans > 0 and #robots > 0
end

-- Match all slots, including multi-faction cards restricted to a single seat.
local function reserve(kingdoms, candidates, cardKey, count, landlord)
  local slots, occupied = {}, {}
  local function fill(slot, seen)
    for _, name in ipairs(candidates[slot.kingdom]) do
      local key = cardKey(name)
      if not seen[key] then
        seen[key] = true
        if not occupied[key] or fill(occupied[key], seen) then
          occupied[key] = slot
          slot.name = name
          return true
        end
      end
    end
    return false
  end

  for seat, kingdom in ipairs(kingdoms) do
    local extras = landlord and seat == 1 and 2 or 0
    for _ = 1, count + extras do
      local slot = { seat = seat, kingdom = kingdom }
      if not fill(slot, {}) then return end
      table.insert(slots, slot)
    end
  end
  return slots
end

local function findDraft(pool, factions, teams, groups, count, options)
  local function cardKey(name)
    return options.distinctVersions and name or Fk.generals[name].trueName
  end

  local best
  local function tryFactions(allowed)
    local candidates, kept, excluded = {}, {}, {}
    for _, kingdom in ipairs(allowed) do candidates[kingdom] = {} end
    for _, name in ipairs(pool) do
      local entry = Guest.resolve(name, allowed, options.guestReplacement)
      if entry and not (options.humanVsAI and entry.wild) then
        table.insert(kept, name)
        for _, kingdom in ipairs(entry.kingdoms) do table.insert(candidates[kingdom], name) end
      else
        table.insert(excluded, name)
      end
    end
    local kingdoms = table.map(teams, function(team) return allowed[team] end)
    if options.shuffle2v2 then options.shuffle2v2(kingdoms) end
    for size = count, best and best.count + 1 or 2, -1 do
      local slots = reserve(kingdoms, candidates, cardKey, size, options.landlord)
      if slots then
        best = { slots = slots, kingdoms = kingdoms, allowed = table.simpleClone(allowed),
          kept = kept, excluded = excluded, count = size }
        return size == count
      end
    end
  end

  local allowed = {}
  local function assignFaction()
    if #allowed == groups then return tryFactions(allowed) end
    for _, kingdom in ipairs(factions) do
      if not table.contains(allowed, kingdom) then
        table.insert(allowed, kingdom)
        if assignFaction() then return true end
        table.remove(allowed)
      end
    end
  end
  assignFaction()
  return best
end

local function fixedTeams(num)
  return num == 3 and { 1, 2, 2 } or { 1, 1, 2, 2 }
end

function M.canDeal(plan, num, distinctVersions, guestReplacement, rule)
  local options = { distinctVersions = distinctVersions, guestReplacement = guestReplacement,
    humanVsAI = rule == M.humanVsAI, landlord = num == 3 and rule ~= M.humanVsAI }
  if not options.humanVsAI then
    return findDraft(plan.kept, plan.allowed, fixedTeams(num), 2, 2, options) ~= nil
  end

  -- The creation screen knows the capacity but not which seats will be bots.
  -- Check for any feasible composition. The server checks the final roster.
  for humanCount = 1, num - 1 do
    local humans, robots = {}, {}
    for seat = 1, num do table.insert(seat <= humanCount and humans or robots, seat) end
    local teams, groups = humanTeams(humans, robots)
    if findDraft(plan.kept, plan.allowed, teams, groups, 2, options) then return true end
  end
  return false
end

function M.deal(room, plan, count)
  local num = #room.players
  if not M.matchesPlayerCount(num, room:getSettings(M.ruleKey)) then return end
  local humanVsAI = M.isHumanVsAI(room)
  local options = { distinctVersions = room:getSettings("disableSameConvert"),
    guestReplacement = Guest.replacementEnabled(room), landlord = num == 3 and not humanVsAI,
    humanVsAI = humanVsAI }
  local shuffle = function(list) room:shuffleTable(list) end
  local teams, groups
  if options.humanVsAI then
    local humans, robots = sides(room)
    teams, groups = humanTeams(humans, robots, shuffle)
  else
    teams, groups = fixedTeams(num), 2
    if num == 4 then options.shuffle2v2 = shuffle end
  end
  if not teams then return end

  local pool = table.simpleClone(plan.kept)
  local factions = table.simpleClone(plan.allowed)
  shuffle(pool)
  shuffle(factions)
  local draft = findDraft(pool, factions, teams, groups, count, options)
  if not draft then return end

  local assigned, offers = {}, {}
  for seat, player in ipairs(room.players) do
    assigned[player], offers[player] = draft.kingdoms[seat], {}
  end
  for _, slot in ipairs(draft.slots) do
    table.insert(offers[room.players[slot.seat]], slot.name)
  end
  for _, player in ipairs(room.players) do shuffle(offers[player]) end
  plan.allowed = draft.allowed
  plan.rotationBans = plan.banned
  plan.banned = table.filter(plan.candidates, function(kingdom)
    return not table.contains(plan.allowed, kingdom)
  end)
  plan.kept = draft.kept
  table.insertTable(plan.excluded, draft.excluded)
  return offers, assigned, draft.count
end

function M.adjusted(_, player)
  if M.isHumanVsAI(player.room) then return {} end
  if #player.room.players == 3 and player.seat == 1 then
    return { hp = player.hp + 1, maxHp = player.maxHp + 1 }
  end
  if #player.room.players == 4 then
    return { draw_init = openingHandAdjustments[player.seat] }
  end
  return {}
end

return M
