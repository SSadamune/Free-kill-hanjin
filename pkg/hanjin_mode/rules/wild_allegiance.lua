-- 野心家效忠版登记。
--
-- This is the single registration source used by `general_versions.lua` (the
-- unified normal/lord/loyalty query layer), the opening pool plan, the
-- preparation-phase promotion and the tests. It stores only the explicit
-- original -> allegiance mapping; the opening plan and in-game promotion should
-- ask this module rather than infer a mapping from names or true names.
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local M = {}

M.versions = {}   -- original wild general name -> { original, name, kingdoms }
M.originals = {}  -- allegiance version name -> original wild general name

local function validKingdoms(kingdoms)
  assert(type(kingdoms) == "table", "Allegiance kingdoms must be a list")
  local result = {}
  for _, kingdom in ipairs(kingdoms) do
    assert(table.contains(Ban.kingdoms, kingdom), "Invalid allegiance kingdom: " .. tostring(kingdom))
    table.insertIfNeed(result, kingdom)
  end
  assert(#result > 0, "An allegiance version must have at least one regular kingdom")
  return result
end

---Register the one allegiance version of a wild-exclusive general.
---@param original string @ wild-exclusive general name
---@param spec string|table @ version name, or { name = ..., kingdoms = {...} }
---@return table
function M.registerAllegiance(original, spec)
  assert(type(original) == "string" and original ~= "", "Invalid wild general name")
  local originalGeneral = assert(Fk.generals[original], "Unknown wild general: " .. original)
  assert(originalGeneral.kingdom == "wild",
    "Only a wild-exclusive general can have an allegiance version: " .. original)
  local entry
  if type(spec) == "string" then
    entry = { original = original, name = spec }
  else
    assert(type(spec) == "table" and type(spec.name) == "string" and spec.name ~= "",
      "Invalid allegiance registration")
    entry = { original = original, name = spec.name,
      kingdoms = spec.kingdoms and validKingdoms(spec.kingdoms) or nil }
  end
  assert(entry.name ~= original, "An allegiance version must have its own general name")
  assert(not M.versions[original], "Duplicate allegiance version for " .. original)
  assert(not M.originals[entry.name], "General is already registered as an allegiance version: " .. entry.name)
  local general = assert(Fk.generals[entry.name], "Missing allegiance general: " .. entry.name)
  assert(general.kingdom ~= "wild", "An allegiance version cannot be a wild-exclusive general")
  entry.kingdoms = entry.kingdoms or validKingdoms(Ban.affiliations(general))
  M.versions[original] = entry
  M.originals[entry.name] = original
  return entry
end

---@param original string
---@return table?
function M.variantOf(original)
  return M.versions[original]
end

---@param name string
---@return string?
function M.originalOf(name)
  return M.originals[name]
end

---@param name string
---@return boolean
function M.isAllegiance(name)
  return type(name) == "string" and M.originals[name] ~= nil
end

---Regular kingdoms declared by an allegiance version, optionally intersected
---with this game's allowed kingdoms. Never inherits a wild main-general pass.
---@param target table|string @ entry, original name or version name
---@param allowed string[]?
---@return string[]
function M.kingdomsOf(target, allowed)
  local entry = target
  if type(target) == "string" then
    entry = M.versions[target]
      or (M.originals[target] and M.versions[M.originals[target]])
  end
  assert(entry, "Unknown allegiance version")
  local kingdoms = entry.kingdoms
  if not kingdoms then
    local general = assert(Fk.generals[entry.name], "Missing allegiance general: " .. entry.name)
    kingdoms = validKingdoms(Ban.affiliations(general))
    entry.kingdoms = kingdoms
  end
  if allowed then
    kingdoms = table.filter(kingdoms, function(k) return table.contains(allowed, k) end)
  end
  return table.simpleClone(kingdoms)
end

return M
