-- Independent HanJin adaptation rules. Metadata and execution state are per card/use,
-- never inferred from a view-as card's physical subcards or shared across uses.
local A = {}
local Config = require "packages.hanjin.pkg.hanjin_mode.rules.config"
local states = setmetatable({}, { __mode = "k" })
local conditions = { "fujia", "canqu", "zhuzhan", "kongchao", "gujun" }
local effects = {}
A.Triggered = TriggerEvent:subclass("HanjinAdaptationTriggered")

local function extra(use)
  use.extra_data = use.extra_data or {}
  return use.extra_data
end

function A.setCardEntries(card, entries)
  card.extra_data = table.simpleClone(card.extra_data or {})
  card.extra_data.hanjin_adaptation = table.clone(entries)
end

function A.addEntry(use, entry)
  assert(not states[use], "Add adaptation entries before condition detection")
  local data = extra(use)
  data.hanjin_adaptation_entries = data.hanjin_adaptation_entries or {}
  table.insert(data.hanjin_adaptation_entries, table.clone(entry))
end

function A.getEntries(card, use)
  local entries = {}
  for _, source in ipairs({ { "card", (card.extra_data or {}).hanjin_adaptation or {} },
    { "use", use and (use.extra_data or {}).hanjin_adaptation_entries or {} } }) do
    for i, value in ipairs(source[2]) do
      local entry = table.clone(value)
      entry.id = entry.id or source[1] .. ":" .. i
      table.insert(entries, entry)
    end
  end
  return entries
end

function A.isAdaptationCard(card, use)
  if not card then return false end
  return table.find(A.getEntries(card, use), function(e)
    return table.contains(conditions, e.condition) and type(e.effect) == "string" and e.effect ~= ""
  end) ~= nil
end

-- Each grant is one token and can bypass only one entry, even if conditions repeat.
function A.grantIgnore(use, source, entryId)
  assert(not states[use], "Grant ignores before condition detection")
  assert(type(source) == "string" and source ~= "", "Ignore effects need a source identifier")
  local data = extra(use)
  data.hanjin_adaptation_ignores = data.hanjin_adaptation_ignores or {}
  table.insert(data.hanjin_adaptation_ignores, { source = source, entry_id = entryId })
end

function A.snapshot(room, use)
  local from = use.from
  local H = require "packages.hegemony.util"
  return {
    fujia = table.every(room.alive_players, function(p) return from:getHandcardNum() >= p:getHandcardNum() end),
    canqu = from.hp == 1,
    kongchao = from:isKongcheng(),
    gujun = from.kingdom ~= "unknown" and H.getSameKingdomPlayersNum(room, from) == 1,
  }
end

function A.registerEffect(name, spec)
  assert(not effects[name], "Duplicate adaptation effect: " .. name)
  assert(type(spec.apply) == "function", "Adaptation effect needs an implementation")
  effects[name] = spec
end

local function validSupportCard(player, use, reply)
  if player.dead or player == use.from or table.contains(use.tos or {}, player) then return end
  if type(reply) ~= "table" then return end
  local ids = type(reply.card) == "table" and reply.card.subcards or reply
  if type(ids) ~= "table" or #ids ~= 1 or type(ids[1]) ~= "number" then return end
  local id = ids[1]
  if table.contains(player:getCardIds("h"), id) and Fk:getCardById(id).type == use.card.type
    and not player:prohibitDiscard(id) then return id end
end

function A.askForSupport(room, use)
  local candidates = table.filter(room.alive_players, function(p)
    return p ~= use.from and not table.contains(use.tos or {}, p)
      and table.find(p:getCardIds("h"), function(id)
        return Fk:getCardById(id).type == use.card.type and not p:prohibitDiscard(id)
      end) ~= nil
  end)
  while #candidates > 0 do
    local req = Request:new(candidates, "AskForUseActiveSkill", 1)
    req.focus_text = "hanjin_condition_zhuzhan"
    for _, p in ipairs(candidates) do
      req:setData(p, { "discard_skill", "#hanjin_adaptation_support:" .. use.from.id .. "::" .. use.card:getTypeString(), true,
        { num = 1, min_num = 1, include_equip = false, skillName = "#hanjin_adaptation_rule",
          pattern = ".|.|.|hand|.|" .. use.card:getTypeString() } })
    end
    -- Invalid replies are cancellations, not race winners. All requests are still sent together.
    local originalCheck = req._checkReply
    function req:_checkReply(player, useAi)
      local reply = originalCheck(self, player, useAi)
      if reply == "__notready" or reply == "__cancel" then return reply end
      return validSupportCard(player, use, reply) and reply or "__cancel"
    end
    req:ask()
    local winner = req.winners[1]
    if not winner then return false end
    local id = validSupportCard(winner, use, req:getResult(winner))
    if id then
      room:throwCard(id, "#hanjin_adaptation_rule", winner, winner)
      if not table.contains(winner:getCardIds("h"), id) then
        return true, { player = winner.id, card = id }
      end
    end
    -- A cost invalidated by another effect must not create a false successful adaptation.
    table.removeOne(candidates, winner)
  end
  return false
end

function A.prepare(room, use)
  if states[use] then return states[use].result end
  local entries = A.getEntries(use.card, use)
  local timing = Config.adaptation_condition_timing
  assert(timing == "sequential" or timing == "snapshot", "Invalid adaptation condition timing")
  local state = { entries = entries, timing = timing,
    snapshot = timing == "snapshot" and A.snapshot(room, use) or nil,
    tokens = table.clone((use.extra_data or {}).hanjin_adaptation_ignores or {}), result = {
    condition_timing = timing,
    is_adaptation_card = #entries > 0, triggered = false, triggered_count = 0, entries = {}, effects = {},
  } }
  states[use] = state
  extra(use).hanjin_adaptation_result = state.result
  local seen = {}
  for _, e in ipairs(entries) do
    assert(not seen[e.id], "Duplicate adaptation entry id: " .. e.id)
    seen[e.id] = true
    assert(table.contains(conditions, e.condition), "Unknown adaptation condition: " .. tostring(e.condition))
    assert(effects[e.effect], "Unimplemented adaptation effect: " .. tostring(e.effect))
  end
  return state.result
