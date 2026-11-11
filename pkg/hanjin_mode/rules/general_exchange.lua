-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- HanJin independent general exchange rule (rules/general-exchange.md).
--
-- This module only reads the engine API and room-scoped state.  It does not
-- patch upstream `HegUtil.swapDeputy`, the engine, or any upstream package.
-- Every public entry point takes a Room/ServerPlayer that is running inside the
-- HanJin national-war mode; the exchange itself is a synchronous server rule.
--
-- Public surface:
--   Exchange.validate(room, first, second, options) -> true | false, reason
--   Exchange.exchange(room, first, second, options) -> context | false, reason
--   Exchange.addCompletionListener(fn)              -- commander integration
--   Exchange.recordSkillEffect(player, data)        -- called by the mode recorder
--   Exchange.clearLedgerScope(room, scope)          -- called by the mode recorder
--
-- A position argument is `{ player = ServerPlayer, isDeputy = boolean,
-- general = optional<expected card name> }`.  A caller must pass the player's
-- explicit exceptions, e.g. `{ cross_kingdom = true }` for a future special
-- rule that relaxes the default same-kingdom requirement.

local M = {}

local LEDGER_TAG = "hanjin_skill_ledger_v1"
local HISTORY_SCOPES = { Player.HistoryPhase, Player.HistoryTurn, Player.HistoryRound, Player.HistoryGame }

-- Exchanged white soldiers count as "obtained" by the receiving position.  The
-- commander/retinue module registers its own independent retinue generals here;
-- do not infer registered retinues from the `blank_` prefix (see
-- rules/commander-retinue.md).
M.soldier_generals = {
  blank_shibing = "white",
  blank_nvshibing = "white",
}

-- Explicit lord registry.  HanJin generals may declare `general.is_lord = true`
-- while the formal pool is still empty; names containing "lord" are also
-- recognised because locked upstream content uses that convention.
M.lord_generals = {}

-- Skill-specific marks that must follow the general card.  A HanJin skill that
-- keeps activation state in a custom mark registers it here (or declares
-- `skel.hanjin_exchange_marks`).  Engine switch/quest marks and `<skill>-<suffix>`
-- marks are handled automatically.
M.skill_marks = {}

local completion_listeners = {}

local function heg()
  return require "packages.hegemony.util"
end

local function isTable(value)
  return type(value) == "table"
end

local function cloneCounts(counts)
  return {
    counts[Player.HistoryPhase] or 0,
    counts[Player.HistoryTurn] or 0,
    counts[Player.HistoryRound] or 0,
    counts[Player.HistoryGame] or 0,
  }
end

local function zeroCounts()
  return { 0, 0, 0, 0 }
end

local function ensureHistoryTables(player)
  player.skillUsedHistory = player.skillUsedHistory or {}
  player.skillBranchUsedHistory = player.skillBranchUsedHistory or {}
end

local function historyCounts(target, key)
  local counts = target[key]
  if not counts then
    counts = zeroCounts()
    target[key] = counts
  end
  return counts
end

local function branchCounts(target, skillName, branch)
  local branches = target[skillName]
  if not branches then
    branches = {}
    target[skillName] = branches
  end
  local counts = branches[branch]
  if not counts then
    counts = zeroCounts()
    branches[branch] = counts
  end
  return counts
end

---------------------------------------------------------------------------
-- Registries
---------------------------------------------------------------------------

---@param name string
---@param kind "white"|"retinue"
function M.registerSoldierGeneral(name, kind)
  assert(type(name) == "string" and name ~= "", "A soldier general needs a name")
  assert(kind == "white" or kind == "retinue", "Soldier kind must be white or retinue")
  M.soldier_generals[name] = kind
end

---@param name string
---@return string?
function M.soldierKind(name)
  return M.soldier_generals[name]
end

---@param name string
---@return boolean
function M.isSoldier(name)
  return M.soldier_generals[name] ~= nil
end

---@param name string
---@return boolean
function M.isWhiteSoldier(name)
  return M.soldier_generals[name] == "white"
end

---@param name string
function M.registerLordGeneral(name)
  assert(type(name) == "string" and name ~= "", "A lord general needs a name")
  M.lord_generals[name] = true
end

