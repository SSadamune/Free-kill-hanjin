local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Cuipo = require "packages.qiao.pkg.qiao_generals.util.cuipo"

local M = {}

local damage = {
  qiao__slash = true, qiao__fire__slash = true, qiao__thunder__slash = true,
  qiao__ice__slash = true, qiao__unexpectation = true, qiao__duel = true,
  qiao__drowning = true, qiao__fire_attack = true,
}
local removal = {
  qiao__dismantlement = true, qiao__snatch = true, qiao__chasing_near = true,
}
local enemyPhase = { qiao__indulgence = true, qiao__supply_shortage = true }
local enemyGroup = {
  qiao__archery_attack = true, qiao__savage_assault = true, qiao__burning_camps = true,
}
local selfBenefit = { qiao__foresight = 100, qiao__strengthen_state = 100, qiao__peach = 95 }

function M.safeDamage(ai, card, target, use, source)
  if not ai:isEnemy(target) then return false end
  local nature = Damage.cardNature(card, use)
  if not target.chained or not Fk:canChain(nature) then return true end
  source = source or ai.player
  local amount = Damage.cardAmount(card, use, source)
  local ignoreTargetArmor = not use and card.trueName == "slash" and Cost.effectable(source, "#qinggang_sword_skill")
  return Damage.worth(Damage.assess(ai, target, amount, nature, { ignoreTargetArmor = ignoreTargetArmor }))
end

function M.isHarmful(card)
  local name = card.name
  return damage[name] or removal[name] or enemyPhase[name] or enemyGroup[name] or name == "qiao__collateral"
end

function M.scoreTarget(ai, card, target, use)
  local name = card.name
  if damage[name] or enemyGroup[name] then
    if M.safeDamage(ai, card, target, use) then return ai:hostileScore(target, 20 - target.hp) end
  elseif removal[name] then
    if ai:isEnemy(target) and not target:isNude() then
      local obtains = name == "qiao__snatch"
        or (name == "qiao__chasing_near" and ai.player:distanceTo(target) == 1)
      local tactical = (obtains and 8 or 0) + 2 * #target:getCardIds("e") + target:getHandcardNum()
      return ai:hostileScore(target, tactical)
    end
  elseif enemyPhase[name] then
    return ai:hostileScore(target, target:getHandcardNum())
  elseif name == "qiao__restore_heartland" then
    if ai:isFriend(target) then return target == ai.player and 1 or 2 end
  elseif name == "qiao__iron_chain" then
    if target.chained and ai:isFriend(target) then return 20 - target.hp end
  end
end

local function hasSlashTarget(ai)
  return table.find(ai:getEnabledCards("slash"), function(id)
    local card = Fk:getCardById(id)
    return table.find(card:getAvailableTargets(ai.player, ai.handler.extra_data), function(target)
      return M.safeDamage(ai, card, target)
    end) ~= nil
  end) ~= nil
end

local function fireSuits(ai, card)
  local suits = {}
  for _, id in ipairs(ai.player:getCardIds("h")) do
    local material = Fk:getCardById(id)
    if id ~= card.id and material.suit ~= Card.NoSuit and Cost.value(ai, id) <= 2
      and not ai.player:prohibitDiscard(id) then
      table.insertIfNeed(suits, material.suit)
    end
  end
  return #suits
end

local function emptySlot(player, card)
  if card.name == "qiao__linxiao_yuyu" or card.name == "qiao__liulongcanjia" then
    return player:hasEmptyEquipSlot(Card.SubtypeOffensiveRide)
      and player:hasEmptyEquipSlot(Card.SubtypeDefensiveRide)
  end
  return player:hasEmptyEquipSlot(card.sub_type)
end

local function physicalReply(ai)
  return { card = ai:getSelectedCard().id, targets = table.map(ai:getSelectedTargets(), Util.IdMapper) }
end

