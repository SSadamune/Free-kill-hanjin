-- SPDX-License-Identifier: GPL-3.0-or-later
--
-- QUN012 断肠：死亡时令来源失去一张武将牌的技能（docs/rules/standard-generals.md、
-- rulebook/topics/skill-effect-classification.md）。
--
-- 本模块记录“某张武将牌不再提供其技能”并执行移除，不修改引擎：
--   * 记录按武将牌名保存在房间标签中，因此交换该牌后仍然有效；
--   * 只处理断肠选中的那张牌，另一张牌和后天独立来源的同名技能不动；
--   * 已明置的牌移除真实技能；暗置的牌移除对应 fake skill，后续明置由引擎的
--     “先授予再按 tolose 收回”流程自然保持失去，规则技能另做一次核对；
--   * 丢失记录通过 general_exchange 的技能来源过滤器生效，交换不会重新授回。
--
-- 锁定技与已建立的持续效果不需要特殊分支：移除技能不撤销已经写入角色/回合的
-- 延时效果（例如裸衣的回合标记），只由引擎清理技能自己的派生牌。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local CardSkills = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"

local M = {}

M.SKILL = "qiao__skill_qun012_2"
M.RULE_SKILL = "qiao__qun_duanchang_rule"
M.TAG = "qiao_duanchang_lost_v1"

local function isLord(player)
  local room = player.room
  return player.role == "lord" and player.role_shown and room:isGameMode("role_mode")
end

local function lostData(room, create)
  local data = room:getTag(M.TAG)
  if type(data) ~= "table" then
    if not create then return nil end
    data = {}
    room:setTag(M.TAG, data)
  end
  return data
end

--- 该武将牌已被断肠失去的全部技能名（含未实际移除、但已记录为失去的）。
---@param room Room
---@param generalName string
---@return table<string, boolean>?
function M.lostSkills(room, generalName)
  local data = lostData(room, false)
  local entry = data and data[generalName]
  return type(entry) == "table" and entry or nil
end

---@param room Room
---@param generalName string
---@param skillName string
---@return boolean
function M.isLost(room, generalName, skillName)
  local entry = M.lostSkills(room, generalName)
  return entry ~= nil and entry[skillName] == true
end

---@param room Room
---@param generalName string
---@param skillNames string[]
function M.markLost(room, generalName, skillNames)
  local data = lostData(room, true)
  local entry = data[generalName]
  if not entry then
    entry = {}
    data[generalName] = entry
  end
  for _, skillName in ipairs(skillNames) do
    entry[skillName] = true
  end
  room:setTag(M.TAG, data)
  local markers = require "packages.qiao.pkg.qiao_mode.rules.marker_cards"
  for _, name in ipairs(skillNames) do markers.endCard(room, generalName, name) end
  CardSkills.sync(room)
end

--- 一张将牌的全部印刷及后天附着技能（含主将技/副将技/related），不按当前位置过滤。
--- 断肠失去的是这张牌的技能：今天在错误位置不可用，换到正确位置后仍不得恢复。
---@param player ServerPlayer
---@param generalName string
---@return string[]
local function printedSkills(player, generalName)
  local general = Fk.generals[generalName]
  if not general then return {} end
  local result=general:getSkillNameList(isLord(player), true)
  for _,name in ipairs(CardSkills.skills(player.room,generalName)) do table.insertIfNeed(result,name) end
  return result
end

--- 一张将牌的印刷基础及后天附着技能（不含印刷 related）。related 随所属技能派生，不能单独
--- 作为恢复/授予目标，否则正常明置也可能被额外授技。
---@param player ServerPlayer
---@param generalName string
---@return string[]
local function baseSkills(player, generalName)
  local general = Fk.generals[generalName]
  if not general then return {} end
  local result=general:getSkillNameList(isLord(player), false)
  for _,name in ipairs(CardSkills.skills(player.room,generalName)) do table.insertIfNeed(result,name) end
  return result
end

--- 房间是否存在任意断肠失技记录。没有记录时规则完全旁路，不扫描正常明置。
---@param room Room
---@return boolean
local function roomHasLost(room)
  local data = lostData(room, false)
  return type(data) == "table" and next(data) ~= nil
end

--- 本次明置角色的主将或副将至少一张有断肠记录。
---@param room Room
---@param player ServerPlayer
---@return boolean
local function pairHasLost(room, player)
  for _, isDeputy in ipairs({ false, true }) do
    local name = Exchange.actualGeneral(player, isDeputy)
    if name ~= "" and name ~= "anjiang" and M.lostSkills(room, name) ~= nil then
      return true
    end
  end
  return false
end

local DISPLAY_MARK = "@@qiao_duanchang"
local DISPLAY_TAG = "qiao_duanchang_cards"
Fk:loadTranslationTable { [DISPLAY_MARK] = "断肠" }

