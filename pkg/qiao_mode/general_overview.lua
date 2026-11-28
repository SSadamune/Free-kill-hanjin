local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"

local M = {}
local packages = { qiao_prefix_zhen = 1, qiao_prefix_shi = 2, qiao_prefix_bian = 3, qiao_prefix_quan = 4 }
local kingdoms = { han = 1, wei = 2, shu = 3, wu = 4, qun = 5, jin = 6 }

local function factionNumber(general)
  local number, variant = general.name:match("(%d+)([a-z]?)$")
  return ("%02d/%06d/%s"):format(kingdoms[general.kingdom] or 99, tonumber(number) or 999999, variant or "")
end

function M.zhenshiRanks()
  local origins = {}
  for id, source in pairs(Commander.commanders) do
    local position = factionNumber(Fk.generals[id])
    for _, retinue in ipairs(source.retinues) do
      -- A retinue shared by multiple factions takes its earliest listed source.
      if not origins[retinue] or position < origins[retinue] then origins[retinue] = position end
    end
  end

  local keys, names = {}, {}
  for _, general in ipairs(Fk.packages.qiao_zhenshi.generals) do
    local name = general.name
    local kind = 2
    if name:startsWith("qiao_heg__em_") then kind = 1 end
    if Commander.retinues[name] then kind = 3 end
    keys[name] = ("%d/%02d/%s/%s"):format(kind, packages[general.prefix] or 99,
      origins[name] or factionNumber(general), name)
    table.insert(names, name)
  end

  table.sort(names, function(a, b) return keys[a] < keys[b] end)
  local ranks = {}
  for rank, name in ipairs(names) do ranks[name] = rank end
  return ranks
end

return M