---@param name string
---@return boolean
function M.isLordGeneral(name)
  if M.lord_generals[name] then return true end
  local general = Fk.generals[name]
  if not general then return false end
  if general.is_lord then return true end
  for _, text in ipairs({ general.name, general.trueName }) do
    if type(text) == "string" and text:find("lord", 1, true) then return true end
  end
  local lordGenerals = heg().lordGenerals or {}
  for _, lordName in pairs(lordGenerals) do
    if lordName == name then return true end
  end
  for _, skillName in ipairs(general:getSkillNameList(true)) do
    local skill = Fk.skills[skillName]
    if skill and skill:hasTag(Skill.Lord) then return true end
  end
  return false
end

---@param name string
---@return boolean
function M.isWildGeneral(name)
  local general = Fk.generals[name]
  return general ~= nil and general.kingdom == "wild"
end

---@param skillName string
---@param marks string|string[]
function M.registerSkillMarks(skillName, marks)
  assert(type(skillName) == "string" and skillName ~= "", "A skill needs a name")
  if type(marks) == "string" then marks = { marks } end
  local registered = M.skill_marks[skillName] or {}
  for _, mark in ipairs(marks or {}) do
    assert(type(mark) == "string" and mark ~= "", "A skill mark needs a name")
    table.insertIfNeed(registered, mark)
  end
  M.skill_marks[skillName] = registered
end

---------------------------------------------------------------------------
-- Positions and validation
---------------------------------------------------------------------------

---@param player ServerPlayer
---@param isDeputy boolean
---@return string
function M.publicGeneral(player, isDeputy)
  if isDeputy then return player.deputyGeneral or "" end
  return player.general or ""
end

--- Read the server-side card identity.  Only used for internal state (skill
-- source bookkeeping); legality always uses the public position state.
---@param player ServerPlayer
---@param isDeputy boolean
---@return string
function M.actualGeneral(player, isDeputy)
  local public = M.publicGeneral(player, isDeputy)
  if public ~= "anjiang" then return public end
  local mark = isDeputy and "__heg_deputy" or "__heg_general"
  local hidden = player:getMark(mark)
  if type(hidden) == "string" and hidden ~= "" then return hidden end
  return public
end

--- A selected card must be publicly revealed.  Server knowledge of a hidden
-- card's mark must never make it selectable.
---@param player ServerPlayer
---@param isDeputy boolean
---@return boolean
function M.isRevealed(player, isDeputy)
  local name = M.publicGeneral(player, isDeputy)
  return name ~= "" and name ~= "anjiang"
end

---@param player ServerPlayer
---@param isDeputy boolean
---@return boolean
function M.hasPosition(player, isDeputy)
  local name = M.publicGeneral(player, isDeputy)
  return name ~= ""
end

local function isLordPlayer(room, player)
  return player.role == "lord" and player.role_shown and room:isGameMode("role_mode")
end

--- Skill names printed on a general in one position, after the engine's
-- main-place/deputy-place filters.  `includeRelated` also includes related
-- skills, which the engine attaches as derivatives.
---@param generalName string
---@param isDeputy boolean
---@param isLord boolean
---@param includeRelated boolean
---@return string[]
function M.positionSkills(generalName, isDeputy, isLord, includeRelated)
  local general = Fk.generals[generalName]
  if not general then return {} end
  local result = {}
  for _, skillName in ipairs(general:getSkillNameList(isLord, includeRelated)) do
    local skill = Fk.skills[skillName]
    if skill then
      local wrongPlace = (isDeputy and skill:hasTag(Skill.MainPlace))
        or (not isDeputy and skill:hasTag(Skill.DeputyPlace))
      if not wrongPlace then table.insertIfNeed(result, skillName) end
    end
  end
  return result
end

local function normalizePosition(position)
  if not isTable(position) or not position.player or type(position.player.id) ~= "number" then
    return nil
  end
  return {
    player = position.player,
    isDeputy = position.isDeputy and true or false,
    general = position.general,
  }
end

local function checkPosition(room, side)
  local player = side.player
  if player.room ~= room or room:getPlayerById(player.id) ~= player then
    return false, "invalid_player"
  end
  if not M.hasPosition(player, side.isDeputy) then
    return false, "missing_position"
  end
  if not M.isRevealed(player, side.isDeputy) then
    return false, "not_revealed"
  end
  local name = M.publicGeneral(player, side.isDeputy)
  if not Fk.generals[name] then
    return false, "unknown_general"
  end
  if type(side.general) == "string" and side.general ~= name then
    return false, "stale_selection"
  end
  return true
end

