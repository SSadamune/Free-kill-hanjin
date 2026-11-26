local M = {}

local damage = {
  qiao__slash = true, qiao__fire__slash = true, qiao__thunder__slash = true,
  qiao__ice__slash = true, qiao__unexpectation = true, qiao__duel = true,
  qiao__drowning = true,
}
local elemental = {
  qiao__fire__slash = true, qiao__thunder__slash = true, qiao__ice__slash = true,
  qiao__fire_attack = true, qiao__drowning = true, qiao__burning_camps = true,
}
local removal = {
  qiao__dismantlement = true, qiao__snatch = true, qiao__chasing_near = true,
}
local enemyPhase = { qiao__indulgence = true, qiao__supply_shortage = true }
local enemyGroup = {
  qiao__archery_attack = true, qiao__savage_assault = true, qiao__burning_camps = true,
}
local selfBenefit = { qiao__foresight = 100, qiao__strengthen_state = 100, qiao__peach = 95 }

function M.safeDamage(ai, card, target)
  if not ai:isEnemy(target) then return false end
  if not elemental[card.name] or not target.chained then return true end
  -- Chain propagation can hit everyone still chained. Unknown players are
  -- insufficient evidence for taking that risk.
  return table.every(ai.room:getPresentPlayers(), function(other)
    return not other.chained or ai:isEnemy(other)
  end)
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

function M.bestTarget(ai, score)
  local best, bestScore
  for _, target in ipairs(ai:getEnabledTargets()) do
    local value = score(target)
    if value and (not bestScore or value > bestScore
      or (value == bestScore and target.seat < best.seat)) then
      best, bestScore = target, value
    end
  end
  return best
end

-- Let the real request handler enforce target restrictions and feasibility.
-- Single-target plays stop there. Support plays may also take additional legal targets.
local function selectTargets(ai, score, extend)
  while extend or not ai:okButtonEnabled() do
    local target = M.bestTarget(ai, score)
    if not target then break end
    ai:selectTarget(target, true)
  end
  if ai:okButtonEnabled() then return physicalReply(ai) end
end

local function hurt(ai, card)
  local score = function(target)
    if M.safeDamage(ai, card, target) then return 20 - target.hp end
  end
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

local function fixedGroup(ai, card, safe, useful)
  local targets = card:getAvailableTargets(ai.player, ai.handler.extra_data)
  if table.every(targets, safe) and table.find(targets, useful) and ai:okButtonEnabled() then
    return physicalReply(ai)
  end
end

local function playSelected(ai, card)
  local name, player = card.name, ai.player
  if selfBenefit[name] or card.type == Card.TypeEquip then
    if ai:okButtonEnabled() then return physicalReply(ai) end
  elseif damage[name] then
    return hurt(ai, card)
  elseif removal[name] then
    return selectTargets(ai, function(target)
      if ai:isEnemy(target) and not target:isNude() then
        local obtains = name == "qiao__snatch"
          or (name == "qiao__chasing_near" and player:distanceTo(target) == 1)
        return (obtains and 8 or 0) + 2 * #target:getCardIds("e") + target:getHandcardNum()
      end
    end)
  elseif enemyPhase[name] then
    return selectTargets(ai, function(target)
      if ai:isEnemy(target) then return target:getHandcardNum() end
    end)
  elseif enemyGroup[name] then
    local safe = function(target) return M.safeDamage(ai, card, target) end
    return fixedGroup(ai, card, safe, safe)
  elseif name == "qiao__god_salvation" then
    local woundedFriend = function(target) return target:isWounded() and ai:isFriend(target) end
    return fixedGroup(ai, card, function(target)
      return not target:isWounded() or ai:isFriend(target)
    end, woundedFriend)
  elseif name == "qiao__restore_heartland" then
    return selectTargets(ai, function(target)
      if ai:isFriend(target) then return target == player and 1 or 2 end
    end, true)
  elseif name == "qiao__befriend_attacking" then
    return selectTargets(ai, function(target)
      if ai:isEnemy(target) then return target.hp end
    end)
  elseif name == "qiao__iron_chain" then
    return selectTargets(ai, function(target)
      if target.chained and ai:isFriend(target) then return 20 - target.hp end
    end, true)
  elseif name == "qiao__collateral" then
    -- Both the weapon holder and any victim must be enemies. Retry another
    -- legal holder when its only secondary targets are friendly or unknown.
    local rejected = {}
    while true do
      local holder = M.bestTarget(ai, function(target)
        if not rejected[target] and ai:isEnemy(target) then
          return #target:getEquipments(Card.SubtypeWeapon)
        end
      end)
      if not holder then break end
      ai:selectTarget(holder, true)
      local reply = selectTargets(ai, function(target)
        if ai:isEnemy(target) then return 20 - target.hp end
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
  if name == "qiao__befriend_attacking" then return 80 end
  if name == "qiao__iron_chain" or name == "qiao__god_salvation" then return 75 end
  if removal[name] or enemyPhase[name] or name == "qiao__collateral" then return 70 end
  if damage[name] or enemyGroup[name] then return 60 end
end

function M.play(ai)
  local candidates = {}
  for _, id in ipairs(ai:getEnabledCards()) do
    local card = Fk:getCardById(id)
    local value = priority(ai, card)
    if value then table.insert(candidates, { card = card, value = value }) end
  end
  table.sort(candidates, function(a, b)
    if a.value == b.value then return a.card.id < b.card.id end
    return a.value > b.value
  end)
  for _, candidate in ipairs(candidates) do
    local card = candidate.card
    ai:selectCard(card.id, true)
    local reply = playSelected(ai, card)
    if reply then return reply end
    ai:selectCard(card.id, false)
  end
end

return M
