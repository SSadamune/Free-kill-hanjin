-- JIN010 扼绝：技能来源分类与单技能失去。
--
-- 武将牌和翼从实例分别记录失技；角色独立获授的技能按当前来源移除。
-- 不把同名独立来源全部封死：若同名技能仍由另一张将牌或外部来源提供，记录该
-- 将牌已失去，但保留实际技能。实际移除复用 qun_duanchang 的单技能入口。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Duanchang = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"
local CardSkills = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local SkillSources = require "packages.qiao.pkg.qiao_mode.rules.skill_sources"
local SameName = require "packages.qiao.pkg.qiao_mode.rules.same_name_skills"
local Retinues = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local M = {}

M.SKILL = "qiao__skill_jin010_2"

local function isLord(player)
  local room = player.room
  return player.role == "lord" and player.role_shown and room:isGameMode("role_mode")
end

local function canLose(player, name)
  return SameName.canonicalHistoryKey(name) ~= M.SKILL
    and SkillSources.isGeneralSkill(Fk.skills[name], player)
end

--- 扼绝可选的武将技能，按武将牌位置、翼从实例或角色授予来源分别列出。
---@param player ServerPlayer
---@return table[]
function M.choices(player)
  local result, seen = {}, {}
  local function addChoice(skillName, general, deputy, source, extra)
    if not canLose(player, skillName) then return end
    local key = table.concat({ skillName, general or "", tostring(deputy or ""),
      source and source.name or "", extra and "extra" or "" }, "|")
    if seen[key] then return end
    seen[key] = true
    table.insert(result, {
      skill = skillName,
      general = general,
      deputy = deputy,
      source = source,
      extra = extra == true,
    })
  end
  local lord = isLord(player)
  for _, isDeputy in ipairs({ false, true }) do
    local name = Exchange.actualGeneral(player, isDeputy)
    if name ~= "" and name ~= "anjiang" and Fk.generals[name] and not Exchange.isSoldier(name) then
      for _, skillName in ipairs(Exchange.positionSkills(name, isDeputy, lord, false)) do
        local skill = Fk.skills[skillName]
        if skill ~= nil and not Duanchang.isLost(player.room, name, skillName)
          and (player:hasSkill(skillName, true, true) or player:isFakeSkill(skill)) then
          addChoice(skillName, name, isDeputy)
        end
      end
    end
  end

  for _, instance in ipairs(Retinues.instances(player)) do
    if not instance.skillLost and canLose(player, instance.skill) and player:hasSkill(instance.skill, true, true) then
      table.insert(result, {
        skill = instance.skill,
        retinueId = instance.id,
        retinuePosition = instance.position,
      })
    end
  end

  for _, skillName in ipairs(player:getTableMark("ExtraAttachedSkills")) do
    if player:hasSkill(skillName, true, true) then
      addChoice(skillName, nil, nil, nil, true)
    end
  end
  for sourceSkill, skills in pairs(player.derivative_skills or {}) do
    if sourceSkill.name ~= CardSkills.SOURCE and sourceSkill.name ~= Retinues.SOURCE_SKILL then
      for _, skill in ipairs(skills) do
        if player:hasSkill(skill.name, true, true) then
          addChoice(skill.name, nil, nil, sourceSkill)
        end
      end
    end
  end
  return result
end

--- 失去选择项。将牌技能记录到该牌；非将牌技能按来源移除。
---@param room Room
---@param player ServerPlayer
---@param choice table
---@return boolean
function M.lose(room, player, choice)
  if not room or not player or not choice or not canLose(player, choice.skill) then return false end
  if choice.retinueId ~= nil then
    local instance = Retinues.get(player, choice.retinueId)
    return instance ~= nil and instance.skill == choice.skill
      and player:hasSkill(instance.skill, true, true) and Retinues.loseSkill(player, instance.id)
  end
  if choice.general ~= nil then
    return Duanchang.loseCardSkill(room, player, choice.deputy == true, choice.skill)
  end
  if choice.extra then
    room:removeTableMark(player, "ExtraAttachedSkills", choice.skill)
    -- 同名将牌/派生来源仍在时，只移除这份外部来源，不误删实际技能。
    if Exchange.skillOwner(player, choice.skill) ~= nil then return true end
  end
  if not player:hasSkill(choice.skill, true, true) then return true end
  room:handleAddLoseSkills(player, "-" .. choice.skill, choice.source, true, false)
  return true
end

return M
