-- 统领与翼从公共规则。武将牌只登记牌面数据；翼从的卡面与技能由
-- 汉晋内容包独立创建。上游 hegemony 仅用于移将、明置和势力流程。
local H = require "packages.hegemony.util"
local Adaptation = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
local M = {}

M.RULE_SKILL = "#hanjin_commander_rule"
M.ABILITY_SKILL = "hanjin_commander_ability"
M.SOURCE_MARK = "@[hanjin_commander_sources]"
M.SOURCE_TAG = "hanjin_commander_sources"
M.PENDING_TAG = "hanjin_commander_pending"
M.CARD_SOURCE_MARK = "hanjin_commander_source"
-- 两项每局记录彼此独立：偏将的取得是全场唯一的牌面身份，限一统领能力是
-- 某一来源的视为用牌机会。两者只在本局开始时清空，跨势力、移除、离场和
-- 重新明置均不重置。
M.USED_RETINUE_TAG = "hanjin_limited_retinues"
M.USED_ABILITY_TAG = "hanjin_limited_abilities"
-- 支付后、使用宣告前的临时占用。它只在回调期间阻挡同一来源的重入，
-- 使用中止时释放，实际使用后转为永久记录。
M.RESERVE_TAG = "hanjin_limited_reserved"

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
  local card_text = spec.card_text or translate(spec.card)
  local data = {
    general = general,
    card = spec.card,
    suit = spec.suit,
    bypass_distances = spec.bypass_distances == true,
    adaptation = table.clone(spec.adaptation or {}),
    card_text = card_text,
    source_text = spec.source_text or (translate(general) .. "｜" .. card_text),
    retinues = retinues,
    -- 来源能力自身的“限一”与偏将/翼从的限一身份是两件事。
    limited = spec.limited == true,
  }
  M.commanders[general] = data
  Fk:loadTranslationTable {
    ["hanjin_commander_source:" .. general] = data.source_text,
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
    -- 「限一」是偏将的牌面身份：每局全场只能实际取得一次。
    limited = spec.limited == true,
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

--- 偏将（限一翼从）的全场唯一取得记录。返回 偏将名 -> 取得者信息。
function M.usedLimitedRetinues(room)
  return room:getTag(M.USED_RETINUE_TAG) or {}
end

--- 限一统领来源的视为用牌机会记录。返回 统领武将名 -> 使用者信息。
function M.usedLimitedAbilities(room)
  return room:getTag(M.USED_ABILITY_TAG) or {}
end

--- 支付完成但尚未宣告使用时，按来源临时占用。返回 统领武将名 -> 支付者信息。
function M.reservedAbilities(room)
  return room:getTag(M.RESERVE_TAG) or {}
end

function M.abilityReserved(room, general)
  return M.reservedAbilities(room)[general] ~= nil
end

--- 支付成功后占用该来源，阻止移将回调期间或同一时机的重入；不写永久记录。
function M.reserveAbility(room, source, player)
  if source == nil then return false end
  if M.isLimitedSource(source) and M.limitedAbilityUsed(room, source.general) then return false end
  local reserved = M.reservedAbilities(room)
  if reserved[source.general] ~= nil then return false end
  reserved[source.general] = { player = player and player.id or 0, seat = player and player.seat or 0 }
  room:setTag(M.RESERVE_TAG, reserved)
  M.refreshAvailability(room)
  return true
end

--- 使用中止（如 PreCardUse 被中断）时释放临时占用；不消耗本局机会。
function M.releaseAbilityReservation(room, general)
  local reserved = M.reservedAbilities(room)
  if reserved[general] == nil then return false end
  reserved[general] = nil
  room:setTag(M.RESERVE_TAG, reserved)
  M.refreshAvailability(room)
  return true
end

--- 兜底清理：正常使用流程是同步的，临时占用不应跨回合。若某个
--- 询问返回的使用数据最终没有被 room:useCard 消费，回合开始时释放它。
function M.clearReservations(room)
  local reserved = M.reservedAbilities(room)
  if next(reserved) == nil then return false end
  room:setTag(M.RESERVE_TAG, nil)
  M.refreshAvailability(room)
  return true
end

--- 使用已宣告时把临时占用转为永久记录。非限一来源只释放占用。
--- 已正式使用后被无懈可击等抵消不调用此函数，因此不会返还次数。
function M.commitAbilityUse(room, general, player)
  local reserved = M.reservedAbilities(room)
  if reserved[general] == nil then return false end
  reserved[general] = nil
  room:setTag(M.RESERVE_TAG, reserved)
  local spec = M.commanders[general]
  if spec ~= nil and spec.limited then
    local used = M.usedLimitedAbilities(room)
    if used[general] == nil then
      used[general] = { player = player and player.id or 0, seat = player and player.seat or 0 }
      room:setTag(M.USED_ABILITY_TAG, used)
    end
  end
  M.refreshAvailability(room)
  return true
end

function M.isLimitedRetinue(name)
  local retinue = type(name) == "string" and M.retinues[name] or nil
  return retinue ~= nil and retinue.limited == true
end

--- 来源是否提供偏将。提供偏将的统领来源，其视为用牌机会每局限一次。
function M.isLimitedSource(source)
  if source == nil then return false end
  if source.limited ~= nil then return source.limited == true end
  local spec = M.commanders[source.general]
  return spec ~= nil and spec.limited == true
end

function M.limitedRetinueTaken(room, retinue)
  return M.isLimitedRetinue(retinue) and M.usedLimitedRetinues(room)[retinue] ~= nil
end

function M.limitedAbilityUsed(room, general)
  return M.usedLimitedAbilities(room)[general] ~= nil
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
      limited = spec.limited == true,
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

--- 统领能力是否仍可使用。除来源已明置且仍在场外，还要检查本局的
--- 限一视为用牌机会；临时占用期间同样不可再次发动。
function M.abilityAvailable(room, source)
  if not M.sourceAbilityActive(room, source) then return false end
  if M.abilityReserved(room, source.general) then return false end
  if M.isLimitedSource(source) and M.limitedAbilityUsed(room, source.general) then return false end
  return true
end

--- 来源的统领能力只对其当前持有者所在势力开放。source.factions 只用于
--- 翼从兵种的持续获得；暗置迁势力后旧势力仍可取得兵种，但不能发动能力。
function M.sourceAuthorizedFor(room, source, player)
  if not M.abilityAvailable(room, source) then return false end
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
--- 已被本局取得的偏将从所有势力的候选中排除；普通翼从不受此限制。
function M.availableRetinues(room, faction)
  if isUnknown(faction) then return {} end
  local sources = M.getSources(room)
  local used = M.usedLimitedRetinues(room)
  local result = {}
  local names = {}
  for general in pairs(sources) do table.insert(names, general) end
  table.sort(names)
  for _, general in ipairs(names) do
    local source = sources[general]
    if source.factions[faction] then
      for _, retinue in ipairs(source.retinues) do
        local taken = M.isLimitedRetinue(retinue) and used[retinue] ~= nil
        if not taken then table.insertIfNeed(result, retinue) end
      end
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
    local descriptions = {}
    local faction = M.factionOf(player)
    local used = M.usedLimitedRetinues(room)
    for key, source in pairs(M.getSources(room)) do
      if M.sourceAuthorizedFor(room, source, player) or source.factions[faction] then
        local retinues = table.filter(source.retinues, function(name)
          return not M.isLimitedRetinue(name) or not used[name]
        end)
        table.insert(descriptions, { key = key, retinues = retinues,
          active = M.sourceAuthorizedFor(room, source, player) })
      end
    end
    table.sort(descriptions, function(a, b) return a.key < b.key end)
    room:setPlayerMark(player, "hanjin_commander_descriptions", #descriptions > 0 and descriptions or 0)
  end
end

-- Public, room-specific source data is synchronized by refreshAvailability.
-- Client descriptions never inspect server-only source tags.
function M.describeSource(key, retinues, active, lang, abilityOnly)
  local spec = M.commanders[key]
  if spec == nil then return "" end
  local name = Fk:translate(key, lang)
  local card = spec.card_text or Fk:translate(spec.card, lang)
  if abilityOnly then
    return "移除一张不为" .. name .. "的武将牌，视为使用【" .. card .. "】。"
  end
  local text = name .. "："
  if active ~= false then
    text = text .. "若你没有士兵，你可以移除一张不为" .. name .. "的武将牌，视为使用【" .. card .. "】。"
    if spec.limited then text = text .. "此统领能力每局所有角色合计限一次。" end
  else
    text = text .. "当前不能借助" .. name .. "的统领能力使用【" .. card .. "】。"
  end
  local names = table.map(retinues or {}, function(id) return "「" .. Fk:translate(id, lang) .. "」" end)
  if #names == 1 then
    text = text .. "你所属势力可获得的翼从兵种包括" .. names[1] .. "。"
  elseif #names > 1 then
    text = text .. "你所属势力可获得的翼从兵种包括" .. table.concat(names, "、") .. "。"
  else
    text = text .. "当前没有可由" .. name .. "获得的翼从。"
  end
  for _, id in ipairs(retinues or {}) do
    if M.isLimitedRetinue(id) then
      text = text .. "「" .. Fk:translate(id, lang) .. "」为偏将，每局全场只能取得一次。"
    end
  end
  return text
end

function M.description(player, key, lang, abilityOnly)
  local entries = player and player:getMark("hanjin_commander_descriptions") or 0
  local lines = {}
  for _, entry in ipairs(type(entries) == "table" and entries or {}) do
    if key == nil or key == entry.key then
      table.insert(lines, M.describeSource(entry.key, entry.retinues, entry.active, lang, abilityOnly))
    end
  end
  if #lines > 0 then return table.concat(lines, "<br/>") end
  return abilityOnly and "当前没有可用的统领能力。" or "当前没有可用的统领来源或翼从。"
end

function M.hasAvailableMark(player)
  local mark = player:getMark(M.SOURCE_MARK)
  return type(mark) == "table" and #mark > 0
end

--- 当前窗口的可用来源。只用客户端可读取的隐藏来源列表，不读服务端
--- room tag；mark 由服务端在来源/代价/限一状态变化后刷新。为避免把
--- “有来源”当成“这张牌现在能使用”，这里复用新月杀当前请求的 canUse/
--- response 判定。合法目标由进入用牌界面后的目标选择与确认流程检查。

local function canUseInCurrent(player, card)
  -- ClientInstance without an active request handler is a headless call; the
  -- engine's canUseOrResponseInCurrent assumes handler.extra_data exists there.
  if Fk.currentResponsePattern ~= nil and ClientInstance ~= nil
    and ClientInstance.current_request_handler == nil then
    return card:matchVSPattern(Fk.currentResponsePattern) and not player:prohibitUse(card)
  end
  return player:canUseOrResponseInCurrent(card)
end

local function sourceCardUsable(player, card, mode)
  if card == nil then return false end
  -- 无懈/闪等被动牌只能在实际响应窗口使用，不能在出牌阶段主动使用。
  if mode == "play" and card.is_passive then return false end
  card:setVSPattern(M.ABILITY_SKILL, player)
  if not canUseInCurrent(player, card) then return false end
  if mode == "nullification" then
    return card.trueName == "nullification" and card.is_passive
  end
  return true
end

local function sourceHasCostForUI(player, key)
  -- The hidden source mark is refreshed by the server only for sources with a
  -- removable main/deputy general. Never read the server room tag on a client;
  -- the server rechecks the real cost in before_use.
  return M.commanders[key] ~= nil
end

function M.abilityLabel(key)
  local spec = M.commanders[key]
  if spec == nil then return key end
  local label = Fk:translate(key) .. "·" .. (spec.card_text or Fk:translate(spec.card))
  if M.isLimitedSource({ general = key }) then label = label .. "（限一）" end
  return label
end

--- 返回客户端可直接渲染的来源按钮数据。key 是权威 sourceKey，label 只供显示。
--- @param player Player
--- @param mode? "play"|"response"|"nullification"
--- @return table[]
function M.availableSourceEntries(player, mode)
  if player == nil or player.dead then return {} end
  mode = mode or (Fk.currentResponsePattern ~= nil and "response" or "play")
  local entries = {}
  for _, key in ipairs(M.markSources(player)) do
    local spec = M.commanders[key]
    if spec ~= nil and Fk.all_card_types[spec.card] ~= nil
      and sourceHasCostForUI(player, key) then
      local card = M.viewAsCardForClient(player, key)
      if sourceCardUsable(player, card, mode) then
        table.insert(entries, {
          key = key,
          label = M.abilityLabel(key),
          limited = M.isLimitedSource({ general = key }),
        })
      end
    end
  end
  -- 来源键来自服务端排序后的 mark；再次排序保证客户端顺序稳定。
  table.sort(entries, function(a, b) return a.key < b.key end)
  return entries
end

function M.hasUsableSource(player, mode)
  return #M.availableSourceEntries(player, mode) > 0
end

--- 客户端 view_as 只能依赖客户端已有、可读取的标记数据和全局牌面登记；
--- 来源标记在 UI 中隐藏，但 Player:getMark 仍保留列表。不能读取服务端房间
--- tag。服务端会在 before_use 中重新核验。
function M.viewAsCardForClient(player, sourceKey)
  local spec = M.commanders[sourceKey]
  if spec == nil or Fk.all_card_types[spec.card] == nil then return nil end
  local card = Fk:cloneCard(spec.card, spec.suit)
  if #spec.adaptation > 0 then Adaptation.setCardEntries(card, spec.adaptation) end
  card.skillName = M.ABILITY_SKILL
  card:setMark(M.CARD_SOURCE_MARK, sourceKey)
  return card
end

function M.hasNullificationSource(player)
  return M.hasUsableSource(player, "nullification")
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
    prompt = M.description(player, source.general, nil, true) .. "<br/>请选择要移除的武将牌。",
  })
  return answer == "deputyGeneral"
