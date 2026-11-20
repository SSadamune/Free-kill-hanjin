-- 同一实现可以由两张武将牌各提供一次。实例 ID 为引擎隔离历史和触发，
-- 将牌上的技能名及翻译仍使用原技能。
local Cards = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"

local M = {}
local instances = {}
local originals = {}
local effectPairs = {}
local historyKeys = {}
local canonicalKeys = {}
local scopes = setmetatable({}, { __mode = "k" })
local tracked = setmetatable({}, { __mode = "k" })
local primaryCards = setmetatable({}, { __mode = "k" })

function M.instanceName(name)
  return name .. "_second_source"
end

-- 原实现的查询可能捕获原技能名。仅在实例回调期间解释为实例本身。
local function installQueries()
  for _, method in ipairs({ "hasSkill", "hasShownSkill", "usedSkillTimes", "usedEffectTimes" }) do
    local original = Player[method]
    Player[method] = function(player, name, ...)
      local scope = scopes[coroutine.running()]
      if scope and scope.player == player and name == scope.name then
        name = scope.instance
      end
      return original(player, name, ...)
    end
  end
end

local function scoped(callback, name, instance, ownerIndex)
  return function(self, ...)
    local owner = select(ownerIndex, ...)
    if type(owner) ~= "table" or not owner.player_skills
      or not table.contains(owner.player_skills, Fk.skills[instance]) then return end
    local thread = coroutine.running()
    local old = scopes[thread]
    scopes[thread] = { player = owner, name = name, instance = instance }
    local ok, result = pcall(callback, self, ...)
    scopes[thread] = old
    if not ok then error(result, 0) end
    return result
  end
end

-- Active/ViewAs 和大部分状态技以第一个参数为角色；Filter 的牌过滤以第二个
-- 参数为角色。触发技的第三个参数是技能持有者，而非事件目标。
local statusOwner = {
  card_filter = 2, is_prohibited = 2,
  equip_skill_filter = 2, card_skill_filter = 2,
}
local ownedChecks = {
  can_use = true, enabled_at_play = true, enabled_at_response = true,
  enabled_at_nullification = true, can_trigger = true, can_refresh = true,
  can_wake = true, trigger_times = true,
}

local function registerInstance(original)
  local source = original:getSkeleton()
  if not source or #source.effect_spec_list == 0 then return end
  local name = source.name
  local id = M.instanceName(name)
  local alias = setmetatable(table.simpleClone(source), getmetatable(source))
  alias.name = id
  alias.effects, alias.effect_names, alias.effect_spec_list = {}, {}, {}
  alias.tests, alias.aux_spec_list = {}, {}
  if source.dynamicName then alias.dynamicName = function(_, ...) return source:dynamicName(...) end end
  if source.dynamicDesc then alias.dynamicDesc = function(_, ...) return source:dynamicDesc(...) end end
  -- 派生牌堆及全局/延时规则与原技能共享。
  alias.derived_piles = nil
  local sourceIndexes = {}
  for index, effect in ipairs(source.effect_spec_list) do
    local key, attr, spec = table.unpack(effect, 1, 3)
    if not (spec.global or spec.is_delay_effect or attr and attr.is_delay_effect) then
      local copy = table.simpleClone(spec)
      copy.derived_piles = nil
      local trigger = type(key) == "table"
      local status = not trigger and key ~= "active" and key ~= "viewas"
      for field, callback in pairs(spec) do
        if type(callback) == "function" and (status or ownedChecks[field]) then
          copy[field] = scoped(callback, name, id, trigger and 3 or status and (statusOwner[field] or 1) or 1)
        end
      end
      if trigger and not copy.can_trigger and (copy.on_trigger or copy.on_cost or copy.on_use) then
        copy.can_trigger = function(_, _, _, player) return player:hasSkill(id) end
      end
      table.insert(alias.effect_spec_list, { key, attr, copy })
      table.insert(sourceIndexes, index)
    end
  end
  if #alias.effect_spec_list == 0 then return end
  Fk:loadTranslationTable({ [id] = Fk:translate(name), [":" .. id] = Fk:translate(":" .. name) }, Config.language)
  Fk.skill_skels[id] = alias
  local skill = alias:createSkill()
  skill.package = original.package
  for _, effect in ipairs(skill.related_skills) do effect.package = original.package end
  Fk:addSkill(skill)
  instances[name] = id
  originals[id] = name
  local pairsOfKeys = { { name, id } }
  for index, originalIndex in ipairs(sourceIndexes) do
    table.insert(pairsOfKeys, { source.effect_names[originalIndex], alias.effect_names[index] })
  end
  effectPairs[name] = pairsOfKeys
  for _, keys in ipairs(pairsOfKeys) do
    local first, second = table.unpack(keys)
    historyKeys[first] = { root = name, second = second }
    canonicalKeys[second] = first
  end
end

function M.register()
  installQueries()
  local skills = {}
  for name, skill in pairs(Fk.skills) do
    if skill.visible and skill.package and skill.package.extensionName == "qiao"
      and skill:getSkeleton() and skill:getSkeleton().name == name
      and not skill:getSkeleton().attached_equip then
      table.insert(skills, skill)
    end
  end
  table.sort(skills, function(first, second) return first.name < second.name end)
  for _, skill in ipairs(skills) do registerInstance(skill) end
  local ServerPlayer = require "ltk.server.serverplayer"
  local playSound = ServerPlayer.broadcastSkillInvoke
  ServerPlayer.broadcastSkillInvoke = function(player, name, ...)
    return playSound(player, originals[name] or name, ...)
  end
