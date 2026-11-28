local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Health = require "packages.qiao.pkg.qiao_mode.ai.health_value"
local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"
local SlashDefense = require "packages.qiao.pkg.qiao_mode.ai.slash_defense"
local CardTargets = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local Kongcheng = require "packages.qiao.pkg.qiao_generals.skills.skill_shu004_2"

local M = {
  driveTiger = "qiao__skill_wei013_1",
  fenyue = "qiao__skill_han013_1",
}

local function playValue(ai, discard)
  local player = ai.player
  local best = 0
  for _, id in ipairs(player:getCardIds("h")) do
    if id ~= discard then
      local card = Fk:getCardById(id)
      if card.trueName == "slash" or card.trueName == "duel" or card.name == "qiao__unexpectation" then
        for _, target in ipairs(card:getAvailableTargets(player)) do
          best = math.max(best, Cards.attackValue(ai, card, target) or 0)
        end
      elseif card.trueName == "peach" and player:canUseTo(card, player) then
        best = math.max(best, Health.recovery(ai, player, 1))
      elseif card.name == "qiao__foresight" or card.name == "qiao__strengthen_state" then
        if player:canUse(card) then best = math.max(best, 6) end
      end
    end
  end
  return best
end

function M.shensu(ai, prompt, extra)
  local player, cost = ai.player, 0
  if prompt == "#qiao__skill_wei008_1-judge" then
    cost = 6
    for _, id in ipairs(player:getCardIds("j")) do
      local name = Fk:getCardById(id).trueName
      if name == "indulgence" then cost = cost - 3 end
      if name == "supply_shortage" then cost = cost - 4 end
      if name == "lightning" then cost = cost - Health.damage(ai, 3 / 8) end
    end
  elseif prompt == "#qiao__skill_wei008_1-play" then
    local id, price = Cost.cheapest(ai)
    if not id then return "" end
    cost = price + playValue(ai, id)
    ai:selectCard(id, true)
  else
    if player.hp <= 1 then return "" end
    cost = Health.damage(ai, 1)
    local prices = {}
    for _, id in ipairs(player:getCardIds("h")) do
      if not player:prohibitDiscard(id) then table.insert(prices, Cost.value(ai, id)) end
    end
    table.sort(prices)
    for i = 1, math.min(#prices, player:getHandcardNum() - player:getMaxCards()) do cost = cost - prices[i] end
  end

  local slash = Fk:cloneCard("qiao__slash")
  return Requests.targets(ai, function(target)
    local value = Cards.attackValue(ai, slash, target)
    if value and value > math.max(0, cost) then return ai:hostileScore(target, value) end
  end, extra.num or extra.max_t_num or 1)
end

function M.driveTigerScore(ai, actor, target)
  if target and target ~= actor and actor:inMyAttackRange(target) then
    return Damage.enemyValue(ai, target, 1, fk.NormalDamage, { source = actor })
  end
end

local function driveTigerRisk(ai, source)
  local player, slash = ai.player, Fk:cloneCard("qiao__slash")
  if Kongcheng.protectsFrom(player, slash) or SlashDefense.vineBlocks(source, slash, player) then return 0 end
  local policy = CardTargets.explicit({ other_roles = true }, { names = { "qiao__slash" } })
  if not table.contains(CardTargets.effectCandidates(ai.room, source, slash, policy), player) then return 0 end
  local outcome = Damage.assess(ai, player, Damage.cardAmount(slash, nil, source), fk.NormalDamage,
    { source = source, card = slash })
  return math.max(0, -Damage.value(outcome))
end

local function fenyueGain(ai, target, id, number)
  local player = ai.player
  if number < 9 then
    local fire = Fk:cloneCard("qiao__fire__slash")
    local policy = CardTargets.explicit({ other_roles = true }, { names = { "qiao__fire__slash" } })
    if not table.contains(CardTargets.effectCandidates(ai.room, player, fire, policy), target) then return 0 end
    local result = Cards.damageOutcome(ai, fire, target)
    return result and Damage.worth(result) and Damage.value(result) or 0
  end
  local gain = 0
  for _, other in ipairs(player:getCardIds("h")) do
    local card = Fk:getCardById(other)
    if other ~= id and card.trueName == "slash" and player:canUseTo(card, target) then
      local outcome = Cards.damageOutcome(ai, card, target)
      if outcome and Damage.worth(outcome) then
        local expected = Cards.attackValue(ai, card, target)
        gain = math.max(gain, Damage.value(outcome) - expected)
      end
    end
  end
  return gain
end

function M.pindianCard(ai, reason, target, ids)
  local hand = target and target:getHandcardNum() or 0
  if hand == 0 or not ai:isEnemy(target) then return end
  local damage = 0
  if reason == M.driveTiger then
    for _, victim in ipairs(ai.room:getPresentPlayers()) do
      damage = math.max(damage, M.driveTigerScore(ai, target, victim) or 0)
    end
  end
  local risk = reason == M.driveTiger and driveTigerRisk(ai, target)
    or math.min(Health.harm(ai, ai.player, 0, 1), playValue(ai))
  return Requests.bestCard(ids, function(id)
    local card = Fk:getCardById(id)
    local gain = reason == M.driveTiger and damage or fenyueGain(ai, target, id, card.number)
    local win = (math.max(0, card.number - 1) / 13) ^ hand
    return win * gain - (1 - win) * risk - Cost.value(ai, id)
  end)
end

function M.fenyueFailure(ai)
  local value = playValue(ai)
  local loss = Health.harm(ai, ai.player, 0, 1)
  if Cost.zhaxiangTrade(ai.player) then loss = loss - 9 end
  return value > loss and ai.player.hp > 1 and "#qiao__skill_han013_1-lose_hp" or "#qiao__skill_han013_1-end_phase"
end

return M