end

--- 记录待转换的势力或位置，不立即结算。批量入口先把同一事件中的全部
--- 白板士兵登记完，再统一按行动顺序转换，避免用数组或 pairs 顺序结算。
local function queueConversion(room, faction, player, isDeputy)
  local pending = room:getTag(M.PENDING_TAG) or { factions = {}, positions = {} }
  pending.factions = pending.factions or {}
  pending.positions = pending.positions or {}
  if not isUnknown(faction) then pending.factions[faction] = true end
  if player ~= nil then
    local key = player.id .. (isDeputy and ":d" or ":m")
    pending.positions[key] = { id = player.id, isDeputy = isDeputy }
  end
  room:setTag(M.PENDING_TAG, pending)
end

M.queueConversion = queueConversion

local function requestConversion(room, faction, player, isDeputy)
  queueConversion(room, faction, player, isDeputy)
  M.flushConversions(room)
end

M.requestConversion = requestConversion

function M.assignRetinue(player, isDeputy, retinue)
  if not M.isRetinue(retinue) then return false end
  local room = player.room
  local old = positionName(player, isDeputy)
  if not M.isBlankSoldier(old) then return false end
  -- 偏将全场唯一：询问期间或重入时若已被取得，本次取得失败并保留白板。
  if M.limitedRetinueTaken(room, retinue) then return false end
  room:changeHero(player, retinue, false, isDeputy, false, false, false)
  if positionName(player, isDeputy) ~= retinue then return false end
  room:setPlayerMark(player, isDeputy and "__heg_deputy" or "__heg_general", retinue)
  if M.isLimitedRetinue(retinue) then
    local used = M.usedLimitedRetinues(room)
    used[retinue] = { player = player.id, seat = player.seat }
    room:setTag(M.USED_RETINUE_TAG, used)
  end
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
  -- 每一位都重新计算当前可得兵种：前一位取得偏将后，后续位置立即排除。
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

