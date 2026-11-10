-- Pure rules: no process-global history, no mutation of upstream generals/cards.
--
-- BAN-001 is driven only by the host's candidate-kingdom selection. The pool's
-- own general affiliations are never used to infer the candidate set. This makes
-- a candidate kingdom with no general in the pile (or one that appears only as
-- a guest faction) legal without silently extending the set.
local M = {}

local BASE_KINGDOMS = { "wei", "shu", "wu", "qun", "han", "jin" }
M.kingdoms = table.clone(BASE_KINGDOMS)
M.defaultKingdoms = table.clone(BASE_KINGDOMS)

M.candidateKey = "hanjin_candidate_kingdoms"
M.limitKey = "hanjin_kingdom_limit"
M.candidatePrefix = "hanjin_candidate_"

---Add a future regular kingdom. It is selectable by the host but is not part of
---the default candidate set unless registered with `{ default = true }`.
---@param kingdom string
---@param opts? { default?: boolean }
---@return string
function M.registerKingdom(kingdom, opts)
  assert(type(kingdom) == "string" and kingdom ~= "", "Invalid kingdom id")
  assert(not M.isKnown(kingdom), "Kingdom is already registered: " .. kingdom)
  table.insert(M.kingdoms, kingdom)
  if opts and opts.default then table.insert(M.defaultKingdoms, kingdom) end
  return kingdom
end

---Restore the six built-in kingdoms. Intended for isolated tests of future
---kingdom ids, not for normal gameplay.
function M.resetKingdoms()
  for i = #M.kingdoms, 1, -1 do M.kingdoms[i] = nil end
  for i = #M.defaultKingdoms, 1, -1 do M.defaultKingdoms[i] = nil end
  table.insertTable(M.kingdoms, BASE_KINGDOMS)
  table.insertTable(M.defaultKingdoms, BASE_KINGDOMS)
end

---@param kingdom string
---@return boolean
function M.isKnown(kingdom)
  return table.contains(M.kingdoms, kingdom)
end

---@param g General
---@return string[]
function M.affiliations(g)
  local result = {}
  for _, k in ipairs({ g.kingdom, g.subkingdom }) do
    if M.isKnown(k) then table.insertIfNeed(result, k) end
  end
  return result
end

