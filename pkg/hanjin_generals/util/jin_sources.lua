-- JIN010 扼绝：技能来源分类与单技能失去。
--
-- 将牌技能按“具体武将牌 + 技能”记录；非将牌技能按当前派生/附加来源移除。
-- 不把同名独立来源全部封死：若同名技能仍由另一张将牌或外部来源提供，记录该
-- 将牌已失去，但保留实际技能。实际移除复用 qun_duanchang 的单技能入口。
local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"
local Duanchang = require "packages.hanjin.pkg.hanjin_mode.rules.qun_duanchang"

local M = {}

M.SKILL = "hanjin__skill_jin010_2"

local function isLord(player)
  local room = player.room
  return player.role == "lord" and player.role_shown and room:isGameMode("role_mode")
end

local function excluded(skill, name)
  if name == nil or name == "" or name == M.SKILL then return true end
  if name:sub(1, 1) == "#" then return true end
  if skill == nil then return true end
  if skill.cardSkill or skill.attached_equip then return true end
  local skel = skill:getSkeleton()
  if skel ~= nil and (skel.attached_equip or tostring(skel.name):sub(1, 1) == "#") then
    return true
  end
  return false
end

local function addChoice(result, seen, skillName, general, deputy, source, extra)
  local skill = Fk.skills[skillName]
  if excluded(skill, skillName) then return end
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

--- 扼绝可选的当前实际技能。将牌技能按主/副将分别列出；非将牌技能保留来源。
---@param player ServerPlayer
---@return table[]
function M.choices(player)
  local result, seen = {}, {}
  local lord = isLord(player)
  for _, isDeputy in ipairs({ false, true }) do
    local name = Exchange.actualGeneral(player, isDeputy)
    if name ~= "" and name ~= "anjiang" and Fk.generals[name] then
      for _, skillName in ipairs(Exchange.positionSkills(name, isDeputy, lord, false)) do
        local skill = Fk.skills[skillName]
        if skill ~= nil and not Duanchang.isLost(player.room, name, skillName)
          and (player:hasSkill(skillName, true, true) or player:isFakeSkill(skill)) then
          addChoice(result, seen, skillName, name, isDeputy, nil)
        end
      end
    end
  end

  for _, skillName in ipairs(player:getTableMark("ExtraAttachedSkills")) do
    if player:hasSkill(skillName, true, true) then
      addChoice(result, seen, skillName, nil, nil, nil, true)
    end
  end
  for sourceSkill, skills in pairs(player.derivative_skills or {}) do
    for _, skill in ipairs(skills) do
      if player:hasSkill(skill.name, true, true) then
        addChoice(result, seen, skill.name, nil, nil, sourceSkill)
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
  if room == nil or player == nil or choice == nil then return false end
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
