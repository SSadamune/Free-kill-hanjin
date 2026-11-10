-- Pure rules: no process-global history, no mutation of upstream generals/cards.
local M = {}
M.kingdoms = { "wei", "shu", "wu", "qun", "han", "jin" }

local function affiliations(g)
  local result = {}
  for _, k in ipairs({ g.kingdom, g.subkingdom }) do
    if table.contains(M.kingdoms, k) then table.insertIfNeed(result, k) end
  end
  return result
end

function M.collectKingdoms(names, get)
  local result = {}
  for _, name in ipairs(names) do
    for _, k in ipairs(affiliations(get(name))) do table.insertIfNeed(result, k) end
  end
  return result
end

function M.plan(kingdoms, previous, pick)
  local banned, protected = {}, previous and previous.banned or {}
  local count = math.max(#kingdoms - 4, 0)
  if count > 0 then
    for _, k in ipairs(previous and previous.winners or {}) do
      if table.contains(kingdoms, k) then
        assert(not table.contains(protected, k), "Contradictory previous winner and ban: " .. k)
        table.insertIfNeed(banned, k)
      end
    end
    local candidates = table.filter(kingdoms, function(k)
      return not table.contains(protected, k) and not table.contains(banned, k)
    end)
    assert(#banned <= count and #candidates >= count - #banned,
      "Cannot leave four kingdoms while respecting previous-game constraints")
    table.insertTable(banned, pick(candidates, count - #banned))
  end
  return {
    banned = banned,
    allowed = table.filter(kingdoms, function(k) return not table.contains(banned, k) end),
  }
end

function M.generalAllowed(g, allowed)
  if g.kingdom == "wild" then return true end
  return table.find(affiliations(g), function(k) return table.contains(allowed, k) end) ~= nil
end

function M.pairKingdoms(main, deputy, allowed)
  if deputy.kingdom == "wild" then return {} end
  local first = main.kingdom == "wild" and allowed or affiliations(main)
  return table.filter(affiliations(deputy), function(k)
    return table.contains(first, k) and table.contains(allowed, k)
  end)
end

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
