-- 统一版本登记：普通版、君主版与野心家效忠版。
--
-- 效忠版的登记与开局入池由 wild_allegiance.lua 负责（该模块也是选将池
-- general_pool.lua 的数据来源）；本模块补充君主版的显式登记，并提供
-- 供准备阶段升变和规则测试使用的一层统一查询接口。
--
-- 君主版程序名不得包含 "lord"，以免触发上游 new_hegemony_mode /
-- hegemony_rule 中只按名字识别的君主特例。君主版自身永远 hidden，
-- 不能进入发将牌堆；只能在普通升变或死亡继位时由 changeHero 换上。
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
local Wild = require "packages.hanjin.pkg.hanjin_mode.rules.wild_allegiance"
local M = {}

-- normal -> { normal = name, lord = name|nil }
M.families = {}
M.lords = {} -- lord -> { normal = name, kingdoms = { ... } }
M.loyalties = {} -- loyalty version name -> { normal = name, name = version }

local function assertGeneral(name, role)
  assert(type(name) == "string" and name ~= "", "A " .. role .. " general needs a name")
  local general = Fk.generals[name]
  assert(general ~= nil, "Unknown " .. role .. " general: " .. tostring(name))
  assert(not name:find("lord", 1, true),
    "Hanjin " .. role .. " versions must not use upstream 'lord' name markers: " .. name)
  return general
end