---@class HanjinExchangeOptions
---@field cross_kingdom? boolean Explicit future permission for different kingdom players.
---@field kingdom_allowed? fun(from: ServerPlayer, to: ServerPlayer): boolean
---@field allow_lord? boolean Explicit permission for lord generals.
---@field allow_wild? boolean Explicit permission for wild-exclusive generals.
---@field allowed_generals? table<string, boolean> Per-card explicit permissions.

---@param room Room
---@param first table
---@param second table
---@param options? HanjinExchangeOptions
---@return boolean, string?
function M.validate(room, first, second, options)
  options = options or {}
  local a = normalizePosition(first)
  local b = normalizePosition(second)
  if not a or not b then return false, "invalid_position" end

  local ok, reason = checkPosition(room, a)
  if not ok then return false, reason end
  ok, reason = checkPosition(room, b)
  if not ok then return false, reason end

  if a.player == b.player and a.isDeputy == b.isDeputy then
    return false, "same_position"
  end

  if a.player ~= b.player then
    local allowed = options.cross_kingdom == true
    if type(options.kingdom_allowed) == "function" then
      allowed = options.kingdom_allowed(a.player, b.player) and true or false
    end
    if not allowed and not heg().compareKingdomWith(a.player, b.player) then
      return false, "different_kingdom"
    end
  end

  local allowedGenerals = options.allowed_generals or {}
  for _, side in ipairs({ a, b }) do
    local name = M.publicGeneral(side.player, side.isDeputy)
    if not allowedGenerals[name] then
      if M.isWildGeneral(name) and not options.allow_wild then
        return false, "restricted_wild"
      end
      if M.isLordGeneral(name) and not options.allow_lord then
        return false, "restricted_lord"
      end
    end
  end

  -- Faction banning keeps wild-exclusive generals main-only.  Even an explicit
  -- exchange exception must not move one into a deputy position.
  for _, pair in ipairs({ { a, b }, { b, a } }) do
    local source, target = pair[1], pair[2]
    local name = M.publicGeneral(source.player, source.isDeputy)
    if M.isWildGeneral(name) and target.isDeputy then
      return false, "restricted_wild_deputy"
    end
  end

  return true
end

---------------------------------------------------------------------------
-- Activation-time skill source ledger
---------------------------------------------------------------------------

local function ledgerData(room)
  local data = room:getTag(LEDGER_TAG)
  if not isTable(data) then
    data = {}
    room:setTag(LEDGER_TAG, data)
  end
  return data
end

local function cardLedger(room, generalName, create)
  local data = ledgerData(room)
  local entry = data[generalName]
  if not entry and create then
    entry = { history = {}, branches = {} }
    data[generalName] = entry
  end
  return entry
end

--- Which general card currently provides `skillName` for its holder?  Revealed
-- positions win over hidden (prelighted) ones; main wins if both positions
-- provide the same name.  This deterministic convention is what lets the
-- exchange move per-card usage that the engine would otherwise aggregate.
---@param player ServerPlayer
---@param skillName string
---@return string?
function M.skillOwner(player, skillName)
  local room = player.room
  local isLord = isLordPlayer(room, player)
  local candidates = {}
  for _, isDeputy in ipairs({ false, true }) do
    local name = M.actualGeneral(player, isDeputy)
    if Fk.generals[name] then
      local active = M.isRevealed(player, isDeputy)
        or player:isFakeSkill(skillName)
      if active and table.contains(M.positionSkills(name, isDeputy, isLord, true), skillName) then
        table.insert(candidates, {
          name = name,
          revealed = M.isRevealed(player, isDeputy),
          isDeputy = isDeputy,
        })
      end
    end
  end
  for _, candidate in ipairs(candidates) do
    if candidate.revealed then return candidate.name end
  end
  return candidates[1] and candidates[1].name or nil
end

local function bumpCounts(counts, amount)
  for _, scope in ipairs(HISTORY_SCOPES) do
    counts[scope] = (counts[scope] or 0) + amount
  end
end

