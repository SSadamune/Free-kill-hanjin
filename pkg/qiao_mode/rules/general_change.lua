-- 汉晋通用“变更武将”入口。已确认规则：同势力三候选、明置加入、不先亮旧暗将、
-- 不触发“明置武将牌后”、不重算体力；禁选/君主/野心家与客将按公开登记判断。
local M = {}

local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local CardState = require "packages.qiao.pkg.qiao_mode.rules.general_card_state"
local CardSkills = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local function kingdomOf(player)
  local kingdom = player:getMark("__heg_kingdom")
  if type(kingdom) == "string" and kingdom ~= "" and kingdom ~= "unknown" then return kingdom end
  return player.kingdom
end

local function positionName(player, isDeputy)
  if isDeputy then
    if player.deputyGeneral ~= "anjiang" and player.deputyGeneral ~= "" then return player.deputyGeneral end
    return player:getMark("__heg_deputy")
  end
  if player.general ~= "anjiang" then return player.general end
  return player:getMark("__heg_general")
end

local function hasAffiliation(general, kingdom)
  for _, k in ipairs(Ban.affiliations(general)) do
    if k == kingdom then return true end
  end
  return false
end

--- 合法候选：本局将池内同（牌面/客将）势力普通武将，排除当前主副将、君主版、
--- 天然野心家、禁用牌及重复。
function M.candidates(room, player, isDeputy)
  -- 君主武将牌不能被选择或实际变更，包括暗置的牌；该位置没有变更候选。
  if Exchange.isLordPosition(player, isDeputy) then return {} end
  local kingdom = kingdomOf(player)
  local currentMain = positionName(player, false)
  local currentDeputy = positionName(player, true)
  local disabled = room.disabled_generals or {}
  local result = {}
  for _, name in ipairs(room.general_pile or {}) do
    local general = Fk.generals[name]
    if general ~= nil and general.kingdom ~= "wild" and not Versions.is_lord(name)
      and not table.contains(disabled, name)
      and name ~= currentMain and name ~= currentDeputy
      and hasAffiliation(general, kingdom) and not table.contains(result, name) then
      result[#result + 1] = name
    end
  end
  return result
end

--- 变更一个武将位置。@return boolean, string?
function M.change(room, player, isDeputy, options)
  options = options or {}
  if player == nil or player.dead or player:isRemoved() then return false end
  -- 先于候选、选将询问及任何离牌状态清理拒绝；君主牌所在位置不可变更。
  if Exchange.isLordPosition(player, isDeputy == true) then return false, "restricted_lord" end
  local okWei, Wei = pcall(require, "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei")
  if okWei and Wei.isPositionRestricted and Wei.isPositionRestricted(room, player, isDeputy == true) then
    return false, "restricted"
  end
  local pool = M.candidates(room, player, isDeputy == true)
  if #pool == 0 then return false, "no_candidate" end
  local num = math.min(options.num or 3, #pool)
  local shown = room:tableRandomPick(pool, num)
  local chosen
  if #shown == 1 then
    chosen = shown[1]
  else
    chosen = room:askToChoice(player, {
      choices = shown,
      skill_name = options.skill_name or "change_general",
      prompt = options.prompt or "#qiao_change_general-choose",
      cancelable = true,
    })
  end
  if chosen == nil or chosen == "Cancel" or not table.contains(shown, chosen) then
    return false, "cancel"
  end
  local oldName = positionName(player, isDeputy == true)
  if oldName ~= nil and oldName ~= "" then
    CardState.clearLeavingCardState(player, oldName, isDeputy == true)
  end
  local ok = room:changeHero(player, chosen, false, isDeputy == true, true, false, false)
  local newName = positionName(player, isDeputy == true)
  if ok == false or newName ~= chosen then return false, "change_failed" end
  room:setPlayerMark(player, isDeputy and "__heg_deputy" or "__heg_general", chosen)
  if oldName ~= nil and oldName ~= "" and not table.contains(room.general_pile, oldName) then
    table.insert(room.general_pile, oldName)
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
}

return M
