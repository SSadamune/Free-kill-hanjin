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

--- 合法候选：本局将池内同（牌面/客将）势力普通武将，排除当前主副将、君主版、
--- 天然野心家、禁用牌及重复。
function M.candidates(room, player, isDeputy)
  -- 君主武将牌不能被选择或实际变更，包括暗置的牌；该位置没有变更候选。
  if Exchange.isLordPosition(player, isDeputy) or Wei.isPositionRestricted(room, player, isDeputy) then return {} end
  local kingdom = kingdomOf(player)
  local currentMain = positionName(player, false)
  local currentDeputy = positionName(player, true)
  local disabled = room.disabled_generals or {}
  local result = {}
  for _, name in ipairs(room.general_pile or {}) do
    local entry = Guest.factionsOf(room, name)
    if entry ~= nil and not entry.wild and not Versions.is_lord(name)
      and not table.contains(disabled, name)
      and name ~= currentMain and name ~= currentDeputy
      and table.contains(entry.kingdoms, kingdom) and not table.contains(result, name) then
      result[#result + 1] = name
    end
  end
  return result
end

local function chooseCandidate(room, player, isDeputy, shown, options)
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
    return reply.general
  end
end

--- 变更一个武将位置。@return boolean, string?
function M.change(room, player, isDeputy, options)
  options = options or {}
  isDeputy = isDeputy == true
  if player == nil or player.dead or player:isRemoved() then return false end
  -- 先于候选、选将询问及任何离牌状态清理拒绝；君主牌所在位置不可变更。
  if Exchange.isLordPosition(player, isDeputy) then return false, "restricted_lord" end
  if Wei.isPositionRestricted(room, player, isDeputy) then
    return false, "restricted"
  end
  local pool = M.candidates(room, player, isDeputy)
  if #pool == 0 then return false, "no_candidate" end
  local num = math.min(options.num or 3, #pool)
  local shown = room:tableRandomPick(pool, num)
  if #shown == 0 then return false, "no_candidate" end
  local oldName = positionName(player, isDeputy)
  local chosen = chooseCandidate(room, player, isDeputy, shown, options)
  if chosen == nil then return false, "cancel" end
  if player.dead or player:isRemoved() or positionName(player, isDeputy) ~= oldName
    or not table.contains(M.candidates(room, player, isDeputy), chosen) then
    return false, "invalid_candidate"
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
  while table.removeOne(room.general_pile, chosen) do end
  if CardSkills and CardSkills.sync then CardSkills.sync(room) end
  return true, chosen
end

function M.changeDeputy(room, player, options)
  return M.change(room, player, true, options)
end

Fk:loadTranslationTable {
  ["#qiao_change_general-choose"] = "变更武将：选择一名同势力武将",
  ["qiao_change_general-commander"] = "统领能力",
  ["qiao_change_general-commander-used"] = "此限一统领能力本局已使用。",
  ["qiao_change_general-companion"] = "与保留的武将牌珠联璧合",
}

return M
