-- Independent HanJin adaptation rules. Metadata and execution state are per card/use,
-- never inferred from a view-as card's physical subcards or shared across uses.
local A = {}
local Config = require "packages.qiao.pkg.qiao_mode.rules.config"
local ExtraTargets = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"
local states = setmetatable({}, { __mode = "k" })
local supportContexts = setmetatable({}, { __mode = "k" })
local conditions = { "fujia", "canqu", "zhuzhan", "kongchao", "gujun" }
local effects = {}
A.Triggered = TriggerEvent:subclass("QiaoAdaptationTriggered")

local function extra(use)
  use.extra_data = use.extra_data or {}
  return use.extra_data
end

function A.setCardEntries(card, entries)
  card.extra_data = table.simpleClone(card.extra_data or {})
  card.extra_data.qiao_adaptation = table.clone(entries)
end

function A.addEntry(use, entry)
  assert(not states[use], "Add adaptation entries before condition detection")
  local data = extra(use)
  data.qiao_adaptation_entries = data.qiao_adaptation_entries or {}
  table.insert(data.qiao_adaptation_entries, table.clone(entry))
end

function A.getEntries(card, use)
  local entries = {}
  for _, source in ipairs({ { "card", (card.extra_data or {}).qiao_adaptation or {} },
    { "use", use and (use.extra_data or {}).qiao_adaptation_entries or {} } }) do
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

-- Display helpers -----------------------------------------------------------
-- Marks and card tips are derived only from explicit metadata on this concrete
-- card (never from another position with the same name or from a material
-- subcard). They describe what the card may do; they do not evaluate whether
-- the condition currently holds.
A.MARK_PREFIX = "@qiao_adaptation_"

local function translate(key)
  local text = Fk:translate(key)
  return text ~= key and text or key
end

function A.markKey(index, condition)
  return A.MARK_PREFIX .. tostring(index) .. "_" .. tostring(condition)
end

--- The condition is the mark label; the value only adds the effect. The
--- visible label therefore reads e.g. "残躯 · 目标+1", without a generic
--- "应变" prefix or an empty leading label.
function A.markValue(entry)
  return {
    "·",
    "qiao_adaptation_" .. entry.effect,
  }
end

function A.entryTip(entry)
  return translate("qiao_condition_" .. entry.condition) .. "·"
    .. translate("qiao_adaptation_" .. entry.effect)
end

--- Entries explicitly attached to a concrete card. Use-only entries are not
--- included because the hand/selection display cannot see the server use data.
function A.displayEntries(card)
  if card == nil then return {} end
  return table.filter(A.getEntries(card), function(entry)
    return table.contains(conditions, entry.condition)
      and type(entry.effect) == "string" and entry.effect ~= ""
  end)
end

--- Replace the adaptation marks of one physical card with its current entries.
--- Distinct entry indices avoid one entry silently overwriting another; marks
--- are stored per card id, so same-name cards at other positions are untouched.
--- `audience` limits the SetCardMark notification to the clients that can see
--- the card; nil keeps the legacy broadcast-to-all behavior.
local function writeCardMark(room, card, mark, value, audience)
  card:setMark(mark, value)
  if card:isVirtual() then return end
  if audience == nil then
    room:setCardMark(card, mark, value)
  else
    room:doBroadcastNotify("SetCardMark", { card.id, mark, value }, audience)
  end
end

function A.stampCard(room, card, audience)
  if room == nil or card == nil or card:isVirtual() then return false end
  for _, mark in ipairs(card:getMarkNames()) do
    if mark:startsWith(A.MARK_PREFIX) then writeCardMark(room, card, mark, 0, audience) end
  end
  local entries = A.displayEntries(card)
  for index, entry in ipairs(entries) do
    writeCardMark(room, card, A.markKey(index, entry.condition), A.markValue(entry), audience)
  end
  return #entries > 0
end

