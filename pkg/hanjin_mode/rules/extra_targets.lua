-- Public adapter for "增加/指定额外目标" in the HanJin national-war mode.
--
-- Design rules:
-- * The central algorithm only applies independent/common rules: the target
--   must be alive, not currently selected, and not prohibited by the card.
-- * The concrete card's own target condition is expressed by its CardSkill's
--   modTargetFilter (the engine's hook for extra/alternate targets).  The
--   central adapter never reimplements a card-specific condition and contains
--   no card-name allow/deny list.
-- * Cards with semantics that cannot be recovered from the current target list
--   (for example a group card that has already expanded its targets) attach a
--   structured rule to their own skill.  The rule supplies a stable selection
--   context and/or an explicit candidate predicate; the center only composes
--   it with the common rules above.
-- * A skill may provide a structured `target_condition` in the adaptation
--   entry.  It *replaces* the card's printed target condition (it is not ANDed
--   with it).  Quantity-only effects simply omit it and therefore keep the
--   printed condition.  Example:
--
--     A.addEntry(use, {
--       condition = "fujia", effect = "add_target",
--       target_condition = { max_distance = 1 }, -- or filter(room, use, target)
--     })
--
local E = {}

local rules = setmetatable({}, { __mode = "k" })

local function hegemony()
  return require "packages.hegemony.util"
end

--- Attach a structured extra-target rule to one concrete card skill.
--- rule fields (all optional):
---   context(room, use) -> any
---   selected(room, use, context) -> ServerPlayer[]   -- selection context for
---       the card's own modTargetFilter
---   requires_selection boolean                        -- no context => no candidate
---   filter(room, use, target, context) -> boolean     -- replaces modTargetFilter
---   sub_candidates(room, use, main, context) -> ServerPlayer[]
---       -- attached targets this main target can legally choose; when present a
---       -- candidate main target must have at least one.
function E.attach(skill, rule)
  assert(skill ~= nil, "ExtraTargets.attach needs a concrete card skill")
  assert(type(rule) == "table", "ExtraTargets.attach needs a rule table")
  for _, key in ipairs({ "context", "selected", "filter", "sub_candidates" }) do
    assert(rule[key] == nil or type(rule[key]) == "function",
      "ExtraTargets rule field must be a function: " .. key)
  end
  rules[skill] = rule
  return rule
end

function E.ruleFor(card)
  local skill = type(card) == "table" and card.skill or nil
  return skill and rules[skill] or nil
end

--- Cards that use a role target list can receive role extra targets.  Equipment
--- and delayed tricks cannot; a passive response card whose target is a card
--- (闪、无懈可击) is represented by `use.toCard` and likewise has no role list.
function E.isRoleTargetUse(use)
  local card = use and use.card
  if card == nil then return false end
  if card.type == Card.TypeEquip or card.sub_type == Card.SubtypeDelayedTrick then return false end
  if use.toCard ~= nil then return false end
  return card.skill ~= nil and type(card.skill.modTargetFilter) == "function"
end

local function commonLegal(use, target)
  return target ~= nil
    and target:isAlive()
    and not target:isRemoved()
    and not table.contains(use.tos or {}, target)
    and not use.from:isProhibited(target, use.card)
end

--- Shared structured target condition.  This is used by both the extra-target
--- adapter and the initial-use target policy so the two cannot drift.
--- Supported fields (all ANDed):
---   filter(room, player, card, target) -> boolean
---   other_roles (boolean; target ~= player)
---   distance / min_distance / max_distance (integer, from the user)
---   same_kingdom / different_kingdom (boolean)
---   kingdom (string, actual Hegemony kingdom)
---   area_has_cards ("h"/"e"/"j"/"hej"/true)
function E.matchesTarget(room, player, card, target, condition)
  if type(condition) ~= "table" then return false end
  if condition.filter ~= nil
    and condition.filter(room, player, card, target) ~= true then return false end
  if condition.other_roles ~= nil and (target ~= player) ~= (condition.other_roles == true) then
    return false
  end
  local distance
  local function currentDistance()
    distance = distance or player:distanceTo(target)
    return distance
  end
  if condition.distance ~= nil and currentDistance() ~= condition.distance then return false end
  if condition.min_distance ~= nil and currentDistance() < condition.min_distance then return false end
  if condition.max_distance ~= nil and currentDistance() > condition.max_distance then return false end
  local H = hegemony()
  if condition.same_kingdom ~= nil then
    if H.compareKingdomWith(target, player) ~= (condition.same_kingdom == true) then return false end
  end
  if condition.different_kingdom ~= nil then
    if H.compareKingdomWith(target, player, true) ~= (condition.different_kingdom == true) then return false end
  end
  if condition.kingdom ~= nil then
    if H.getKingdom(target) ~= condition.kingdom then return false end
  end
  if condition.area_has_cards ~= nil then
    local area = condition.area_has_cards
    if area == true then area = "hej" end
    local ids = {}
    for code in tostring(area):gmatch(".") do
      table.insertTable(ids, target:getCardIds(code))
    end
    if #ids == 0 then return false end
  end
  return true
