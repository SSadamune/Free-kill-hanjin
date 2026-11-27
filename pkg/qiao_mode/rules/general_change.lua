-- 汉晋通用“变更武将”入口。已确认规则：同势力三候选、明置加入、不先亮旧暗将、
-- 不触发“明置武将牌后”、不重算体力；禁选/君主/野心家与客将按公开登记判断。
local M = {}

local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local CardState = require "packages.qiao.pkg.qiao_mode.rules.general_card_state"
local CardSkills = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Wei = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"

local completion_listeners = {}

function M.addCompletionListener(fn)
  assert(type(fn) == "function", "Change completion listener must be a function")
  table.insertIfNeed(completion_listeners, fn)
  return fn
end

local function notifyCompletion(room, context)
  for _, listener in ipairs(completion_listeners) do
    listener(room, context)
  end
end

local function kingdomOf(player)
  local kingdom = player:getMark("__heg_kingdom")
  if type(kingdom) ~= "string" or kingdom == "" or kingdom == "unknown" then
    kingdom = player.kingdom
  end
  if kingdom == "wild" and player:getMark("__heg_wild") ~= 1 then
    -- 优先用转野当时的归属。旧局未记录时沿用国战的初始归属回退。
    local departed = player.tag.qiao_departed_kingdom or player:getMark("__heg_init_kingdom")
    if Ban.isKnown(departed) then return departed end
  end
  return kingdom
end

local function positionName(player, isDeputy)
  if isDeputy then
    if player.deputyGeneral ~= "anjiang" and player.deputyGeneral ~= "" then return player.deputyGeneral end
    return player:getMark("__heg_deputy")
  end
  if player.general ~= "anjiang" then return player.general end
  return player:getMark("__heg_general")
end

