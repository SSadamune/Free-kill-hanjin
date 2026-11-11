-- HanJin selection interaction and server-side validation.
--
-- The final pair uses the engine's generic ChooseGeneralBox with a HanJin
-- choose-general rule (registered by the mode package). The rule receives the
-- per-room pairing map as extra data, so a guest candidate is filtered by its
-- actual this-game factions instead of the engine's global general definition.
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local Discard = require "packages.hanjin.pkg.hanjin_mode.rules.general_discard"
local M = {}

M.defaultTimeout = 90
M.rule = "hanjin_heg_pair"
M.redraw_url = "packages/hanjin/pkg/hanjin_mode/qml/GuestRedrawBox.qml"

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
function M.canPair(room, main, deputy)
  if main == deputy then return false end
  local a, b = Fk.generals[main], Fk.generals[deputy]
  if not (a and b) then return false end
  if not room:getSettings("disableSameConvert") and a.trueName == b.trueName then return false end
  return Guest.canPair(room, main, deputy)
end

---@param room Room
---@param names string[]
---@return table[]
function M.legalPairs(room, names)
  local result = {}
  for i = 1, #names do
    for j = i + 1, #names do
      -- Wild-exclusive generals may only be main generals, so the same two
      -- cards can be legal in one orientation and illegal in the other. The
      -- final offers are shuffled, so both orders must be considered.
      if M.canPair(room, names[i], names[j]) then
        table.insert(result, {
          main = names[i], deputy = names[j],
          kingdoms = Guest.pairKingdoms(room, names[i], names[j]),
        })
      elseif M.canPair(room, names[j], names[i]) then
        table.insert(result, {
          main = names[j], deputy = names[i],
          kingdoms = Guest.pairKingdoms(room, names[j], names[i]),
        })
      end
    end
  end
  return result
end

---@param room Room
---@param names string[]
---@return table?
function M.firstLegalPair(room, names)
  return M.legalPairs(room, names)[1]
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
function M.pairing(room, offers)
  local names, seen = {}, {}
  local function add(name)
    if not seen[name] and Fk:canUseGeneral(name) then
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
      if M.canPair(room, names[i], names[j]) or M.canPair(room, names[j], names[i]) then
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