--- Record one engine skill effect into the per-general ledger.  Called by the
-- mode recorder after `SkillEffect:main` has already added the aggregate
-- history, so the same keys are mirrored here.
---@param player ServerPlayer
---@param data SkillEffectData
function M.recordSkillEffect(player, data)
  local skill = data and data.skill
  if not skill or skill.cardSkill then return end
  local skeleton = skill:getSkeleton()
  if not skeleton then return end

  local owner = M.skillOwner(player, skeleton.name)
  if not owner then return end

  local entry = cardLedger(player.room, owner, true)
  bumpCounts(historyCounts(entry.history, skill.name), 1)

  if skill.is_delay_effect then return end

  local branch = data.skill_data and data.skill_data.history_branch
  if skill.name ~= skeleton.name then
    bumpCounts(historyCounts(entry.history, skeleton.name), 1)
    if branch then
      bumpCounts(branchCounts(entry.branches, skeleton.name, branch), 1)
    end
  else
    bumpCounts(historyCounts(entry.history, "#" .. skill.name .. "_main_skill"), 1)
    if branch then
      bumpCounts(branchCounts(entry.branches, skill.name, branch), 1)
    end
  end
end

--- Reset one engine history scope in every per-card ledger.  The recorder
-- skill calls this at the same points as `Room:clearHistory`.
---@param room Room
---@param scope integer
function M.clearLedgerScope(room, scope)
  local data = room:getTag(LEDGER_TAG)
  if not isTable(data) then return end
  for _, entry in pairs(data) do
    for _, counts in pairs(entry.history or {}) do
      counts[scope] = 0
    end
    for _, branches in pairs(entry.branches or {}) do
      for _, counts in pairs(branches) do
        counts[scope] = 0
      end
    end
  end
end

---------------------------------------------------------------------------
-- Piles, marks and skills
---------------------------------------------------------------------------

local function addPileNames(result, piles)
  if type(piles) == "string" then piles = { piles } end
  for _, pile in ipairs(piles or {}) do
    table.insertIfNeed(result, pile)
  end
end

--- Named private piles belonging to a card's printed skills.  Effects may also
-- declare `derived_piles`, mirroring `SkillSkeleton:onLose`.
---@param skills string[]
---@return string[]
local function skillPileNames(skills)
  local result = {}
  for _, skillName in ipairs(skills) do
    local skeleton = Fk.skill_skels[skillName]
    if skeleton then
      addPileNames(result, skeleton.derived_piles)
      for _, effect in ipairs(skeleton.effects or {}) do
        addPileNames(result, effect.derived_piles)
      end
    end
    local skill = Fk.skills[skillName]
    if skill then addPileNames(result, skill.derived_piles) end
  end
  return result
end

local function markBaseNames(markName)
  local base = markName
  base = base:gsub("^@+%$?", "")
  base = base:gsub("^&", "")
  base = base:gsub("^!", "")
  return base
end

local function isSkillMark(markName, skillName)
  local base = markBaseNames(markName)
  if base == skillName then return true end
  if base == MarkEnum.SwithSkillPreName .. skillName then return true end
  if base == MarkEnum.QuestSkillPreName .. skillName then return true end
  if table.contains(M.skill_marks[skillName] or {}, markName) then return true end
  if base:startsWith(skillName .. "-") then return true end
  local skeleton = Fk.skill_skels[skillName]
  if skeleton and table.contains(skeleton.hanjin_exchange_marks or {}, markName) then return true end
  return false
end

local function captureMarks(player, skills)
  local result = {}
  local owners = {}
  for markName in pairs(player.mark) do
    for _, skillName in ipairs(skills) do
      if isSkillMark(markName, skillName) then
        result[markName] = player:getMark(markName)
        owners[markName] = owners[markName] or {}
        table.insertIfNeed(owners[markName], skillName)
      end
    end
  end
  return result, owners
end

local function externalSkillNames(player)
  local result = {}
  for _, skillName in ipairs(player:getTableMark("ExtraAttachedSkills")) do
    table.insertIfNeed(result, skillName)
  end
  for _, skill in ipairs(player.player_skills) do
    local skeleton = skill:getSkeleton()
    if skeleton and skeleton.attached_equip then
      table.insertIfNeed(result, skill.name)
    end
  end
  return result
end

local function prelightedSkillNames(player)
  local result = {}
  for _, skill in ipairs(player.prelighted_skills or {}) do
    table.insertIfNeed(result, skill.name)
  end
  return result
end

local function otherSourceSkills(player, excludedNames)
  local result = {}
  for source, skills in pairs(player.derivative_skills) do
    if not table.contains(excludedNames, source.name) then
      for _, skill in ipairs(skills) do
        table.insertIfNeed(result, skill.name)
      end
    end
  end
  return result
end