--- 按引擎行动顺序（当前回合角色起、下家方向即逆时针）返回存活角色。
--- 不直接使用 room.alive_players 的数组顺序。当前回合角色未确定时
--- sortByAction 退化为座位顺序，仍作为确定性的开始位置。
function M.orderedAlivePlayers(room)
  local players = table.simpleClone(room.alive_players)
  room:sortByAction(players)
  return players
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
  if #positions > 0 then
    -- 逐人、逐位置：从当前回合角色起按逆时针座次处理，同一人先主将后副将。
    local order = {}
    for index, player in ipairs(M.orderedAlivePlayers(room)) do order[player.id] = index end
    local function rank(entry) return order[entry.player.id] or math.huge end
    table.sort(positions, function(a, b)
      local ra, rb = rank(a), rank(b)
      if ra ~= rb then return ra < rb end
      return (a.isDeputy and 1 or 0) < (b.isDeputy and 1 or 0)
    end)
    for _, entry in ipairs(positions) do M.convertPosition(entry.player, entry.isDeputy) end
  end
  M.refreshAvailability(room)
end

function M.buildViewAsCard(player, sourceKey)
  local source = M.source(player.room, sourceKey)
  if source == nil or not M.sourceAuthorizedFor(player.room, source, player) then return nil end
  if M.hasSoldier(player) then return nil end
  return M.viewAsCardForClient(player, sourceKey)