--- 技能调用的可用武将牌堆（排除本局禁用、君主、天然野心家、士兵及指定排除名单）。
function M.skillAvailablePool(room, options)
  options = options or {}
  local disabled = room.disabled_generals or {}
  local exclude = options.exclude or {}
  local result = {}
  for _, name in ipairs(room.general_pile or {}) do
    local entry = Guest.factionsOf(room, name)
    if entry ~= nil and not entry.wild and not Versions.is_lord(name)
      and not Exchange.isSoldier(name)
      and not table.contains(disabled, name)
      and not table.contains(exclude, name)
      and not table.contains(result, name) then
      if options.any_kingdom then
        result[#result + 1] = name
      elseif type(options.kingdoms) == "table" then
        for _, k in ipairs(options.kingdoms) do
          if table.contains(entry.kingdoms, k) then
            result[#result + 1] = name
            break
          end
        end
      else
        result[#result + 1] = name
      end
      if options.limit and #result >= options.limit then break end
    end
  end
  return result
end

--- 合法候选：本局将池内同（牌面/客将）势力普通武将，排除当前主副将、君主版、
--- 天然野心家、禁用牌及重复。专属野心家变更普通副将时随机从可用将池取将。
function M.candidates(room, player, isDeputy, options)
  options = options or {}
  -- 君主武将牌不能被选择或实际变更，包括暗置的牌；该位置没有变更候选。
  if Exchange.isLordPosition(player, isDeputy) or Wei.isPositionRestricted(room, player, isDeputy) then return {} end
  local currentMain = positionName(player, false)
  local currentDeputy = positionName(player, true)
  local currentPos = isDeputy and currentDeputy or currentMain
  if options.require_general_card and (currentPos == nil or currentPos == "" or Exchange.isSoldier(currentPos)) then
    return {}
  end
  local exclude = table.simpleClone(options.exclude or {})
  if currentMain and currentMain ~= "" then table.insertIfNeed(exclude, currentMain) end
  if currentDeputy and currentDeputy ~= "" then table.insertIfNeed(exclude, currentDeputy) end
  local kingdoms = options.kingdoms
  -- 仅在未显式限定势力时，专属野心家变更普通副将才放宽至全可用将池；显式传入 kingdoms（如【焚心】额外备选）仍严格按指定势力筛选。
  local anyKingdom = options.any_kingdom == true
    or (kingdoms == nil and isDeputy and player:getMark("__heg_wild") == 1)
  if not anyKingdom and kingdoms == nil then
    kingdoms = { kingdomOf(player) }
  end
  return M.skillAvailablePool(room, {
    any_kingdom = anyKingdom,
    kingdoms = kingdoms,
    exclude = exclude,
  })
end

local function chooseCandidate(room, player, isDeputy, shown, options)
  options = options or {}
  local guestIllustrations = Guest.replacementEnabled(room)
  local guestFactions, commanderDetails = {}, {}
  for _, name in ipairs(shown) do
    if guestIllustrations and Guest.isGuest(room, name) then
      guestFactions[name] = Guest.guestKingdoms(name)
    end
    local spec = Commander.commanders[name]
    if spec then
      local retinues = table.filter(spec.retinues, function(id) return Commander.retinueAllowed(room, id) end)
      local text = Commander.describeSource(name, retinues)
      if Commander.limitedAbilityUsed(room, name) then
        text = text .. Fk:translate("qiao_change_general-commander-used")
      end
      commanderDetails[name] = text
    end
  end
  local partner = positionName(player, not isDeputy)
  local reply = room:askToCustomDialog(player, {
    skill_name = options.skill_name or "change_general",
    component = {
      url = "packages/qiao/pkg/qiao_mode/qml/GeneralChangeBox.qml",
      prop = {
        candidates = shown,
        cancelable = options.cancelable ~= false,
        actions = options.actions or {},
        prompt = options.prompt or "#qiao_change_general-choose",
        guestIllustrations = guestIllustrations,
        guestFactions = guestFactions,
        commanderDetails = commanderDetails,
        partner = Fk.generals[partner] and partner or "",
        isDeputy = isDeputy,
      },
    },
  })
  if type(reply) == "table" and type(reply.general) == "string" and table.contains(shown, reply.general) then
    if not options.actions or table.contains(options.actions, reply.action) then
      return reply.general, reply.action
    end
  end
  if options.cancelable == false then
    return shown[1], options.actions and options.actions[1]
  end
end

--- 复用变更选将面板，让玩家从给定武将牌列表中选择一张（带详情与珠联预览）。
function M.chooseGeneral(room, player, isDeputy, candidates, options)
  if type(candidates) ~= "table" or #candidates == 0 then return nil end
  return chooseCandidate(room, player, isDeputy == true, candidates, options)
end

--- 将指定位置直接变更为给定的合法武将牌（明置加入、不触发明置后、旧将入弃牌堆）。
function M.changeTo(room, player, isDeputy, chosen, options)
  options = options or {}
  isDeputy = isDeputy == true
  if player == nil or player.dead or player:isRemoved() then return false end
  if type(chosen) ~= "string" or Fk.generals[chosen] == nil then return false, "invalid_candidate" end
  if Versions.is_lord(chosen) or Exchange.isLordGeneral(chosen) then return false, "restricted_lord" end
  if Exchange.isLordPosition(player, isDeputy) then return false, "restricted_lord" end
  if Wei.isPositionRestricted(room, player, isDeputy) then return false, "restricted" end
  local oldName = positionName(player, isDeputy)
  if options.require_general_card and (oldName == nil or oldName == "" or Exchange.isSoldier(oldName)) then
    return false, "not_general_card"
  end
  if oldName ~= nil and oldName ~= "" then
    CardState.clearLeavingCardState(player, oldName, isDeputy)
  end
  local ok = room:changeHero(player, chosen, false, isDeputy, true, false, false)
  local newName = positionName(player, isDeputy)
  if ok == false or newName ~= chosen then return false, "change_failed" end
  room:setPlayerMark(player, isDeputy and "__heg_deputy" or "__heg_general", chosen)
  if oldName and oldName ~= "" and not Exchange.isSoldier(oldName) then
    Discard.add(room, { oldName })
  end
  if options.from_pile ~= false then
    while table.removeOne(room.general_pile, chosen) do end
  end
  if CardSkills and CardSkills.sync then CardSkills.sync(room) end
  notifyCompletion(room, {
    player = player,
    isDeputy = isDeputy,
    oldGeneral = oldName,
    newGeneral = chosen,
  })
  return true, chosen
end

--- 变更一个武将位置。支持通过 options.extra_kingdoms / options.extra_num 合并额外备选池。
---@return boolean, string?
function M.change(room, player, isDeputy, options)
  options = options or {}
  isDeputy = isDeputy == true
  if player == nil or player.dead or player:isRemoved() then return false end
  -- 先于候选、选将询问及任何离牌状态清理拒绝；君主牌所在位置不可变更。
  if Exchange.isLordPosition(player, isDeputy) then return false, "restricted_lord" end
  if Wei.isPositionRestricted(room, player, isDeputy) then
    return false, "restricted"
  end
  local oldName = positionName(player, isDeputy)
  if options.require_general_card and (oldName == nil or oldName == "" or Exchange.isSoldier(oldName)) then
    return false, "not_general_card"
  end
  local pool = M.candidates(room, player, isDeputy, options)
  local shown = {}
  if #pool > 0 then
    local num = math.min(options.num or 3, #pool)
    shown = room:tableRandomPick(pool, num)
  end
  local extraPool = {}
  if type(options.extra_kingdoms) == "table" and #options.extra_kingdoms > 0 then
    extraPool = M.candidates(room, player, isDeputy, {
      kingdoms = options.extra_kingdoms,
      exclude = table.connect(options.exclude or {}, shown),
      require_general_card = options.require_general_card,
    })
    local need = (options.extra_num or 3) - #extraPool
    if need > 0 and #shown > 0 then
      local eligible = M.candidates(room, player, isDeputy, { kingdoms = options.extra_kingdoms,
        exclude = options.exclude, require_general_card = options.require_general_card })
      local replacements = table.filter(pool, function(name)
        return not table.contains(shown, name) and not table.contains(eligible, name)
      end)
      for i, name in ipairs(shown) do
        if need <= 0 or #replacements == 0 then break end
        if table.contains(eligible, name) then
          local replacement = room:tableRandomPick(replacements, 1)[1]
          table.removeOne(replacements, replacement)
          shown[i] = replacement
          table.insert(extraPool, name)
          need = need - 1
        end
      end
    end
    if #extraPool > 0 then
      local extraNum = math.min(options.extra_num or 3, #extraPool)
      for _, name in ipairs(room:tableRandomPick(extraPool, extraNum)) do
        table.insertIfNeed(shown, name)
      end
    end
  end
  if #shown == 0 then return false, "no_candidate" end
  local display = table.simpleClone(options)
  display.cancelable = false
  local chosen = chooseCandidate(room, player, isDeputy, shown, display)
  if chosen == nil then return false, "cancel" end
  if player.dead or player:isRemoved() or positionName(player, isDeputy) ~= oldName then
    return false, "invalid_candidate"
  end
  local validNow = table.contains(M.candidates(room, player, isDeputy, options), chosen)
  if not validNow and type(options.extra_kingdoms) == "table" and #options.extra_kingdoms > 0 then
    validNow = table.contains(M.candidates(room, player, isDeputy, {
      kingdoms = options.extra_kingdoms,
      exclude = options.exclude,
      require_general_card = options.require_general_card,
    }), chosen)
  end
  if not validNow then
    return false, "invalid_candidate"
  end
  return M.changeTo(room, player, isDeputy, chosen, options)
end

function M.changeDeputy(room, player, options)
  return M.change(room, player, true, options)
end

--- 按第 14 项公共裁定定位“每技能每局限一次变更”的来源键：武将牌自带技能随武将牌记录。
function M.skillChangeSourceKey(room, holder, skillName)
  if holder ~= nil then
    for _, deputy in ipairs({ false, true }) do
      local general = Exchange.actualGeneral(holder, deputy)
      if Exchange.cardProvidesSkill(room, general, skillName) then
        return "qiao_skill_change_used:" .. skillName .. ":card:" .. general
      end
    end
    return "qiao_skill_change_used:" .. skillName .. ":player:" .. tostring(holder.id)
  end
  return "qiao_skill_change_used:" .. skillName
end

function M.canUseSkillChange(room, holder, skillName)
  return not room:getTag(M.skillChangeSourceKey(room, holder, skillName))
end

function M.markSkillChangeUsed(room, holder, skillName)
  room:setTag(M.skillChangeSourceKey(room, holder, skillName), true)
end

function M.unmarkSkillChangeUsed(room, holder, skillName)
  room:setTag(M.skillChangeSourceKey(room, holder, skillName), nil)
end

--- 公共入口：受“每技能每局限一次”约束的变更副将（先锁定发动时来源键，成功变更才消耗次数）。
function M.performSkillChangeDeputy(room, target, sourceHolder, skillName, options)
  if target == nil or target.dead or target:isRemoved() then return false end
  local key = M.skillChangeSourceKey(room, sourceHolder, skillName)
  if room:getTag(key) then return false, "used" end
  local opts = table.simpleClone(options or {})
  opts.skill_name = opts.skill_name or skillName
  local ok, result = M.changeDeputy(room, target, opts)
  if ok then room:setTag(key, true) end
  return ok, result
end

Fk:loadTranslationTable {
  ["#qiao_change_general-choose"] = "变更武将：选择一名同势力武将",
  ["qiao_change_general-commander"] = "统领能力",
  ["qiao_change_general-commander-used"] = "此限一统领能力本局已使用。",
  ["qiao_change_general-companion"] = "与保留的武将牌珠联璧合",
}

return M