local function providedByOtherPosition(room, player, isDeputy, excludedNames)
  local result = {}
  for _, otherDeputy in ipairs({ false, true }) do
    if otherDeputy ~= isDeputy and M.isRevealed(player, otherDeputy) then
      local name = M.publicGeneral(player, otherDeputy)
      for _, skillName in ipairs(M.positionSkills(name, otherDeputy, isLordPlayer(room, player), true)) do
        table.insertIfNeed(result, skillName)
      end
    end
  end
  for _, skillName in ipairs(externalSkillNames(player)) do
    table.insertIfNeed(result, skillName)
  end
  for _, skillName in ipairs(prelightedSkillNames(player)) do
    table.insertIfNeed(result, skillName)
  end
  for _, skillName in ipairs(otherSourceSkills(player, excludedNames)) do
    table.insertIfNeed(result, skillName)
  end
  return result
end

local function moveCounts(sourceCounts, targetCounts, ledgerCounts)
  for _, scope in ipairs(HISTORY_SCOPES) do
    local moved = math.min(ledgerCounts[scope] or 0, sourceCounts[scope] or 0)
    sourceCounts[scope] = (sourceCounts[scope] or 0) - moved
    targetCounts[scope] = (targetCounts[scope] or 0) + moved
    ledgerCounts[scope] = moved
  end
end

local function ledgerHasSkill(entry, skillName)
  if not entry then return false end
  if entry.history[skillName] or entry.history["#" .. skillName .. "_main_skill"] then
    return true
  end
  if entry.branches[skillName] then return true end
  return false
end

local function transferSourcesWithoutLedger(from, to, skillName)
  ensureHistoryTables(from)
  ensureHistoryTables(to)
  local source = from.skillUsedHistory[skillName]
  if source then
    local target = historyCounts(to.skillUsedHistory, skillName)
    for _, scope in ipairs(HISTORY_SCOPES) do
      target[scope] = (target[scope] or 0) + (source[scope] or 0)
      source[scope] = 0
    end
  end
  local mainKey = "#" .. skillName .. "_main_skill"
  local mainSource = from.skillUsedHistory[mainKey]
  if mainSource then
    local target = historyCounts(to.skillUsedHistory, mainKey)
    for _, scope in ipairs(HISTORY_SCOPES) do
      target[scope] = (target[scope] or 0) + (mainSource[scope] or 0)
      mainSource[scope] = 0
    end
  end
  local branches = from.skillBranchUsedHistory[skillName]
  if branches then
    for branch, counts in pairs(branches) do
      local target = branchCounts(to.skillBranchUsedHistory, skillName, branch)
      for _, scope in ipairs(HISTORY_SCOPES) do
        target[scope] = (target[scope] or 0) + (counts[scope] or 0)
        counts[scope] = 0
      end
    end
  end
end

local function snapshotSkillHistory(from, skillName)
  local snapshot = { history = {}, branches = {} }
  local function record(key)
    local counts = from.skillUsedHistory[key]
    if counts then snapshot.history[key] = cloneCounts(counts) end
  end
  record(skillName)
  record("#" .. skillName .. "_main_skill")
  for branch, counts in pairs(from.skillBranchUsedHistory[skillName] or {}) do
    snapshot.branches[branch] = cloneCounts(counts)
  end
  return snapshot
end

local function transferHistory(room, from, to, generalName, skills, sourceStillProvides)
  local entry = cardLedger(room, generalName, false)
  local ledger = entry or { history = {}, branches = {} }
  ensureHistoryTables(from)
  ensureHistoryTables(to)

  for key, counts in pairs(ledger.history or {}) do
    moveCounts(historyCounts(from.skillUsedHistory, key), historyCounts(to.skillUsedHistory, key), counts)
  end
  for skillName, branches in pairs(ledger.branches or {}) do
    for branch, counts in pairs(branches) do
      moveCounts(branchCounts(from.skillBranchUsedHistory, skillName, branch),
        branchCounts(to.skillBranchUsedHistory, skillName, branch), counts)
    end
  end

  -- Fallback for history written outside the recorder.  It is only safe when
  -- no other source on the old holder provides the same skill name.  The
  -- transferred amounts are written to the ledger so a later swap-back is
  -- symmetric instead of stranding the counts on the new holder.
  for _, skillName in ipairs(skills) do
    if not ledgerHasSkill(entry, skillName) and not table.contains(sourceStillProvides, skillName) then
      local snapshot = snapshotSkillHistory(from, skillName)
      transferSourcesWithoutLedger(from, to, skillName)
      local created = cardLedger(room, generalName, true)
      for key, counts in pairs(snapshot.history) do
        created.history[key] = counts
      end
      for branch, counts in pairs(snapshot.branches) do
        created.branches[skillName] = created.branches[skillName] or {}
        created.branches[skillName][branch] = counts
      end
    end
  end
