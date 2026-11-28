local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local SkillEffects = require "packages.qiao.pkg.qiao_mode.ai.skill_effects"
local Vine = require "packages.qiao.pkg.qiao_cards.skills.vine"
local Zouyu = require "packages.qiao.pkg.qiao_cards.skills.zouyu_fan"
local Qianxi = require "packages.qiao.pkg.qiao_generals.util.shu019_qianxi"
local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"

local M = {}

function M.ignoresArmor(source, card, use)
  return card.trueName == "slash" and ((use and use.extra_data and use.extra_data.qiao_skill_han010_1_ignore_armor)
    or table.find(SkillEffects.ignoreSlashArmor, function(name) return Cost.effectable(source, name) end) ~= nil)
end

function M.vineBlocks(source, card, target, use)
  return card.trueName == "slash" and Vine.nullifiesCard(card) and Cost.effectable(target, Vine.name)
    and not M.ignoresArmor(source, card, use)
end

local function forcedOrMoreResponses(source, target, use, ignoredSkill)
  if use and (use.disresponsive or use.unoffsetable
    or table.contains(use.disresponsiveList or {}, target) or table.contains(use.unoffsetableList or {}, target)) then
    return true, 1
  end
  if not use and table.contains(source:getTableMark("qiao_skill_han013_1_next_card-turn"), target.id) then
    return true, 1
  end
  local needed = 1
  for name, applies in pairs(SkillEffects.forceSlashHit) do
    if name ~= ignoredSkill and Cost.effectable(source, name) and applies(source, target) then
      if not SkillEffects.extraJink[name] then return true, 1 end
      needed = needed + 1
    end
  end
  return false, needed
end

function M.jinkArmor(source, card, target, use)
  if card.trueName ~= "slash" or M.ignoresArmor(source, card, use) then return end
  if Zouyu.isAvailable(target) and not target:prohibitUse(Fk:cloneCard("jink")) then return "zouyu" end
  if Cost.effectable(target, "qiao__eight_diagram_skill") and not target:prohibitUse(Fk:cloneCard("qiao__jink")) then
    return "eight_diagram"
  end
end

function M.hitFactor(source, card, target, use, ignoredSkill)
  local armor = M.jinkArmor(source, card, target, use)
  if not armor then return 1 end
  local forced, needed = forcedOrMoreResponses(source, target, use, ignoredSkill)
  if forced or needed > 1 then return 1 end
  if armor == "zouyu" then return 0.25 end
  for name in pairs(SkillEffects.retrial) do
    if Cost.effectable(source, name) then return 1 end
  end
  return 0.5
end

-- Use only public hand size and enabled conversion skills. Printed HanJin
-- Jink is red. These per-card estimates express uncertainty about unseen hands.
function M.handHitChance(source, card, target, use, extraColor, ignoredSkill)
  local hand = target:getHandcardNum()
  if card.trueName ~= "slash" or hand == 0 or target:getMark("@@command4_effect-turn") > 0 then return 1 end
  local forced, needed = forcedOrMoreResponses(source, target, use, ignoredSkill)
  if forced or hand < needed then return 1 end

  local red, black = 0.15, 0
  if BattleRoyal.inBattleRoyal(target.room, target) then red = red + 0.08 end
  if Cost.effectable(target, "qiao__skill_shu005_1") then red, black = red + 0.06, 0.12 end
  if Cost.effectable(target, "qiao__skill_wei007_1") then black = 0.4 end
  local blocked = Qianxi.colorsFor(target)
  if extraColor == Card.Red or table.contains(blocked, Card.Red) then red = 0 end
  if extraColor == Card.Black or table.contains(blocked, Card.Black) then black = 0 end
  local responds = red + black
  local term = (1 - responds) ^ hand
  local chance = term
  for count = 1, needed - 1 do
    term = term * (hand - count + 1) / count * responds / (1 - responds)
    chance = chance + term
  end
  return math.min(1, chance)
end

function M.hitChance(source, card, target, use, ignoredSkill)
  return M.hitFactor(source, card, target, use, ignoredSkill)
    * M.handHitChance(source, card, target, use, nil, ignoredSkill)
end

return M
