-- Public "use-card target policy" for the HanJin extension.
--
-- Three explicit strategies, never inferred from card name/virtual identity:
--   * default         : keep the card's printed use-target conditions;
--   * bypass_distance : keep every printed condition except distance;
--   * explicit        : replace the printed target condition with the effect's
--                       own structured condition (target count stays separate).
--
-- The selected strategy is synchronised to the client through a player mark so
-- the card's CardSkill:targetFilter used by the UI is the same proxy used by the
-- server.  A server-issued one-use token in use.extra_data lets PreCardUse
-- reject forged strategy data before the card is declared.  No Room/Card/
-- UseCardData method is monkey patched.
local M = {}

local ExtraTargets = require "packages.hanjin.pkg.hanjin_mode.rules.extra_targets"

M.RULE_SKILL = "#hanjin_use_targets_rule"
M.POLICY_MARK = "@[hanjin_use_target_policy]"
M.POLICY_TAG = "hanjin_use_targets_policies"
M.TOKEN_PREFIX = "hanjin_use_targets_"
M.PROXY_PREFIX = "#hanjin_use_targets_proxy_"

M.KIND_DEFAULT = "default"
M.KIND_BYPASS_DISTANCE = "bypass_distance"
M.KIND_EXPLICIT = "explicit"

local proxyCache = setmetatable({}, { __mode = "k" })
local serial = 0

local function isServer(room)
  return room ~= nil and type(room.getTag) == "function"
end
M.isServer = isServer

local function clone(value)
  if type(value) == "table" then return table.simpleClone(value) end
  return value
end

local function compact(rec)
  return {
    kind = rec.kind,
    names = clone(rec.names),
    condition = clone(rec.condition),
    min_targets = rec.min_targets,
    max_targets = rec.max_targets,
    context = clone(rec.context),
  }
end
M.compact = compact

local function normalize(policy)
  assert(type(policy) == "table", "Target policy must be a table")
  local kind = policy.kind or M.KIND_DEFAULT
  assert(kind == M.KIND_DEFAULT or kind == M.KIND_BYPASS_DISTANCE or kind == M.KIND_EXPLICIT,
    "Unknown use-target policy kind: " .. tostring(kind))
  local rec = {
    kind = kind,
    names = policy.names and table.simpleClone(policy.names) or nil,
    condition = policy.condition and table.simpleClone(policy.condition) or nil,
    min_targets = policy.min_targets,
    max_targets = policy.max_targets,
    context = policy.context and table.simpleClone(policy.context) or nil,
  }
  if kind == M.KIND_EXPLICIT then
    assert(type(rec.condition) == "table", "Explicit target policy needs a condition table")
    assert(rec.condition.filter == nil,
      "Explicit target policy must be declarative (no filter function) so the client uses the same rule")
  end
  if rec.min_targets ~= nil then
    assert(type(rec.min_targets) == "number" and rec.min_targets >= 0,
      "Target policy min_targets must be a non-negative number")
  end
  if rec.max_targets ~= nil then
    assert(type(rec.max_targets) == "number" and rec.max_targets >= 0,
      "Target policy max_targets must be a non-negative number")
  end
  if rec.min_targets ~= nil and rec.max_targets ~= nil then
    assert(rec.min_targets <= rec.max_targets, "Target policy min_targets exceeds max_targets")
  end
  return rec
end

function M.default(opts)
  opts = opts or {}
  return normalize {
    kind = M.KIND_DEFAULT,
    names = opts.names,
    min_targets = opts.min_targets,
    max_targets = opts.max_targets,
    context = opts.context,
  }
end

function M.bypassDistance(opts)
  opts = opts or {}
  return normalize {
    kind = M.KIND_BYPASS_DISTANCE,
    names = opts.names,
    min_targets = opts.min_targets,
    max_targets = opts.max_targets,
    context = opts.context,
  }
end

function M.explicit(condition, opts)
  opts = opts or {}
  return normalize {
    kind = M.KIND_EXPLICIT,
    names = opts.names,
    condition = condition,
    min_targets = opts.min_targets or 1,
    max_targets = opts.max_targets or 1,
    context = opts.context,
  }
end

--- Reconstruct a policy from a compact copy (use.extra_data / request data).
function M.fromCompact(policy)
  return normalize(policy)