end

--- Remove the real skills owned only by the departing card, then add the real
-- skills provided by the incoming arrangement.  Skeleton lose/acquire hooks are
-- deliberately not invoked (they can discard derived piles and reset state).
local function syncSkills(room, player, departingSkills, postProvided, attachable)
  local desired = {}
  for _, skill in ipairs(player.player_skills) do
    if not table.contains(departingSkills, skill.name) then
      table.insertIfNeed(desired, skill.name)
    end
  end
  for _, skillName in ipairs(postProvided) do table.insertIfNeed(desired, skillName) end
  for _, skillName in ipairs(externalSkillNames(player)) do table.insertIfNeed(desired, skillName) end
  for _, skillName in ipairs(prelightedSkillNames(player)) do table.insertIfNeed(desired, skillName) end
  for _, skillName in ipairs(otherSourceSkills(player, departingSkills)) do
    table.insertIfNeed(desired, skillName)
  end

  for _, skill in ipairs(table.simpleClone(player.player_skills)) do
    if table.contains(departingSkills, skill.name) and not table.contains(desired, skill.name) then
      local skeleton = skill:getSkeleton()
      if not (skeleton and skeleton.attached_equip) then
        local lost = player:loseSkill(skill.name)
        for _, lostSkill in ipairs(lost) do
          if not player:hasSkill(lostSkill.name, true, true) then
            room:doBroadcastNotify("LoseSkill", { player.id, lostSkill.name })
          end
        end
      end
    end
  end

  for _, skillName in ipairs(attachable) do
    local skill = Fk.skills[skillName]
    if skill and not table.contains(player.player_skills, skill) then
      local got = player:addSkill(skill)
      for _, gotSkill in ipairs(got) do
        room:doBroadcastNotify("AddSkill", { player.id, gotSkill.name })
      end
    end
  end
end

local function setPosition(room, player, isDeputy, generalName)
  if isDeputy then
    room:setDeputyGeneral(player, generalName)
    room:broadcastProperty(player, "deputyGeneral")
  else
    room:setPlayerGeneral(player, generalName, false)
    room:broadcastProperty(player, "general")
  end
  room:setPlayerMark(player, isDeputy and "__heg_deputy" or "__heg_general", generalName)
end

local function updateWildMark(room, player)
  local main = player.general
  local wild = main ~= "anjiang" and Fk.generals[main] and Fk.generals[main].kingdom == "wild"
  room:setPlayerMark(player, "__heg_wild", wild and 1 or 0)
end

---------------------------------------------------------------------------
-- Completion listeners (commander/retinue integration point)
---------------------------------------------------------------------------

---@param listener fun(room: Room, context: table)
---@return fun(room: Room, context: table)
function M.addCompletionListener(listener)
  assert(type(listener) == "function", "Exchange completion listener must be a function")
  table.insert(completion_listeners, listener)
  return listener
end

function M.removeCompletionListener(listener)
  table.removeOne(completion_listeners, listener)
end

function M.clearCompletionListeners()
  completion_listeners = {}
end

local function notifyCompletion(room, context)
  -- Listeners see a fully updated exchange.  They run synchronously and may
  -- coordinate commander sources / convert the white soldiers reported in
  -- `context.obtained_soldiers`.
  for _, listener in ipairs(table.simpleClone(completion_listeners)) do
    listener(room, context)
  end
end

---------------------------------------------------------------------------
-- Exchange
---------------------------------------------------------------------------

local function captureSide(room, player, isDeputy)
  local generalName = M.publicGeneral(player, isDeputy)
  local general = Fk.generals[generalName]
  local isLord = isLordPlayer(room, player)
  local owned = general and general:getSkillNameList(isLord, true) or {}
  local attachable = general and general:getSkillNameList(isLord, false) or {}
  local piles = {}
  for _, pileName in ipairs(skillPileNames(owned)) do
    local ids = player:getPile(pileName)
    if #ids > 0 then
      table.insert(piles, { name = pileName, ids = ids })
    end
  end
  local marks, markOwners = captureMarks(player, owned)
  return {
    player = player,
    isDeputy = isDeputy,
    general = generalName,
    owned = owned,
    attachable = attachable,
    piles = piles,
    marks = marks,
    markOwners = markOwners,
  }
