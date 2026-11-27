-- HanJin selection interaction and server-side validation.
--
-- The final pair uses the engine's ChooseGeneralModel with a HanJin
-- choose-general rule (registered by the mode package). The rule receives the
-- per-room pairing map as extra data, so a guest candidate is filtered by its
-- actual this-game factions instead of the engine's global general definition.
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local RoomBans = require "packages.qiao.pkg.qiao_mode.rules.room_general_bans"
local FaqRules = require "packages.qiao.pkg.qiao_mode.rules.faq_core_rules"
local Locked = require "packages.qiao.pkg.qiao_mode.rules.locked_factions"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local M = {}

local function canRedraw(room)
  return room:getSettings("gameMode") ~= Modes.locked
end

local function inKingdom(room, name, kingdom)
  if not kingdom then return true end
  local entry = Guest.factionsOf(room, name)
  return entry ~= nil and table.contains(entry.kingdoms, kingdom)
end

M.defaultTimeout = 90
M.rule = "qiao_heg_pair"
M.redraw_url = "packages/qiao/pkg/qiao_mode/qml/GuestRedrawBox.qml"
M.ascension_url = "packages/qiao/pkg/qiao_mode/qml/QiaoChooseGeneralBox.qml"

local function strings(list)
  local result = {}
  for _, value in ipairs(list or {}) do
    if type(value) == "string" and value ~= "" then table.insert(result, value) end
  end
  return result
end

---Decode a pair reply. Accepts the engine's legacy "a,b"/"kingdom,x" shape,
---the ChooseGeneralModel array shape, and a { generals = ... } table.
---@param reply any
---@return string[], table
function M.decode(reply)
  if type(reply) ~= "table" then return {}, {} end
  local names, extra = {}, {}
  if type(reply.generals) == "table" then
    names = strings(reply.generals)
  elseif type(reply[1]) == "table" then
    names = strings(reply[1])
  elseif type(reply[1]) == "string" then
    if reply[1]:find(",", 1, true) then
      names = strings(reply[1]:split(","))
    elseif type(reply[2]) == "string" and not reply[2]:find("kingdom", 1, true) then
      -- ChooseGeneralModel replies with a plain array of two names.
      names = strings({ reply[1], reply[2] })
    else
      names = strings({ reply[1] })
    end
  end
  if type(reply[2]) == "string" then
    extra = reply[2]:split(",")
  elseif type(reply[2]) == "table" then
    extra = reply[2]
  end
  if #names ~= 2 then return {}, {} end
  local kingdom
  if type(reply.kingdom) == "string" then
    kingdom = reply.kingdom
  elseif extra[1] == "kingdom" and type(extra[2]) == "string" then
    kingdom = extra[2]
  end
  return names, { kingdom = kingdom }
end

---Whether a pair is legal for this room: different cards, different true names
---unless same-name conversion is enabled, and a non-empty faction intersection.
---@param room Room
---@param main string
---@param deputy string
---@return boolean
function M.canPair(room, main, deputy, kingdom)
  if main == deputy then return false end
  local a, b = Fk.generals[main], Fk.generals[deputy]
  if not (a and b) then return false end
  if not room:getSettings("disableSameConvert") and a.trueName == b.trueName then return false end
  return #Guest.pairKingdoms(room, main, deputy, kingdom and { kingdom }) > 0
end

---@param room Room
---@param names string[]
---@return table[]
function M.legalPairs(room, names, kingdom)
  local result = {}
  local allowed = kingdom and { kingdom }
  for i = 1, #names do
    for j = i + 1, #names do
      -- Wild-exclusive generals may only be main generals, so the same two
      -- cards can be legal in one orientation and illegal in the other. The
      -- final offers are shuffled, so both orders must be considered.
      if M.canPair(room, names[i], names[j], kingdom) then
        table.insert(result, {
          main = names[i], deputy = names[j],
          kingdoms = Guest.pairKingdoms(room, names[i], names[j], allowed),
        })
      elseif M.canPair(room, names[j], names[i], kingdom) then
        table.insert(result, {
          main = names[j], deputy = names[i],
          kingdoms = Guest.pairKingdoms(room, names[j], names[i], allowed),
        })
      end
    end
  end
  return result
