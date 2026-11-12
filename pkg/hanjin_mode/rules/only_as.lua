-- “X 只能当 Y 使用／打出”公共机制。
--
-- 适用于汉晋国战房间。每个来源独立登记“实体牌匹配 + 转换目标 + 使用/打出
-- 权限 + 时效”，多个来源对同一实体牌提供的用途取并集。实体牌牌名从不改写；
-- 转化结果是一张以实体牌为子卡的新虚拟牌。客户端只读取服务端同步的玩家
-- mark，不读取服务端 room tag；服务端在 before_use 与 PreCardUse/Respond
-- 时重新核对来源、底牌、目标和当前请求模式。
local M = {}
-- card_use_targets 是并行任务的可选模块。本文件必须能在没有它时独立加载；
-- 有该模块时只使用其静态注册的受信 hook，不把任意 use.extra_data 提升为可信。
local C
local function cardUseTargets()
  if C == nil then
    local ok, mod = pcall(require,
      "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets")
    if ok and type(mod) == "table" then C = mod end
  end
  return C
end

M.PROHIBIT_SKILL = "#hanjin_only_as_prohibit"
M.RULE_SKILL = "#hanjin_only_as_rule"

M.SOURCE_TAG = "hanjin_only_as_sources"
M.SOURCE_MARK = "hanjin_only_as_sources"
M.REQUEST_TAG = "hanjin_only_as_requests"
M.AUTH_TAG = "hanjin_only_as_auth"
M.TURN_TAG = "hanjin_only_as_turn"
M.INIT_TAG = "hanjin_only_as_initialized"
M.CARD_MARK = "hanjin_only_as_conversion"
M.CARD_TARGET_MARK = "hanjin_only_as_target"
M.VERIFIED_MARK = "hanjin_only_as_verified"
M.RESTRICTED_MARK = "hanjin_only_as_restricted"

-- 稳定 source definition 表。正式技能（突袭、双刃等）以后可以直接引用这些
-- 键；未登记来源时定义本身不产生任何效果。
M.defs = {}
M.def_order = {}
M.counter = 0

local function trueName(name)
  local proto = Fk.all_card_types and Fk.all_card_types[name]
  return proto and proto.trueName or name
end

local function copyList(list)
  return list and table.simpleClone(list) or nil
end

local function normalizeMatch(match)
  if match == nil then return nil end
  local ret = {}
  for key, value in pairs(match) do
    if type(value) == "table" then
      ret[key] = table.simpleClone(value)
    else
      ret[key] = value
    end
  end
  return ret
end

local function normalizeConversion(conv)
  assert(type(conv) == "table" and type(conv.name) == "string",
    "Only-as conversion must have a card name")
  local modes = conv.modes or { "use" }
  local ret = {
    name = conv.name,
    true_name = conv.true_name,
    modes = table.simpleClone(modes),
    order = conv.order,
    server_only = conv.server_only == true,
  }
  return ret
end

local function normalizeConversions(list)
  local ret = {}
  for _, conv in ipairs(list or {}) do
    table.insert(ret, normalizeConversion(conv))
  end
  return ret
end