end

local function buildPostPositions(a, b)
  local function current(player)
    return {
      main = player.general or "",
      deputy = player.deputyGeneral or "",
    }
  end
  local aField = a.isDeputy and "deputy" or "main"
  local bField = b.isDeputy and "deputy" or "main"
  local result = {}
  if a.player == b.player then
    local positions = current(a.player)
    positions[aField], positions[bField] = positions[bField], positions[aField]
    result[a.player] = positions
  else
    local first = current(a.player)
    local second = current(b.player)
    first[aField], second[bField] = second[bField], first[aField]
    result[a.player] = first
    result[b.player] = second
  end
  return result
end

local function postProvidedSkills(room, player, positions, excludedNames)
  local isLord = isLordPlayer(room, player)
  local result = {}
  for _, isDeputy in ipairs({ false, true }) do
    local name = isDeputy and positions.deputy or positions.main
    if name and name ~= "" and name ~= "anjiang" then
      for _, skillName in ipairs(M.positionSkills(name, isDeputy, isLord, true)) do
        table.insertIfNeed(result, skillName)
      end
    end
  end
  for _, skillName in ipairs(externalSkillNames(player)) do
    table.insertIfNeed(result, skillName)
  end
  for _, skillName in ipairs(prelightedSkillNames(player)) do
    table.insertIfNeed(result, skillName)
  end
  for _, skillName in ipairs(otherSourceSkills(player, excludedNames)) do
    table.insertIfNeed(result, skillName)
  end
  return result
end

local function postAttachableSkills(room, player, positions)
  local isLord = isLordPlayer(room, player)
  local result = {}
  for _, isDeputy in ipairs({ false, true }) do
    local name = isDeputy and positions.deputy or positions.main
    if name and name ~= "" and name ~= "anjiang" then
      for _, skillName in ipairs(M.positionSkills(name, isDeputy, isLord, false)) do
        table.insertIfNeed(result, skillName)
      end
    end
  end
  return result
end

local function transferPiles(room, fromPlayer, toPlayer, side, samePlayer)
  if samePlayer then return end
  for _, pile in ipairs(side.piles) do
    if #pile.ids > 0 then
      room:moveCardTo(pile.ids, Card.PlayerSpecial, toPlayer, fk.ReasonJustMove,
        nil, pile.name, nil, toPlayer)
    end
  end
end

local function transferMarks(room, a, b, aStillProvides, bStillProvides, samePlayer)
  if samePlayer then return end
  local names = {}
  for markName in pairs(a.marks) do table.insertIfNeed(names, markName) end
  for markName in pairs(b.marks) do table.insertIfNeed(names, markName) end

  for _, markName in ipairs(names) do
    local aValue = a.marks[markName]
    local bValue = b.marks[markName]
    local function keeps(side, stillProvides)
      for _, skillName in ipairs(side.markOwners[markName] or {}) do
        if table.contains(stillProvides, skillName) then return true end
      end
      return false
    end
    local aFinal, bFinal
    if keeps(a, aStillProvides) then aFinal = aValue else aFinal = bValue end
    if keeps(b, bStillProvides) then bFinal = bValue else bFinal = aValue end
    if aFinal ~= nil then
      room:setPlayerMark(a.player, markName, aFinal)
    else
      room:setPlayerMark(a.player, markName, 0)
    end
    if bFinal ~= nil then
      room:setPlayerMark(b.player, markName, bFinal)
    else
      room:setPlayerMark(b.player, markName, 0)
    end
  end
end

