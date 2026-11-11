-- HanJin selection interaction and server-side validation.
--
-- The final pair uses the engine's generic ChooseGeneralBox with a HanJin
-- choose-general rule (registered by the mode package). The rule receives the
-- per-room pairing map as extra data, so a guest candidate is filtered by its
-- actual this-game factions instead of the engine's global general definition.
-- Guest redraw is a separate custom dialog before the final selection; a
-- successful redraw can produce another guest candidate, which is offered again
-- (chained redraw).
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
local Discard = require "packages.hanjin.pkg.hanjin_mode.rules.general_discard"
local M = {}

M.rule = "hanjin_heg_pair"
M.redraw_url = "packages/hanjin/qml/GuestRedrawBox.qml"

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
  return table.concat(table.map(kingdoms, function(k) return Fk:translate(k) end), "/")
end

---Prompt text that marks guest candidates and their this-game kingdoms.
---@param room Room
---@param offers string[]
---@return string
function M.prompt(room, offers)
  local marks = {}
  for _, name in ipairs(offers) do
    local entry = Guest.factionsOf(room, name)
    if entry and entry.source == "guest" then
      table.insert(marks, Fk:translate(name) .. "（" .. kingdomList(entry.kingdoms) .. "）")
    end
  end
  if #marks == 0 then return "#HanjinChooseGenerals" end
  return "#HanjinChooseGeneralsGuest:::" .. table.concat(marks, "、")
end

---Dialog data for the final pair selection.
---@param room Room
---@param offers string[]
---@return table
function M.askData(room, offers)
  local _, pairing = M.pairing(room, offers)
  local wild = {}
  for _, name in ipairs(offers) do
    local entry = Guest.factionsOf(room, name)
    if entry and entry.wild then wild[name] = true end
  end
  return {
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
          extraData = { pairing = pairing, wild = wild },
        },
      },
    },
  }
end

---Ask every player for a final pair.
---@param room Room
---@param players ServerPlayer[]
---@param offers table<ServerPlayer, string[]>
---@return table<ServerPlayer, string[]>
function M.ask(room, players, offers)
  local req = Request:new(players, "CustomDialog")
  req.focus_text = "AskForGeneral"
  req.timeout = room:getSettings("generalTimeout") or room.timeout
  for _, player in ipairs(players) do
    local default = M.firstLegalPair(room, offers[player])
    assert(default, "Each player must receive a legal pair")
    req:setData(player, M.askData(room, offers[player]))
    req:setDefaultReply(player, { default.main, default.deputy })
  end
  local answers = {}
  for _, player in ipairs(players) do
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
  req.timeout = room:getSettings("generalTimeout") or room.timeout
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

---Dialog data for the voluntary guest redraw step.
---@param room Room
---@param offers string[]
---@param unasked string[]
---@return table
function M.redrawData(room, offers, unasked)
  local factions = {}
  for _, name in ipairs(offers) do
    local entry = Guest.factionsOf(room, name)
    if entry then
      factions[name] = { kingdoms = entry.kingdoms, source = entry.source }
    end
  end
  return {
    component = {
      url = M.redraw_url,
      prop = {
        generals = table.simpleClone(offers),
        factions = factions,
        guests = table.simpleClone(unasked),
        prompt = "#HanjinGuestRedraw",
        maxSelect = #unasked,
      },
    },
  }
end

---Decode a redraw reply into offers names. Unknown/foreign indices are ignored.
---@param reply any
---@param offers string[]
---@return string[]
function M.decodeRedraw(reply, offers)
  if type(reply) ~= "table" then return {} end
  local indices = reply.indices
  if type(indices) ~= "table" then
    indices = type(reply[1]) == "table" and reply[1].indices or reply
    if type(indices) ~= "table" then indices = {} end
  end
  local selected, seen = {}, {}
  for _, value in ipairs(indices) do
    local name
    if type(value) == "number" then
      name = offers[value]
    elseif type(value) == "string" then
      name = table.contains(offers, value) and value or nil
    end
    if name and not seen[name] then
      seen[name] = true
      table.insert(selected, name)
    end
  end
  return selected
end

---One simultaneous redraw round. Returns only newly redrawn names per player.
---All eligible candidates are marked as asked before the request, so a declined
---or failed candidate is not offered again; only a newly dealt guest candidate
---triggers another round (chained redraw).
---@param room Room
---@param players ServerPlayer[]
---@param offers table<ServerPlayer, string[]>
---@param asked table<ServerPlayer, table<string, boolean>>
---@return table<ServerPlayer, string[]>
function M.askRedraw(room, players, offers, asked)
  local targets, data = {}, {}
  for _, player in ipairs(players) do
    local unasked = table.filter(Guest.guestCandidates(room, offers[player]), function(name)
      return not (asked[player] and asked[player][name])
    end)
    if #unasked > 0 then
      table.insert(targets, player)
      data[player] = unasked
      asked[player] = asked[player] or {}
      for _, name in ipairs(unasked) do asked[player][name] = true end
    end
  end
  if #targets == 0 then return {} end

  local req = Request:new(targets, "CustomDialog")
  req.focus_text = "hanjin_guest_redraw"
  req.timeout = room:getSettings("generalTimeout") or room.timeout
  for _, player in ipairs(targets) do
    req:setData(player, M.redrawData(room, offers[player], data[player]))
    req:setDefaultReply(player, { indices = {} })
  end
  local choices = {}
  for _, player in ipairs(targets) do
    local names = M.decodeRedraw(req:getResult(player), offers[player])
    names = table.filter(names, function(name)
      return table.contains(data[player], name)
    end)
    if #names > 0 then choices[player] = names end
  end
  return choices
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

  offers[player] = table.filter(offers[player], function(name)
    return not table.contains(names, name)
  end)
  table.insertTable(offers[player], replacements)
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

---Run guest redraw until no newly dealt guest candidate remains.
---@param room Room
---@param players ServerPlayer[]
---@param offers table<ServerPlayer, string[]>
---@return table[]
function M.redraw(room, players, offers)
  local asked = {}
  for _, player in ipairs(players) do asked[player] = {} end
  local rounds = 0
  while true do
    rounds = rounds + 1
    if rounds > 256 then
      room:setTag("hanjin_guest_redraw_error_v1", "redraw round limit")
      break
    end
    local choices = M.askRedraw(room, players, offers, asked)
    local changed = false
    for _, player in ipairs(players) do
      local names = choices[player]
      if names and #names > 0 then
        local ok = M.applyRedraw(room, player, offers, names)
        if ok then changed = true end
      end
    end
    if not changed then break end
  end
  return room:getTag("hanjin_guest_redraws_v1") or {}
end

return M