end

--- 支付统领能力的移将代价。支付前核验无士兵条件及来源是否仍可发动；
--- 支付成功先临时占用来源（阻挡回调期间的重入），使用宣告后再转为永久记录。
--- 移将被阻止或没有改变该位置时释放占用并返回 false，调用者不得继续用牌。
function M.payCost(player, source, isDeputy)
  local room = player.room
  if source == nil or not M.sourceAuthorizedFor(room, source, player) then return false end
  if M.hasSoldier(player) then return false end
  if not table.contains(M.costCandidates(player, source), isDeputy) then return false end
  if not M.reserveAbility(room, source, player) then return false end
  local old = positionName(player, isDeputy)
  H.removeGeneral(player, isDeputy)
  local new = positionName(player, isDeputy)
  -- 移将可能立即生成白板士兵并按规则转换成翼从；两者都表示移除成功。
  if new == old or not M.isSoldier(new) then
    M.releaseAbilityReservation(room, source.general)
    return false
  end
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
      for registered in pairs(source.factions) do queueConversion(room, registered) end
    end
  end
  -- 普通武将明置也会使角色取得确定势力；带白板士兵加入势力时立即转换。
  local faction = M.factionOf(player)
  if not isUnknown(faction) then
    queueConversion(room, nil, player, false)
    queueConversion(room, nil, player, true)
  end
  -- 同一明置事件中的全部位置统一按行动顺序结算。
  M.flushConversions(room)
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
  queueConversion(room, M.factionOf(player), player, isDeputy)
  M.flushConversions(room)
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
          queueConversion(room, newFaction)
        end
      end
    end
    if not isUnknown(newFaction) then
      -- 带白板士兵加入新势力；统领转入时上方已请求整个新势力。
      queueConversion(room, nil, player, false)
      queueConversion(room, nil, player, true)
    end
  end

  local generalChange = results.generalChange
  if generalChange and M.isBlankSoldier(generalChange[2]) then
    queueConversion(room, M.factionOf(player), player, false)
  end
  local deputyChange = results.deputyChange
  if deputyChange and M.isBlankSoldier(deputyChange[2]) then
    queueConversion(room, M.factionOf(player), player, true)
  end
  M.flushConversions(room)
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
      queueConversion(room, nil, entry.player, entry.isDeputy)
    end
  end
  for faction in pairs(affected) do queueConversion(room, faction) end
  -- 来源全部就绪后，按同一行动顺序统一转换。
  M.flushConversions(room)
  M.refreshAvailability(room)
end

function M.reset(room)
  room:setTag(M.SOURCE_TAG, nil)
  room:setTag(M.PENDING_TAG, nil)
  room:setTag(M.USED_RETINUE_TAG, nil)
  room:setTag(M.USED_ABILITY_TAG, nil)
  room:setTag(M.RESERVE_TAG, nil)
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