CardSkills.addChangeListener(function(room)
  local affected = room:getTag(DISPLAY_TAG)
  if not affected then return end
  for _, player in ipairs(room.players) do
    local main = Exchange.actualGeneral(player, false)
    local deputy = Exchange.actualGeneral(player, true)
    local value = not player.dead and (affected[main] or affected[deputy]) and 1 or 0
    if player:getMark(DISPLAY_MARK) ~= value then room:setPlayerMark(player, DISPLAY_MARK, value) end
  end
end)

--- 只在“本角色双将有断肠记录”时，为与另一张将牌共享的同名基础技能计算明置
--- 恢复候选（引擎 revealGeneral 的 tolose 可能误删存活来源）。不处理 related，
--- 不为单牌独有技能或正常明置补授。
---@param room Room
---@param player ServerPlayer
---@param isDeputy boolean
---@param name string 刚明置的将牌
---@param lost table<string, boolean>? 该牌自己的断肠记录
---@return string[]
local function sharedRestoreSkills(room, player, isDeputy, name, lost)
  local result = {}
  local otherDeputy = not isDeputy
  local otherName
  if Exchange.hasPosition(player, otherDeputy) then
    otherName = Exchange.actualGeneral(player, otherDeputy)
  end
  if otherName == nil or otherName == "" or otherName == "anjiang" then return result end
  local otherPrinted = printedSkills(player, otherName)
  if #otherPrinted == 0 then return result end
  local otherLost = M.lostSkills(room, otherName)
  local otherValid = Exchange.positionSkills(otherName, otherDeputy, isLord(player), false)
  local selfValid = Exchange.positionSkills(name, isDeputy, isLord(player), false)
  for _, skillName in ipairs(baseSkills(player, name)) do
    if table.contains(otherPrinted, skillName)
      and not player:hasSkill(skillName, true, true) then
      -- 该同名技能只要还有一张牌未失去且位置有效，就应恢复；两张都失去则
      -- 没有存活来源，不补授。related 不在 baseSkills 内，不会单独恢复。
      local selfProvides = not (lost and lost[skillName])
        and table.contains(selfValid, skillName)
      local otherProvides = (otherLost == nil or not otherLost[skillName])
        and table.contains(otherValid, skillName)
      if selfProvides or otherProvides then
        table.insert(result, skillName)
      end
    end
  end
  return result
end

--- 一张牌在当前配置下可用的技能。位置条件由公共 positionSkills 过滤。
---@param player ServerPlayer
---@param generalName string
---@param isDeputy boolean
---@return string[]
local function cardSkills(player, generalName, isDeputy)
  return Exchange.positionSkills(generalName, isDeputy, isLord(player), true)
end

--- 除断肠选中的牌以外，仍提供这些技能名的真正独立来源：另一将的印刷技能
--- （该牌自身已断肠失去的技能不算）、外部附加技能、不属于选中牌的预亮技能，
--- 以及别的源技能派生技能。选中牌自己的预亮技能不是独立来源。
---@param room Room
---@param player ServerPlayer
---@param isDeputy boolean 被选中的牌位置
---@param cardName string 被选中的武将牌名
---@param printed string[] 被选中牌的印刷技能名
---@return string[]
local function otherProvided(room, player, isDeputy, cardName, printed)
  local result = {}
  local otherDeputy = not isDeputy
  local otherName
  local otherPrinted = {}
  local otherValid = {}
  if Exchange.hasPosition(player, otherDeputy) then
    otherName = Exchange.actualGeneral(player, otherDeputy)
    if otherName ~= "" and otherName ~= "anjiang" then
      otherPrinted = printedSkills(player, otherName)
      for _, skillName in ipairs(cardSkills(player, otherName, otherDeputy)) do
        if not M.isLost(room, otherName, skillName) then
          table.insertIfNeed(result, skillName)
          table.insertIfNeed(otherValid, skillName)
        end
      end
    end
  end
  for _, skill in ipairs(player.prelighted_skills or {}) do
    -- 预亮的 fake skill 只有在不属于被断肠的这张牌、也不属于另一将的印刷技能时
    -- 才是独立来源。属于另一将的预亮由上面的位置有效技能表处理；该牌自己已经
    -- 断肠失去的同名技能不能反过来保护。
    if not table.contains(printed, skill.name)
      and not table.contains(otherPrinted, skill.name) then
      table.insertIfNeed(result, skill.name)
    end
  end
  for _, skillName in ipairs(player:getTableMark("ExtraAttachedSkills")) do
    table.insertIfNeed(result, skillName)
  end
  local printedGeneral=Fk.generals[cardName]
  local innate=printedGeneral and printedGeneral:getSkillNameList(true) or {}
  for _,name in ipairs(CardSkills.skills(room,cardName)) do
    if not table.contains(innate,name) and table.contains(player.player_skills,Fk.skills[name]) then
      table.insertIfNeed(result,name)
    end
  end
  for sourceSkill, skills in pairs(player.derivative_skills) do
    if sourceSkill.name ~= CardSkills.SOURCE and sourceSkill.name ~= cardName and not table.contains(printed, sourceSkill.name) then
      for _, skill in ipairs(skills) do
        table.insertIfNeed(result, skill.name)
      end
    end
  end
  return result