function A.cardStamped(card)
  if card == nil or card:isVirtual() then return true end
  local expected = {}
  local entries = A.displayEntries(card)
  for index, entry in ipairs(entries) do
    expected[A.markKey(index, entry.condition)] = A.markValue(entry)
  end

  local actual = {}
  for _, mark in ipairs(card:getMarkNames()) do
    if mark:startsWith(A.MARK_PREFIX) then actual[mark] = card:getMark(mark) end
  end

  local expectedCount = 0
  for mark, value in pairs(expected) do
    expectedCount = expectedCount + 1
    local current = actual[mark]
    if type(current) ~= "table" or #current ~= #value then return false end
    for part = 1, #value do
      if current[part] ~= value[part] then return false end
    end
  end
  local actualCount = 0
  for mark in pairs(actual) do
    actualCount = actualCount + 1
    if expected[mark] == nil then return false end
  end
  return actualCount == expectedCount
end

function A.hasDisplayMarks(card)
  if card == nil or card:isVirtual() then return false end
  for _, mark in ipairs(card:getMarkNames()) do
    if mark:startsWith(A.MARK_PREFIX) then return true end
  end
  return false
end

--- Stamp one card only when its current display state differs. Used by the
--- manual full-sync helper; move/initial hooks re-stamp to update the audience.
function A.syncCard(room, card, audience)
  if card == nil or card:isVirtual() then return false end
  if (A.isAdaptationCard(card) or A.hasDisplayMarks(card)) and not A.cardStamped(card) then
    A.stampCard(room, card, audience)
    return true
  end
  return false
end

--- Manual full sync helper. It is not called at GamePrepared: that would mark
--- every face-down draw-pile card. By default it updates only server-side mark
--- state (empty audience); callers must pass the intended audience to notify
--- clients, so this helper cannot accidentally leak hidden-card marks.
function A.stampAll(room, audience)
  if room == nil then return end
  audience = audience or {}
  for _, card in ipairs(Fk.cards) do
    if room:getCardArea(card.id) ~= Card.Unknown then
      A.syncCard(room, card, audience)
    end
  end
end

--- Stamp the initial hand of one player. DrawInitial uses notifyMoveCards
--- rather than fk.AfterCardsMove, so this hook is what covers the first hand.
function A.stampCards(room, cards, audience)
  for _, id in ipairs(cards or {}) do
    local card = Fk:getCardById(id, true)
    if card ~= nil and not card:isVirtual()
      and (A.isAdaptationCard(card) or A.hasDisplayMarks(card)) then
      A.stampCard(room, card, audience)
    end
  end
end

--- Cards are public when they reach Processing/equip/judge. A hand card only
--- reports its marks to its owner. Draw pile/discard/void get no notification.
local function audienceForMove(move)
  local area = move.toArea
  if area == Player.Hand then
    return move.to and { move.to } or {}
  elseif area == Player.Equip or area == Player.Judge or area == Card.Processing then
    return nil
  end
  return false
end

--- Stamp cards that were created or moved after the initial hand. Cards that
--- are not yet visible (draw pile/discard/void) are skipped, so ordinary moves
--- and face-down cards do not broadcast mark data. A hand card only notifies
--- its owner; public areas notify all players.
function A.stampMoved(room, moves)
  for _, move in ipairs(moves or {}) do
    local audience = audienceForMove(move)
    if audience ~= false then
      for _, info in ipairs(move.moveInfo or {}) do
        local card = Fk:getCardById(info.cardId, true)
        if card ~= nil and not card:isVirtual()
          and (A.isAdaptationCard(card) or A.hasDisplayMarks(card)) then
          -- Re-stamp even when the server mark state is current: the audience
          -- may have changed with the move (e.g. hand -> new owner/public area).
          A.stampCard(room, card, audience)
        end
      end
    end
  end
end