--- Exchange two revealed general positions in one atomic rule resolution.
---
-- Both selected cards must be publicly revealed.  The default policy only
-- allows players of the same current national-war kingdom and rejects lord and
-- wild-exclusive cards; `options` is the explicit place for a future special
-- rule to relax those restrictions.
---
---@param room Room
---@param first table
---@param second table
---@param options? HanjinExchangeOptions
---@return table|false, string?
function M.exchange(room, first, second, options)
  options = options or {}
  local ok, reason = M.validate(room, first, second, options)
  if not ok then return false, reason end
  assert(Fk:currentRoom() == room, "General exchange must resolve inside the room's game logic")

  local a = normalizePosition(first)
  local b = normalizePosition(second)
  local samePlayer = a.player == b.player
  local positions = buildPostPositions(a, b)
  local aSide = captureSide(room, a.player, a.isDeputy)
  local bSide = captureSide(room, b.player, b.isDeputy)

  local aStillProvides = providedByOtherPosition(room, a.player, a.isDeputy, aSide.owned)
  local bStillProvides = providedByOtherPosition(room, b.player, b.isDeputy, bSide.owned)

  -- 1. Histories follow their card, using the activation-time ledger.
  if not samePlayer then
    transferHistory(room, a.player, b.player, aSide.general, aSide.owned, aStillProvides)
    transferHistory(room, b.player, a.player, bSide.general, bSide.owned, bStillProvides)
  end

  -- 2. Public positions and the national-war main/deputy records.
  setPosition(room, a.player, a.isDeputy, bSide.general)
  setPosition(room, b.player, b.isDeputy, aSide.general)
  if not a.isDeputy then updateWildMark(room, a.player) end
  if not b.isDeputy then updateWildMark(room, b.player) end

  -- 3. Skills at their new positions.  A position mismatch is retained in the
  -- history ledger but the skill is not active at the wrong place.
  local aPostProvided = postProvidedSkills(room, a.player, positions[a.player], aSide.owned)
  local aPostAttachable = postAttachableSkills(room, a.player, positions[a.player])
  local bPostProvided = postProvidedSkills(room, b.player, positions[b.player], bSide.owned)
  local bPostAttachable = postAttachableSkills(room, b.player, positions[b.player])
  syncSkills(room, a.player, aSide.attachable, aPostProvided, aPostAttachable)
  syncSkills(room, b.player, bSide.attachable, bPostProvided, bPostAttachable)

  -- 4. Named private piles move with the card after the new skills are in
  -- place (never for a same-player swap).
  transferPiles(room, a.player, b.player, aSide, samePlayer)
  transferPiles(room, b.player, a.player, bSide, samePlayer)

  -- 5. Skill-owned marks (switch/quest/custom) follow the card.
  transferMarks(room, aSide, bSide, aStillProvides, bStillProvides, samePlayer)

  for _, player in ipairs({ a.player, b.player }) do
    room:updateAllLimitSkillUI(player)
    player:filterHandcards()
  end

  local context = {
    room = room,
    options = options,
    same_player = samePlayer,
    sides = {
      {
        player = a.player, isDeputy = a.isDeputy,
        previous = aSide.general, general = bSide.general,
      },
      {
        player = b.player, isDeputy = b.isDeputy,
        previous = bSide.general, general = aSide.general,
      },
    },
    moved = {
      {
        from = { player = a.player, isDeputy = a.isDeputy },
        to = { player = b.player, isDeputy = b.isDeputy },
        general = aSide.general,
        soldier = M.isSoldier(aSide.general),
        white_soldier = M.isWhiteSoldier(aSide.general),
        retinue = M.soldierKind(aSide.general) == "retinue",
      },
      {
        from = { player = b.player, isDeputy = b.isDeputy },
        to = { player = a.player, isDeputy = a.isDeputy },
        general = bSide.general,
        soldier = M.isSoldier(bSide.general),
        white_soldier = M.isWhiteSoldier(bSide.general),
        retinue = M.soldierKind(bSide.general) == "retinue",
      },
    },
    -- White soldiers arriving at a position are treated as obtained there.
    -- The commander/retinue module converts them for the receiving position.
    obtained_soldiers = {},
  }

  for _, move in ipairs(context.moved) do
    if move.white_soldier then
      table.insert(context.obtained_soldiers, {
        player = move.to.player,
        isDeputy = move.to.isDeputy,
        general = move.general,
        from_player = move.from.player,
        from_isDeputy = move.from.isDeputy,
        same_player = samePlayer,
      })
    end
  end

  room:sendLog {
    type = "#HanjinGeneralExchange",
    from = a.player.id,
    to = { b.player.id },
    arg = aSide.general,
    arg2 = bSide.general,
  }

  -- Both sides are fully updated before the completion entry point runs.
  notifyCompletion(room, context)
  return context
end

Fk:loadTranslationTable {
  ["#HanjinGeneralExchange"] = "%from 与 %to 交换了武将 %arg 与 %arg2",
}

return M