--- 登记一组版本。spec = { normal=..., lord=..., loyalty=... }
--- loyalty 通过 wild_allegiance 的公开 API 登记，保证开局入池、选将和
--- 局中效忠升变读取的是同一份对应关系。
function M.register(spec)
  assert(type(spec) == "table", "Version registration must be a table")
  local normal = spec.normal
  local general = assertGeneral(normal, "normal")
  local family = M.families[normal]
  if family == nil then
    family = { normal = normal }
    M.families[normal] = family
    general.ishanjin_normal = true
  end

  if spec.lord ~= nil then
    local lord = assertGeneral(spec.lord, "lord")
    assert(lord.kingdom ~= "wild", "A lord version cannot be a wild general: " .. spec.lord)
    local kingdoms = Ban.affiliations(lord)
    assert(#kingdoms > 0, "A lord version needs a regular kingdom: " .. spec.lord)
    if family.lord ~= nil then
      assert(family.lord == spec.lord, "A normal version has two lord versions: " .. normal)
    end
    local owner = M.lords[spec.lord]
    if owner ~= nil then
      assert(owner.normal == normal, "A lord version belongs to two normal versions: " .. spec.lord)
    else
      lord.hidden = true
      lord.is_lord = true
      M.lords[spec.lord] = { normal = normal, kingdoms = kingdoms }
    end
    family.lord = spec.lord
  end

  if spec.loyalty ~= nil then
    local loyalty = spec.loyalty
    if type(loyalty) == "table" then
      assert(#loyalty == 1, "A wild-exclusive general has one allegiance version")
      loyalty = loyalty[1]
    end
    assertGeneral(loyalty, "loyalty")
    -- wild_allegiance 负责重复登记和势力合法性检查。
    if not Wild.isAllegiance(loyalty) then
      Wild.registerAllegiance(normal, loyalty)
    end
    M.loyalties[loyalty] = { normal = normal, name = loyalty }
  end

  local ok, Exchange = pcall(require, "packages.hanjin.pkg.hanjin_mode.rules.general_exchange")
  if ok and Exchange.registerLordGeneral and spec.lord ~= nil then
    Exchange.registerLordGeneral(spec.lord)
  end
  return family
end

function M.family(normal)
  return M.families[normal]
end

function M.lord_version(normal)
  local family = M.families[normal]
  return family and family.lord or nil
end

--- 效忠版由 wild_allegiance 登记；返回数组便于统一遍历。
function M.loyalty_versions(normal)
  local entry = Wild.variantOf(normal)
  return entry and { entry.name } or {}
end

function M.is_lord(name)
  return type(name) == "string" and M.lords[name] ~= nil
end

function M.is_loyalty(name)
  return Wild.isAllegiance(name)
end

function M.is_normal(name)
  return type(name) == "string" and M.families[name] ~= nil
end

function M.lord_kingdoms(name)
  local data = M.lords[name]
  return data and table.simpleClone(data.kingdoms) or {}
end

function M.loyalty_kingdoms(name)
  return Wild.kingdomsOf(name)
end

function M.lord_is_for(name, kingdom)
  return table.contains(M.lord_kingdoms(name), kingdom)
end

function M.original_of(name)
  return Wild.originalOf(name)
end

--- 把通过 wild_allegiance 直接登记的效忠版同步到统一查询表。
function M.sync_loyalties()
  for version, original in pairs(Wild.originals) do
    M.loyalties[version] = M.loyalties[version] or { normal = original, name = version }
  end
end

--- 纯规则版本池规划：决定本局可发哪些普通版和效忠版。
--- @param playerCount integer
--- @param names string[] @ 本局基础牌堆
--- @param previous table? @ 上一局记录
--- @param wildCount integer @ 允许保留的原版野心家专属武将数
--- @param pick fun(list: string[], n: integer): string[]
--- @param get fun(name: string): General
--- @param opts? { candidates?: string[], limit?: integer } @ 房主候选势力与允许上限；缺省六势力/4
function M.planPool(playerCount, names, previous, wildCount, pick, get, opts)
  assert(type(playerCount) == "number" and playerCount >= 1, "Invalid player count")
  assert(type(wildCount) == "number" and wildCount >= 0 and wildCount % 1 == 0,
    "Wild general count must be a non-negative integer")
  M.sync_loyalties()

  local normal, wild, seen = {}, {}, {}
  for _, name in ipairs(names) do
    if not M.is_lord(name) and not M.is_loyalty(name) then
      local general = get(name)
      if general.kingdom == "wild" then
        if not seen[name] then seen[name] = true; table.insert(wild, name) end
      elseif not seen[name] then
        seen[name] = true
        table.insert(normal, name)
      end
    end
  end

  -- 四人及以下：原版野心家专属武将完全不参与发将，全部由登记的效忠版代替。
  local keptWild = {}
  if playerCount > 4 then
    keptWild = pick(wild, math.min(wildCount, #wild))
  end
  local keptWildSet = {}
  for _, name in ipairs(keptWild) do keptWildSet[name] = true end

  -- 被排除的原版（含人数上限随机排除与四人局规则）把效忠版加入候选，
  -- 同一效忠版只加入一次。未登记效忠版的原版直接移出本局。
  local candidates, candidateSeen = table.simpleClone(normal), {}
  for _, name in ipairs(normal) do candidateSeen[name] = true end
  for _, name in ipairs(wild) do
    if not keptWildSet[name] then
      for _, loyalty in ipairs(M.loyalty_versions(name)) do
        if not candidateSeen[loyalty] then
          candidateSeen[loyalty] = true
          table.insert(candidates, loyalty)
        end
      end
    end
  end

  -- BAN-001's candidate set comes only from the host settings; it is never
  -- inferred from the pile or from the generals' printed/guest affiliations.
  local selection = opts or {}
  local plan = Ban.plan(selection.candidates or Ban.defaultKingdoms,
    previous, pick, selection.limit)
  -- Plan filtering uses the same per-room resolution as the pool builder: keep
  -- a general when at least one printed (or loyalty-declared) kingdom is
  -- allowed, or when a registered guest faction is usable. A general whose
  -- only affiliations are outside the host's candidates is excluded.
  local kept, excluded = {}, {}
  for _, name in ipairs(candidates) do
    if Guest.resolve(name, plan.allowed) ~= nil then
      table.insert(kept, name)
    else
      table.insert(excluded, name)
    end
  end
  for _, name in ipairs(keptWild) do table.insert(kept, name) end
  for _, name in ipairs(wild) do
    if not keptWildSet[name] then table.insert(excluded, name) end
  end

  return {
    banned = plan.banned,
    allowed = plan.allowed,
    candidates = plan.candidates,
    limit = plan.limit,
    kept = kept,
    excluded = excluded,
    wild_kept = keptWild,
  }
end

--- 房间入口；mode.lua 只调用此函数即可得到完整的允许势力、将池与排除名单。
function M.plan(room, names, previous, wildCount, pick, get, opts)
  return M.planPool(#room.players, names, previous, wildCount, pick, get, opts)
end

--- 选将合法性查询。君主版永不合法；普通牌和已入池的效忠版沿用
--- Fk:canUseGeneral 的禁用与隐藏判断。
function M.selectable(name, room)
  if Fk.generals[name] == nil or M.is_lord(name) then return false end
  if Fk:canUseGeneral(name) then return true end
  return M.is_loyalty(name) and room ~= nil and table.contains(room.general_pile, name)
end

return M