end

-- Strategy mark -------------------------------------------------------------

function M.stack(player)
  local mark = player and player:getMark(M.POLICY_MARK)
  return type(mark) == "table" and mark or {}
end

local function nameMatches(rec, card)
  if rec.names == nil then return true end
  return table.contains(rec.names, card.name) or table.contains(rec.names, card.trueName)
end

function M.activePolicy(room, player, card)
  if player == nil or card == nil then return nil end
  local stack = M.stack(player)
  for i = #stack, 1, -1 do
    if nameMatches(stack[i], card) then return stack[i] end
  end
  -- Client target validation can run before the mark notification has been
  -- processed.  The request's extra_data is the same server-authored strategy,
  -- so use it as a client-side fallback.
  if ClientInstance ~= nil and ClientInstance.current_request_handler ~= nil then
    local extra = ClientInstance.current_request_handler.extra_data
    local rec = extra and extra.hanjin_use_targets
    if type(rec) == "table" and nameMatches(rec, card) then return rec end
  end
  return nil
end

function M.topPolicy(room, player)
  local stack = M.stack(player)
  return stack[#stack]
end

--- Server-only trusted view of the currently pushed request policy.  This is
--- used during before_use, before a use object can carry a server token.
function M.activePolicyRecord(room, player, card)
  if not isServer(room) then return nil end
  return M.activePolicy(room, player, card)
end

--- Push one request-scoped strategy. `names` restricts it to the concrete card
--- names this request may produce; other cards keep their normal conditions.
function M.push(room, player, names, policy, context)
  assert(isServer(room), "Target policies can only be pushed on the server")
  local rec = normalize(policy)
  rec.names = names and table.simpleClone(names) or rec.names
  assert(type(rec.names) == "table" and #rec.names > 0,
    "Target policy push needs at least one concrete card name")
  rec.context = context or rec.context
  serial = serial + 1
  rec.serial = serial
  local stack = table.simpleClone(M.stack(player))
  table.insert(stack, rec)
  room:setPlayerMark(player, M.POLICY_MARK, stack)
  return rec
end

function M.pop(room, player, rec)
  if not isServer(room) or player == nil or rec == nil then return end
  local stack = table.simpleClone(M.stack(player))
  for i = #stack, 1, -1 do
    if stack[i].serial == rec.serial then
      table.remove(stack, i)
      break
    end
  end
  room:setPlayerMark(player, M.POLICY_MARK, #stack > 0 and stack or 0)
end

--- Run a query with exactly one request-scoped strategy on top of the stack.
--- The stack is always popped, including when the query raises, so an aborted
--- nested request cannot leave a stale strategy active for the next request.
local function withPushedPolicy(room, player, names, rec, fn)
  local pushed = M.push(room, player, names, rec, rec and rec.context)
  local ok, a, b, c = pcall(fn)
  M.pop(room, player, pushed)
  if not ok then error(a, 0) end
  return a, b, c
end

local function targetIds(list)
  local ret = {}
  for _, value in ipairs(list or {}) do
    local id = type(value) == "number" and value or (value and value.id)
    if id ~= nil then table.insert(ret, id) end
  end
  return ret
end

local function playerFrom(room, value)
  if type(value) == "number" then return room:getPlayerById(value) end
  return value
end

-- Trusted use token ---------------------------------------------------------
--
-- A token is more than "this strategy exists": it is bound to the concrete
-- player, card name and request that produced it, and carries the selection
-- stage target snapshot.  A client cannot move a token to another player/card,
-- and the declared-stage check can tell the original selection apart from
-- targets the card's own onUse later expands or the extra-target adapter adds.

local function usePlayerId(use)
  local from = use and use.from
  if type(from) == "number" then return from end
  return from and from.id
end

local function useCardName(use)
  return use and use.card and use.card.name
end

local function tokenMatchesUse(record, use)
  if type(record) ~= "table" then return false end
  local pid = usePlayerId(use)
  if record.player ~= nil and pid ~= nil and record.player ~= pid then return false end
  local name = useCardName(use)
  if name ~= nil and type(record.names) == "table"
    and not table.contains(record.names, name) then
    return false
  end
  -- The request id is also copied to the use by attachUse.  A token copied to
  -- another use of the same player/card, or left over from an earlier request,
  -- does not carry the matching request id and is rejected.
  local request = use.extra_data and use.extra_data.hanjin_use_targets_request
  if record.request ~= nil and request ~= record.request then return false end
  return true
end

local function tokenTable(room)
  return room:getTag(M.POLICY_TAG) or {}
end

--- Clear request-scoped tokens and marks.  Called at GameStart and TurnStart so
--- an abort in another PreCardUse skill cannot leave an old token alive for a
--- later request.
function M.clearTokens(room)
  if not isServer(room) then return end
  room:setTag(M.POLICY_TAG, nil)
  for _, player in ipairs(room.players) do
    room:setPlayerMark(player, M.POLICY_MARK, 0)
  end
end

function M.issueToken(room, rec, use, requestSerial)
  assert(isServer(room), "Target policy tokens are server-only")
  serial = serial + 1
  local token = M.TOKEN_PREFIX .. serial
  local tag = tokenTable(room)
  local record = compact(rec)
  record.player = usePlayerId(use)
  -- Preserve the request serial of the pushed strategy.  attachUse passes it
  -- explicitly because normalize() intentionally keeps only transferable fields.
  record.request = requestSerial or serial
  record.selection = targetIds(use and use.tos)
  if record.names == nil and useCardName(use) ~= nil then
    record.names = { useCardName(use) }
  end
  tag[token] = record
  room:setTag(M.POLICY_TAG, tag)
  return token
end

--- Release a token only when it really authorizes this use.  A forged use that
--- reuses another player's/card's token must not delete that legitimate token.
function M.releaseToken(room, use)
  if not isServer(room) or use == nil then return end
  local data = use.extra_data or {}
  local token = data.hanjin_use_targets_token
  if type(token) ~= "string" then return end
  local tag = tokenTable(room)
  local record = tag[token]
  if record ~= nil and not tokenMatchesUse(record, use) then return end
  tag[token] = nil
  room:setTag(M.POLICY_TAG, next(tag) ~= nil and tag or nil)
end

function M.trustedPolicy(room, use)
  if not isServer(room) or use == nil then return nil end
  local data = use.extra_data or {}
  local token = data.hanjin_use_targets_token
  if type(token) ~= "string" then return nil end
  local record = tokenTable(room)[token]
  if not tokenMatchesUse(record, use) then return nil end
  return record
end

function M.attachUse(room, use, rec, preferredToken)
  assert(isServer(room), "Target policies can only be attached on the server")
  use.extra_data = use.extra_data or {}
  local requestSerial = rec and rec.serial
  local copy = normalize(rec)
  if copy.names == nil then
    assert(useCardName(use) ~= nil, "Target policy needs a concrete card name")
    copy.names = { useCardName(use) }
  end
  local tag = tokenTable(room)
  local existing = use.extra_data.hanjin_use_targets_token
  -- A stale token on the same use is replaced; a token that belongs to another
  -- use is never removed here.
  if type(existing) == "string" and tag[existing] ~= nil
    and not tokenMatchesUse(tag[existing], use) then
    existing = nil
  end
  -- A previous request for this player and these card names may have been
  -- aborted by another PreCardUse effect before CardUseFinished could release
  -- it.  Starting a new request clears those stale tokens, so an abort cannot
  -- make a later use inherit an old authorization.
  local pid = usePlayerId(use)
  for token, record in pairs(tag) do
    if token ~= existing and token ~= preferredToken
      and type(record) == "table" and record.player == pid
      and type(record.names) == "table" and type(copy.names) == "table"
      and table.hasIntersection(record.names, copy.names) then
      tag[token] = nil
    end
  end
  local token
  if type(preferredToken) == "string" and tag[preferredToken] ~= nil
    and tokenMatchesUse(tag[preferredToken], use) then
    token = preferredToken
  elseif type(existing) == "string" and tag[existing] ~= nil then
    token = existing
    -- Re-attaching the same use with an updated strategy must not keep the old
    -- policy body.  The selection snapshot and request binding stay intact.
    local record = tag[token]
    record.kind = copy.kind
    record.condition = copy.condition
    record.min_targets = copy.min_targets
    record.max_targets = copy.max_targets
    record.names = copy.names
    record.context = copy.context
  else
    token = M.issueToken(room, copy, use, requestSerial)
  end
  use.extra_data.hanjin_use_targets = compact(copy)
  use.extra_data.hanjin_use_targets_token = token
  local finalTag = tokenTable(room)
  use.extra_data.hanjin_use_targets_request = finalTag[token] and finalTag[token].request
  return token
end

-- Condition matching --------------------------------------------------------

function M.matchesCondition(room, player, card, target, condition)
  return ExtraTargets.matchesTarget(room, player, card, target, condition)
end

-- Proxy CardSkill -----------------------------------------------------------

local function originalCanUse(original, player, card, extra_data)
  return original:canUse(player, card, extra_data)
end

local function originalTargetFilter(original, player, to_select, selected, selected_cards, card, extra_data)
  return original:targetFilter(player, to_select, selected, selected_cards, card, extra_data)
end

local function originalModTargetFilter(original, player, to_select, selected, card, extra_data)
  return original:modTargetFilter(player, to_select, selected, card, extra_data)
end

local function withBypass(extra_data)
  local ret = extra_data and table.simpleClone(extra_data) or {}
  ret.bypass_distances = true
  return ret
end

local function proxyFor(original)
  local cached = proxyCache[original]
  if cached ~= nil then return cached end
  local base = M.PROXY_PREFIX .. original.name:gsub("[^%w_]", "_")
  local name, suffix = base, 0
  while Fk.skills[name] ~= nil and Fk.skills[name]._hanjinTargetOrigin ~= original do
    suffix = suffix + 1
    name = base .. "_" .. suffix
  end
  local existing = Fk.skills[name]
  if existing ~= nil then
    proxyCache[original] = existing
    return existing
  end

  local proxy = CardSkill:new(name, Skill.NotFrequent)
  proxy._hanjinTargetOrigin = original
  proxy.visible = false

  function proxy:getMinTargetNum(player)
    local rec = M.topPolicy(player and player.room, player)
    if rec ~= nil and rec.min_targets ~= nil then return rec.min_targets end
    if rec ~= nil and rec.kind == M.KIND_EXPLICIT then return 1 end
    return original:getMinTargetNum(player)
  end

  function proxy:getMaxTargetNum(player, card)
    local rec = M.activePolicy(player and player.room, player, card)
    if rec ~= nil and rec.max_targets ~= nil then return rec.max_targets end
    if rec ~= nil and rec.kind == M.KIND_EXPLICIT then
      return original:getMaxTargetNum(player, card)
    end
    return original:getMaxTargetNum(player, card)
  end

  function proxy:getMinCardNum(player)
    return original:getMinCardNum(player)
  end

  function proxy:getMaxCardNum(player)
    return original:getMaxCardNum(player)
  end

  function proxy:canUse(player, card, extra_data)
    return originalCanUse(original, player, card, extra_data)
  end

  function proxy:fixTargets(player, selected_cards, card, extra_data)
    local rec = M.activePolicy(player and player.room, player, card)
    if rec ~= nil and rec.kind == M.KIND_EXPLICIT then return nil end
    return original:fixTargets(player, selected_cards, card, extra_data)
  end

  function proxy:modTargetFilter(player, to_select, selected, card, extra_data)
    local rec = M.activePolicy(player and player.room, player, card)
    if rec == nil or rec.kind == M.KIND_DEFAULT then
      return originalModTargetFilter(original, player, to_select, selected, card, extra_data)
    end
    if rec.kind == M.KIND_BYPASS_DISTANCE then
      return originalModTargetFilter(original, player, to_select, selected, card, withBypass(extra_data))
    end
    if player:isProhibited(to_select, card) then return false end
    return M.matchesCondition(player.room, player, card, to_select, rec.condition)
  end

  function proxy:targetFilter(player, to_select, selected, selected_cards, card, extra_data)
    local rec = M.activePolicy(player and player.room, player, card)
    if rec == nil or rec.kind == M.KIND_DEFAULT then
      if rec ~= nil and (rec.min_targets ~= nil or rec.max_targets ~= nil)
        and original.targetFilter == Util.CardTargetFilter then
        return Util.CardTargetFilter(proxy, player, to_select, selected, selected_cards, card, extra_data)
      end
      return originalTargetFilter(original, player, to_select, selected, selected_cards, card, extra_data)
    end
    if rec.kind == M.KIND_BYPASS_DISTANCE then
      local merged = withBypass(extra_data)
      if (rec.min_targets ~= nil or rec.max_targets ~= nil)
        and original.targetFilter == Util.CardTargetFilter then
        return Util.CardTargetFilter(proxy, player, to_select, selected, selected_cards, card, merged)
      end
      return originalTargetFilter(original, player, to_select, selected, selected_cards, card, merged)
    end
    if player:isProhibited(to_select, card) then return false end
    if not M.matchesCondition(player.room, player, card, to_select, rec.condition) then return false end
    local max = rec.max_targets or original:getMaxTargetNum(player, card)
    if max > 0 and #selected >= max then return false end
    return true
  end

  function proxy:prompt(...)
    local value = original.prompt
    if type(value) == "function" then return value(original, ...) end
    return value
  end

  function proxy:cardTip(...)
    if original.cardTip == nil then return nil end
    return original:cardTip(...)
  end

  function proxy:targetTip(...)
    if original.targetTip == nil then return nil end
    return original:targetTip(...)
  end

  Fk:addSkill(proxy)
  proxyCache[original] = proxy
  return proxy
end

function M.proxyNameFor(original)
  if original == nil then return nil end
  return proxyFor(original).name
end

-- Candidate and validation --------------------------------------------------

--- Server-side candidate list under one strategy.  This deliberately runs the
--- card's own targetFilter (through the proxy) so UI, server request checks and
--- final validation share one rule.  The policy mark is pushed only for the
--- duration of the query.
function M.candidates(room, player, card, policy, extra_data)
  if card == nil or player == nil then return {} end
  local rec = normalize(policy)
  local names = rec.names or { card.name }
  local ok, result = pcall(function()
    return withPushedPolicy(room, player, names, rec, function()
      return card:getAvailableTargets(player, extra_data)
    end)
  end)
  if not ok or type(result) ~= "table" then return {} end
  return result
end

-- Real CardSkill target selection.  The engine's target-selection UI calls
-- CardSkill:targetFilter, which is *not* always Util.CardTargetFilter (for
-- example 联军盛宴 forbids selecting yourself as the first target even though
-- its modTargetFilter permits self for the expanded use).  Use the concrete
-- skill's own targetFilter when it defines one, and only fall back to the
-- convenience function when the skill kept the base implementation.
local function targetFilterAllows(card_skill, player, target, selected, subcards, card, extra_data)
  if card_skill.targetFilter ~= nil and card_skill.targetFilter ~= ButtonSkill.targetFilter then
    return card_skill:targetFilter(player, target, selected, subcards, card, extra_data) == true
  end
  return Util.CardTargetFilter(card_skill, player, target, selected, subcards, card, extra_data) == true
end

--- Selection-stage validation.  `tos` is exactly the list the player selected
--- before any card onUse expansion.  This is the only stage where the number of
--- selected targets may be compared with min/max target numbers.
local function validateSelectionList(room, player, card, tos, extra_data, ignore_fixed, subset)
  local card_skill = card:getSkill(player)
  local players, seen = {}, {}
  for _, value in ipairs(tos or {}) do
    local target = playerFrom(room, value)
    if target == nil then return false, "missing-target" end
    if seen[target.id] then return false, "duplicate-target" end
    seen[target.id] = true
    table.insert(players, target)
  end

  for _, target in ipairs(players) do
    if not target:isAlive() or target:isRemoved() then return false, "dead-target" end
    if player:isProhibited(target, card) then return false, "prohibit-target" end
  end

  -- Fixed-target cards (桃、无中、AOE、以逸待劳……) are not chosen from a
  -- candidate list.  The engine fills them when the list is empty; when a list
  -- is supplied it must be exactly the set the engine would use.  This also
  -- keeps a partial forged AOE from looking legal.
  local fixed = (not ignore_fixed) and card:getFixedTargets(player, extra_data) or nil
  if fixed ~= nil then
    if #players == 0 then return true end
    local expected = card:getAvailableTargets(player, extra_data)
    if not subset and #players ~= #expected then return false, "fixed-target-count" end
    for _, target in ipairs(players) do
      if not table.contains(expected, target) then return false, "fixed-target" end
    end
    return true
  end

  local min_num = card_skill:getMinTargetNum(player)
  local max_num = card_skill:getMaxTargetNum(player, card)
  if not subset then
    if #players < min_num then return false, "missing-target" end
    if max_num > 0 and #players > max_num then return false, "too-many-targets" end
  end

  local selected = {}
  local subcards = Card:getIdList(card)
  for _, target in ipairs(players) do
    if not targetFilterAllows(card_skill, player, target, selected, subcards, card, extra_data) then
      return false, "illegal-target-combination"
    end
    table.insert(selected, target)
  end
  if not subset and not card_skill:feasible(player, selected, subcards, card) then
    return false, "infeasible-targets"
  end
  return true
end

local function explicitCondition(rec)
  if rec ~= nil and rec.kind == M.KIND_EXPLICIT then return rec.condition end
  return nil
end

local function adaptationEntries(use)
  local ret = {}
  local data = use.extra_data or {}
  for _, entry in ipairs(data.hanjin_adaptation_entries or {}) do
    table.insert(ret, entry)
  end
  local card_data = use.card and use.card.extra_data or {}
  for _, entry in ipairs(card_data.hanjin_adaptation or {}) do
    table.insert(ret, entry)
  end
  return ret
end

--- Declared-stage validation.  The engine has already run card.skill:onUse, so
--- the target structure may be an expansion of the original selection (群体牌),
--- a transformation into main+sub targets (借刀杀人), or both.  The original
--- selection is compared with selection rules; every newly added main target is
--- checked with the card's own extra-target interface; every sub target is
--- checked with the card's own sub-target rule.  Target counts are deliberately
--- not compared here: an expanded group or an adaptation "target +1" is a legal
--- change, not a violation of the initial target count.
local function validateDeclared(room, player, use, rec, extra_data)
  local card = use.card
  local tos = use.tos or {}
  local subTos = use.subTos or {}
  local players, indices, seen = {}, {}, {}
  for index, value in ipairs(tos) do
    local target = playerFrom(room, value)
    if target == nil then return false, "missing-target" end
    if seen[target.id] then return false, "duplicate-target" end
    seen[target.id] = true
    table.insert(players, target)
    indices[target.id] = index
  end

  local subLists = {}
  local hasSubs = false
  for index, target in ipairs(players) do
    local list, listSeen = {}, {}
    for _, value in ipairs(subTos[index] or {}) do
      local sub = playerFrom(room, value)
      if sub == nil then return false, "missing-sub-target" end
      if sub == target then return false, "self-sub-target" end
      -- A sub target is bound to its own main target.  Two different main
      -- targets may choose the same victim (each resolved independently); only
      -- a duplicate within one main target's own sub list is invalid.
      if listSeen[sub.id] then return false, "duplicate-sub-target" end
      listSeen[sub.id] = true
      hasSubs = true
      table.insert(list, sub)
    end
    subLists[index] = list
  end
  for index = #players + 1, #subTos do
    if #(subTos[index] or {}) > 0 then return false, "orphan-sub-target" end
  end

  local represented = table.simpleClone(seen)
  for _, list in ipairs(subLists) do
    for _, sub in ipairs(list) do represented[sub.id] = true end
  end

  local baseline = rec and rec.selection or nil
  local unchanged = type(baseline) == "table"
  local baselineCount = 0
  if unchanged then
    for _, id in ipairs(baseline) do
      baselineCount = baselineCount + 1
      if not seen[id] then unchanged = false end
    end
    if baselineCount ~= #players then unchanged = false end
  end
  local explicit_policy = rec ~= nil and rec.kind == M.KIND_EXPLICIT
  if unchanged and not hasSubs then
    return validateSelectionList(room, player, card, players, extra_data, explicit_policy)
  end

  -- Recheck the original selection while it still has a counterpart in this
  -- use.  A target intentionally removed by another effect is absent here and
  -- therefore not re-added, but an original target that changed state (lost the
  -- required card/weapon, became prohibited, moved out of range) is rejected.
  if type(baseline) == "table" then
    local present = {}
    for _, id in ipairs(baseline) do
      local target = room:getPlayerById(id)
      if target ~= nil and represented[id] then table.insert(present, target) end
    end
    if #present > 0 then
      -- A target legally removed after the initial selection (or a fixed
      -- target that died) leaves a subset; recheck each surviving target's
      -- condition but do not re-impose the original selection count.
      local ok, reason = validateSelectionList(room, player, card, present, extra_data,
        explicit_policy, true)
      if not ok then return false, reason end
    end
  end

  local condition = explicitCondition(rec)
  local bypass = rec ~= nil and rec.kind == M.KIND_BYPASS_DISTANCE
  local entries = adaptationEntries(use)
  local rule = ExtraTargets.ruleFor(card)
  for _, target in ipairs(players) do
    local isBaseline = type(baseline) == "table" and table.contains(baseline, target.id)
    if not isBaseline then
      if not ExtraTargets.targetLegal(room, use, target, {
        condition = condition,
        bypass_distance = bypass,
        entries = entries,
        extra_data = extra_data,
      }) then
        return false, "illegal-extra-target"
      end
      if rule ~= nil and rule.sub_candidates ~= nil and #subLists[indices[target.id]] == 0 then
        return false, "extra-target-needs-sub"
      end
    end
  end
  for index, target in ipairs(players) do
    for _, sub in ipairs(subLists[index]) do
      if not ExtraTargets.subTargetLegal(room, use, target, sub, {
        extra_data = extra_data,
      }) then
        return false, "illegal-sub-target"
      end
    end
  end
  return true
end

--- Shared target validation used by the policy module, the only-as conversion
--- layer and PreCardUse.  `stage` is "selection" before room:useCard (initial
--- choice) or "declared" after card.skill:onUse (expanded/sub-target shape).
function M.validateTargets(room, player, use, rec, stage, opts)
  opts = opts or {}
  if use == nil or use.card == nil or player == nil then return false, "missing-use" end
  if use.card.is_passive or use.toCard ~= nil then return true end
  local policy = rec
  if policy == nil then
    policy = normalize(M.default { names = { use.card.name } })
  end
  if policy.names == nil then policy.names = { use.card.name } end
  local extra_data = opts.extra_data or use.extra_data
  local ok, result, reason = pcall(function()
    return withPushedPolicy(room, player, policy.names, policy, function()
      if stage == "declared" then
        return validateDeclared(room, player, use, policy, extra_data)
      end
      return validateSelectionList(room, player, use.card, use.tos or {}, extra_data,
        policy.kind == M.KIND_EXPLICIT)
    end)
  end)
  if not ok then return false, "validation-error" end
  return result, reason
end

--- Validate a constructed use against the trusted strategy.  Callers invoke it
--- before room:useCard (stage "selection") and the rule skill invokes it again
--- at PreCardUse (stage "declared") for defence in depth.
function M.validateUse(room, player, use, policy, context, opts)
  opts = opts or {}
  if use == nil or use.card == nil or player == nil then return false, "missing-use" end
  local trusted = M.trustedPolicy(room, use)
  if opts.trusted_active and policy == nil and trusted == nil then
    return false, "missing-policy"
  end
  if opts.require_trusted and trusted == nil and not opts.trusted_active then
    return false, "untrusted-policy"
  end
  local rec = policy or trusted
  if rec == nil then return false, "missing-policy" end
  -- Passive response cards (闪/无懈) target a card, not role targets; their
  -- response legality is handled by the response pipeline, but independent
  -- prohibit rules still apply.
  if use.card.is_passive or use.toCard ~= nil then
    if player:prohibitUse(use.card) or player:prohibitResponse(use.card) then
      return false, "prohibit-response"
    end
    return true
  end
  if player.dead then return false, "dead-user" end
  if player:prohibitUse(use.card) then return false, "prohibit-use" end
  if rec.names ~= nil and not nameMatches(rec, use.card) then
    return false, "policy-card-mismatch"
  end
  return M.validateTargets(room, player, use, rec, opts.stage or "selection", opts)
end

local function forwardParams(room, player, params, rec)
  local ret = table.simpleClone(params)
  ret.policy = nil
  ret.names = nil
  ret.context = nil
  ret.extra_data = ret.extra_data and table.simpleClone(ret.extra_data) or {}
  ret.extra_data.hanjin_use_targets = compact(rec)
  return ret
end

--- Ask for a physical card under a strategy.  The request itself never uses the
--- card (upstream Room:askToUseCard only returns the constructed use), so the
--- caller must use the returned, already validated use exactly once.  A server
--- token is attached before returning and PreCardUse rechecks it.
function M.askToUseCard(room, player, params)
  params = params or {}
  local names = params.names or (params.card_name and { params.card_name }) or nil
  assert(type(names) == "table" and #names > 0,
    "askToUseCard target policy needs concrete card name(s)")
  local rec = M.push(room, player, names, params.policy or M.default(), params.context)
  local ask = forwardParams(room, player, params, rec)
  local ok, use = pcall(room.askToUseCard, room, player, ask)
  M.pop(room, player, rec)
  if not ok then error(use, 0) end
  if use == nil then return nil end
  M.attachUse(room, use, rec)
  if not M.validateUse(room, player, use, rec, params.context,
    { require_trusted = true, stage = "selection" }) then
    M.releaseToken(room, use)
    return nil
  end
  return use
end

--- Selection half of the virtual-card request.  It always forces `skip` on the
--- upstream request: upstream would otherwise call room:useCard before the
--- server token and target recheck exist.  After the selection returns it
--- attaches the token and validates the initial targets, but deliberately does
--- NOT use the card.  Callers that need the engine to perform the actual use
--- (for example only_as returning a use to ViewAsSkill:onUse) use this half.
function M.selectVirtualCard(room, player, params)
  params = table.simpleClone(params or {})
  local names = params.names
  if names == nil then
    if type(params.name) == "table" then names = table.simpleClone(params.name)
    else names = { params.name } end
  end
  assert(type(names) == "table" and #names > 0,
    "selectVirtualCard target policy needs concrete card name(s)")
  local rec = M.push(room, player, names, params.policy or M.default(), params.context)
  local ask = forwardParams(room, player, params, rec)
  -- Forced regardless of the caller's value: selection must finish, then the
  -- token is attached and the strategy is rechecked before any use event.
  ask.skip = true
  local ok, use = pcall(room.askToUseVirtualCard, room, player, ask)
  M.pop(room, player, rec)
  if not ok then error(use, 0) end
  if use == nil or use.card == nil then return nil end
  M.attachUse(room, use, rec)
  if not M.validateUse(room, player, use, rec, params.context,
    { require_trusted = true, stage = "selection" }) then
    M.releaseToken(room, use)
    return nil
  end
  return use
end

--- Ask for a virtual card and use it exactly once.  Both the default and an
--- explicit `skip` follow this contract: upstream selection is forced to skip;
--- after the server token is attached and the selection validates, this function
--- issues the single room:useCard.  Callers must not use the returned use again.
function M.askToUseVirtualCard(room, player, params)
  local use = M.selectVirtualCard(room, player, params)
  if use == nil then return nil end
  room:useCard(use)
  return use
end

--- Use an already constructed virtual card under a strategy.  The card is
--- validated before room:useCard; no target is silently rewritten.
function M.useVirtualCard(room, player, card_name, subcards, tos, skillName, extra, extra_data, policy, context)
  local rec = M.push(room, player, { card_name }, policy or M.default(), context)
  local card = Fk:cloneCard(card_name)
  if skillName then card.skillName = skillName end
  if subcards ~= nil then card:addSubcards(Card:getIdList(subcards)) end
  if tos ~= nil and tos[1] == nil then tos = { tos } end
  local use = {
    from = player,
    tos = table.simpleClone(tos or {}),
    card = card,
    extraUse = extra,
    extra_data = extra_data and table.simpleClone(extra_data) or {},
  }
  M.attachUse(room, use, rec)
  local ok = M.validateUse(room, player, use, rec, context,
    { require_trusted = true, stage = "selection" })
  M.pop(room, player, rec)
  if not ok then
    M.releaseToken(room, use)
    return nil
  end
  room:useCard(use)
  return use
end

--- Use an already constructed UseCardData-like table under a strategy.
function M.useCard(room, player, use, policy, context)
  local rec = M.push(room, player, { use.card.name }, policy or M.default(), context)
  M.attachUse(room, use, rec)
  local ok = M.validateUse(room, player, use, rec, context,
    { require_trusted = true, stage = "selection" })
  M.pop(room, player, rec)
  if not ok then
    M.releaseToken(room, use)
    return nil
  end
  room:useCard(use)
  return use
end

return M
