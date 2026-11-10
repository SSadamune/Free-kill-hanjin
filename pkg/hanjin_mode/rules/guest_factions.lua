-- 客将 factions and per-room resolved general affiliations.
--
-- The engine's `kingdom` / `subkingdom` fields only describe printed
-- affiliations. A guest general keeps them unchanged; this module records the
-- guest factions separately and resolves, per room, which regular factions a
-- general may actually use. The result is stored on the native Room tag so that
-- dealing, the selection UI, server-side pairing checks, the initial kingdom
-- choice and later general draws all read the same decision.
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local M = {}

M.guests = {} -- general name -> guest regular kingdoms
M.key = "hanjin_general_factions_v1"
M.guest_key = "hanjin_guest_generals_v1"

local function validKingdoms(kingdoms)
  assert(type(kingdoms) == "table", "Guest factions must be a list")
  local result = {}
  for _, kingdom in ipairs(kingdoms) do
    assert(table.contains(Ban.kingdoms, kingdom), "Invalid guest kingdom: " .. tostring(kingdom))
    table.insertIfNeed(result, kingdom)
  end
  assert(#result > 0, "A guest general must have at least one guest faction")
  return result
end

---Register the guest factions printed on a general.
---@param name string
---@param kingdoms string[]
---@return string[]
function M.registerGuest(name, kingdoms)
  assert(type(name) == "string" and name ~= "", "Invalid guest general name")
  local list = validKingdoms(kingdoms)
  assert(not M.guests[name], "Duplicate guest faction registration: " .. name)
  M.guests[name] = list
  return table.simpleClone(list)
end

---@param name string
---@return string[]
function M.guestKingdoms(name)
  return table.simpleClone(M.guests[name] or {})
end

---Resolve one general against this game's allowed kingdoms.
---
---Order: keep the printed affiliations that are allowed; only when every
---printed affiliation is banned does the guest faction take over. A wild
---general stays a wild main general and never uses guest factions.
---@param name string
---@param allowed string[]
---@return table? @ { name, source = "original"|"guest"|"wild", kingdoms, guest?, wild? }
function M.resolve(name, allowed)
  local general = Fk.generals[name]
  if not general then return nil end
  if general.kingdom == "wild" then
    return { name = name, source = "wild", kingdoms = {}, wild = true }
  end
  local original = table.filter(Ban.affiliations(general), function(kingdom)
    return table.contains(allowed, kingdom)
  end)
  if #original > 0 then
    return { name = name, source = "original", kingdoms = original }
  end
  local guest = table.filter(M.guests[name] or {}, function(kingdom)
    return table.contains(allowed, kingdom)
  end)
  if #guest > 0 then
    return { name = name, source = "guest", kingdoms = guest, guest = true }
  end
  return nil
end

---Persist this game's resolved affiliations on the native Room.
---@param room Room
---@param factions table<string, table>
function M.store(room, factions)
  local guests = {}
  for name, entry in pairs(factions) do
    local copy = {
      name = name,
      source = entry.source,
      kingdoms = table.simpleClone(entry.kingdoms or {}),
    }
    if entry.guest then copy.guest = true end
    if entry.wild then copy.wild = true end
    factions[name] = copy
    if copy.guest then table.insert(guests, name) end
  end
  table.sort(guests)
  room:setTag(M.key, factions)
  room:setTag(M.guest_key, guests)
  return factions
end

---Add resolutions for names that entered through another path (for example a
---redraw replacement already present in the pile).
---@param room Room
---@param names string[]
function M.ensure(room, names)
  local map = room:getTag(M.key) or {}
  local allowed = room:getBanner("all_kingdoms") or {}
  local changed = false
  for _, name in ipairs(names) do
    if not map[name] then
      local entry = M.resolve(name, allowed)
      if entry then
        map[name] = entry
        changed = true
        if entry.guest then
          local guests = room:getTag(M.guest_key) or {}
          table.insertIfNeed(guests, name)
          table.sort(guests)
          room:setTag(M.guest_key, guests)
        end
      end
    end
  end
  if changed then room:setTag(M.key, map) end
  return map
end

---@param room Room
---@param name string
---@return table?
function M.factionsOf(room, name)
  local map = room:getTag(M.key)
  if map and map[name] then return map[name] end
  local allowed = room:getBanner("all_kingdoms") or {}
  return M.resolve(name, allowed)
end

---@param room Room
---@param name string
---@return boolean
function M.isGuest(room, name)
  local entry = M.factionsOf(room, name)
  return entry ~= nil and entry.source == "guest"
end

---@param room Room
---@param names string[]
---@return string[]
function M.guestCandidates(room, names)
  return table.filter(names, function(name) return M.isGuest(room, name) end)
end

---Legal initial kingdoms for a selected main/deputy pair.
---Uses the per-room resolution, not the engine's global general definitions.
---@param room Room
---@param main string
---@param deputy string
---@param allowed? string[]
---@return string[]
function M.pairKingdoms(room, main, deputy, allowed)
  if type(main) ~= "string" or type(deputy) ~= "string" or main == deputy then return {} end
  allowed = allowed or room:getBanner("all_kingdoms") or {}
  local first = M.factionsOf(room, main)
  local second = M.factionsOf(room, deputy)
  if not first or not second then return {} end
  if second.wild then return {} end
  if first.wild then
    return table.filter(second.kingdoms, function(k) return table.contains(allowed, k) end)
  end
  return table.filter(first.kingdoms, function(k)
    return table.contains(allowed, k) and table.contains(second.kingdoms, k)
  end)
end

---@param room Room
---@param main string
---@param deputy string
---@return boolean
function M.canPair(room, main, deputy)
  return #M.pairKingdoms(room, main, deputy) > 0
end

---@param room Room
---@param names string[]
---@return table[] @ { main, deputy, kingdoms }
function M.legalPairs(room, names)
  local result = {}
  for i = 1, #names do
    for j = i + 1, #names do
      local kingdoms = M.pairKingdoms(room, names[i], names[j])
      if #kingdoms > 0 then
        table.insert(result, { main = names[i], deputy = names[j], kingdoms = kingdoms })
      else
        kingdoms = M.pairKingdoms(room, names[j], names[i])
        if #kingdoms > 0 then
          table.insert(result, { main = names[j], deputy = names[i], kingdoms = kingdoms })
        end
      end
    end
  end
  return result
end

---@param room Room
---@param names string[]
---@return table?
function M.firstLegalPair(room, names)
  return M.legalPairs(room, names)[1]
end

return M