--- Client-facing card-selection tips. Only explicit card metadata produces a
--- tip; no condition evaluation is performed here.
function A.cardTips(card)
  if card == nil then return nil end
  local tips = {}
  for _, entry in ipairs(A.displayEntries(card)) do
    table.insert(tips, { content = A.entryTip(entry), type = "normal" })
  end
  return #tips > 0 and tips or nil
end

-- Each grant is one token and can bypass only one entry, even if conditions repeat.
-- A use-scoped trigger may register its token after AfterCardUseDeclared (for
-- example 通法 pays when the card is actually used); resolve reads the same live
-- table, so such a token is still considered once per unsettled entry. It must
-- not be added while entries are already resolving.
function A.grantIgnore(use, source, entryId)
  assert(states[use] == nil or not states[use].resolving,
    "Grant ignores before resolution starts")
  assert(type(source) == "string" and source ~= "", "Ignore effects need a source identifier")
  local data = extra(use)
  data.qiao_adaptation_ignores = data.qiao_adaptation_ignores or {}
  table.insert(data.qiao_adaptation_ignores, { source = source, entry_id = entryId })
end

-- Read-only condition check. Selection-time code may call this; it must never
-- draw, discard, ask a question or emit an event.
function A.conditionSatisfied(room, player, condition)
  local H = require "packages.hegemony.util"
  if condition == "fujia" then
    return table.every(room:getPresentPlayers(), function(p)
      return player:getHandcardNum() >= p:getHandcardNum()
    end)
  elseif condition == "canqu" then
    return player.hp == 1
  elseif condition == "kongchao" then
    return player:isKongcheng()
  elseif condition == "gujun" then
    return player.kingdom ~= "unknown" and H.getSameKingdomPlayersNum(room, player) == 1
  end
  return false
end

function A.snapshot(room, use)
  local from = use.from
  local result = {}
  for _, condition in ipairs({ "fujia", "canqu", "kongchao", "gujun" }) do
    result[condition] = A.conditionSatisfied(room, from, condition)
  end
  return result
end

function A.hasEffectEntry(card, use, effectName)
  if not card then return false end
  return table.find(A.getEntries(card, use), function(e) return e.effect == effectName end) ~= nil
end

A.BOLU_MARK = "@qiao_bolu_condition"

local BOLU_PREFIX = "qiao_condition_"