end

---@param room Room
---@param names string[]
---@return table?
function M.firstLegalPair(room, names, kingdom)
  return M.legalPairs(room, names, kingdom)[1]
end

---Whether a reply name is an offered card or a legal same-name replacement.
---@param room Room
---@param offers string[]
---@param name any
---@return boolean
function M.offered(room, offers, name)
  if type(name) ~= "string" then return false end
  local general = Fk.generals[name]
  if not general or not Fk:canUseGeneral(name) then return false end
  return table.find(offers, function(original)
    if original == name then return true end
    return not room:getSettings("disableSameConvert")
      and Fk.generals[original].trueName == general.trueName
  end) ~= nil
end

---Pairing map for the client rule, including legal same-name conversion targets.
---@param room Room
---@param offers string[]
---@return string[], table<string, string[]>
function M.pairing(room, offers, kingdom)
  local names, seen = {}, {}
  local function add(name)
    if not seen[name] and Fk:canUseGeneral(name) and inKingdom(room, name, kingdom) then
      seen[name] = true
      table.insert(names, name)
    end
  end
  for _, name in ipairs(offers) do
    add(name)
    if not room:getSettings("disableSameConvert") then
      for _, same in ipairs(Fk:getSameGenerals(name)) do add(same) end
    end
  end
  local pairing = {}
  for _, name in ipairs(names) do pairing[name] = {} end
  for i = 1, #names do
    for j = i + 1, #names do
      if M.canPair(room, names[i], names[j], kingdom) or M.canPair(room, names[j], names[i], kingdom) then
        table.insert(pairing[names[i]], names[j])
        table.insert(pairing[names[j]], names[i])
      end
    end
  end
  return names, pairing
end

local function kingdomList(kingdoms)
  return table.concat(table.map(kingdoms, Ban.kingdomLabel), "/")
end

---Free assignment is only a test/room option. When enabled it ignores this
---extension's pairing rule and the room's faction bans, but a reply must still
---name two distinct, real general cards.
---@param room Room
---@return boolean
function M.freeAssign(room)
  return room:getSettings("gameMode") ~= Modes.locked and room:getSettings("enableFreeAssign") == true
end

---@param name any
---@return boolean
local function validFreeGeneral(name)
  if type(name) ~= "string" then return false end
  local general = Fk.generals[name]
  return general ~= nil and not general.total_hidden and name ~= "anjiang"
end