end

--- Backwards-compatible use-shaped condition used by adaptation add_target.
--- Table filters in this API historically receive (room, use, target); the
--- shared initial-use API uses (room, player, card, target).
function E.matchesCondition(room, use, target, condition)
  if type(condition) == "function" then return condition(room, use, target) == true end
  if type(condition) == "table" and condition.filter ~= nil then
    local wrapped = table.simpleClone(condition)
    local filter = condition.filter
    wrapped.filter = function(room2, player, card, target2)
      return filter(room2, use, target2)
    end
    return E.matchesTarget(room, use.from, use.card, target, wrapped)
  end
  return E.matchesTarget(room, use.from, use.card, target, condition)
end

local function ruleContext(rule, room, use)
  if rule == nil or rule.context == nil then return nil end
  return rule.context(room, use)
end

local function selectionFor(rule, room, use, context)
  if rule == nil then return use.tos end
  if rule.selected ~= nil then return rule.selected(room, use, context) or {} end
  return use.tos
end

local function subCandidates(room, use, main, rule, context)
  if rule == nil or rule.sub_candidates == nil then return {} end
  local list = rule.sub_candidates(room, use, main, context) or {}
  return table.filter(list, function(player)
    return player ~= nil and player ~= main and player:isAlive() and not player:isRemoved()
  end)
end

--- Public candidate query.  `opts` may be an adaptation entry (or a table with
--- `target_condition`) and is only used to read the explicit replacement
--- condition.  The target list itself is always recomputed from current state.
function E.candidates(room, use, opts)
  if use == nil or use.from == nil or use.card == nil then return {} end
  if not E.isRoleTargetUse(use) then return {} end
  opts = opts or {}
  local rule = E.ruleFor(use.card)
  local context = ruleContext(rule, room, use)
  local explicit = opts.target_condition
  local selected
  if explicit == nil then
    selected = selectionFor(rule, room, use, context)
    if rule ~= nil and rule.requires_selection and (type(selected) ~= "table" or #selected == 0) then
      return {}
    end
  end

  local result = {}
  for _, target in ipairs(room.alive_players) do
    if commonLegal(use, target) then
      local legal
      if explicit ~= nil then
        legal = E.matchesCondition(room, use, target, explicit)
      elseif rule ~= nil and rule.filter ~= nil then
        legal = rule.filter(room, use, target, context) == true
      else
        legal = use.card.skill:modTargetFilter(use.from, target, selected, use.card, use.extra_data) == true
      end
      if legal and rule ~= nil and rule.sub_candidates ~= nil then
        legal = #subCandidates(room, use, target, rule, context) > 0
      end
      if legal then table.insert(result, target) end
    end
  end
  return result
end

function E.isCandidate(room, use, target, opts)
  if target == nil then return false end
  return table.contains(E.candidates(room, use, opts), target)
end

--- Public attached-target query.  A card with `sub_candidates` must choose one
--- of these for each newly added main target; it is independent of the sub
--- target already used by the original main target.
function E.subCandidates(room, use, main, opts)
  if use == nil or main == nil then return {} end
  local rule = E.ruleFor(use.card)
  return subCandidates(room, use, main, rule, ruleContext(rule, room, use))
end

--- Add one extra target, with an independent attached target when the card
--- declares one.  The request is cancelable and the whole operation is atomic:
--- nothing is written to the use data until both selections have been rechecked
--- against the current game state.
function E.addTarget(room, use, entry)
  if use == nil or use.from == nil or use.card == nil then return false end
  if use.from.dead then return false end
  entry = entry or {}
  local rule = E.ruleFor(use.card)
  local candidates = E.candidates(room, use, entry)
  if #candidates == 0 then return false end

  local chosen = room:askToChoosePlayers(use.from, {
    min_num = 1, max_num = 1, targets = candidates,
    skill_name = "#hanjin_adaptation_rule",
    prompt = "#hanjin_adaptation_add_target",
    cancelable = true,
  })
  local main = chosen and chosen[1]
  if main == nil or use.from.dead or not E.isCandidate(room, use, main, entry) then return false end

  if rule ~= nil and rule.sub_candidates ~= nil then
    local subs = E.subCandidates(room, use, main, entry)
    if #subs == 0 then return false end
    local subChosen = room:askToChoosePlayers(use.from, {
      min_num = 1, max_num = 1, targets = subs,
      skill_name = "#hanjin_adaptation_rule",
      prompt = "#hanjin_adaptation_sub_target",
      cancelable = true,
    })
    local sub = subChosen and subChosen[1]
    if sub == nil or use.from.dead then return false end
    -- Both the main target condition and the attached-target condition may have
    -- changed while the second request was being answered.
    if not E.isCandidate(room, use, main, entry) then return false end
    if not table.contains(E.subCandidates(room, use, main, entry), sub) then return false end
    use:addTarget(main, { sub })
    return true
  end

  use:addTarget(main)
  return true
end

Fk:loadTranslationTable {
  ["#hanjin_adaptation_sub_target"] = "应变：请选择新增目标的合法副目标",
}

return E
