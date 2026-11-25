local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local M = {}
M.ruleKey = "qiao_locked_game_rule"
M.rules = { "qiao_locked_landlord", "qiao_locked_2v2" }
M.roomSizes = { [M.rules[1]] = 3, [M.rules[2]] = 4 }
local openingHandAdjustments = { -1, 0, 0, 1 }

-- Old rooms without a saved rule still derive the rule from their capacity.
function M.matchesPlayerCount(count, rule)
  if rule == nil then return count == 3 or count == 4 end
  return M.roomSizes[rule] ~= nil and M.roomSizes[rule] == count
end

-- Match every slot before choosing a faction pair. A multi-faction card can
-- move to another slot to make space for a card with fewer legal destinations.
local function reserve(kingdoms, candidates, cardKey, count)
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
    local extras = #kingdoms == 3 and seat == 1 and 2 or 0
    for _ = 1, count + extras do
      local slot = { seat = seat, kingdom = kingdom }
      if not fill(slot, {}) then return end
      table.insert(slots, slot)
    end
  end
  return slots
end

local function findDraft(pool, factions, num, count, distinctVersions, guestReplacement, shuffle)
  local function cardKey(name)
    return distinctVersions and name or Fk.generals[name].trueName
  end

  local best
  for i, first in ipairs(factions) do
    for j, second in ipairs(factions) do
      if i ~= j and (num == 3 or j > i) then
        local allowed = { first, second }
        local candidates, kept, excluded = { [first] = {}, [second] = {} }, {}, {}
        for _, name in ipairs(pool) do
          local entry = Guest.resolve(name, allowed, guestReplacement)
          if entry then
            table.insert(kept, name)
            for _, kingdom in ipairs(entry.kingdoms) do table.insert(candidates[kingdom], name) end
          else
            table.insert(excluded, name)
          end
        end
        local kingdoms = num == 3 and { first, second, second } or { first, first, second, second }
        if num == 4 and shuffle then shuffle(kingdoms) end
        for size = count, best and best.count + 1 or 2, -1 do
          local slots = reserve(kingdoms, candidates, cardKey, size)
          if slots then
            best = { slots = slots, kingdoms = kingdoms, allowed = allowed,
              kept = kept, excluded = excluded, count = size }
            if size == count then return best end
            break
          end
        end
      end
    end
  end
  return best
end

function M.canDeal(plan, num, distinctVersions, guestReplacement)
  return findDraft(plan.kept, plan.allowed, num, 2, distinctVersions, guestReplacement) ~= nil
end

function M.deal(room, plan, count)
  local num = #room.players
  if not M.matchesPlayerCount(num, room:getSettings(M.ruleKey)) then return end
  local pool = table.simpleClone(plan.kept)
  local factions = table.simpleClone(plan.allowed)
  room:shuffleTable(pool)
  room:shuffleTable(factions)
  local draft = findDraft(pool, factions, num, count, room:getSettings("disableSameConvert"),
    Guest.replacementEnabled(room), function(list) room:shuffleTable(list) end)
  if not draft then return end

  local assigned, offers = {}, {}
  for seat, player in ipairs(room.players) do
    assigned[player], offers[player] = draft.kingdoms[seat], {}
  end
  for _, slot in ipairs(draft.slots) do
    table.insert(offers[room.players[slot.seat]], slot.name)
  end
  for _, player in ipairs(room.players) do room:shuffleTable(offers[player]) end
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
  if #player.room.players == 3 and player.seat == 1 then
    return { hp = player.hp + 1, maxHp = player.maxHp + 1 }
  end
  if #player.room.players == 4 then
    return { draw_init = openingHandAdjustments[player.seat] }
  end
  return {}
end

return M
