-- 在查询期间排除代价武将牌提供的技能。实际移将仍使用国战移将入口。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local CardSkills = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local SameName = require "packages.qiao.pkg.qiao_mode.rules.same_name_skills"

local M = {}

local function rootName(skill)
  local skeleton = skill and skill:getSkeleton()
  return skeleton and skeleton.name or (skill and skill.name)
end

local function positionSkills(room, player, deputy)
  local names = {}
  if not Exchange.isRevealed(player, deputy) then return names end
  local general = Exchange.actualGeneral(player, deputy)
  for _, name in ipairs(Exchange.positionSkills(general, deputy, false, true, room)) do
    if Exchange.cardProvidesSkill(room, general, name) then
      names[SameName.historyKey(player, general, name)] = true
    end
  end
  return names
end

function M.excludedSkills(room, player, deputy)
  local departing = positionSkills(room, player, deputy)
  local remaining = positionSkills(room, player, not deputy)
  local roots = {}
  for name in pairs(departing) do
    if not remaining[name] then roots[name] = true end
  end
  -- 另有同名来源时，引擎保留由它提供的技能。仅撤销随原来源离开的派生技能。
  local lost = table.simpleClone(roots)
  for source, skills in pairs(player.derivative_skills) do
    if roots[rootName(source)] then
      for _, skill in ipairs(skills) do
        local name = rootName(skill)
        if name and not remaining[name] and not table.contains(player.player_skills, Fk.skills[name]) then
          lost[name] = true
        end
      end
    end
  end
  for source, skills in pairs(player.derivative_skills) do
    local sourceName = rootName(source)
    if sourceName ~= CardSkills.SOURCE and not roots[sourceName] then
      for _, skill in ipairs(skills) do
        local name = rootName(skill)
        if name and sourceName ~= name then lost[name] = nil end
      end
    end
  end
  local result = {}
  for name in pairs(lost) do
    -- 隐藏位置与当前未公开的技能不写入客户端摘要。
    if player:hasShownSkill(name, true, true) then table.insert(result, name) end
  end
  table.sort(result)
  return result
end

function M.checkWithout(player, names, check)
  if #names == 0 then return check() end
  local previous, hasSkill = rawget(player, "hasSkill"), player.hasSkill
  player.hasSkill = function(self, value, ...)
    local name = type(value) == "string" and SameName.querySkillName(self, value) or rootName(value)
    local root = rootName(Fk.skills[name]) or name
    if table.contains(names, root) then return false end
    return hasSkill(self, value, ...)
  end
  local ok, result = pcall(check)
  player.hasSkill = previous
  if not ok then error(result, 0) end
  return result
end

return M