end

--- 可复用的“单技能失去”入口：只把指定技能记录到指定武将牌。
--- 若同名技能还有另一张将牌/预亮/外部来源，记录该牌已失去，但不实际移除
--- 仍在生效的技能；否则移除当前实际持有的技能（暗置牌移除 fake skill）。
--- 原断肠的整牌失去仍使用自己的 applyLoss，不改其记录格式。
---@param room Room
---@param player ServerPlayer
---@param isDeputy boolean
---@param skillName string
---@return boolean lostRecorded
function M.loseCardSkill(room, player, isDeputy, skillName)
  if room == nil or player == nil or type(skillName) ~= "string" then return false end
  local cardName = Exchange.actualGeneral(player, isDeputy)
  if cardName == "" or cardName == "anjiang" then return false end
  local printed = printedSkills(player, cardName)
  if not table.contains(printed, skillName) then return false end
  if M.isLost(room, cardName, skillName) then return false end

  M.markLost(room, cardName, { skillName })
  local protected = otherProvided(room, player, isDeputy, cardName, printed)
  if table.contains(protected, skillName) then return true end

  local skill = Fk.skills[skillName]
  if skill == nil then return true end
  if not Exchange.isRevealed(player, isDeputy) and player:isFakeSkill(skill) then
    player:loseFakeSkill(skill)
  elseif player:hasSkill(skillName, true, true) then
    room:handleAddLoseSkills(player, "-" .. skillName, nil, true, false)
  end
  return true
end

--- 断肠可选的目标将牌。暗置牌只显示主将／副将位置，不暴露牌名。
---@param source ServerPlayer
---@return string[]
function M.choices(source)
  local result = {}
  for _, isDeputy in ipairs({ false, true }) do
    if Exchange.hasPosition(source, isDeputy) then
      local name = Exchange.actualGeneral(source, isDeputy)
      -- 印刷技能全为当前不可用位置技的牌也可选：失去记录按整张牌保存。
      if name ~= "" and name ~= "anjiang" and #printedSkills(source, name) > 0 then
        if Exchange.isRevealed(source, isDeputy) then
          table.insert(result, name)
        else
          table.insert(result, isDeputy and "deputyGeneral" or "mainGeneral")
        end
      end
    end
  end
  return result
end

--- 按位置应用失去。记录的是整张牌的印刷技能；实际移除只针对当前真正持有的
--- 技能。被另一来源提供的同名技能不实际移除，但仍记录为该牌已失去。
---@param room Room
---@param player ServerPlayer
---@param isDeputy boolean
---@param cardName string
---@param printed string[]
local function applyLoss(room, player, isDeputy, cardName, printed)
  local protected = otherProvided(room, player, isDeputy, cardName, printed)
  local revealed = Exchange.isRevealed(player, isDeputy)
  local toLose = {}
  for _, skillName in ipairs(printed) do
    if not table.contains(protected, skillName) then
      local skill = Fk.skills[skillName]
      if not revealed and skill and player:isFakeSkill(skill) then
        player:loseFakeSkill(skill)
      elseif player:hasSkill(skillName, true, true) then
        table.insert(toLose, skillName)
      end
    end
  end
  if #toLose > 0 then
    -- handleAddLoseSkills 会触发 EventLoseSkill 与骨架 onLose；这会把技能自己的
    -- 派生牌置入弃牌堆，符合“失去技能”的分类，而不会撤销已建立的延时效果。
    room:handleAddLoseSkills(player, "-" .. table.concat(toLose, "|-"), nil, true, false)
  end
end

--- 断肠是“死亡时”技能：暗置武将牌的 fake skill 不是活动技能，但按
-- rulebook/events/death.md 的例子，暗置的蔡文姬死亡时仍能发动断肠。已明置的
-- 牌仍走 hasSkill，尊重技能无效等公共状态。
---@param player ServerPlayer
---@return boolean
function M.ownerHasSkill(player)
  if player:hasSkill(M.SKILL, false, true) then return true end
  for _, isDeputy in ipairs({ false, true }) do
    if not Exchange.isRevealed(player, isDeputy) then
      local name = Exchange.actualGeneral(player, isDeputy)
      if name ~= "" and name ~= "anjiang"
        and table.contains(cardSkills(player, name, isDeputy), M.SKILL) then
        return true
      end
    end
  end
  return false
