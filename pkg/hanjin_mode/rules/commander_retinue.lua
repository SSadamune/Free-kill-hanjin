-- 统领与翼从公共规则。武将牌只登记牌面数据；翼从的卡面与技能由
-- 汉晋内容包独立创建。上游 hegemony 仅用于移将、明置和势力流程。
local H = require "packages.hegemony.util"
local M = {}

M.RULE_SKILL = "#hanjin_commander_rule"
M.ABILITY_SKILL = "#hanjin_commander_ability"
M.SOURCE_MARK = "@hanjin_commander_sources"
M.SOURCE_TAG = "hanjin_commander_sources"
M.PENDING_TAG = "hanjin_commander_pending"
M.CARD_SOURCE_MARK = "hanjin_commander_source"

-- 全局登记表只在进程内描述牌面数据；对局状态一律保存在房间中。
M.commanders = {}
M.retinues = {}

local function translate(name)
  local ret = Fk:translate(name)
  return ret ~= name and ret or name
end

local function isUnknown(faction)
  return faction == nil or faction == "" or faction == "unknown"
end

function M.factionOf(player)
  if player == nil then return "unknown" end
  if player.kingdom == "wild" then return player.role or "wild" end
  return player.kingdom or "unknown"
end

function M.factionFromRaw(player, raw)
  if raw == "wild" then return player.role or "wild" end
  return raw or "unknown"
end

function M.registerCommander(general, spec)
  assert(type(general) == "string" and Fk.generals[general], "Unknown commander general: " .. tostring(general))
  assert(not M.retinues[general], "A commander cannot also be a retinue: " .. general)
  assert(type(spec) == "table", "Commander spec must be a table")
  assert(type(spec.card) == "string" and spec.card ~= "",
    "Commander must mark a card type: " .. tostring(spec.card))
  assert(type(spec.retinues) == "table" and #spec.retinues > 0,
    "Commander must provide at least one retinue")
  local retinues = {}
  for _, name in ipairs(spec.retinues) do
    assert(M.retinues[name], "Unknown retinue general: " .. tostring(name))
    table.insertIfNeed(retinues, name)
  end
  local data = {
    general = general,
    card = spec.card,
    retinues = retinues,
  }
  M.commanders[general] = data
  Fk:loadTranslationTable {
    ["hanjin_commander_source:" .. general] = translate(general) .. "｜" .. translate(spec.card),
  }
  return data
end

function M.registerRetinue(general, spec)
  assert(type(general) == "string" and Fk.generals[general], "Unknown retinue general: " .. tostring(general))
  assert(not M.commanders[general], "A retinue cannot also be a commander: " .. general)
  spec = spec or {}
  M.retinues[general] = {
    general = general,
    name = spec.name or general,
  }
  -- 翼从只由规则授予，不进入初始发将、普通换将候选或普通将池。
  Fk.generals[general].hidden = true
  local ok, Exchange = pcall(require, "packages.hanjin.pkg.hanjin_mode.rules.general_exchange")
  if ok and Exchange.registerSoldierGeneral then
    Exchange.registerSoldierGeneral(general, "retinue")
  end
  return M.retinues[general]
end

function M.isRetinue(name)
  return type(name) == "string" and M.retinues[name] ~= nil
end

function M.isBlankSoldier(name)
  return type(name) == "string" and name:startsWith("blank_")
end

function M.isSoldier(name)
  return M.isBlankSoldier(name) or M.isRetinue(name)
end

function M.isCommander(name)
  return type(name) == "string" and M.commanders[name] ~= nil
end

function M.hasSoldier(player)
  return M.isSoldier(player.general) or M.isSoldier(player.deputyGeneral)
end

function M.getSources(room)
  return room:getTag(M.SOURCE_TAG) or {}
end

function M.saveSources(room, sources)
  room:setTag(M.SOURCE_TAG, sources)
end

function M.source(room, general)
  return M.getSources(room)[general]
end

function M.ensureSource(room, general)
  local sources = M.getSources(room)
  local source = sources[general]
  if source == nil then
    local spec = assert(M.commanders[general], "Unknown commander: " .. tostring(general))
    source = {
      general = general,
      card = spec.card,
      retinues = table.simpleClone(spec.retinues),
      factions = {},
      revealed = false,
      removed = false,
      holder_id = 0,
    }
    sources[general] = source
    M.saveSources(room, sources)
  end
  return source
end

function M.sourcePresent(source, holder)
  if holder == nil or holder.dead then return false end
  return holder.general == source.general or holder.deputyGeneral == source.general
end

function M.sourceAbilityActive(room, source)
  if not source.revealed or source.removed then return false end
  local holder = room:getPlayerById(source.holder_id or 0)
  return holder ~= nil and not holder.dead and M.sourcePresent(source, holder)
end

