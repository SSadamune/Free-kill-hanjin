-- EM(JIN001) 诸王敕封册
-- 首次双亮全局记账（无持旗者也记），持旗者在 GeneralRevealed 实际发动；
-- “赐”按持有者公开表标记保存，客户端可读取自身赐与分支可用性。
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local First = require "packages.qiao.pkg.qiao_generals.util.jin_first_reveal"

local skill = fk.CreateSkill { name = "qiao__skill_em_jin001_banner" }
skill.qiaoImplemented = true

local SHOWN_MARK = "qiao_jin001_first_double"
local USED_MARK = "qiao_jin001_change_used"

local function lord(room)
  if room == nil then return nil end
  for _, p in ipairs(room:getPresentPlayers()) do
    local kingdom = p.kingdom
    if kingdom ~= "jin" and p:getMark("__heg_kingdom") == "jin" then kingdom = "jin" end
    if not p.dead and not p:isRemoved() and kingdom == "jin"
      and p:hasShownSkill("qiao__skill_em_jin001_1")
      and p:hasSkill(skill.name) then
      return p
    end
  end
  return nil
end

local function affiliations(general)
  return general and Ban.affiliations(general) or {}
end

local function deputyName(target)
  local name = target.deputyGeneral
  if name == "anjiang" or name == nil or name == "" then
    name = target:getMark("__heg_deputy")
  end
  return type(name) == "string" and name or nil
end

local function ciList(holder)
  if holder == nil then return {} end
  return table.simpleClone(holder:getTableMark(skill.name))
end

local function saveCi(room, holder, list)
  room:setPlayerMark(holder, skill.name, #list > 0 and list or 0)
end

local function pickCi(room, holder, target)
  local name = deputyName(target)
  if name == nil or name:startsWith("blank_") or Commander.isSoldier(name) or Commander.isRetinue(name) then return end
  local deputy = Fk.generals[name]
  if deputy == nil then return end
  local kinds = affiliations(deputy)
  local candidates = {}
  for _, candidate in ipairs(room.general_pile or {}) do
    local general = Fk.generals[candidate]
    if general ~= nil and general.kingdom ~= "wild" and not Versions.is_lord(candidate)
      and not Commander.isSoldier(candidate) and not Commander.isRetinue(candidate)
      and not table.contains(room.disabled_generals or {}, candidate)
      and table.find(kinds, function(k) return table.contains(affiliations(general), k) end) then
      table.insert(candidates, candidate)
    end
  end
  if #candidates == 0 then return end
  local chosen
  if #candidates == 1 then
    chosen = candidates[1]
  else
    chosen = room:askToChoice(holder, {
      choices = candidates, skill_name = skill.name,
      prompt = "#qiao__jin001_banner-pick", cancelable = true,
    })
    if chosen == nil or not table.contains(candidates, chosen) then return end
  end
  table.removeOne(room.general_pile, chosen)
  local list = ciList(holder)
  list[#list + 1] = chosen
  saveCi(room, holder, list)
end

skill:addEffect(fk.GeneralRevealed, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil or not First.isFirst(event) then return false end
    return player == lord(target.room)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__jin001_banner-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local holder = lord(target.room)
    if holder ~= nil then pickCi(target.room, holder, target) end
  end,
})

skill:addEffect(fk.Death, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil then return false end
    local killer = data and data.killer
    if killer == nil or killer.dead or killer.kingdom ~= "jin" or killer == target then return false end
    return player == lord(target.room) and target:getMark("qiao_jin001_death_ci") == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__jin001_banner-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = target.room
    local holder = lord(room)
    if holder == nil then return end
    room:setPlayerMark(target, "qiao_jin001_death_ci", 1)
    pickCi(room, holder, target)
  end,
})

local function positionFish(name)
  local general = Fk.generals[name]
  return general and general.maxHp or nil
end

local function positionName(player, isDeputy)
  local name = isDeputy and player.deputyGeneral or player.general
  if name == "anjiang" or name == "" then
    name = player:getMark(isDeputy and "__heg_deputy" or "__heg_general")
  end
  return name
