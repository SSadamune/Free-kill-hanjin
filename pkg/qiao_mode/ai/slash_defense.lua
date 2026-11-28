local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local SkillEffects = require "packages.qiao.pkg.qiao_mode.ai.skill_effects"
local Vine = require "packages.qiao.pkg.qiao_cards.skills.vine"
local Zouyu = require "packages.qiao.pkg.qiao_cards.skills.zouyu_fan"

local M = {}

function M.ignoresArmor(source, card, use)
  return card.trueName == "slash" and ((use and use.extra_data and use.extra_data.qiao_skill_han010_1_ignore_armor)
    or table.find(SkillEffects.ignoreSlashArmor, function(name) return Cost.effectable(source, name) end) ~= nil)
end

function M.vineBlocks(source, card, target, use)
  return card.trueName == "slash" and Vine.nullifiesCard(card) and Cost.effectable(target, Vine.name)
    and not M.ignoresArmor(source, card, use)
end

local function forcesHit(source, target, use)
  if use and (use.disresponsive or use.unoffsetable
    or table.contains(use.disresponsiveList or {}, target) or table.contains(use.unoffsetableList or {}, target)) then
    return true
  end
  for name, applies in pairs(SkillEffects.forceSlashHit) do
    if Cost.effectable(source, name) and applies(source, target) then return true end
  end
  return false
end

function M.jinkArmor(source, card, target, use)
  if card.trueName ~= "slash" or M.ignoresArmor(source, card, use) then return end
  if Zouyu.isAvailable(target) and not target:prohibitUse(Fk:cloneCard("jink")) then return "zouyu" end
  if Cost.effectable(target, "qiao__eight_diagram_skill") and not target:prohibitUse(Fk:cloneCard("qiao__jink")) then
    return "eight_diagram"
  end
end

function M.penalty(source, card, target, use)
  local armor = M.jinkArmor(source, card, target, use)
  if not armor or forcesHit(source, target, use) then return 0 end
  if armor == "zouyu" then return 3 end
  for name in pairs(SkillEffects.retrial) do
    if Cost.effectable(source, name) then return 0 end
  end
  return 2
end

return M