end

local function position(player, deputy)
  local name = Exchange.actualGeneral(player, deputy)
  local skills = {}
  for _, root in ipairs(Exchange.positionSkills(name, deputy, false, false, player.room)) do
    if instances[root] and Exchange.cardProvidesSkill(player.room, name, root) then skills[root] = true end
  end
  return { name = name, shown = Exchange.isRevealed(player, deputy), skills = skills }
end

local function hasRealSkill(player, name)
  return table.contains(player.player_skills, Fk.skills[name])
end

function M.owner(player, name)
  if originals[name] then return (tracked[player] or {})[originals[name]] end
  if (tracked[player] or {})[name] then return (primaryCards[player] or {})[name] end
end

function M.canonicalHistoryKey(key)
  return canonicalKeys[key] or key
end

function M.historyKey(player, general, key)
  local pair = historyKeys[key]
  if pair and (tracked[player] or {})[pair.root] == general then return pair.second end
  return key
end

-- 原技能名留给仍明置的一份。更换占用原名的将牌时，计数随来源对调，
-- 复明后同一份技能仍保留此前的阶段、回合、轮次及整局使用记录。
local function swapHistory(player, root, id)
  local previous = {}
  for _, keys in ipairs(effectPairs[root]) do
    for _, key in ipairs(keys) do
      previous[key] = table.simpleClone(player.skillUsedHistory[key] or {})
    end
  end
  for _, keys in ipairs(effectPairs[root]) do
    local first, second = table.unpack(keys)
    for scope = Player.HistoryPhase, Player.HistoryGame do
      if previous[first][scope] or previous[second][scope] then
        player:setSkillUseHistory(first, previous[second][scope] or 0, scope)
        player:setSkillUseHistory(second, previous[first][scope] or 0, scope)
      end
    end
  end
  local counts = player.skillBranchUsedHistory
  local first = table.clone(counts[root] or {})
  local second = table.clone(counts[id] or {})
  local branches = {}
  for branch in pairs(first) do branches[branch] = true end
  for branch in pairs(second) do branches[branch] = true end
  for branch in pairs(branches) do
    for scope = Player.HistoryPhase, Player.HistoryGame do
      player:setSkillBranchUseHistory(root, branch, (second[branch] or {})[scope] or 0, scope)
      player:setSkillBranchUseHistory(id, branch, (first[branch] or {})[scope] or 0, scope)
    end
  end
end

local function sync(room)
  if not Modes.inRoom(room) or room:getTag("qiao_sync_same_name_skills") then return end
  room:setTag("qiao_sync_same_name_skills", true)
  local ok, err = pcall(function()
    local reassign = false
    for _, player in ipairs(room.alive_players) do
      local main, deputy = position(player, false), position(player, true)
      local prior = tracked[player] or {}
      local previousPrimary = primaryCards[player] or {}
      local nextSources, nextPrimary = {}, {}
      if deputy.shown then
        for root in pairs(deputy.skills) do nextPrimary[root] = deputy.name end
      end
      for root in pairs(main.skills) do
        if main.shown then nextPrimary[root] = main.name end
        if deputy.skills[root] then
          if main.shown or deputy.shown then
            local keepDeputy = deputy.shown and (not main.shown or previousPrimary[root] == deputy.name)
            nextSources[root] = keepDeputy and main.name or deputy.name
          end
        end
      end
      for root, source in pairs(prior) do
        if (main.name == source and main.skills[root]) or (deputy.name == source and deputy.skills[root]) then
          nextSources[root] = source
        end
      end
      local changes = {}
      for root, source in pairs(nextSources) do
        local id = instances[root]
        local first, second = main, deputy
        if main.name == source then first, second = deputy, main end
        local primary = first.shown and first.skills[root]
        local additional = second.shown and second.name == source and second.skills[root]
        if additional and not primary then
          swapHistory(player, root, id)
          nextSources[root] = first.skills[root] and first.name or nil
          first, primary, additional = second, true, false
          reassign = true
        end
        if primary then
          nextPrimary[root] = first.name
          if player:isFakeSkill(root) then
            player:prelightSkill(root, false)
            player:loseFakeSkill(root)
          end
          if not player:hasSkill(root, true, true) and not Cards.provides(room, first.name, root) then
            table.insert(changes, root)
          end
        end
        if additional and not hasRealSkill(player, id) then
          table.insert(changes, id)
        elseif not additional and hasRealSkill(player, id) then
          table.insert(changes, "-" .. id)
        end
      end
      for root in pairs(prior) do
        if not nextSources[root] and hasRealSkill(player, instances[root]) then
          table.insert(changes, "-" .. instances[root])
        end
      end
      tracked[player] = nextSources
      primaryCards[player] = nextPrimary
      if #changes > 0 then room:handleAddLoseSkills(player, changes, nil, false, true) end
    end
    if reassign then Cards.sync(room) end
  end)
  room:setTag("qiao_sync_same_name_skills", nil)
  if not ok then error(err, 0) end
end

Cards.addChangeListener(sync)
Cards.setPrimarySourceFilter(function(player, general, name)
  return not tracked[player] or tracked[player][name] ~= general
end)

return M
