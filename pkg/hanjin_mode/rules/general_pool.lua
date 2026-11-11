-- Per-room guest-faction resolution layered on the shared version plan.
--
-- The opening version replacement (wild cap, four-player rule, loyalty-version
-- registration and faction filtering) is owned by `general_versions.lua`.
-- This module takes that plan's kept general names and resolves each one against
-- this game's allowed kingdoms, enabling guest factions only when every printed
-- affiliation is banned. The result is stored per room so dealing, selection,
-- server validation, the initial kingdom and later draws share it.
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
local Versions = require "packages.hanjin.pkg.hanjin_mode.rules.general_versions"
local M = {}

local function unique(names)
  local seen, result = {}, {}
  for _, name in ipairs(names) do
    if not seen[name] then
      seen[name] = true
      table.insert(result, name)
    end
  end
  return result
end

---Resolve a version plan into this game's pool and faction map.
---@param room Room
---@param plan table @ result of Versions.plan / planPool
---@param opts table @ { wildNames?: string[], getGeneral? }
---@return table @ { names, excluded, factions, keptWild, replaced, versions }
function M.resolve(room, plan, opts)
  opts = opts or {}
  local allowed = plan.allowed or {}
  assert(type(allowed) == "table", "Missing allowed kingdoms")
  local result = {
    names = {}, excluded = {}, factions = {},
    keptWild = plan.wild_kept or {}, replaced = {}, versions = {},
  }
  local keptSet = {}
  for _, name in ipairs(plan.kept) do
    keptSet[name] = true
    local entry = Guest.resolve(name, allowed)
    if entry then
      table.insert(result.names, name)
      result.factions[name] = entry
    else
      table.insert(result.excluded, name)
    end
  end

  -- A registered loyalty version is never independently dealt. If it is not in
  -- this game's kept list (original kept, no original, or banned), hide it.
  for name in pairs(Versions.loyalties) do
    if not keptSet[name] then table.insert(result.excluded, name) end
  end

  table.insertTable(result.excluded, plan.excluded or {})
  result.names = unique(result.names)
  result.excluded = table.filter(unique(result.excluded), function(name)
    return not keptSet[name]
  end)

  if opts.wildNames then
    for _, name in ipairs(opts.wildNames) do
      if not table.contains(result.keptWild, name) then
        table.insert(result.replaced, name)
      end
    end
  end
  for _, name in ipairs(result.names) do
    if Versions.is_loyalty(name) then table.insert(result.versions, name) end
  end
  return result
end

---Persist the resolved result on the native Room.
---@param room Room
---@param built table
function M.apply(room, built)
  room.general_pile = table.simpleClone(built.names)
  table.insertTableIfNeed(room.disabled_generals, built.excluded)
  Guest.store(room, built.factions)
  room:setTag("hanjin_wild_replaced_originals_v1", built.replaced)
  room:setTag("hanjin_wild_kept_originals_v1", built.keptWild)
  room:setTag("hanjin_allegiance_versions_v1", built.versions)
  return built
end

function M.pairKingdoms(room, main, deputy, allowed)
  return Guest.pairKingdoms(room, main, deputy, allowed)
end

function M.canPair(room, main, deputy)
  return Guest.canPair(room, main, deputy)
end

function M.legalPairs(room, names)
  return Guest.legalPairs(room, names)
end

function M.firstLegalPair(room, names)
  return Guest.firstLegalPair(room, names)
end

return M