end

--- 是否应当触发：没有死亡来源或来源已死亡时按不可执行处理，不另选目标。
---@param player ServerPlayer
---@param data DeathData
---@return boolean
function M.canUse(player, data)
  local source = data and data.killer
  if source == nil or source.dead or source == player then return false end
  return #M.choices(source) > 0
end

--- 询问蔡文姬选择来源的一张将牌，并永久记录、应用失技。
---@param room Room
---@param player ServerPlayer 断肠的拥有者（已死亡）
---@param source ServerPlayer?
---@return boolean
function M.resolve(room, player, source)
  if source == nil or source.dead then return false end
  local choices = M.choices(source)
  if #choices == 0 then return false end

  local choice = room:askToChoice(player, {
    choices = choices,
    skill_name = M.SKILL,
    prompt = "#" .. M.SKILL .. "-ask::" .. source.id,
    cancelable = false,
  })

  local isDeputy
  if choice == "mainGeneral" then
    isDeputy = false
  elseif choice == "deputyGeneral" then
    isDeputy = true
  elseif Exchange.isRevealed(source, false) and choice == Exchange.publicGeneral(source, false) then
    isDeputy = false
  elseif Exchange.isRevealed(source, true) and choice == Exchange.publicGeneral(source, true) then
    isDeputy = true
  else
    return false
  end

  local cardName = Exchange.actualGeneral(source, isDeputy)
  if cardName == "" or cardName == "anjiang" then return false end
  local printed = printedSkills(source, cardName)
  if #printed == 0 then return false end

  local affected = room:getTag(DISPLAY_TAG) or {}
  affected[cardName] = true
  room:setTag(DISPLAY_TAG, affected)
  M.markLost(room, cardName, printed)
  applyLoss(room, source, isDeputy, cardName, printed)
  return true
end

--- 明置时是否需要核对。房间没有任何断肠记录、或本次角色双将都没有记录时
--- 立即返回 false，正常明置路径完全不进入本规则。
---@param room Room
---@param player ServerPlayer
---@param data ShowGeneralData
---@return boolean
function M.shownHasLost(room, player, data)
  if not roomHasLost(room) or not pairHasLost(room, player) then return false end
  for _, isDeputy in ipairs({ false, true }) do
    local name = data and data[isDeputy and "d" or "m"]
    if type(name) == "string" then
      local printed = printedSkills(player, name)
      local lost = M.lostSkills(room, name)
      if lost ~= nil then
        local protected = otherProvided(room, player, isDeputy, name, printed)
        for _, skillName in ipairs(printed) do
          if lost[skillName] and not table.contains(protected, skillName)
            and player:hasSkill(skillName, true, true) then
            return true
          end
        end
      end
      if #sharedRestoreSkills(room, player, isDeputy, name, lost) > 0 then
        return true
      end
    end
  end
  return false
end

--- 规则技能在明置时核对一次，且只在房间已有断肠记录、本角色双将至少一张有
--- 记录时进入：
---   1. 被断肠记录的牌即使走到重新授予的路径，也再次收回其仍在生效的记录技能；
---   2. 只为与另一张将牌共享的同名基础技能补回被引擎 tolose 误删的存活来源。
---@param player ServerPlayer
---@param data ShowGeneralData
function M.enforceShown(player, data)
  local room = player.room
  if not roomHasLost(room) or not pairHasLost(room, player) then return end
  for _, isDeputy in ipairs({ false, true }) do
    local name = data and data[isDeputy and "d" or "m"]
    if type(name) == "string" then
      local printed = printedSkills(player, name)
      local lost = M.lostSkills(room, name)
      if lost ~= nil then
        local protected = otherProvided(room, player, isDeputy, name, printed)
        local toLose = {}
        for _, skillName in ipairs(printed) do
          if lost[skillName] and not table.contains(protected, skillName)
            and player:hasSkill(skillName, true, true) then
            table.insert(toLose, skillName)
          end
        end
        if #toLose > 0 then
          room:handleAddLoseSkills(player, "-" .. table.concat(toLose, "|-"), nil, true, false)
        end
      end
      for _, skillName in ipairs(sharedRestoreSkills(room, player, isDeputy, name, lost)) do
        room:handleAddLoseSkills(player, skillName, nil, true, false)
      end
    end
  end
end

-- 交换、替换或其他重新授技路径通过该过滤器尊重断肠的永久失技记录。
Exchange.registerSkillProviderFilter(function(room, generalName, skillName)
  return not M.isLost(room, generalName, skillName)
end)

return M