--- 来源的统领能力只对其当前持有者所在势力开放。source.factions 只用于
--- 翼从兵种的持续获得；暗置迁势力后旧势力仍可取得兵种，但不能发动能力。
function M.sourceAuthorizedFor(room, source, player)
  if not M.sourceAbilityActive(room, source) then return false end
  local holder = room:getPlayerById(source.holder_id or 0)
  if holder == nil or player == nil or player.dead then return false end
  if isUnknown(M.factionOf(player)) then return false end
  if holder == player then return true end
  return H.compareKingdomWith(holder, player)
end

function M.markSources(player)
  local mark = player and player:getMark(M.SOURCE_MARK)
  if type(mark) ~= "table" then return {} end
  return table.simpleClone(mark)
end

function M.addSourceFaction(source, faction)
  if not isUnknown(faction) then source.factions[faction] = true end
end

function M.removeSourceFaction(source, faction)
  if not isUnknown(faction) then source.factions[faction] = nil end
end

--- 取得某势力可由所有已提供兵种的统领来源获得的兵种（去重、保持登记顺序）。
function M.availableRetinues(room, faction)
  if isUnknown(faction) then return {} end
  local result = {}
  local names = {}
  for general in pairs(M.getSources(room)) do table.insert(names, general) end
  table.sort(names)
  for _, general in ipairs(names) do
    local source = M.getSources(room)[general]
    if source.factions[faction] then
      for _, retinue in ipairs(source.retinues) do table.insertIfNeed(result, retinue) end
    end
  end
  return result
end

function M.abilitySources(player)
  if player == nil or player.dead or M.hasSoldier(player) then return {} end
  local faction = M.factionOf(player)
  if isUnknown(faction) then return {} end
  local room = player.room
  local result = {}
  for general, source in pairs(M.getSources(room)) do
    if M.sourceAuthorizedFor(room, source, player)
      and #M.costCandidates(player, source) > 0 then
      table.insert(result, general)
    end
  end
  table.sort(result)
  local ret = {}
  for _, general in ipairs(result) do table.insert(ret, M.getSources(room)[general]) end
  return ret
end