function M.bestCandidate(ai, candidates, score)
  local best, bestScore
  for _, target in ipairs(candidates) do
    local value = score(target)
    if value then value = ai:supportScore(target, value) end
    if value and (not bestScore or value > bestScore
      or (value == bestScore and target.seat < best.seat)) then
      best, bestScore = target, value
    end
  end
  return best
end

function M.bestTarget(ai, score)
  return M.bestCandidate(ai, ai:getEnabledTargets(), score)
end

-- Let the real request handler enforce target restrictions and feasibility.
-- Single-target plays stop there. Support plays may also take additional legal targets.
local function selectTargets(ai, score, extend)
  while extend or not ai:okButtonEnabled() do
    local target = M.bestTarget(ai, score)
    if not target then break end
    ai:selectTarget(target, true)
  end
  if ai:okButtonEnabled() and table.every(ai:getSelectedTargets(), function(target) return score(target) ~= nil end) then
    return physicalReply(ai)
  end
end

local function hurt(ai, card)
  local score = function(target) return M.scoreTarget(ai, card, target) end
  local fixed = card:getFixedTargets(ai.player, ai.handler.extra_data)
  if fixed then
    if #fixed > 0 and table.every(fixed, function(p) return score(p) ~= nil end) then
      return selectTargets(ai, score)
    end
    return
  end
  return selectTargets(ai, score)
end

function M.playEnemySlash(ai)
  for _, id in ipairs(ai:getEnabledCards("slash")) do
    local card = Fk:getCardById(id)
    ai:selectCard(id, true)
    local reply = hurt(ai, card)
    if reply then return reply end
    ai:selectCard(id, false)
  end
end

function M.respond(ai, pattern)
  local enabled = ai:getEnabledCards(pattern)
  table.sort(enabled)
  for _, id in ipairs(enabled) do
    ai:selectCard(id, true)
    if not ai:getSelectedSkill() and ai:okButtonEnabled() then return physicalReply(ai) end
    ai:selectCard(id, false)
  end
end

local function fixedGroup(ai, card, safe, useful)
  local targets = card:getAvailableTargets(ai.player, ai.handler.extra_data)
  if table.every(targets, safe) and table.find(targets, useful) and ai:okButtonEnabled() then
    return physicalReply(ai)
  end
end

function M.groupOutcome(ai, card)
  local targets = card:getAvailableTargets(ai.player, ai.handler.extra_data)
  return Damage.group(ai, card, targets)
end