end

--- 只接受实际普通武将牌、同鱼数、非君主、未建安锁定的位置。
local function matchingPosition(room, player, fish)
  local result = {}
  local okWei, Wei = pcall(require, "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei")
  for _, isDeputy in ipairs({ false, true }) do
    local name = positionName(player, isDeputy)
    if type(name) == "string" and name ~= "" and name ~= "anjiang"
      and not Versions.is_lord(name) and not Commander.isSoldier(name) and not Commander.isRetinue(name)
      and Fk.generals[name] ~= nil and positionFish(name) == fish
      and not (okWei and Wei.isPositionRestricted and Wei.isPositionRestricted(room, player, isDeputy)) then
      result[#result + 1] = isDeputy
    end
  end
  return result
end

skill:addEffect("active", {
  prompt = "#qiao__jin001_banner-active",
  target_num = 0,
  card_num = 0,
  max_phase_use_time = 1,
  can_use = function(self, player)
    return player ~= nil and not player.dead and player.phase == Player.Play
      and #ciList(player) > 0 and player:hasSkill(skill.name)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local list = ciList(player)
    if #list == 0 then return end
    local chosen = list[1]
    if #list > 1 then
      chosen = room:askToChoice(player, {
        choices = list, skill_name = skill.name,
        prompt = "#qiao__jin001_banner-ci", cancelable = true,
      })
      if chosen == nil or not table.contains(list, chosen) then return end
    end
    local fish = positionFish(chosen)
    if fish == nil then return end
    local changePositions = matchingPosition(room, player, fish)
    local branches = { "resource" }
    if #changePositions > 0 and player:getMark(USED_MARK) == 0 then table.insert(branches, "change") end
    table.insert(branches, "Cancel")
    local branch = room:askToChoice(player, {
      choices = branches, skill_name = skill.name,
      prompt = "#qiao__jin001_banner-branch", cancelable = true,
    })
    if branch == "Cancel" then return end
    if branch == "change" then
      local isDeputy
      if #changePositions == 1 then
        isDeputy = changePositions[1]
      else
        local choice = room:askToChoice(player, {
          choices = { "main", "deputy" }, skill_name = skill.name,
          prompt = "#qiao__jin001_banner-position", cancelable = true,
        })
        if choice == "Cancel" then return end
        isDeputy = choice == "deputy"
        if not table.contains(changePositions, isDeputy) then return end
      end
      if not Change.change(room, player, isDeputy, { num = 3, skill_name = skill.name }) then return end
      room:setPlayerMark(player, USED_MARK, 1)
    else
      if fish <= 3 then
        room:addPlayerMark(player, MarkEnum.AddMaxCardsInTurn, 3)
      else
        local n = math.max(0, 4 - #player:getCardIds("h"))
        if n > 0 then player:drawCards(n, skill.name) end
      end
    end
    table.removeOne(list, chosen)
    saveCi(room, player, list)
    -- 消费后解除占用，赐将牌回到剩余池。
    if not table.contains(room.general_pile, chosen) then table.insert(room.general_pile, chosen) end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "诸王敕封册",
  [":" .. skill.name] = "当一名角色的武将牌首次均明置后，或被晋势力角色杀死后，你可以将一张符合其副将牌面势力的剩余武将牌置为“赐”。",
  ["#qiao__jin001_banner-invoke"] = "诸王敕封册：是否将一张剩余武将牌置为“赐”",
  ["#qiao__jin001_banner-pick"] = "诸王敕封册：选择一张剩余武将牌作为赐",
  ["#qiao__jin001_banner-active"] = "诸王敕封册：消耗一枚赐",
  ["#qiao__jin001_banner-ci"] = "诸王敕封册：选择一枚赐",
  ["#qiao__jin001_banner-branch"] = "诸王敕封册：选择资源效果或变更",
  ["#qiao__jin001_banner-position"] = "诸王敕封册：选择变更位置（main 主将 / deputy 副将）",
}

return skill
