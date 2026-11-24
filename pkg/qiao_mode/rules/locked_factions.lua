local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local M = {}
local openingHandAdjustments = { -1, 0, 0, 1 }

-- Give each seat two distinct legal cards before filling the remaining slots.
-- If a card is shared by both factions, try moving its current slot to another
-- card so that the more restricted seat can still receive a pair.
local function reserve(kingdoms, candidates, cardKey)
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
    for _ = 1, 2 do
      local slot = { seat = seat, kingdom = kingdom }
      if not fill(slot, {}) then return end
      table.insert(slots, slot)
    end
  end
  return slots, occupied
end

function M.deal(room, plan, count)
  local num = #room.players
  assert(num == 3 or num == 4, "Locked Draft requires three or four players")
  local landlord = num == 3 and room.players[1] or nil
  local landlordBonus = landlord and 2 or 0
  local pool = table.simpleClone(plan.kept)
  local factions = table.simpleClone(plan.allowed)
  room:shuffleTable(pool)
  room:shuffleTable(factions)
  local distinctVersions = room:getSettings("disableSameConvert")
  local function cardKey(name)
    return distinctVersions and name or Fk.generals[name].trueName
  end
  local guestReplacement = Guest.replacementEnabled(room)

  for i, first in ipairs(factions) do
    for j, second in ipairs(factions) do
      if i ~= j and (num == 3 or j > i) then
        local allowed = { first, second }
        local candidates, kept, excluded = { [first] = {}, [second] = {} }, {}, {}
        for _, name in ipairs(pool) do
          local entry = Guest.resolve(name, allowed, guestReplacement)
          if entry then
            table.insert(kept, name)
            for _, kingdom in ipairs(entry.kingdoms) do
              table.insert(candidates[kingdom], name)
            end
          else
            table.insert(excluded, name)
          end
        end
        local kingdoms = num == 3 and { first, second, second } or { first, first, second, second }
        if num == 4 then room:shuffleTable(kingdoms) end
        local slots, occupied = reserve(kingdoms, candidates, cardKey)
        if slots then
          local assigned, offers = {}, {}
          for seat, player in ipairs(room.players) do
            assigned[player], offers[player] = kingdoms[seat], {}
          end
          for _, slot in ipairs(slots) do
            table.insert(offers[room.players[slot.seat]], slot.name)
          end
          for size = 3, count + landlordBonus do
            for _, player in ipairs(room.players) do
              if #offers[player] == size - 1 and (size <= count or player == landlord) then
                local name = table.find(candidates[assigned[player]], function(candidate)
                  return not occupied[cardKey(candidate)]
                end)
                if name then
                  occupied[cardKey(name)] = true
                  table.insert(offers[player], name)
                end
              end
            end
          end
          for _, player in ipairs(room.players) do room:shuffleTable(offers[player]) end
          plan.allowed = allowed
          plan.rotationBans = plan.banned
          plan.banned = table.filter(plan.candidates, function(kingdom)
            return not table.contains(plan.allowed, kingdom)
          end)
          plan.kept = kept
          table.insertTable(plan.excluded, excluded)
          return offers, assigned
        end
      end
    end
  end
  error("Not enough legal general pairs for two factions in Locked Draft")
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
