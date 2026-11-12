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

-- Trusted use token ---------------------------------------------------------

function M.issueToken(room, rec)
  assert(isServer(room), "Target policy tokens are server-only")
  serial = serial + 1
  local token = M.TOKEN_PREFIX .. serial
  local tag = room:getTag(M.POLICY_TAG) or {}
  tag[token] = table.simpleClone(rec)
  room:setTag(M.POLICY_TAG, tag)
  return token
end

function M.releaseToken(room, use)
  if not isServer(room) or use == nil then return end
  local data = use.extra_data or {}
  local token = data.hanjin_use_targets_token
  if type(token) ~= "string" then return end
  local tag = room:getTag(M.POLICY_TAG) or {}
  tag[token] = nil
  room:setTag(M.POLICY_TAG, next(tag) ~= nil and tag or nil)
end

function M.trustedPolicy(room, use)
  if not isServer(room) or use == nil then return nil end
  local data = use.extra_data or {}
  local token = data.hanjin_use_targets_token
  if type(token) ~= "string" then return nil end
  return (room:getTag(M.POLICY_TAG) or {})[token]
end

function M.attachUse(room, use, rec, preferredToken)
  use.extra_data = use.extra_data or {}
  local token = use.extra_data.hanjin_use_targets_token
  if type(preferredToken) == "string" and (room:getTag(M.POLICY_TAG) or {})[preferredToken] ~= nil then
    token = preferredToken
  end
  if type(token) ~= "string" or (room:getTag(M.POLICY_TAG) or {})[token] == nil then
    token = M.issueToken(room, rec)
  end
  use.extra_data.hanjin_use_targets = compact(rec)
  use.extra_data.hanjin_use_targets_token = token
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
  local pushed = M.push(room, player, names, rec, rec.context)
  local ok, result = pcall(function()
    return card:getAvailableTargets(player, extra_data)
  end)
  M.pop(room, player, pushed)
  if not ok then return {} end
  return result
end

local function countRange(room, player, card, rec)
  local min = rec.min_targets or card.skill:getMinTargetNum(player)
  local max = rec.max_targets or card.skill:getMaxTargetNum(player, card)
  return min, max
end

--- Validate a constructed use against the trusted strategy.  This is the
--- service/server-side recheck; callers should invoke it before room:useCard and
--- the rule skill invokes it again at PreCardUse for defence in depth.
function M.validateUse(room, player, use, policy, context, opts)
  opts = opts or {}
  if use == nil or use.card == nil or player == nil then return false, "missing-use" end
  local trusted = M.trustedPolicy(room, use)
  if opts.trusted_active and policy == nil then return false, "missing-policy" end
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
  local tos = use.tos or {}
  local seen = {}
  for _, to in ipairs(tos) do
    local key = type(to) == "number" and to or (to and to.id)
    if key == nil then return false, "missing-target" end
    if seen[key] then return false, "duplicate-target" end
    seen[key] = true
  end
  local min, max = countRange(room, player, use.card, rec)
  if #tos < min or (max > 0 and #tos > max) then return false, "target-count" end
  local candidates = M.candidates(room, player, use.card, rec, use.extra_data)
  for _, to in ipairs(tos) do
    if type(to) == "number" then to = room:getPlayerById(to) end
    if to == nil then return false, "missing-target" end
    if player:isProhibited(to, use.card) then return false, "prohibit-target" end
    if not table.contains(candidates, to) then return false, "illegal-target" end
  end
  return true
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

--- Ask for a physical card under a strategy.  The returned use receives a
--- server-only token after the request; PreCardUse validates it again.
function M.askToUseCard(room, player, params)
  params = params or {}
  local names = params.names or (params.card_name and { params.card_name }) or nil
  assert(type(names) == "table" and #names > 0,
    "askToUseCard target policy needs concrete card name(s)")
  local rec = M.push(room, player, names, params.policy or M.default(), params.context)
  local ask = forwardParams(room, player, params, rec)
  local use = room:askToUseCard(player, ask)
  M.pop(room, player, rec)
  if use == nil then return nil end
  M.attachUse(room, use, rec)
  if not M.validateUse(room, player, use, rec, params.context, { require_trusted = true }) then
    M.releaseToken(room, use)
    return nil
  end
  return use
end

--- Ask for a virtual card under a strategy.
function M.askToUseVirtualCard(room, player, params)
  params = params or {}
  local names = params.names
  if names == nil then
    if type(params.name) == "table" then names = table.simpleClone(params.name)
    else names = { params.name } end
  end
  assert(type(names) == "table" and #names > 0,
    "askToUseVirtualCard target policy needs concrete card name(s)")
  local rec = M.push(room, player, names, params.policy or M.default(), params.context)
  local ask = forwardParams(room, player, params, rec)
  local use = room:askToUseVirtualCard(player, ask)
  M.pop(room, player, rec)
  if use == nil then return nil end
  M.attachUse(room, use, rec)
  if not M.validateUse(room, player, use, rec, params.context, { require_trusted = true }) then
    M.releaseToken(room, use)
    return nil
  end
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
  local ok = M.validateUse(room, player, use, rec, context, { require_trusted = true })
  if not ok then
    M.releaseToken(room, use)
    M.pop(room, player, rec)
    return nil
  end
  M.pop(room, player, rec)
  room:useCard(use)
  return use
end

--- Use an already constructed UseCardData-like table under a strategy.
function M.useCard(room, player, use, policy, context)
  local rec = M.push(room, player, { use.card.name }, policy or M.default(), context)
  M.attachUse(room, use, rec)
  local ok = M.validateUse(room, player, use, rec, context, { require_trusted = true })
  M.pop(room, player, rec)
  if not ok then
    M.releaseToken(room, use)
    return nil
  end
  room:useCard(use)
  return use
end

return M