--- 读取角色当前挂载的【拨律】应变条件覆写（纯读取，客户端/服务端共用）。
function A.boluCondition(player)
  if player == nil then return nil end
  local raw = player:getMark(A.BOLU_MARK)
  if type(raw) ~= "string" then return nil end
  local cond = raw:startsWith(BOLU_PREFIX) and raw:sub(#BOLU_PREFIX + 1) or raw
  return table.contains(conditions, cond) and cond or nil
end

--- 返回应用【拨律】覆写后的有效应变条目列表（不修改原牌数据）。
function A.effectiveEntries(card, use, player)
  local entries = A.getEntries(card, use)
  if #entries == 0 then return entries end
  local override = use and (use.extra_data or {}).qiao_bolu_override or nil
  if override == nil then
    override = A.boluCondition(player or (use and use.from))
  end
  if override ~= nil and table.contains(conditions, override) then
    for _, entry in ipairs(entries) do
      entry.condition = override
    end
  end
  return entries
end

--- 首次使用应变牌时锁定并消耗【拨律】标记，使同一张牌的全部应变条目共用此次覆写。
function A.consumeBolu(room, use)
  if room == nil or use == nil or use.from == nil or not A.isAdaptationCard(use.card, use) then
    return nil
  end
  local data = extra(use)
  if data.qiao_bolu_override ~= nil then return data.qiao_bolu_override end
  local override = A.boluCondition(use.from)
  if override ~= nil then
    data.qiao_bolu_override = override
    room:setPlayerMark(use.from, A.BOLU_MARK, 0)
  end
  return override
end

-- Side-effect-free bypass query used by the card's card-skill while the player
-- is still selecting the card and its target. It only answers "may this use
-- exceed the limit"; it does not lock, spend a token or resolve any effect.
function A.ignoreTimesCandidate(room, player, card, use)
  for _, entry in ipairs(A.effectiveEntries(card, use, player)) do
    if entry.effect == "ignore_times" and A.conditionSatisfied(room, player, entry.condition) then
      return true, entry
    end
  end
  return false
end

-- Called once at PreCardUse, before UseCard:main records the use in history.
-- The result is fixed for this use: later condition changes cannot undo or
-- create the exemption. A token can enable this entry only when it explicitly
-- names the entry and is granted before this point.
function A.lockIgnoreTimes(room, use)
  A.consumeBolu(room, use)
  local data = extra(use)
  data.qiao_ignore_times_locked = true
  data.qiao_adaptation_locked = data.qiao_adaptation_locked or {}
  local tokens = data.qiao_adaptation_ignores or {}
  for _, entry in ipairs(A.effectiveEntries(use.card, use, use.from)) do
    if entry.effect == "ignore_times" and not data.qiao_adaptation_locked[entry.id] then
      local satisfied = A.conditionSatisfied(room, use.from, entry.condition)
      local ignoredBy
      if not satisfied then
        local token = table.find(tokens, function(t)
          return not t.spent and (t.entry_id or t.chosen_id) == entry.id
        end)
        if token then
          token.spent = true
          token.chosen_id = entry.id
          ignoredBy = token.source
          satisfied = true
        end
      end
      data.qiao_adaptation_locked[entry.id] = { satisfied = satisfied, ignored_by = ignoredBy }
      if satisfied then use.extraUse = true end
    end
  end
  return data.qiao_adaptation_locked
end

function A.registerEffect(name, spec)
  assert(not effects[name], "Duplicate adaptation effect: " .. name)
  assert(type(spec.apply) == "function", "Adaptation effect needs an implementation")
  effects[name] = spec
end

local function validSupportCard(player, use, reply)
  if player.dead or player:isRemoved() or player == use.from
    or table.contains(use.tos or {}, player) then return end
  if type(reply) ~= "table" then return end
  local ids = type(reply.card) == "table" and reply.card.subcards or reply
  if type(ids) ~= "table" or #ids ~= 1 or type(ids[1]) ~= "number" then return end
  local id = ids[1]
  if table.contains(player:getCardIds("h"), id) and Fk:getCardById(id).type == use.card.type
    and not player:prohibitDiscard(id) then return id end
end

function A.supportContext(extraData)
  local context = supportContexts[extraData]
  if context then return context.use, context.entry end
end

function A.askForSupport(room, use, entry)
  -- The shared focus notification names participants. Use public eligibility
  -- here and check the private card type only in each request and its reply.
  local candidates = table.filter(room:getPresentPlayers(), function(p)
    return p ~= use.from and not table.contains(use.tos or {}, p) and not p:isKongcheng()
  end)
  local prompt = "#qiao_adaptation_support:" .. use.from.id .. "::" .. use.card:getTypeString()
  if entry then prompt = prompt .. ":qiao_adaptation_" .. entry.effect end
  while #candidates > 0 do
    local req = Request:new(candidates, "AskForUseActiveSkill", 1)
    req.focus_text = "qiao_condition_zhuzhan"
    for _, p in ipairs(candidates) do
      local extraData = {
        num = 1, min_num = 1, include_equip = false, skillName = "#qiao_adaptation_rule",
        pattern = ".|.|.|hand|.|" .. use.card:getTypeString(),
      }
      -- Keep the live use on the server. Only the public effect label goes to the client.
      if entry then supportContexts[extraData] = { use = use, entry = entry } end
      req:setData(p, { "discard_skill", prompt, true, extraData })
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
      room:throwCard(id, "#qiao_adaptation_rule", winner, winner)
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
  A.consumeBolu(room, use)
  local entries = A.effectiveEntries(use.card, use, use.from)
  local timing = Config.adaptation_condition_timing
  assert(timing == "sequential" or timing == "snapshot", "Invalid adaptation condition timing")
  -- Direct rule/API callers may skip PreCardUse. Locking here keeps their
  -- ignore_times result consistent, although only PreCardUse is early enough
  -- to keep the use out of the engine's history count.
  local locked = A.lockIgnoreTimes(room, use)
  -- Materialize the live token table now. A use-scoped skill may append its
  -- token after this refresh (通法); resolve must see the same table.
  local tokenTable = extra(use).qiao_adaptation_ignores
  if tokenTable == nil then
    tokenTable = {}
    use.extra_data.qiao_adaptation_ignores = tokenTable
  end
  local state = { entries = entries, timing = timing,
    snapshot = timing == "snapshot" and A.snapshot(room, use) or nil,
    locked = locked,
    -- Keep the live table: a token can be registered by a skill triggered after
    -- this refresh (通法) and MUST still be readable when resolve reaches a later
    -- unsatisfied entry.
    tokens = tokenTable, result = {
    condition_timing = timing,
    is_adaptation_card = #entries > 0, triggered = false, triggered_count = 0, entries = {}, effects = {},
  } }
  states[use] = state
  extra(use).qiao_adaptation_result = state.result
  local seen = {}
  for _, e in ipairs(entries) do
    assert(not seen[e.id], "Duplicate adaptation entry id: " .. e.id)
    seen[e.id] = true
    assert(table.contains(conditions, e.condition), "Unknown adaptation condition: " .. tostring(e.condition))
    assert(effects[e.effect], "Unimplemented adaptation effect: " .. tostring(e.effect))
  end
  return state.result
end

function A.choiceLabel(entry, index, satisfied)
  -- The unrendered source field identifies duplicate condition/effect pairs.
  local label = satisfied and "qiao_ignore_option_satisfied" or "qiao_ignore_option"
  return string.format("%s:%d::qiao_condition_%s:qiao_adaptation_%s",
    label, index, entry.condition, entry.effect)
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
            return A.choiceLabel(e, i)
          end)
          local choice = room:askToChoice(use.from, { choices = choices, cancelable = false,
            skill_name = "#qiao_adaptation_rule", prompt = "#qiao_adaptation_ignore" })
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
      local locked = state.locked[entry.id]
      entry.locked = locked ~= nil
      if locked and entry.effect == "ignore_times" then
        -- The usage-count exemption was fixed before the engine counted this
        -- use. Do not re-detect the condition or let a later token add a
        -- second exemption after the fact.
        entry.satisfied = locked.satisfied == true
        entry.ignored_by = locked.ignored_by
      else
        local natural = state.snapshot or A.snapshot(room, use)
        entry.satisfied = natural[entry.condition] == true
        if not entry.satisfied then entry.satisfied = tryIgnore(room, use, state, entry, natural) end
        if entry.condition == "zhuzhan" and not entry.satisfied then
          entry.satisfied, entry.support = A.askForSupport(room, use, entry)
        end
      end
      local handler = effects[entry.effect]
      local applied = false
      if entry.satisfied then
        local result = handler.apply(room, use, entry)
        -- Non-target effects are mandatory. Only declining/failing an optional target change is a non-trigger.
        applied = not handler.target_change or result == true
      end
      local record = { id = entry.id, condition = entry.condition, effect = entry.effect,
        satisfied = entry.satisfied == true, triggered = applied, ignored_by = entry.ignored_by, support = entry.support,
        locked = entry.locked == true }
      table.insert(state.result.entries, record)
      if applied then
        state.result.triggered = true
        state.result.triggered_count = state.result.triggered_count + 1
        state.result.effects[entry.effect] = (state.result.effects[entry.effect] or 0) + 1
        -- Name the concrete condition in the center popup. This is the only
        -- success notice; the triggering skill effects are muted so preparing
        -- a use or a failed condition cannot show the generic "汉晋应变" text.
        room:sendLog { type = "#InvokeSkillQiaoAdaptation", from = use.from.id,
          arg = "qiao_condition_" .. entry.condition }
        room.logic:trigger(A.Triggered, use.from, { use = use, entry = table.clone(record) })
      end
    end
  end
  state.resolving = false
  return state.result