local function playSelected(ai, card)
  local name = card.name
  if selfBenefit[name] or name == "qiao__analeptic" or card.type == Card.TypeEquip then
    if ai:okButtonEnabled() then return physicalReply(ai) end
  elseif damage[name] then
    return hurt(ai, card)
  elseif removal[name] or enemyPhase[name] then
    return selectTargets(ai, function(target) return M.scoreTarget(ai, card, target) end)
  elseif enemyGroup[name] then
    if Damage.worth(M.groupOutcome(ai, card)) and ai:okButtonEnabled() then return physicalReply(ai) end
  elseif name == "qiao__god_salvation" then
    local woundedFriend = function(target) return target:isWounded() and ai:isFriend(target) end
    return fixedGroup(ai, card, function(target)
      return not target:isWounded() or ai:isFriend(target)
    end, woundedFriend)
  elseif name == "qiao__restore_heartland" or name == "qiao__iron_chain" then
    return selectTargets(ai, function(target) return M.scoreTarget(ai, card, target) end, true)
  elseif name == "qiao__befriend_attacking" then
    return selectTargets(ai, function(target)
      if ai:isEnemy(target) then return 10 * ai:attitude(target) + 0.1 * target.hp end
    end)
  elseif name == "qiao__collateral" then
    -- Both the weapon holder and any victim must be enemies. Retry another
    -- legal holder when its only secondary targets are friendly or unknown.
    local rejected = {}
    while true do
      local holder = M.bestTarget(ai, function(target)
        if not rejected[target] then
          return ai:hostileScore(target, #target:getEquipments(Card.SubtypeWeapon))
        end
      end)
      if not holder then break end
      ai:selectTarget(holder, true)
      local reply = selectTargets(ai, function(target)
        return ai:hostileScore(target, 20 - target.hp)
      end)
      if reply then return reply end
      ai:selectTarget(holder, false)
      rejected[holder] = true
    end
  end
end

local function priority(ai, card)
  if selfBenefit[card.name] then
    if card.name == "qiao__peach" and not ai.player:isWounded() then return end
    return selfBenefit[card.name]
  end
  if card.type == Card.TypeEquip and card.name:startsWith("qiao__") and emptySlot(ai.player, card) then
    return 85
  end
  local name = card.name
  if name == "qiao__restore_heartland" then return 90 end
  if name == "qiao__analeptic" and ai.command == "PlayCard" and hasSlashTarget(ai) then return 65 end
  if name == "qiao__fire_attack" and fireSuits(ai, card) < 3 then return end
  if name == "qiao__befriend_attacking" then return 80 end
  if name == "qiao__iron_chain" or name == "qiao__god_salvation" then return 75 end
  if removal[name] or enemyPhase[name] or name == "qiao__collateral" then return 70 end
  if damage[name] or enemyGroup[name] then return 60 end
end

local function stageOf(card)
  local name = card.name
  if name == "qiao__foresight" or name == "qiao__strengthen_state"
    or name == "qiao__restore_heartland" or name == "qiao__befriend_attacking" then return "draw" end
  if removal[name] or name == "qiao__collateral" then return "disrupt" end
  if enemyPhase[name] then return "delayed" end
  if damage[name] or enemyGroup[name] or name == "qiao__analeptic" then return "damage" end
  return "setup"
end

function M.matchesCuipo(ai, card, index)
  if not index or Cuipo.cardNameLength(card) ~= index then return false end
  if damage[card.name] or enemyGroup[card.name] or card.type == Card.TypeEquip then return true end
  -- Self-targeting cards draw and other harmless uses still get their usual
  -- evaluation below. A no-target card would not emit TargetSpecified.
  local fixed = card:getFixedTargets(ai.player, ai.handler.extra_data)
  return (fixed and table.contains(fixed, ai.player)) or card.name == "qiao__restore_heartland"
    or (card.name == "qiao__iron_chain" and ai.player.chained)
end

function M.play(ai, stage, cuipoIndex)
  local candidates = {}
  for _, id in ipairs(ai:getEnabledCards()) do
    local card = Fk:getCardById(id)
    local value = priority(ai, card)
    if value and (not stage or stageOf(card) == stage) and (not cuipoIndex or M.matchesCuipo(ai, card, cuipoIndex)) then
      table.insert(candidates, { card = card, value = value })
    end
  end
  table.sort(candidates, function(a, b)
    if a.value == b.value then return a.card.id < b.card.id end
    return a.value > b.value
  end)
  for _, candidate in ipairs(candidates) do
    local card = candidate.card
    ai:selectCard(card.id, true)
    local reply = not ai:getSelectedSkill() and playSelected(ai, card)
    if reply then return reply end
    ai:selectCard(card.id, false)
  end
end

function M.recast(ai)
  local hand = ai.player:getCardIds("h")
  local enabled = ai:getEnabledCards()
  table.sort(enabled)
  for _, id in ipairs(enabled) do
    local card = Fk:getCardById(id)
    if table.contains(card.special_skills or {}, "recast") and table.contains(hand, id)
      and Fk.skills.recast:canUse(ai.player) then
      ai:selectCard(id, true)
      ai.handler:selectSpecialUse("recast")
      if ai:okButtonEnabled() then
        return { card = id, targets = {}, special_skill = "recast" }
      end
      ai:selectCard(id, false)
    end
  end
end

return M