function M.refreshAvailability(room)
  if room == nil then return end
  for _, player in ipairs(room.players) do
    local list = {}
    for _, source in ipairs(M.abilitySources(player)) do table.insert(list, source.general) end
    room:setPlayerMark(player, M.SOURCE_MARK, #list > 0 and list or 0)
  end
end

function M.hasAvailableMark(player)
  local mark = player:getMark(M.SOURCE_MARK)
  return type(mark) == "table" and #mark > 0
end

--- 客户端 view_as 只能依赖客户端已有的可见标记和全局牌面登记，
--- 不能读取服务端房间 tag。服务端会在 before_use 中重新核验。
function M.viewAsCardForClient(player, sourceKey)
  local spec = M.commanders[sourceKey]
  if spec == nil or Fk.all_card_types[spec.card] == nil then return nil end
  local card = Fk:cloneCard(spec.card)
  card.skillName = M.ABILITY_SKILL
  card:setMark(M.CARD_SOURCE_MARK, sourceKey)
  return card
end

function M.hasNullificationSource(player)
  for _, sourceKey in ipairs(M.markSources(player)) do
    local spec = M.commanders[sourceKey]
    if spec ~= nil and Fk.all_card_types[spec.card] ~= nil then
      local card = Fk:cloneCard(spec.card)
      local pattern = Fk.currentResponsePattern
      if card.trueName == "nullification" and card.is_passive
        and (pattern == nil or card:matchVSPattern(pattern)) then
        return true
      end
    end
  end
  return false
end

local function positionName(player, isDeputy)
  return isDeputy and player.deputyGeneral or player.general
end

function M.costCandidates(player, source)
  local result = {}
  for _, isDeputy in ipairs({ false, true }) do
    local general = positionName(player, isDeputy)
    if type(general) == "string" and general ~= "" and not M.isSoldier(general) then
      -- 代价不得是本次提供能力的统领本身；自己的其他统领可以作为代价。
      if not (source.holder_id == player.id and source.general == general) then
        table.insert(result, isDeputy)
      end
    end
  end
  return result
end

function M.chooseCostPosition(player, source)
  local candidates = M.costCandidates(player, source)
  if #candidates == 0 then return nil end
  if #candidates == 1 then return candidates[1] end
  local answer = player.room:askToChoice(player, {
    choices = { "mainGeneral", "deputyGeneral" },
    skill_name = M.ABILITY_SKILL,
    prompt = "#hanjin_commander_choose_cost",
  })
  return answer == "deputyGeneral"
end

local function requestConversion(room, faction, player, isDeputy)
  local pending = room:getTag(M.PENDING_TAG) or { factions = {}, positions = {} }
  pending.factions = pending.factions or {}
  pending.positions = pending.positions or {}
  if not isUnknown(faction) then pending.factions[faction] = true end
  if player ~= nil then
    local key = player.id .. (isDeputy and ":d" or ":m")
    pending.positions[key] = { id = player.id, isDeputy = isDeputy }
  end
  room:setTag(M.PENDING_TAG, pending)
  M.flushConversions(room)
end

M.requestConversion = requestConversion

function M.assignRetinue(player, isDeputy, retinue)
  if not M.isRetinue(retinue) then return false end
  local room = player.room
  local old = positionName(player, isDeputy)
  if not M.isBlankSoldier(old) then return false end
  room:changeHero(player, retinue, false, isDeputy, false, false, false)
  room:setPlayerMark(player, isDeputy and "__heg_deputy" or "__heg_general", retinue)
  room:sendLog {
    type = "#HanjinRetinueGained",
    from = player.id,
    arg = isDeputy and "deputyGeneral" or "mainGeneral",
    arg2 = retinue,
  }
  return true
end

function M.convertPosition(player, isDeputy)
  if player == nil or player.dead then return false end
  local old = positionName(player, isDeputy)
  if not M.isBlankSoldier(old) then return false end
  local faction = M.factionOf(player)
  if isUnknown(faction) then return false end
  local room = player.room
  local choices = M.availableRetinues(room, faction)
  if #choices == 0 then return false end
  local choice = choices[1]
  if #choices > 1 then
    local answer = room:askToChooseGeneral(player, {
      generals = choices,
      n = 1,
      no_convert = true,
      prompt = "#hanjin_commander_choose_retinue",
    })
    if type(answer) == "table" then answer = answer[1] end
    if table.contains(choices, answer) then choice = answer end
  end
  return M.assignRetinue(player, isDeputy, choice)
end

function M.flushConversions(room)
  local pending = room:getTag(M.PENDING_TAG)
  if pending == nil then return end
  room:setTag(M.PENDING_TAG, nil)
  local seen, positions = {}, {}
  local function add(player, isDeputy)
    if player == nil or player.dead then return end
    local key = player.id .. (isDeputy and ":d" or ":m")
    if seen[key] then return end
    seen[key] = true
    table.insert(positions, { player = player, isDeputy = isDeputy })
  end
  for faction in pairs(pending.factions or {}) do
    for _, player in ipairs(room.alive_players) do
      if M.factionOf(player) == faction then
        add(player, false)
        add(player, true)
      end
    end
  end
  for _, entry in pairs(pending.positions or {}) do
    add(room:getPlayerById(entry.id), entry.isDeputy)
  end
  for _, entry in ipairs(positions) do M.convertPosition(entry.player, entry.isDeputy) end
  M.refreshAvailability(room)
end

function M.buildViewAsCard(player, sourceKey)
  local source = M.source(player.room, sourceKey)
  if source == nil or not M.sourceAuthorizedFor(player.room, source, player) then return nil end
  if M.hasSoldier(player) then return nil end
  return M.viewAsCardForClient(player, sourceKey)
end

--- 支付统领能力的移将代价。支付前核验无士兵条件及来源是否仍可发动；
--- 移除被阻止或没有改变该位置时返回 false，调用者不得继续用牌。
function M.payCost(player, source, isDeputy)
  local room = player.room
  if source == nil or not M.sourceAuthorizedFor(room, source, player) then return false end
  if M.hasSoldier(player) then return false end
  if not table.contains(M.costCandidates(player, source), isDeputy) then return false end
  local old = positionName(player, isDeputy)
  H.removeGeneral(player, isDeputy)
  local new = positionName(player, isDeputy)
  -- 移将可能立即生成白板士兵并按规则转换成翼从；两者都表示移除成功。
  if new == old or not M.isSoldier(new) then return false end
  return true
end

function M.onGeneralShown(room, player, data)
  local names = {}
  if type(data) == "table" then
    if data.m then table.insert(names, data.m) end
    if data.d then table.insert(names, data.d) end
  end
  for _, general in ipairs(names) do
    if M.isCommander(general) then
      local source = M.ensureSource(room, general)
      source.holder_id = player.id
      source.revealed = true
      source.removed = false
      local faction = M.factionOf(player)
      if not isUnknown(faction) then
        source.factions[faction] = true
        source.last_faction = faction
      end
      -- 暗置期间改势力未迁移时，明置后新旧势力均保有该来源。
      for registered in pairs(source.factions) do requestConversion(room, registered) end
    end
  end
  -- 普通武将明置也会使角色取得确定势力；带白板士兵加入势力时立即转换。
  local faction = M.factionOf(player)
  if not isUnknown(faction) then
    requestConversion(room, nil, player, false)
    requestConversion(room, nil, player, true)
  end
  M.refreshAvailability(room)
end

function M.onGeneralHidden(room, player, general)
  local source = M.source(room, general)
  if source ~= nil and source.holder_id == player.id then
    source.revealed = false
  end
  M.refreshAvailability(room)
end

function M.onGeneralRemoved(room, player, data)
  local orig = data and data.origName or ""
  local isDeputy = data and data.isDeputy or false
  local source = M.source(room, orig)
  if source ~= nil then
    source.revealed = false
    source.removed = true
  end
  if M.isRetinue(orig) then
    table.removeOne(room.general_pile, orig)
  end
  requestConversion(room, M.factionOf(player), player, isDeputy)
  M.refreshAvailability(room)
end

function M.onDeath(room, player)
  local changed = false
  for _, source in pairs(M.getSources(room)) do
    if source.holder_id == player.id then
      source.revealed = false
      changed = true
    end
  end
  if changed then M.refreshAvailability(room) end
end

function M.onAfterPropertyChange(room, player, data)
  local results = data and data.results or {}
  local kingdomChange = results.kingdomChange
  if kingdomChange then
    local oldFaction = M.factionFromRaw(player, kingdomChange[1])
    local newFaction = M.factionOf(player)
    if not isUnknown(newFaction) then
      for _, source in pairs(M.getSources(room)) do
        if source.holder_id == player.id and source.revealed
          and M.sourcePresent(source, player) then
          if not isUnknown(oldFaction) and oldFaction ~= newFaction then
            source.factions[oldFaction] = nil
          end
          source.factions[newFaction] = true
          source.last_faction = newFaction
          requestConversion(room, newFaction)
        end
      end
    end
    if not isUnknown(newFaction) then
      -- 带白板士兵加入新势力；统领转入时上方已请求整个新势力。
      requestConversion(room, nil, player, false)
      requestConversion(room, nil, player, true)
    end
  end

  local generalChange = results.generalChange
  if generalChange and M.isBlankSoldier(generalChange[2]) then
    requestConversion(room, M.factionOf(player), player, false)
  end
  local deputyChange = results.deputyChange
  if deputyChange and M.isBlankSoldier(deputyChange[2]) then
    requestConversion(room, M.factionOf(player), player, true)
  end
  M.refreshAvailability(room)
end

--- 交换模块在双方新位置全部就绪后同步调用。只迁移已明置统领的来源；
--- 交换来的白板士兵按“获得”处理，并在来源更新后统一转换。
function M.onExchangeCompleted(room, context)
  if context == nil or context.sides == nil then return end
  local sides = context.sides
  local affected = {}
  local function previousSide(general)
    for _, side in ipairs(sides) do
      if side.previous == general then return side end
    end
  end
  for _, side in ipairs(sides) do
    local general = side.general
    if M.isCommander(general) then
      local oldSide = previousSide(general)
      local oldFaction = oldSide and M.factionOf(oldSide.player) or nil
      local newFaction = M.factionOf(side.player)
      local source = M.ensureSource(room, general)
      source.holder_id = side.player.id
      source.removed = false
      source.revealed = true
      if oldFaction ~= nil and not isUnknown(oldFaction) and not isUnknown(newFaction)
        and oldFaction ~= newFaction then
        source.factions[oldFaction] = nil
      end
      if not isUnknown(newFaction) then
        source.factions[newFaction] = true
        affected[newFaction] = true
      end
      source.last_faction = newFaction
    end
  end

  for _, source in pairs(M.getSources(room)) do
    if source.revealed then
      local holder = room:getPlayerById(source.holder_id or 0)
      if not M.sourcePresent(source, holder) then source.revealed = false end
    end
  end

  for _, entry in ipairs(context and context.obtained_soldiers or {}) do
    if M.isBlankSoldier(entry.general) then
      requestConversion(room, nil, entry.player, entry.isDeputy)
    end
  end
  for faction in pairs(affected) do requestConversion(room, faction) end
  M.refreshAvailability(room)
  M.flushConversions(room)
end

function M.reset(room)
  room:setTag(M.SOURCE_TAG, nil)
  room:setTag(M.PENDING_TAG, nil)
  for _, player in ipairs(room.players) do
    room:setPlayerMark(player, M.SOURCE_MARK, 0)
  end
end

function M.grantAbility(player)
  local room = player.room
  if Fk.skills[M.ABILITY_SKILL] == nil then return end
  room:handleAddLoseSkills(player, M.ABILITY_SKILL, nil, false, true)
end

function M.excludeRetinuesFromPile(room)
  room.general_pile = table.filter(room.general_pile, function(name)
    return not M.isRetinue(name)
  end)
end

local ok, Exchange = pcall(require, "packages.hanjin.pkg.hanjin_mode.rules.general_exchange")
if ok and Exchange.addCompletionListener then
  Exchange.addCompletionListener(M.onExchangeCompleted)
end

return M