end

local function tryIgnore(room, use, state, entry, natural)
  for _, token in ipairs(state.tokens) do
    if not token.spent then
      local chosenId = token.entry_id or token.chosen_id
      if not chosenId then
        local available = table.filter(state.entries, function(e)
          return (e == entry or not e.settled) and natural[e.condition] ~= true
            and not table.find(state.tokens, function(other)
              return other ~= token and not other.spent and (other.entry_id or other.chosen_id) == e.id
            end)
        end)
        local selected
        if #available == 1 then
          selected = available[1]
        elseif #available > 1 then
          local choices = table.map(available, function(e, i)
            return "hanjin_ignore_option:::" .. i .. ":hanjin_condition_" .. e.condition
          end)
          local choice = room:askToChoice(use.from, { choices = choices, cancelable = false,
            skill_name = "#hanjin_adaptation_rule", prompt = "#hanjin_adaptation_ignore" })
          selected = available[table.indexOf(choices, choice)] or available[1]
        end
        if selected then token.chosen_id = selected.id; chosenId = selected.id end
      end
      if chosenId == entry.id then
        token.spent = true
        entry.ignored_by = token.source
        return true
      end
    end
  end
  return false
end

function A.resolve(room, use)
  A.prepare(room, use)
  local state = states[use]
  if state.resolving then return state.result end
  state.resolving = true
  for _, entry in ipairs(state.entries) do
    if not entry.settled then
      entry.settled = true -- Guard against reentrant event listeners and duplicate event hooks.
      local natural = state.snapshot or A.snapshot(room, use)
      entry.satisfied = natural[entry.condition] == true
      if not entry.satisfied then entry.satisfied = tryIgnore(room, use, state, entry, natural) end
      if entry.condition == "zhuzhan" and not entry.satisfied then
        entry.satisfied, entry.support = A.askForSupport(room, use)
      end
      local handler = effects[entry.effect]
      local applied = false
      if entry.satisfied then
        local result = handler.apply(room, use, entry)
        -- Non-target effects are mandatory. Only declining/failing an optional target change is a non-trigger.
        applied = not handler.target_change or result == true
      end
      local record = { id = entry.id, condition = entry.condition, effect = entry.effect,
        satisfied = entry.satisfied == true, triggered = applied, ignored_by = entry.ignored_by, support = entry.support }
      table.insert(state.result.entries, record)
      if applied then
        state.result.triggered = true
        state.result.triggered_count = state.result.triggered_count + 1
        state.result.effects[entry.effect] = (state.result.effects[entry.effect] or 0) + 1
        room:sendLog { type = "#HanjinAdaptationTriggered", from = use.from.id,
          arg = "hanjin_condition_" .. entry.condition, arg2 = "hanjin_adaptation_" .. entry.effect }
        room.logic:trigger(A.Triggered, use.from, { use = use, entry = table.clone(record) })
      end
    end
  end
  state.resolving = false
  return state.result
end

function A.getResult(use) return (use.extra_data or {}).hanjin_adaptation_result end
function A.hasEffect(use, name) return ((A.getResult(use) or {}).effects or {})[name] ~= nil end
function A.clear(use) states[use] = nil end

A.registerEffect("draw", { apply = function(room, use)
  if not use.from.dead then use.from:drawCards(1, "#hanjin_adaptation_rule") end
end })
A.registerEffect("damage", { apply = function(room, use) use.additionalDamage = (use.additionalDamage or 0) + 1 end })
A.registerEffect("disresponsive", { apply = function(room, use)
  use.disresponsiveList = use.disresponsiveList or {}
  table.insertTableIfNeed(use.disresponsiveList, room.alive_players)
end })
A.registerEffect("execute_both", { apply = function(room, use)
  -- Card implementations inspect hasEffect(use, 'execute_both'); this is not an extra card-resolution count.
  extra(use).hanjin_execute_both = (extra(use).hanjin_execute_both or 0) + 1
end })
A.registerEffect("obtain_response_card", { apply = function(room, use)
  if not use.from.dead and use.responseToEvent and use.toCard and room:getCardArea(use.toCard) == Card.Processing then
    room:obtainCard(use.from, use.toCard, true, fk.ReasonJustMove, use.from, "#hanjin_adaptation_rule")
  end
end })
A.registerEffect("add_target", { target_change = true, apply = function(room, use)
  if use.from.dead then return false end
  local targets = use:getExtraTargets()
  if #targets == 0 then return false end
  local selected = room:askToChoosePlayers(use.from, { min_num = 1, max_num = 1, targets = targets,
    skill_name = "#hanjin_adaptation_rule", prompt = "#hanjin_adaptation_add_target", cancelable = true })
  local target = selected[1]
  if not target or not table.contains(use:getExtraTargets(), target) then return false end
  use:addTarget(target)
  return true
end })
A.registerEffect("remove_target", { target_change = true, apply = function(room, use)
  if use.from.dead or #use.tos == 0 then return false end
  local selected = room:askToChoosePlayers(use.from, { min_num = 1, max_num = 1, targets = use.tos,
    skill_name = "#hanjin_adaptation_rule", prompt = "#hanjin_adaptation_remove_target", cancelable = true })
  return selected[1] and use:removeTarget(selected[1]) or false
end })

return A