function M.prompt(room)
  local banned = room:getBanner("qiao_banned_kingdoms") or {}
  return "#QiaoChooseGeneralsBans:::" .. (#banned > 0 and kingdomList(banned) or "无")
end

local function ascensionHints(room, names, freeAssign)
  local allowed = room:getBanner("all_kingdoms") or {}
  local allowsLord = FaqRules.allows_lord_ascension(room)
  local hints = {}
  local function add(name, general)
    if general.kingdom == "wild" then
      for _, loyalty in ipairs(Versions.loyalty_versions(name)) do
        if RoomBans.allows(room, loyalty) then
          local possible
          if freeAssign then
            possible = Guest.factionsOf(room, loyalty)
          else
            possible = table.find(names, function(deputy)
              return M.canPair(room, name, deputy) and #Guest.pairKingdoms(room, loyalty, deputy, allowed) > 0
            end)
          end
          if possible then hints[name] = true; return end
        end
      end
    elseif allowsLord then
      local lord = Versions.lord_version(name)
      if RoomBans.allows(room, lord) and table.find(Versions.lord_kingdoms(lord), function(kingdom)
        return table.contains(allowed, kingdom)
      end) then hints[name] = true end
    end
  end
  if freeAssign then
    for name, general in pairs(Fk.generals) do
      if validFreeGeneral(name) then add(name, general) end
    end
  else
    for _, name in ipairs(names) do add(name, Fk.generals[name]) end
  end
  return hints
end

---Dialog data for the final pair selection.
---@param room Room
---@param offers string[]
---@return table
function M.askData(room, offers, guests, kingdom, seat)
  guests = canRedraw(room) and (guests or Guest.guestCandidates(room, offers)) or {}
  local names, pairing = M.pairing(room, offers, kingdom)
  local freeAssign = M.freeAssign(room)
  local guestIllustrations = Guest.replacementEnabled(room)
  local ascensions = ascensionHints(room, names, freeAssign)
  local prompt = M.prompt(room)
  if kingdom then
    local key = "#QiaoChooseLockedKingdom"
    if Locked.isLandlord(room) then key = seat == 1 and "#QiaoChooseLandlord" or "#QiaoChooseFarmer" end
    prompt = key .. ":::" .. Ban.kingdomLabel(kingdom) .. ":seat#" .. seat
  end
  local wild, guestFactions = {}, {}
  for _, name in ipairs(names) do
    local entry = Guest.factionsOf(room, name)
    -- 牌面显示完整客籍；配将合法性由上面的 pairing 按本局可用势力计算。
    if entry and entry.source == "guest" then guestFactions[name] = Guest.guestKingdoms(name) end
    if entry and entry.wild then wild[name] = true end
  end
  if freeAssign and guestIllustrations then
    -- 自由选将换入的客将也显示完整客籍，重抽资格仍随原始候选。
    for name in pairs(Guest.guests) do
      if not guestFactions[name] and validFreeGeneral(name) then
        local entry = Guest.factionsOf(room, name)
        if entry and entry.source == "guest" then guestFactions[name] = Guest.guestKingdoms(name) end
      end
    end
  end
  local data = {
    component = {
      name = "ChooseGeneralBox", uri = "LunarLtk.Pages.Popups",
      model = {
        name = "ChooseGeneralModel", uri = "LunarLtk.Models.Popups",
        prop = {
          generals = table.simpleClone(offers),
          choiceNum = 2,
          prompt = prompt,
          hegemony = true,
          convertDisabled = room:getSettings("disableSameConvert") or false,
          ruleType = M.rule,
          extraData = { pairing = pairing, wild = wild, guests = guests, guestFactions = guestFactions,
            ascensions = ascensions, locked = kingdom ~= nil, freeAssign = freeAssign, guestIllustrations = guestIllustrations,
            offers = table.simpleClone(offers) },
        },
      },
    },
  }
  -- The HanJin box provides guest illustrations, redraw and free assignment.
  if guestIllustrations or freeAssign then
    data.component.name, data.component.uri = nil, nil
    data.component.url = M.redraw_url
  elseif next(ascensions) then
    data.component.name, data.component.uri = nil, nil
    data.component.url = M.ascension_url
  end
  return data
end

---Ask every player for a final pair.
---@param room Room
---@param players ServerPlayer[]
---@param offers table<ServerPlayer, string[]>
---@return table<ServerPlayer, string[]>
function M.ask(room, players, offers, assigned)
  local answers = {}
  local req = Request:new(players, "CustomDialog")
  req.focus_text = "AskForGeneral"
  req.timeout = room:getSettings("generalTimeout") or M.defaultTimeout
  for _, player in ipairs(players) do
    local kingdom = assigned and assigned[player]
    local data = M.askData(room, offers[player], nil, kingdom, player.seat)
    req:setData(player, data)
    local default = assert(M.firstLegalPair(room, offers[player], kingdom))
    req:setDefaultReply(player, { default.main, default.deputy })
    if data.component.url == M.redraw_url and canRedraw(room) then
      player.mini_game_data = { type = "qiao_guest_selection",
        offers = offers, req = req, failed = {} }
    end
  end
  req:ask()
  for _, player in ipairs(players) do
    player.mini_game_data = nil
    answers[player] = M.decode(req:getResult(player))
  end
  return answers
end

---Validate one pair reply and return the pair that will actually be used.
---Invalid, cancelled or stale replies fall back to the player's offered pair.
---@param room Room
---@param offers string[]
---@param answer string[]
---@return table? @ { main, deputy, kingdoms, fallback }
function M.validate(room, offers, answer, kingdom)
  local main, deputy = answer and answer[1], answer and answer[2]
  if M.freeAssign(room) then
    if validFreeGeneral(main) and validFreeGeneral(deputy) and main ~= deputy then
      -- A normally legal pair keeps its resolved (including guest) kingdoms.
      -- Only when the normal rule has no result does free assignment fall back
      -- to printed affiliations without the room's ban filter.
      local kingdoms = Guest.pairKingdoms(room, main, deputy)
      if #kingdoms == 0 then
        kingdoms = Guest.freePairKingdoms(room, main, deputy)
        if #kingdoms == 0 then kingdoms = { Guest.fallbackKingdom(room) } end
      end
      return {
        main = main, deputy = deputy,
        kingdoms = kingdoms,
        fallback = false,
      }
    end
  elseif main and deputy and main ~= deputy
    and M.offered(room, offers, main) and M.offered(room, offers, deputy)
    and M.canPair(room, main, deputy, kingdom) then
    return {
      main = main, deputy = deputy,
      kingdoms = Guest.pairKingdoms(room, main, deputy, kingdom and { kingdom }),
      fallback = false,
    }
  end
  local pair = M.firstLegalPair(room, offers, kingdom)
  if not pair then return nil end
  return { main = pair.main, deputy = pair.deputy, kingdoms = pair.kingdoms, fallback = true }
end

---Remove every selected exact card name from the cards that may return to the
---pile. This matters under free assignment because a player may pick a card that
---belongs to another player's offers; that card must not come back as drawable.
---@param unused string[]
---@param selected table<string, boolean>
---@return string[]
function M.pruneUnused(unused, selected)
  return table.filter(unused, function(name) return not selected[name] end)
end

---Ask for the initial kingdom after a legal pair is known.
---@param room Room
---@param player ServerPlayer
---@param legal string[]
---@return string?
function M.askKingdom(room, player, legal)
  if #legal == 0 then return nil end
  if #legal == 1 then return legal[1] end
  local mode = room:getSettings("gameMode")
  local req = Request:new(player, "AskForChoices")
  req.focus_text = mode
  req.timeout = room:getSettings("generalTimeout") or M.defaultTimeout
  req:setData(player, { legal, legal, { 1, 1 }, false, mode,
    "#QiaoChooseKingdom", false, true })
  req:setDefaultReply(player, { legal[1] })
  local result = req:getResult(player)
  if type(result) == "table" and table.contains(legal, result[1]) then return result[1] end
  return legal[1]
end

---Ask, validate and resolve the initial kingdom for every player.
---@return table<ServerPlayer, string[]>, table<ServerPlayer, string>, number[]
function M.choose(room, players, offers, assigned)
  local answers = M.ask(room, players, offers, assigned)
  local pairs, kingdoms, fallbacks = {}, {}, {}
  for _, player in ipairs(players) do
    local valid = assert(M.validate(room, offers[player], answers[player], assigned and assigned[player]),
      "Each player must keep a legal pair")
    if valid.fallback then table.insert(fallbacks, player.id) end
    local kingdom = assert(M.askKingdom(room, player, valid.kingdoms),
      "A legal pair must have an initial kingdom")
    pairs[player] = { valid.main, valid.deputy }
    kingdoms[player] = kingdom
  end
  return pairs, kingdoms, fallbacks
end

---Find a replacement set that keeps a legal pair and does not take the old
---candidates before success. Prefers any legal pair in the remaining offers;
---otherwise constructs a pair with one or two replacement cards.
---@param room Room
---@param offers string[]
---@param removing string[]
---@return string[]? , string?
function M.replacements(room, offers, removing)
  local available = table.simpleClone(room.general_pile)
  room:shuffleTable(available)
  local k = #removing
  if k == 0 then return {}, nil end
  if #available < k then return nil, "pool_too_small" end
  local remaining = table.filter(offers, function(name) return not table.contains(removing, name) end)

  local function extras(pair)
    local result = {}
    for _, name in ipairs(available) do
      if #result >= k - #pair then break end
      if not table.contains(pair, name) then table.insert(result, name) end
    end
    if #result < k - #pair then return nil end
    return result
  end

  if M.firstLegalPair(room, remaining) then
    local result = table.slice(available, 1, k + 1)
    if #result == k then return result end
  end

  -- Pairs using one offered card and one replacement. Wild cards may only be
  -- main generals, so try both orientations before rejecting the pair.
  if k >= 1 then
    for _, first in ipairs(remaining) do
      for _, second in ipairs(available) do
        if M.canPair(room, first, second) or M.canPair(room, second, first) then
          local rest = extras({ second })
          if rest then
            table.insert(rest, second)
            return rest
          end
        end
      end
    end
  end
  -- Pairs using two replacement cards.
  if k >= 2 then
    for i = 1, #available do
      for j = i + 1, #available do
        if M.canPair(room, available[i], available[j])
          or M.canPair(room, available[j], available[i]) then
          local rest = extras({ available[i], available[j] })
          if rest then
            table.insert(rest, available[i])
            table.insert(rest, available[j])
            return rest
          end
        end
      end
    end
  end
  return nil, "no_legal_replacement"
end

---Commit one player's redraw. Nothing moves unless a legal replacement exists.
---@param room Room
---@param player ServerPlayer
---@param offers table<ServerPlayer, string[]>
---@param names string[]
---@return boolean, string[]?, string?
function M.applyRedraw(room, player, offers, names)
  if not canRedraw(room) then return false, nil, "redraw_disabled" end
  names = table.filter(names, function(name)
    return Guest.isGuest(room, name) and table.contains(offers[player], name)
  end)
  if #names == 0 then return false, nil, "no_guest_candidate" end
  local replacements, reason = M.replacements(room, offers[player], names)
  if not replacements then
    local failures = room:getTag("qiao_guest_redraw_failures_v1") or {}
    table.insert(failures, { player = player.id, names = table.simpleClone(names), reason = reason })
    room:setTag("qiao_guest_redraw_failures_v1", failures)
    return false, nil, reason
  end

  for i, name in ipairs(names) do
    offers[player][table.indexOf(offers[player], name)] = replacements[i]
  end
  Discard.add(room, names)
  for _, name in ipairs(replacements) do table.removeOne(room.general_pile, name) end
  Guest.ensure(room, replacements)
  local log = room:getTag("qiao_guest_redraws_v1") or {}
  for i, name in ipairs(names) do
    table.insert(log, { player = player.id, from = name, to = replacements[i] })
  end
  room:setTag("qiao_guest_redraws_v1", log)
  return true, replacements
end

-- Intermediate messages update the active dialog. Only the final pair answers
-- the Request, so other players and the original deadline are unaffected.
Fk:addMiniGame {
  name = "qiao_guest_selection",
  update_func = function(player, message)
    local room = player.room
    if not canRedraw(room) then return end
    local state = player.mini_game_data
    if not state or state.type ~= "qiao_guest_selection" or state.req.result[player.id] ~= nil then return end
    local slot, original = tonumber(message[2]), message[3]
    local offers = state.offers[player]
    if message[1] ~= "redraw" or not slot or offers[slot] ~= original or not original
      or state.failed[original] or not Guest.isGuest(room, original) then return end
    local ok = M.applyRedraw(room, player, state.offers, { original })
    if not ok then state.failed[original] = true end
    local guests = table.filter(Guest.guestCandidates(room, offers), function(name)
      return not state.failed[name]
    end)
    local data = M.askData(room, offers, guests)
    state.req:setData(player, data)
    local pair = assert(M.firstLegalPair(room, offers))
    state.req:setDefaultReply(player, { pair.main, pair.deputy })
    player:doNotify("UpdateMiniGame", { slot, original, offers[slot], data.component.model.prop.extraData })
  end,
}

return M