end

function A.getResult(use) return (use.extra_data or {}).qiao_adaptation_result end
function A.hasEffect(use, name) return ((A.getResult(use) or {}).effects or {})[name] ~= nil end
function A.clear(use) states[use] = nil end

A.registerEffect("draw", { apply = function(room, use)
  if not use.from.dead and not use.from:isRemoved() then
    use.from:drawCards(1, "#qiao_adaptation_rule")
  end
end })
A.registerEffect("damage", { apply = function(room, use) use.additionalDamage = (use.additionalDamage or 0) + 1 end })
-- The actual exemption is fixed in A.lockIgnoreTimes before the use is counted.
-- This handler only confirms it when the entry is reached in adaptation order.
A.registerEffect("ignore_times", { apply = function(room, use) use.extraUse = true end })
A.registerEffect("disresponsive", { apply = function(room, use)
  use.disresponsiveList = use.disresponsiveList or {}
  table.insertTableIfNeed(use.disresponsiveList, room:getPresentPlayers())
end })
A.registerEffect("execute_both", { apply = function(room, use)
  -- Card implementations inspect hasEffect(use, 'execute_both'); this is not an extra card-resolution count.
  extra(use).qiao_execute_both = (extra(use).qiao_execute_both or 0) + 1
end })
A.registerEffect("obtain_response_card", { apply = function(room, use)
  if not use.from.dead and not use.from:isRemoved()
    and use.responseToEvent and use.toCard
    and room:getCardArea(use.toCard) == Card.Processing then
    room:obtainCard(use.from, use.toCard, true, fk.ReasonJustMove, use.from, "#qiao_adaptation_rule")
  end
end })
-- Target +1 is resolved by the public adapter.  It composes the card's current
-- target condition (or a skill-provided replacement condition) with independent
-- rules, keeps the current target list/use context, and handles cards whose
-- main targets own an independent sub target.
A.registerEffect("add_target", { target_change = true, apply = function(room, use, entry)
  return ExtraTargets.addTarget(room, use, {
    target_condition = entry.target_condition,
    excluded_player_id = entry.support and entry.support.player,
  })
end })
A.registerEffect("remove_target", { target_change = true, apply = function(room, use)
  if use.from.dead or #use.tos == 0 then return false end
  local selected = room:askToChoosePlayers(use.from, { min_num = 1, max_num = 1, targets = use.tos,
    skill_name = "#qiao_adaptation_rule", prompt = "#qiao_adaptation_remove_target", cancelable = true })
  return selected[1] and use:removeTarget(selected[1]) or false
end })
-- 乘流: this use's damage becomes thunder. The type is recorded on the use, not
-- on the shared card prototype; damage handlers read it through the parent use.
A.registerEffect("thunder_damage", { apply = function(room, use)
  extra(use).qiao_damage_type = fk.ThunderDamage
end })
-- 前驱: discard one equipment card from each actual target of this use. The
-- card's user chooses; a target with no equipment is simply skipped.
A.registerEffect("discard_target_equip", { apply = function(room, use)
  if use.from == nil or use.from.dead then return end
  for _, to in ipairs(use.tos or {}) do
    if to:isAlive() and not to:isRemoved() and #to:getCardIds(Player.Equip) > 0 then
      local id = room:askToChooseCard(use.from, { target = to, flag = "e",
        skill_name = "#qiao_adaptation_rule", prompt = "#qiao_adaptation_discard_equip" })
      if id ~= nil and to:isAlive() and table.contains(to:getCardIds(Player.Equip), id) then
        room:throwCard({ id }, "#qiao_adaptation_rule", to, use.from)
      end
    end
  end
end })

return A