--- 登记一个只读的 source definition。可在扩展代码或测试支持代码中调用。
---@param key string
---@param spec table
function M.define(key, spec)
  assert(type(key) == "string" and key ~= "", "Only-as definition needs a key")
  assert(type(spec) == "table", "Only-as definition must be a table")
  local def = {
    key = key,
    match = normalizeMatch(spec.match),
    conversions = normalizeConversions(spec.conversions),
    direct_zones = spec.direct_zones or "any",
    view_zones = spec.view_zones or { "hand", "handly" },
    ignore_mark = spec.ignore_mark,
    skill = spec.skill,
    card_num = spec.card_num or 1,
  }
  assert(#def.conversions > 0, "Only-as definition needs at least one conversion: " .. key)
  M.defs[key] = def
  if not table.contains(M.def_order, key) then table.insert(M.def_order, key) end
  return def
end

local function defOf(key)
  local def = M.defs[key]
  assert(def ~= nil, "Unknown only-as definition: " .. tostring(key))
  return def
end

--- 当前房间是否为服务端 Room。客户端没有 getTag。
---@param room AbstractRoom
---@return boolean
function M.isServer(room)
  return room ~= nil and type(room.getTag) == "function"
end

function M.turnSerial(room)
  return M.isServer(room) and (room:getTag(M.TURN_TAG) or 0) or 0
end

function M.roundValue(room)
  if M.isServer(room) then
    return room:getBanner("RoundCount") or 0
  end
  if ClientInstance ~= nil then
    return ClientInstance:getBanner("RoundCount") or 0
  end
  return 0
end

local function expiryFor(room, duration)
  if duration == nil or duration == "game" or duration == "manual" then return nil end
  if duration == "turn" then return { kind = "turn", serial = M.turnSerial(room) } end
  if duration == "round" then return { kind = "round", value = M.roundValue(room) } end
  error("Unsupported only-as duration: " .. tostring(duration))
end

local function expired(room, source)
  local expires = source.expires
  if expires == nil then return false end
  if expires.kind == "turn" then
    return M.turnSerial(room) ~= expires.serial
  elseif expires.kind == "round" then
    return M.roundValue(room) ~= expires.value
  end
  return false
end

-- 技能是否仍属于该角色的主将或副将。暗置时武将牌显示为 anjiang，真实武将
-- 记录在 __heg_general/__heg_deputy 标记中。
local function generalsOf(player)
  local main = player.general
  if main == "anjiang" or main == nil or main == "" then
    main = player:getMark("__heg_general")
  end
  local deputy = player.deputyGeneral
  if deputy == "anjiang" or deputy == nil or deputy == "" then
    deputy = player:getMark("__heg_deputy")
  end
  return main, deputy
end

local function generalHasSkill(generalName, skill)
  if type(generalName) ~= "string" or generalName == "" or generalName == "anjiang" then
    return false
  end
  local general = Fk.generals[generalName]
  if general == nil then return false end
  return table.contains(general:getSkillNameList(true), skill)
end

--- 返回 keep, active。keep=false 表示来源应从登记表中删除；active=false 表示
--- 暂时无效（例如武将暗置、被无效化），但保留登记以便恢复。
local function evaluate(room, source)
  if expired(room, source) then return false, false end
  local holder = room:getPlayerById(source.holder or 0)
  if holder == nil or holder.dead then return false, false end
  if source.skill ~= nil then
    local main, deputy = generalsOf(holder)
    if not generalHasSkill(main, source.skill) and not generalHasSkill(deputy, source.skill) then
      return false, false
    end
    if not holder:hasShownSkill(source.skill) then
      return true, false
    end
  end
  if source.ignore_mark ~= nil and holder:getMark(source.ignore_mark) ~= 0 then
    return true, false
  end
  return true, true
end

--- 服务端来源表。调用者不得长期持有；API 返回克隆或读取函数。
function M.sources(room)
  if not M.isServer(room) then return {} end
  return room:getTag(M.SOURCE_TAG) or {}
end

function M.getSource(room, uid)
  return M.sources(room)[uid]
end

local function saveSources(room, sources)
  room:setTag(M.SOURCE_TAG, sources)
end

--- 新增一个来源。返回稳定 uid；同一 uid 重复新增视为幂等更新。
--
--- opts:
---   def         string    M.defs 中的定义键
---   holder      Player|id 来源持有者
---   id?         string    稳定 uid；缺省为自动生成
---   duration?   "game"|"turn"|"round"|"manual"
---   cards?      integer[] 该来源只匹配这些实体牌
---   match?      table     覆盖 def.match 的附加匹配（可同步给客户端）
---   conversions? table    覆盖 def.conversions（可同步给客户端）
---   view_zones? table|"any" 覆盖可选牌区
---   direct_zones? table|"any" 覆盖直接使用/打出的限制牌区
---   skill?      string    来源所属技能；失去技能或武将时失效
---   ignore_mark? string   该标记非 0 时来源暂时无效
---   validate?   fun(room, player, card, target, mode): boolean 仅服务端复核
function M.addSource(room, opts)
  assert(M.isServer(room), "Only-as sources can only be added on the server")
  assert(type(opts) == "table", "Only-as source options must be a table")
  local def = defOf(opts.def)
  local holder = opts.holder
  if type(holder) == "table" then holder = holder.id end
  assert(type(holder) == "number", "Only-as source needs a holder")
  M.counter = M.counter + 1
  local uid = opts.id or (def.key .. ":" .. holder .. ":" .. M.counter)
  local sources = room:getTag(M.SOURCE_TAG) or {}
  local source = sources[uid] or {}
  source.uid = uid
  source.def = def.key
  source.holder = holder
  source.skill = opts.skill or def.skill
  source.ignore_mark = opts.ignore_mark or def.ignore_mark
  source.cards = copyList(opts.cards)
  source.match = normalizeMatch(opts.match)
  source.conversions = opts.conversions and normalizeConversions(opts.conversions) or nil
  source.view_zones = opts.view_zones or def.view_zones
  source.direct_zones = opts.direct_zones or def.direct_zones
  source.validate = opts.validate
  source.reason = opts.reason
  source.created = source.created or M.counter
  source.expires = opts.expires or expiryFor(room, opts.duration)
  sources[uid] = source
  saveSources(room, sources)
  M.refresh(room)
  return uid
end

function M.removeSource(room, uid)
  if not M.isServer(room) then return false end
  local sources = room:getTag(M.SOURCE_TAG) or {}
  if sources[uid] == nil then return false end
  sources[uid] = nil
  saveSources(room, sources)
  M.refresh(room)
  return true
end

--- 撤销一名角色（holder 为 nil 时全体）的全部来源。
function M.clearSources(room, holder)
  if not M.isServer(room) then return end
  local holderId = type(holder) == "table" and holder.id or holder
  local sources = room:getTag(M.SOURCE_TAG) or {}
  for uid, source in pairs(sources) do
    if holderId == nil or source.holder == holderId then sources[uid] = nil end
  end
  saveSources(room, sources)
  M.refresh(room)
end

local function compact(source)
  local rec = { uid = source.uid, def = source.def }
  if source.cards ~= nil then rec.cards = source.cards end
  if source.match ~= nil then rec.match = source.match end
  if source.conversions ~= nil then rec.conversions = source.conversions end
  -- zone 与 direct zone 必须完整同步，包括 "any" 和各 override；否则客户端
  -- 会退回 definition 默认值，与服务端复核结果不一致。
  rec.zones = source.view_zones
  rec.direct_zones = source.direct_zones
  if source.ignore_mark ~= nil then rec.ignore_mark = source.ignore_mark end
  if source.skill ~= nil then rec.skill = source.skill end
  return rec
end

--- 重新计算来源有效性并把可同步的紧凑记录写入玩家 mark。客户端 view_as
--- 只读这个 mark，不访问服务端 room tag。
function M.refresh(room)
  if not M.isServer(room) then return end
  local sources = room:getTag(M.SOURCE_TAG) or {}
  local changed = false
  for uid, source in pairs(sources) do
    local keep = evaluate(room, source)
    if not keep then
      sources[uid] = nil
      changed = true
    end
  end
  if changed then saveSources(room, sources) end

  local byHolder = {}
  for _, source in pairs(sources) do
    local _, active = evaluate(room, source)
    if active then
      byHolder[source.holder] = byHolder[source.holder] or {}
      table.insert(byHolder[source.holder], compact(source))
    end
  end
  for _, player in ipairs(room.players) do
    local list = byHolder[player.id] or {}
    table.sort(list, function(a, b) return a.uid < b.uid end)
    room:setPlayerMark(player, M.SOURCE_MARK, #list > 0 and list or 0)
  end
end

function M.reset(room)
  if not M.isServer(room) then return end
  room:setTag(M.SOURCE_TAG, nil)
  room:setTag(M.REQUEST_TAG, nil)
  room:setTag(M.AUTH_TAG, nil)
  room:setTag(M.TURN_TAG, 0)
  for _, player in ipairs(room.players) do
    room:setPlayerMark(player, M.SOURCE_MARK, 0)
  end
end

function M.advanceTurn(room)
  room:setTag(M.TURN_TAG, M.turnSerial(room) + 1)
  M.refresh(room)
end

--- 回合结束时让“本回合”来源立即到期，而不是拖到下一个 TurnStart。
function M.expireTurn(room)
  if not M.isServer(room) then return end
  local sources = room:getTag(M.SOURCE_TAG) or {}
  local changed = false
  for uid, source in pairs(sources) do
    if source.expires ~= nil and source.expires.kind == "turn" then
      sources[uid] = nil
      changed = true
    end
  end
  if changed then saveSources(room, sources) end
  M.refresh(room)
end

-- 请求时点栈：记录当前是“使用”还是“打出”，以及请求的牌名 pattern。
-- 服务端 before_use 和 PreCardUse/Respond 复核据此判断请求模式。
function M.pushRequest(room, player, mode, pattern, extra_data)
  if not M.isServer(room) then return end
  local stack = room:getTag(M.REQUEST_TAG) or {}
  table.insert(stack, {
    player = player and player.id or 0,
    mode = mode,
    pattern = pattern,
    extra_data = extra_data,
  })
  room:setTag(M.REQUEST_TAG, stack)
end

function M.popRequest(room)
  if not M.isServer(room) then return end
  local stack = room:getTag(M.REQUEST_TAG) or {}
  table.remove(stack)
  room:setTag(M.REQUEST_TAG, #stack > 0 and stack or nil)
end

function M.currentRequest(room)
  if not M.isServer(room) then return nil end
  local stack = room:getTag(M.REQUEST_TAG) or {}
  return stack[#stack]
end

-- 客户端当前请求类型。不能仅凭 Fk.currentResponsePattern 非空判断：
-- AskForUseCard 也会设置 response pattern，但它不是“打出”窗口。
local function clientHandlerMode()
  if ClientInstance == nil then return nil end
  local handler = ClientInstance.current_request_handler
  local class = handler and handler.class
  local name = class and class.name
  if name == "ReqResponseCard" then return "response" end
  if name == "ReqUseCard" or name == "ReqPlayCard" or name == "ReqActiveSkill" then
    return "use"
  end
  return nil
end

function M.currentMode(player, response)
  if response ~= nil then return response and "response" or "use" end
  if player ~= nil and M.isServer(player.room) then
    local request = M.currentRequest(player.room)
    if request ~= nil and request.mode ~= nil then return request.mode end
  end
  local clientMode = clientHandlerMode()
  if clientMode ~= nil then return clientMode end
  -- 仅在没有请求 handler 的离线/构造场景中回退；有 handler 时绝不靠
  -- pattern 非空猜测“打出”。
  if ClientInstance == nil and Fk.currentResponsePattern ~= nil then
    return "response"
  end
  return "use"
end

--- 客户端当前请求的完整 extra_data（用于展示前按 pattern/额外目标限制过滤）。
function M.clientExtraData()
  if ClientInstance == nil then return nil end
  local room = Fk.currentRoom and Fk:currentRoom() or nil
  if room ~= nil and M.isServer(room) then return nil end
  local handler = ClientInstance.current_request_handler
  if handler == nil then return nil end
  return handler.extra_data
end

-- 临时授权：绑定具体玩家、具体实体牌、授权时的牌区和一次受限入口 token。
-- 不允许用同一入口授权的另一张牌替换，也不允许牌离开原牌区后继续使用。
function M.authorizeCard(room, player, cardId, reason, context)
  if not M.isServer(room) then return end
  local auth = room:getTag(M.AUTH_TAG) or {}
  M.counter = M.counter + 1
  auth[player.id] = {
    cardId = cardId,
    reason = reason,
    area = room:getCardArea(cardId),
    token = M.counter,
    mode = context and context.mode or nil,
    pattern = context and context.pattern or nil,
    extra_data = context and context.extra_data or nil,
  }
  room:setTag(M.AUTH_TAG, auth)
  local card = Fk:getCardById(cardId)
  if card ~= nil then card:setMark(M.RESTRICTED_MARK, M.counter) end
end

function M.clearAuthorization(room, player)
  if not M.isServer(room) then return end
  local auth = room:getTag(M.AUTH_TAG) or {}
  local entry = auth[player.id]
  if entry ~= nil then
    local card = Fk:getCardById(entry.cardId)
    if card ~= nil then card:setMark(M.RESTRICTED_MARK, 0) end
  end
  auth[player.id] = nil
  room:setTag(M.AUTH_TAG, auth)
end

function M.consumeAuthorization(room, player, cardId)
  if not M.isServer(room) then return false end
  local auth = room:getTag(M.AUTH_TAG) or {}
  local entry = auth[player.id]
  if entry == nil or entry.cardId ~= cardId then return false end
  if room:getCardArea(cardId) ~= entry.area then
    -- 牌已离开授权时的牌区：授权失效。
    M.clearAuthorization(room, player)
    return false
  end
  local card = Fk:getCardById(cardId)
  if card ~= nil then card:setMark(M.RESTRICTED_MARK, 0) end
  auth[player.id] = nil
  room:setTag(M.AUTH_TAG, auth)
  return true
end

function M.isAuthorized(room, player, cardId)
  if not M.isServer(room) then return false end
  local entry = (room:getTag(M.AUTH_TAG) or {})[player.id]
  return entry ~= nil and entry.cardId == cardId
    and entry.area == room:getCardArea(cardId)
end

function M.authorizationEntry(room, player)
  if not M.isServer(room) then return nil end
  return (room:getTag(M.AUTH_TAG) or {})[player.id]
end

--- 牌移动后使相关授权失效，防止“移出再移回原牌区”让旧授权复活。
function M.clearAuthorizationById(room, cardId)
  if not M.isServer(room) then return end
  local auth = room:getTag(M.AUTH_TAG) or {}
  local changed = false
  for pid, entry in pairs(auth) do
    if entry.cardId == cardId then
      auth[pid] = nil
      changed = true
    end
  end
  if changed then
    local card = Fk:getCardById(cardId)
    if card ~= nil then card:setMark(M.RESTRICTED_MARK, 0) end
    room:setTag(M.AUTH_TAG, auth)
  end
end

-- 客户端来源：只读同步 mark。
local function clientSources(player)
  local mark = player and player:getMark(M.SOURCE_MARK)
  if type(mark) ~= "table" then return {} end
  local ret = {}
  for _, rec in ipairs(mark) do
    local def = M.defs[rec.def]
    if def ~= nil then
      local source = {
        uid = rec.uid,
        def = rec.def,
        holder = player.id,
        skill = rec.skill,
        ignore_mark = rec.ignore_mark or def.ignore_mark,
        cards = rec.cards,
        match = rec.match,
        conversions = rec.conversions,
        view_zones = rec.zones or def.view_zones,
        direct_zones = rec.direct_zones or def.direct_zones,
      }
      if not expired(player.room, source) then table.insert(ret, source) end
    end
  end
  return ret
end

--- 当前玩家可见的有效来源。客户端读 mark，服务端读 tag。
function M.activeSources(player)
  if player == nil then return {} end
  local room = player.room
  if not M.isServer(room) then return clientSources(player) end
  local sources = room:getTag(M.SOURCE_TAG) or {}
  local ret = {}
  for _, source in pairs(sources) do
    if source.holder == player.id then
      local _, active = evaluate(room, source)
      if active then table.insert(ret, source) end
    end
  end
  table.sort(ret, function(a, b) return a.uid < b.uid end)
  return ret
end

local function valueOf(source, key)
  if source.match ~= nil and source.match[key] ~= nil then return source.match[key] end
  local def = M.defs[source.def]
  return def and def.match and def.match[key] or nil
end

local function matchesList(value, list)
  if list == nil then return true end
  if type(list) ~= "table" then list = { list } end
  return table.contains(list, value)
end

--- 实体牌是否匹配来源。牌名使用实体牌 trueName；不读取或改写牌名。
function M.matches(source, card)
  if card == nil then return false end
  if source.cards ~= nil and not table.contains(source.cards, card.id) then return false end
  if not matchesList(card.trueName, valueOf(source, "names")) then return false end
  if not matchesList(card.suit, valueOf(source, "suits")) then return false end
  if not matchesList(card.color, valueOf(source, "colors")) then return false end
  if not matchesList(card.number, valueOf(source, "numbers")) then return false end
  if not matchesList(card.type, valueOf(source, "types")) then return false end
  return true
end

local function zoneIds(player, zone)
  if zone == "hand" then return player:getCardIds("h") end
  if zone == "handly" then return player:getHandlyIds(true) end
  if zone == "equip" then return player:getCardIds("e") end
  if zone == "any" then return nil end
  -- 未知牌区必须明确拒绝，不能按 "any" 放行。
  return false
end

--- 牌是否位于来源允许的牌区。zones 为 "any" 时恒真。
function M.cardInZones(player, cardId, zones)
  if zones == nil or zones == "any" then return true end
  if type(zones) ~= "table" then zones = { zones } end
  for _, zone in ipairs(zones) do
    local ids = zoneIds(player, zone)
    if ids == false then
      -- 未知 zone：该条目不可用；继续检查其它明确条目。
    elseif ids == nil or table.contains(ids, cardId) then
      return true
    end
  end
  return false
end

local function conversionsOf(source)
  if source.conversions ~= nil then return source.conversions end
  local def = M.defs[source.def]
  return def and def.conversions or {}
end

local function modeAllowed(conv, mode)
  return table.contains(conv.modes, mode)
end

local function sortedInsertTarget(ret, seen, entry)
  if seen[entry.target] then return end
  seen[entry.target] = true
  table.insert(ret, entry)
end

--- 指定实体牌在当前玩家、当前模式下可用的转换用途（并集）。
--- opts.check_legal 为真时只保留当前时机实际可用于使用/响应的目标；
--- opts.authorized 为真时忽略 view_zones（供傲才等显式牌集入口）。
function M.actionsForCard(room, player, cardId, mode, opts)
  opts = opts or {}
  mode = mode or M.currentMode(player)
  local card = Fk:getCardById(cardId)
  if card == nil then return {} end
  local authorized = opts.authorized == true or M.isAuthorized(room, player, cardId)
  local ret, seen = {}, {}
  for _, source in ipairs(M.activeSources(player)) do
    if (opts.definition == nil or source.def == opts.definition) and M.matches(source, card) then
      if authorized or M.cardInZones(player, cardId, source.view_zones) then
        for _, conv in ipairs(conversionsOf(source)) do
          if modeAllowed(conv, mode) and not conv.server_only then
            local valid = true
            if opts.use ~= nil and type(source.validate) == "function" then
              valid = source.validate(room, player, card, conv.name, mode, opts.use) ~= false
            end
            if valid then
              local entry = {
                uid = source.uid,
                def = source.def,
                target = conv.name,
                true_name = conv.true_name or trueName(conv.name),
                order = conv.order,
                source = source,
              }
              if opts.check_legal then
                valid = M.canUseInCurrent(player, conv.name, cardId, mode, opts.extra_data,
                  defOf(source.def).entry_skill or source.skill)
              end
              if valid then sortedInsertTarget(ret, seen, entry) end
            end
          end
        end
      end
    end
  end
  table.sort(ret, function(a, b)
    local ao, bo = a.order or 999, b.order or 999
    if ao ~= bo then return ao < bo end
    return a.true_name < b.true_name
  end)
  return ret
end

function M.availableTargets(room, player, cardId, mode)
  local targets = {}
  for _, action in ipairs(M.actionsForCard(room, player, cardId, mode)) do
    table.insertIfNeed(targets, action.target)
  end
  return targets
end

local function canUseInCurrent(player, card)
  if Fk.currentResponsePattern ~= nil and ClientInstance ~= nil
    and ClientInstance.current_request_handler == nil then
    return card:matchVSPattern(Fk.currentResponsePattern) and not player:prohibitUse(card)
  end
  return player:canUseOrResponseInCurrent(card)
end

--- 构造转化牌。实体牌只作为子卡，牌名保持不变。
function M.buildCard(player, cardId, target, skillName)
  if Fk.all_card_types[target] == nil then return nil end
  if skillName == nil then
    for _, action in ipairs(M.actionsForCard(player.room, player, cardId, M.currentMode(player))) do
      if action.target == target then
        skillName = defOf(action.def).entry_skill or action.source.skill
        if skillName ~= nil then break end
      end
    end
  end
  local card = Fk:cloneCard(target)
  card.skillName = skillName or M.RULE_SKILL
  card:addSubcard(cardId)
  card:setMark(M.CARD_MARK, true)
  card:setMark(M.CARD_TARGET_MARK, target)
  return card
end

function M.canUseInCurrent(player, target, cardId, mode, extra_data, skillName)
  local card = M.buildCard(player, cardId, target, skillName)
  if card == nil then return false end
  if mode == "response" then
    if Fk.currentResponsePattern ~= nil then
      return card:matchVSPattern(Fk.currentResponsePattern) and not player:prohibitResponse(card)
    end
    -- 没有请求 pattern 时不能证明该响应窗口合法。
    return false
  end
  if card.is_passive then return false end
  return not player:prohibitUse(card)
    and card:getSkill(player):canUse(player, card, extra_data)
    and #card:getAvailableTargets(player, extra_data) > 0
end

--- 受限入口使用显式请求 pattern 判断目标是否属于当前窗口。
function M.targetAllowedInRequest(player, target, cardId, mode, pattern, extra_data)
  local card = M.buildCard(player, cardId, target)
  if card == nil then return false end
  if pattern ~= nil and not Exppattern:Parse(pattern):match(card) then return false end
  if mode == "response" then
    return not player:prohibitResponse(card)
  end
  if card.is_passive then return false end
  return not player:prohibitUse(card)
    and card:getSkill(player):canUse(player, card, extra_data)
    and #card:getAvailableTargets(player, extra_data) > 0
end

--- 当前请求下是否有至少一张可选实体牌能提供转换用途。
function M.hasAvailable(player, mode, definition)
  mode = mode or M.currentMode(player)
  local extra_data = M.clientExtraData()
  for _, cardId in ipairs(player:getHandlyIds(true)) do
    if #M.actionsForCard(player.room, player, cardId, mode,
      { check_legal = true, extra_data = extra_data, definition = definition }) > 0 then
      return true
    end
  end
  return false
end

--- 当前交互选项：所有可选实体牌提供的目标牌名并集。
function M.interactionChoices(player, definition)
  local mode = M.currentMode(player)
  local extra_data = M.clientExtraData()
  local choices, seen = {}, {}
  for _, cardId in ipairs(player:getHandlyIds(true)) do
    for _, action in ipairs(M.actionsForCard(player.room, player, cardId, mode,
      { check_legal = true, extra_data = extra_data, definition = definition })) do
      if not seen[action.target] then
        seen[action.target] = true
        table.insert(choices, action.target)
      end
    end
  end
  return choices
end

function M.cardSelectable(player, cardId, target, definition)
  if not table.contains(player:getHandlyIds(true), cardId) then return false end
  local mode = M.currentMode(player)
  local extra_data = M.clientExtraData()
  for _, action in ipairs(M.actionsForCard(player.room, player, cardId, mode,
    { check_legal = true, extra_data = extra_data, definition = definition })) do
    if action.target == target then return true end
  end
  return false
end

--- 直接使用/打出的禁止判定。所有合法牌区都受限制，不按手牌区或
--- skillNames 判断；转化牌（虚拟牌）不受“原实体牌禁用”限制。
function M.isForbidden(player, card)
  if player == nil or card == nil or card:isVirtual() then return false end
  for _, source in ipairs(M.activeSources(player)) do
    if M.matches(source, card) then
      if M.cardInZones(player, card.id, source.direct_zones) then
        return true
      end
    end
  end
  return false
end

-- 服务端复核 ---------------------------------------------------------------

local function requestFor(room, opts)
  local current = M.currentRequest(room)
  local ret = {
    mode = current and current.mode or nil,
    pattern = current and current.pattern or nil,
    extra_data = current and current.extra_data or nil,
  }
  if opts ~= nil then
    if opts.mode ~= nil then ret.mode = opts.mode end
    if opts.pattern ~= nil then ret.pattern = opts.pattern end
    if opts.extra_data ~= nil then ret.extra_data = opts.extra_data end
  end
  return ret
end

local function findAction(room, player, card, target, mode, opts)
  local authorized = opts.authorized == true or M.isAuthorized(room, player, card.id)
  for _, source in ipairs(M.activeSources(player)) do
    if (opts.definition == nil or source.def == opts.definition) and M.matches(source, card) then
      if authorized or M.cardInZones(player, card.id, source.view_zones) then
        for _, conv in ipairs(conversionsOf(source)) do
          if conv.name == target and modeAllowed(conv, mode) then
            if type(source.validate) ~= "function"
              or source.validate(room, player, card, target, mode, opts.use) ~= false then
              return source, conv
            end
          end
        end
      end
    end
  end
  return nil
end

--- 服务端复核一张转化牌。返回 ok, reason。
--- opts.mode/opts.pattern 可由调用者显式提供；否则读取当前请求栈。
function M.validateUse(room, player, use, opts)
  opts = opts or {}
  if use == nil or use.card == nil then return false, "missing-card" end
  local card = use.card
  local request = requestFor(room, opts)
  local mode = request and request.mode or "use"
  local pattern = request and request.pattern or opts.pattern
  local target = card.name
  local targetTrue = card.trueName
  local subcards = Card:getIdList(card)
  if #subcards ~= 1 then return false, "subcard-count" end
  local entity = Fk:getCardById(subcards[1])
  if entity == nil then return false, "missing-entity" end
  -- 转化结果必须确实由本机制生成，或至少属于本机制可提供的目标。
  if not card:isVirtual() then return false, "not-converted" end
  local source, conv = findAction(room, player, entity, target, mode, opts)
  if source == nil or conv == nil then return false, "source-target" end
  if (conv.true_name or trueName(conv.name)) ~= targetTrue then return false, "target-name" end
  if mode == "use" and pattern ~= nil then
    if not Exppattern:Parse(pattern):match(card) then return false, "use-pattern" end
  elseif mode == "response" then
    if pattern ~= nil and not Exppattern:Parse(pattern):match(card) then
      return false, "response-pattern"
    end
    if use.tos ~= nil and #use.tos > 0 then return false, "response-targets" end
  end
  local extra_data = request and request.extra_data or nil
  local policy = (use.extra_data or {}).hanjin_use_targets
    or (extra_data and extra_data.hanjin_use_targets)
  local policyRecord
  local trustedActive = false
  if policy ~= nil then
    local lib = cardUseTargets()
    if lib == nil then return false, "untrusted-policy" end
    -- Prefer the one-use server token attached to this use.  During before_use
    -- the use is still inside the request, so the server-authored active policy
    -- is also trustworthy; client-forged compact data alone never is.
    policyRecord = lib.trustedPolicy(room, use)
    if policyRecord == nil then
      policyRecord = lib.activePolicyRecord(room, player, card)
      trustedActive = policyRecord ~= nil
    end
    if policyRecord == nil then return false, "untrusted-policy" end
  end
  if mode == "use" then
    if player:prohibitUse(card) then return false, "prohibit-use" end
    local stage = opts.stage or "selection"
    if policyRecord ~= nil then
      local lib = cardUseTargets()
      local ok, reason = lib.validateUse(room, player, use, policyRecord, nil,
        { require_trusted = not trustedActive, trusted_active = trustedActive,
          stage = stage, extra_data = extra_data })
      if not ok then return false, reason or "illegal-target" end
    else
      local card_skill = card:getSkill(player)
      if not card_skill:canUse(player, card, extra_data) then return false, "cannot-use" end
      local lib = cardUseTargets()
      if lib ~= nil then
        -- Shared real-CardSkill validation: selection count/feasibility before
        -- use, and expanded main/sub target structure after card.skill:onUse.
        local ok, reason = lib.validateTargets(room, player, use, nil, stage,
          { extra_data = extra_data })
        if not ok then return false, reason or "illegal-target" end
      else
        local tos = use.tos or {}
        local fixed = card:getFixedTargets(player, extra_data)
        if fixed ~= nil then
          -- 固定目标牌：允许空目标（引擎自动补全），若显式提交则必须与固定
          -- 目标集合完全一致，不能借机附加其他目标。
          if #tos > 0 then
            local fixedIds, seen = {}, {}
            for _, p in ipairs(fixed) do fixedIds[p.id] = true end
            if #tos ~= #fixed then return false, "fixed-target-count" end
            for _, to in ipairs(tos) do
              local p = type(to) == "table" and to or room:getPlayerById(to)
              if p == nil then return false, "missing-target-player" end
              if seen[p.id] then return false, "duplicate-target" end
              seen[p.id] = true
              if not fixedIds[p.id] then return false, "fixed-target" end
              if player:isProhibited(p, card) then return false, "prohibited-target" end
            end
          end
        else
          local min_num = card_skill:getMinTargetNum(player)
          local max_num = card_skill:getMaxTargetNum(player, card)
          if #tos < min_num then return false, "missing-target" end
          if #tos > max_num then return false, "too-many-targets" end
          -- 按实际 CardSkill 的目标接口逐名复核，维护 selected 组合语义，
          -- 复用引擎的 modTargetFilter/距离/禁止目标与 extra_data 限制。
          local selected, seen = {}, {}
          for _, to in ipairs(tos) do
            local p = type(to) == "table" and to or room:getPlayerById(to)
            if p == nil then return false, "missing-target-player" end
            if seen[p.id] then return false, "duplicate-target" end
            seen[p.id] = true
            if not Util.CardTargetFilter(card_skill, player, p, selected, subcards,
              card, extra_data) then
              return false, "illegal-target-combination"
            end
            table.insert(selected, p)
          end
          if not card_skill:feasible(player, selected, subcards, card) then
            return false, "infeasible-targets"
          end
        end
      end
    end
  elseif player:prohibitResponse(card) then
    return false, "prohibit-response"
  end
  -- 记录本次服务端已验证的完整请求上下文，供请求栈弹出后的
  -- PreCardUse/PreCardRespond 复核使用；第二次复核不得丢掉请求参数。
  card:setMark(M.VERIFIED_MARK, {
    mode = mode,
    pattern = pattern,
    extra_data = extra_data,
    definition = opts.definition,
    restricted_token = M.isAuthorized(room, player, entity.id)
      and M.authorizationEntry(room, player).token or nil,
  })
  if opts.consume_auth then
    M.consumeAuthorization(room, player, subcards[1])
  end
  return true
end

--- 服务端复核直接使用/打出以及本机制转化牌。PreCardUse/PreCardRespond
--- 返回 false 时调用方会 breakEvent。
function M.validateCardUse(room, player, use, mode, opts)
  opts = opts or {}
  if use == nil or use.card == nil then return true end
  local card = use.card
  if not card:isVirtual() then
    if card:getMark(M.RESTRICTED_MARK) ~= 0 then
      local entry = M.authorizationEntry(room, player)
      if entry == nil or entry.mode ~= mode then return false end
      if entry.pattern ~= nil and not Exppattern:Parse(entry.pattern):match(card) then
        return false
      end
      if not M.consumeAuthorization(room, player, card.id) then return false end
    end
    return not M.isForbidden(player, card)
  end
  local marked = card:getMark(M.CARD_MARK) ~= 0
  if not marked then return true end
  -- 只有本次服务端在真实请求中验证过的转化牌才能在宣告时生效。客户端
  -- 伪造的牌面/标记不会带有服务端写入的 verified 记录。
  local verified = card:getMark(M.VERIFIED_MARK)
  if type(verified) ~= "table" or verified.mode ~= mode then
    return false
  end
  if verified.restricted_token ~= nil then
    local ids = Card:getIdList(card)
    local entry = M.authorizationEntry(room, player)
    if #ids ~= 1 or entry == nil or entry.token ~= verified.restricted_token
      or not M.isAuthorized(room, player, ids[1]) then return false end
  end
  local check = {
    mode = verified.mode,
    pattern = verified.pattern,
    extra_data = verified.extra_data,
    definition = verified.definition,
    consume_auth = true,
    stage = "declared",
  }
  return M.validateUse(room, player, use, check)
end

-- 受限入口展示用：每张顶牌至少有花色、点数与牌名，避免同名牌只显示
-- “第 N 张”。该文本只返回给当前询问者，不广播给其他角色。
local SUIT_LABELS = {
  spade = "黑桃", heart = "红桃", club = "梅花", diamond = "方块", nosuit = "",
}
function M.restrictedLabel(card)
  if card == nil then return "" end
  local suit = SUIT_LABELS[card:getSuitString()] or card:getSuitString()
  local number = card.number == 0 and "" or tostring(card.number)
  return "【" .. Fk:translate(card.name) .. "·" .. suit .. number .. "】"
end

--- 傲才等受限入口的公共选择流程。只考虑 params.cards 指定的临时牌集，
--- 不会把手牌或其它技能加入候选。
---@param params table { cards, pattern, is_response, skill_name, prompt, cancelable, extra_data }
function M.askRestricted(room, player, params)
  assert(M.isServer(room), "Only-as restricted entry is server-only")
  local mode = params.is_response and "response" or "use"
  local pattern = params.pattern or "."
  local extra_data = params.extra_data
  M.clearAuthorization(room, player)
  local actions, labels, byLabel = {}, {}, {}
  local function addLabel(action, label)
    if byLabel[label] ~= nil then return end
    byLabel[label] = action
    table.insert(labels, label)
    table.insert(actions, action)
  end
  for index, cardId in ipairs(params.cards or {}) do
    local entity = Fk:getCardById(cardId)
    if entity ~= nil then
      local prefix = M.restrictedLabel(entity) .. "："
      local directOk = Exppattern:Parse(pattern):match(entity)
      if directOk then
        if mode == "response" then
          directOk = not player:prohibitResponse(entity)
        else
          directOk = not player:prohibitUse(entity)
        end
      end
      if directOk then
        addLabel({ kind = "direct", card = cardId },
          prefix .. (mode == "response" and "打出【" or "使用【")
            .. Fk:translate(entity.name) .. "】")
      end
      for _, action in ipairs(M.actionsForCard(room, player, cardId, mode,
        { authorized = true, extra_data = extra_data })) do
        if M.targetAllowedInRequest(player, action.target, cardId, mode, pattern, extra_data) then
          local conv = Fk.all_card_types[action.target]
          addLabel({ kind = "convert", card = cardId, target = action.target, uid = action.uid },
            prefix .. "将【" .. Fk:translate(entity.name) .. "】当【"
              .. Fk:translate(conv and conv.name or action.target) .. "】"
              .. (mode == "response" and "打出" or "使用"))
        end
      end
    end
  end
  if #labels == 0 then return nil end
  local choice = room:askToChoice(player, {
    choices = labels,
    skill_name = params.skill_name or M.RULE_SKILL,
    prompt = params.prompt or "#hanjin_only_as_choose",
    cancelable = params.cancelable ~= false,
  })
  local action = byLabel[choice]
  if action == nil then
    M.clearAuthorization(room, player)
    return nil
  end
  local allowed = params.cards or {}
  local function restrictedContains(card)
    if card == nil then return false end
    local ids = Card:getIdList(card)
    if #ids ~= 1 or ids[1] ~= action.card then return false end
    return table.contains(allowed, ids[1])
  end
  if action.kind == "direct" then
    M.authorizeCard(room, player, action.card, "only-as-restricted-direct", {
      mode = mode, pattern = pattern, extra_data = extra_data,
    })
    if mode == "response" then
      return { from = player, tos = {}, card = Fk:getCardById(action.card) }
    end
    local use = room:askToUseRealCard(player, {
      pattern = tostring(Exppattern{ id = { action.card } }),
      skill_name = params.skill_name or M.RULE_SKILL,
      prompt = params.prompt or "#hanjin_only_as_choose",
      expand_pile = { action.card },
      extra_data = extra_data,
      skip = true,
      cancelable = true,
    })
    -- 服务端复核：受限入口只能使用其临时牌集内、且正是所选项的实体牌。
    if use == nil or use.card == nil or use.card.id ~= action.card then
      M.clearAuthorization(room, player)
      return nil
    end
    return use
  end
  M.authorizeCard(room, player, action.card, "only-as-restricted", {
    mode = mode, pattern = pattern, extra_data = extra_data,
  })
  if mode == "response" then
    local card = M.buildCard(player, action.card, action.target,
      params.skill_name or M.RULE_SKILL)
    local use = { from = player, tos = {}, card = card }
    if not M.validateUse(room, player, use, {
      mode = "response", pattern = pattern, extra_data = extra_data,
    }) then
      M.clearAuthorization(room, player)
      return nil
    end
    return use
  end
  local lib = cardUseTargets()
  local use
  if lib ~= nil and params.policy ~= nil then
    -- Selection-only half: the outer ViewAsSkill/engine performs the single
    -- actual use.  The policy token is already attached and validated here.
    use = lib.selectVirtualCard(room, player, {
      name = action.target,
      subcards = { action.card },
      skill_name = params.skill_name or M.RULE_SKILL,
      prompt = params.prompt or "#hanjin_only_as_choose",
      extra_data = extra_data,
      policy = params.policy or lib.default(),
      names = { action.target },
      context = params.context,
      skip = true,
      cancelable = true,
    })
  else
    use = room:askToUseVirtualCard(player, {
      name = action.target,
      subcards = { action.card },
      skill_name = params.skill_name or M.RULE_SKILL,
      prompt = params.prompt or "#hanjin_only_as_choose",
      extra_data = extra_data,
      skip = true,
      cancelable = true,
    })
  end
  if use == nil or use.card == nil then
    if use ~= nil and lib ~= nil then lib.releaseToken(room, use) end
    M.clearAuthorization(room, player)
    return nil
  end
  use.card:setMark(M.CARD_MARK, true)
  use.card:setMark(M.CARD_TARGET_MARK, action.target)
  if use.card.name ~= action.target or not restrictedContains(use.card) then
    if lib ~= nil then lib.releaseToken(room, use) end
    M.clearAuthorization(room, player)
    return nil
  end
  if not M.validateUse(room, player, use, {
    mode = "use", pattern = pattern,
    extra_data = use.extra_data or extra_data,
  }) then
    if lib ~= nil then lib.releaseToken(room, use) end
    M.clearAuthorization(room, player)
    return nil
  end
  return use
end

--- 把转换效果附加到真实来源技能，不创建“只能当”技能或全局转换按钮。
--- definition 仅选择该来源的用途；其他来源须通过自己的技能或效果入口使用。
function M.addViewAsEffect(skill, definition, prompt)
  defOf(definition).entry_skill = skill.name
  skill:addEffect("viewas", {
    pattern = ".",
    prompt = prompt,
    handly_pile = true,
    interaction = function(self, player)
      local choices = M.interactionChoices(player, definition)
      if #choices > 0 then return UI.ComboBox { choices = choices } end
    end,
    card_filter = function(self, player, id, selected)
      local target = self.interaction and self.interaction.data
      return #selected == 0 and type(target) == "string"
        and M.cardSelectable(player, id, target, definition)
    end,
    view_as = function(self, player, cards)
      local target = self.interaction and self.interaction.data
      if #cards ~= 1 or type(target) ~= "string" then return nil end
      return M.buildCard(player, cards[1], target, skill.name)
    end,
    before_use = function(self, player, use)
      if not M.validateUse(player.room, player, use, { definition = definition }) then
        return skill.name
      end
    end,
    enabled_at_play = function(self, player)
      return M.hasAvailable(player, "use", definition)
    end,
    enabled_at_response = function(self, player, response)
      return M.hasAvailable(player, response and "response" or "use", definition)
    end,
  })
end

-- 来源定义 -----------------------------------------------------------------

M.define("battle_royal", {
  match = { names = { "peach" } },
  conversions = {
    { name = "hanjin__slash", modes = { "use", "response" }, order = 1 },
    { name = "hanjin__jink", modes = { "use", "response" }, order = 2 },
  },
  direct_zones = "any",
  view_zones = { "hand", "handly" },
  ignore_mark = "_heg__BattleRoyalMode_ignore",
})

-- 供后续正式突袭使用的定义：来源通过 cards 限定为“本回合获得的牌”。
M.define("tuxi", {
  conversions = {
    { name = "hanjin__slash", modes = { "use", "response" }, order = 1 },
  },
  direct_zones = "any",
  view_zones = { "hand", "handly" },
})

-- 供后续正式双刃使用的定义：手牌中的【杀】只能当【借刀杀人】使用。
M.define("shuangren", {
  match = { names = { "slash" }, types = { Card.TypeBasic } },
  conversions = {
    { name = "hanjin__collateral", modes = { "use" }, order = 1 },
  },
  direct_zones = { "hand" },
  view_zones = { "hand" },
})

return M