---@param kingdoms string[]
---@return string[]
function M.validateCandidates(kingdoms)
  assert(type(kingdoms) == "table", "Candidate kingdoms must be a list")
  assert(#kingdoms > 0, "At least one candidate kingdom is required")
  local seen, result = {}, {}
  for _, kingdom in ipairs(kingdoms) do
    assert(type(kingdom) == "string" and kingdom ~= "", "Invalid candidate kingdom")
    assert(M.isKnown(kingdom), "Unknown candidate kingdom: " .. kingdom)
    assert(not seen[kingdom], "Duplicate candidate kingdom: " .. kingdom)
    seen[kingdom] = true
    table.insert(result, kingdom)
  end
  return result
end

---@param limit any
---@param candidateCount integer
function M.validateLimit(limit, candidateCount)
  assert(type(limit) == "number" and limit >= 1 and limit % 1 == 0,
    "Kingdom limit must be a positive integer")
  assert(limit <= candidateCount, "Kingdom limit cannot exceed the candidate count")
end

---@param mode table
---@param kingdom string
---@return boolean
function M.candidateValue(mode, kingdom)
  local explicit = mode[M.candidateKey]
  if type(explicit) == "table" then return table.contains(explicit, kingdom) end
  local value = mode[M.candidatePrefix .. kingdom]
  if value == nil then return table.contains(M.defaultKingdoms, kingdom) end
  assert(type(value) == "boolean", "Candidate switches must be booleans")
  return value
end

---Number of selected candidates for UI range calculation. Does not validate, so
---an in-progress edit with zero candidates does not break the QML binding.
---@param mode table
---@return integer
function M.candidateCount(mode)
  local explicit = mode[M.candidateKey]
  if type(explicit) == "table" then return #explicit end
  local count = 0
  for _, kingdom in ipairs(M.kingdoms) do
    if M.candidateValue(mode, kingdom) then count = count + 1 end
  end
  return count
end

---Resolve and validate host settings.
---@param get fun(key: string): any
---@return table @ { candidates = string[], limit = integer }
function M.resolveSettings(get)
  assert(type(get) == "function", "Settings getter must be a function")
  local candidates
  local explicit = get(M.candidateKey)
  if explicit ~= nil then
    candidates = M.validateCandidates(explicit)
  else
    candidates = {}
    local anySwitch = false
    for _, kingdom in ipairs(M.kingdoms) do
      local value = get(M.candidatePrefix .. kingdom)
      if value ~= nil then
        anySwitch = true
        assert(type(value) == "boolean", "Candidate switches must be booleans")
      end
      if value == nil then value = table.contains(M.defaultKingdoms, kingdom) end
      if value then table.insert(candidates, kingdom) end
    end
    if #candidates == 0 then
      assert(not anySwitch, "At least one candidate kingdom is required")
      candidates = table.clone(M.defaultKingdoms)
    end
  end
  local limit = get(M.limitKey)
  if limit == nil then limit = math.min(4, #candidates) end
  M.validateLimit(limit, #candidates)
  return { candidates = candidates, limit = limit }
end

---Pure BAN-001 plan.
---
---`kingdoms` is the host's candidate set. When the set is no larger than the
---limit there is no additional ban, even if the previous game has winners. When
---it is larger, the plan must ban winners that are still candidates, must not ban
---kingdoms protected by the previous game's ban list, and fills the remainder
---with the room's random picker.
---@param kingdoms string[]
---@param previous? { winners: string[], banned: string[] }
---@param pick fun(list: string[], n: integer): string[]
---@param limit? integer
---@return table @ { banned, allowed, candidates, limit }
function M.plan(kingdoms, previous, pick, limit)
  local candidates = M.validateCandidates(kingdoms)
  assert(type(pick) == "function", "Missing room random picker")
  if limit == nil then limit = math.min(4, #candidates) end
  M.validateLimit(limit, #candidates)

  local count = #candidates - limit
  if count <= 0 then
    return {
      banned = {}, allowed = table.clone(candidates),
      candidates = table.clone(candidates), limit = limit,
    }
  end

  local winners = previous and previous.winners or {}
  local protected = previous and previous.banned or {}
  assert(type(winners) == "table" and type(protected) == "table",
    "Invalid previous-game record")
  local protectedSet = {}
  for _, kingdom in ipairs(protected) do protectedSet[kingdom] = true end

  local banned = {}
  for _, kingdom in ipairs(winners) do
    if table.contains(candidates, kingdom) then
      assert(not protectedSet[kingdom], "Contradictory previous winner and ban: " .. kingdom)
      table.insertIfNeed(banned, kingdom)
    end
  end
  assert(#banned <= count, "Previous winners require more bans than the candidate limit allows")

  local available = table.filter(candidates, function(kingdom)
    return not protectedSet[kingdom] and not table.contains(banned, kingdom)
  end)
  assert(#available >= count - #banned,
    "Cannot reach the candidate limit while respecting previous-game constraints")
  local random = pick(available, count - #banned)
  assert(type(random) == "table" and #random == count - #banned,
    "Room random picker did not return enough kingdoms")
  table.insertTable(banned, random)

  return {
    banned = banned,
    allowed = table.filter(candidates, function(kingdom)
      return not table.contains(banned, kingdom)
    end),
    candidates = table.clone(candidates),
    limit = limit,
  }
end

---@param g General
---@param allowed string[]
---@return boolean
function M.generalAllowed(g, allowed)
  if g.kingdom == "wild" then return true end
  return table.find(M.affiliations(g), function(k) return table.contains(allowed, k) end) ~= nil
end

---@param main General
---@param deputy General
---@param allowed string[]
---@return string[]
function M.pairKingdoms(main, deputy, allowed)
  if deputy.kingdom == "wild" then return {} end
  local first = main.kingdom == "wild" and allowed or M.affiliations(main)
  return table.filter(M.affiliations(deputy), function(k)
    return table.contains(first, k) and table.contains(allowed, k)
  end)
end

---Legacy helper for the old wild-count API. Pool construction uses
---`general_versions.planPool` + `general_pool.resolve`; this remains for tests.
function M.filterGenerals(names, allowed, wildCount, pick, get)
  assert(type(wildCount) == "number" and wildCount >= 0 and wildCount % 1 == 0,
    "Wild general count must be a non-negative integer")
  local wild = table.filter(names, function(n) return get(n).kingdom == "wild" end)
  local keptWild = pick(wild, math.min(wildCount, #wild))
  local kept, excluded = {}, {}
  for _, name in ipairs(names) do
    local g = get(name)
    local keep = g.kingdom == "wild" and table.contains(keptWild, name)
      or g.kingdom ~= "wild" and M.generalAllowed(g, allowed)
    table.insert(keep and kept or excluded, name)
  end
  return kept, excluded
end

return M