function M.prompt(room)
  local banned = room:getBanner("hanjin_banned_kingdoms") or {}
  return "#HanjinChooseGeneralsBans:::" .. (#banned > 0 and kingdomList(banned) or "无")
end

---Dialog data for the final pair selection.
---@param room Room
---@param offers string[]
---@return table
function M.askData(room, offers, guests)
  guests = guests or Guest.guestCandidates(room, offers)
  local names, pairing = M.pairing(room, offers)
  local wild, guestFactions = {}, {}
  for _, name in ipairs(names) do
    local entry = Guest.factionsOf(room, name)
    if entry and entry.source == "guest" then guestFactions[name] = entry.kingdoms end
    if entry and entry.wild then wild[name] = true end
  end
  local data = {
    component = {
      name = "ChooseGeneralBox", uri = "LunarLtk.Pages.Popups",
      model = {
        name = "ChooseGeneralModel", uri = "LunarLtk.Models.Popups",
        prop = {
          generals = table.simpleClone(offers),
          choiceNum = 2,
          prompt = M.prompt(room, offers),
          hegemony = true,
          convertDisabled = room:getSettings("disableSameConvert") or false,
          ruleType = M.rule,
          extraData = { pairing = pairing, wild = wild, guests = guests, guestFactions = guestFactions,
            offers = table.simpleClone(offers) },
        },
      },
    },
  }
  if next(guestFactions) then
    data.component.name, data.component.uri = nil, nil
    data.component.url = M.redraw_url
  end
  return data
end

---Ask every player for a final pair.
---@param room Room
---@param players ServerPlayer[]
---@param offers table<ServerPlayer, string[]>
---@return table<ServerPlayer, string[]>
function M.ask(room, players, offers)
  local answers = {}
  local req = Request:new(players, "CustomDialog")
  req.focus_text = "AskForGeneral"
  req.timeout = room:getSettings("generalTimeout") or M.defaultTimeout
  for _, player in ipairs(players) do
    local data = M.askData(room, offers[player])
    req:setData(player, data)
    local default = assert(M.firstLegalPair(room, offers[player]))
    req:setDefaultReply(player, { default.main, default.deputy })
    if data.component.url then
      player.mini_game_data = { type = "hanjin_guest_selection",
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
function M.validate(room, offers, answer)
  local main, deputy = answer and answer[1], answer and answer[2]
  if main and deputy and main ~= deputy
    and M.offered(room, offers, main) and M.offered(room, offers, deputy)
    and M.canPair(room, main, deputy) then
    return {
      main = main, deputy = deputy,
      kingdoms = Guest.pairKingdoms(room, main, deputy),
      fallback = false,
    }
  end
  local pair = M.firstLegalPair(room, offers)
  if not pair then return nil end
  return { main = pair.main, deputy = pair.deputy, kingdoms = pair.kingdoms, fallback = true }
end

---Ask for the initial kingdom after a legal pair is known.
---@param room Room
---@param player ServerPlayer
---@param legal string[]
---@return string?
function M.askKingdom(room, player, legal)
  if #legal == 0 then return nil end
  if #legal == 1 then return legal[1] end
  local req = Request:new(player, "AskForChoices")
  req.focus_text = "hanjin_heg_mode"
  req.timeout = room:getSettings("generalTimeout") or M.defaultTimeout
  req:setData(player, { legal, legal, { 1, 1 }, false, "hanjin_heg_mode",
    "#HanjinChooseKingdom", false, true })
  req:setDefaultReply(player, { legal[1] })
  local result = req:getResult(player)
  if type(result) == "table" and table.contains(legal, result[1]) then return result[1] end
  return legal[1]
end

---Ask, validate and resolve the initial kingdom for every player.
---@return table<ServerPlayer, string[]>, table<ServerPlayer, string>, number[]
function M.choose(room, players, offers)
  local answers = M.ask(room, players, offers)
  local pairs, kingdoms, fallbacks = {}, {}, {}
  for _, player in ipairs(players) do
    local valid = assert(M.validate(room, offers[player], answers[player]),
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
  names = table.filter(names, function(name)
    return Guest.isGuest(room, name) and table.contains(offers[player], name)
  end)
  if #names == 0 then return false, nil, "no_guest_candidate" end
  local replacements, reason = M.replacements(room, offers[player], names)
  if not replacements then
    local failures = room:getTag("hanjin_guest_redraw_failures_v1") or {}
    table.insert(failures, { player = player.id, names = table.simpleClone(names), reason = reason })
    room:setTag("hanjin_guest_redraw_failures_v1", failures)
    return false, nil, reason
  end

  for i, name in ipairs(names) do
    offers[player][table.indexOf(offers[player], name)] = replacements[i]
  end
  Discard.add(room, names)
  for _, name in ipairs(replacements) do table.removeOne(room.general_pile, name) end
  Guest.ensure(room, replacements)
  local log = room:getTag("hanjin_guest_redraws_v1") or {}
  for i, name in ipairs(names) do
    table.insert(log, { player = player.id, from = name, to = replacements[i] })
  end
  room:setTag("hanjin_guest_redraws_v1", log)
  return true, replacements
end

-- Intermediate messages update the active dialog. Only the final pair answers
-- the Request, so other players and the original deadline are unaffected.
Fk:addMiniGame {
  name = "hanjin_guest_selection",
  update_func = function(player, message)
    local state = player.mini_game_data
    if not state or state.type ~= "hanjin_guest_selection" or state.req.result[player.id] ~= nil then return end
    local slot, original = tonumber(message[2]), message[3]
    local offers = state.offers[player]
    if message[1] ~= "redraw" or not slot or offers[slot] ~= original or not original
      or state.failed[original] or not Guest.isGuest(player.room, original) then return end
    local ok = M.applyRedraw(player.room, player, state.offers, { original })
    if not ok then state.failed[original] = true end
    local guests = table.filter(Guest.guestCandidates(player.room, offers), function(name)
      return not state.failed[name]
    end)
    local data = M.askData(player.room, offers, guests)
    -- Keep the live component for reconnect even after the last guest was replaced.
    data.component.name, data.component.uri, data.component.url = nil, nil, M.redraw_url
    state.req:setData(player, data)
    local pair = assert(M.firstLegalPair(player.room, offers))
    state.req:setDefaultReply(player, { pair.main, pair.deputy })
    player:doNotify("UpdateMiniGame", { slot, original, offers[slot], data.component.model.prop.extraData })
  end,
}

return M
