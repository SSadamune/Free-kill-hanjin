local Board = require "packages.qiao.pkg.qiao_mode.ai.board"
local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Removal = require "packages.qiao.pkg.qiao_mode.ai.removal"
local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Visibility = require "packages.qiao.pkg.qiao_mode.rules.card_visibility"
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"
local WeiLord = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local WuLord = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local Slash = require "packages.qiao.pkg.qiao_mode.ai.slash_supply"
local Heg = require "packages.hegemony.util"

local M = {}

local function playerAt(ai, fields, index)
  local id = tonumber(fields[index])
  return id and ai.room:getPlayerById(id)
end

local function trigger(ai)
  local frame = Selection.currentCost(ai.player)
  return frame and frame.data, frame
end

local function normalDamage(ai, target, source)
  return Damage.assess(ai, target, 1, fk.NormalDamage, { source = source or ai.player })
end

local function damageScore(ai, target)
  if not ai:isEnemy(target) then return end
  local outcome = normalDamage(ai, target)
  if Damage.worth(outcome) then return ai:hostileScore(target, outcome.balance) end
end

local function canHeal(player)
  return player:isWounded() and player:getMark("@@command5_effect-turn") == 0
end

local function fudiScore(ai, source)
  if not ai:isEnemy(source) then return end
  local highest, best = 0, nil
  for _, target in ipairs(ai.room:getPresentPlayers()) do
    if target == source or Heg.compareKingdomWith(target, source) then
      if target.hp >= highest then
        if target.hp > highest then highest, best = target.hp, nil end
        local score = damageScore(ai, target)
        if score then best = math.max(best or score, score) end
      end
    end
  end
  if highest >= ai.player.hp then return best end
end

function M.invoke(ai, key, fields)
  local player, target = ai.player, playerAt(ai, fields, 3)
  if key == "#qiao__skill_shu020_1-invoke" then
    return not player:isHandAreaSealed() and (tonumber(fields[4]) or 0) > 0
  elseif key == "#qiao__skill_wu022_2-invoke" then
    return not player:isHandAreaSealed() and player:getHandcardNum() < player.maxHp
  elseif key == "#qiao__skill_wei022_2-invoke" then
    return ai:isFriend(target) and target:canSkip(Player.Discard) and target:getMaxCards() <= target.maxHp
      and (target:getMaxCards() < target.maxHp or not target:isHandAreaSealed())
  elseif key == "#qiao__skill_jin020_1-invoke" then
    local recipient = playerAt(ai, fields, 2)
    return ai:isFriend(recipient) and not recipient:isHandAreaSealed()
  elseif key == "#qiao__retinue_skill_hucheer-invoke" then
    return ai:isEnemy(target) and not player:isHandAreaSealed()
  elseif key == "#qiao__retinue_skill_wudang_feijun-invoke" or key == "#qiao__skill_jin024_1-invoke" then
    if not ai:isEnemy(target) then return false end
    local damage = trigger(ai)
    local urgent = key == "#qiao__retinue_skill_wudang_feijun-invoke"
      and damage and damage.damage >= target.hp + target.shield
    if urgent then return true end
    local _, harmful = Removal.pick(ai, target, "he", false)
    return harmful ~= nil and not table.find(target:getCardIds("j"), function(id)
      return Board.harmfulDelay(target:getVirtualEquip(id) or Fk:getCardById(id))
    end)
  elseif key == "#qiao__skill_shu022_2-invoke" then
    local damage = trigger(ai)
    if not damage or not target then return false end
    local amount = damage.damage
    local outcome = Damage.assess(ai, target, amount, damage.damageType,
      { source = player, alreadyChained = damage.chain, card = damage.card })
    if ai:isFriend(target) then
      return not Damage.worth(outcome) and (amount >= target.hp + target.shield
        or #target:getCardIds("he") == 0 or Removal.pick(ai, target, "j", true) ~= nil)
    end
    local _, payoff = Removal.pick(ai, target, "hej", true)
    return ai:isEnemy(target) and payoff ~= nil and not player:isHandAreaSealed() and outcome.enemyDying == 0
      and (outcome.unsafe or payoff >= 7 and payoff > Damage.value(outcome) + 2)
  elseif key == "#qiao__skill_han023_1-invoke" then
    return player.hp >= 3 and ai:isEnemy(target) and target:isKongcheng()
      and #target:getHandlyIds(false) == 0 and damageScore(ai, target) ~= nil
  elseif key == "#qiao__skill_wei020_2-invoke" then
    local damage = trigger(ai)
    return damage ~= nil and not player:isHandAreaSealed()
      and (not ai:isFriend(damage.from) or damage.from:isKongcheng()) and player:isKongcheng()
  elseif key == "#qiao__skill_wu019_1-invoke" then
    local jink = table.find(player:getCardIds("h"), function(id)
      local card = Fk:getCardById(id)
      return card.trueName == "jink" and not player:prohibitUse(card)
    end)
    return jink ~= nil and player.hp >= 3 and player:canSkip(Player.Draw)
      and (table.find(player:getCardIds("j"), function(id)
        return Board.harmfulDelay(player:getVirtualEquip(id) or Fk:getCardById(id))
      end) ~= nil or table.find(player:getCardIds("h"), function(id)
        return Cost.value(ai, id) <= 2
      end) ~= nil)
  end
end

local function xuanhuScore(ai, target)
  local hand = target:getHandcardNum()
  if ai:isFriend(target) and not target:isHandAreaSealed() then
    if canHeal(target) and hand + 1 == target.hp then return 8 - math.min(3, target.hp) end
    return 2 + 1 / (hand + 1)
  end
  if ai:isEnemy(target) and (not canHeal(target) or (hand ~= target.hp and hand - 1 ~= target.hp))
    and table.find(target:getCardIds("e"), function(id) return not target:prohibitDiscard(id) end) then
    return 1.5
  end
end

local function wanweiWorth(ai, move)
  local actor = move.moveReason == fk.ReasonPrey and (move.to or move.proposer)
    or move.moveReason == fk.ReasonDiscard and move.proposer
  if not ai:isFriend(move.from) or not ai:isEnemy(actor) then return end
  local value = 0
  for _, info in ipairs(move.moveInfo or {}) do
    if info.fromArea == Card.PlayerEquip then
      value = value + 2 + Board.equipScore(info.beforeCard or Fk:getCardById(info.cardId))
    elseif info.fromArea == Card.PlayerHand then
      value = value + (move.from == ai.player and Cost.value(ai, info.cardId) or 3)
    end
  end
  if value >= 4 then return value, move end
end

local function wanweiMove(ai, target)
  if not ai:isFriend(target) then return end
  -- The skill uses the first matching move for the selected owner.
  for _, move in ipairs(trigger(ai) or {}) do
    local actor = move.moveReason == fk.ReasonPrey and (move.to or move.proposer)
      or move.moveReason == fk.ReasonDiscard and move.proposer
    if move.from == target and actor and not Heg.compareKingdomWith(actor, ai.player)
      and table.find(move.moveInfo or {}, function(info)
        return info.fromArea == Card.PlayerEquip or info.fromArea == Card.PlayerHand
      end) then
      if wanweiWorth(ai, move) then return move end
      return
    end
  end
end

function M.targetScore(ai, key, fields)
  if key == "#qiao__skill_han021_2-target" then
    return function(target) return xuanhuScore(ai, target) end
  elseif key == "#qiao__skill_wu021_1-choose" then
    return function(target)
      local _, value = Removal.pick(ai, target, "he", false)
      if value then return ai:hostileScore(target, value) end
    end
  elseif key == "#qiao__skill_wei022_1-target" then
    return function(target)
      local move = wanweiMove(ai, target)
      if move then return wanweiWorth(ai, move) end
    end
  elseif key == "#qiao__skill_qun023_2-target" then
    return function(target) return damageScore(ai, target) end
  elseif key == "#qiao__skill_shu024_1-victim" then
    local actor = playerAt(ai, fields, 3)
    local slash = Fk:cloneCard("qiao__slash")
    return function(target)
      if actor and actor:canUseTo(slash, target, { bypass_distances = true, bypass_times = true }) then
        return damageScore(ai, target)
      end
    end
  elseif key == "#qiao__skill_wu019_1-user" then
    return function(target)
      return not Cost.effectable(target, "qiao__skill_qun023_1") and (ai:isFriend(target) and 2 or 1) or 0
    end
  elseif key == "#qiao__em_wei001_huibian-recover" then
    return function(target)
      if ai:isFriend(target) and canHeal(target) then return ai:supportScore(target, 6 - target.hp) end
    end
  elseif key == "#qiao__skill_wu022_1-choose" then
    return function(target) if target == ai.player then return 1 end end
  end
end

function M.diaoduCard(ai, target, ids)
  if target ~= ai.player then return end
  return table.find(ids, function(id)
    local card = Fk:getCardById(id)
    return card.sub_type == Card.SubtypeWeapon and not target:prohibitUse(card)
      and not target:isProhibited(target, card) and not target:getVirtualEquip(id)
  end)
end

function M.active(ai, key, fields)
  local function pay(count, budget, eligible)
    if Cost.select(ai, count, budget, eligible) then return Requests.reply(ai) end
    return ""
  end

  if key == "#qiao__skill_shu024_2-heart" then
    local target = playerAt(ai, fields, 3)
    local player = ai.player
    if player.hp <= 1 then return pay(1) end
    if Cost.zhaxiangTrade(player) and not ai:isFriend(target) then return "" end
    return pay(1, ai:isFriend(target) and 6 or 3)
  elseif key == "#qiao__skill_han021_1-discard" then
    local _, frame = trigger(ai)
    local entry = frame and frame.event:getCostData(frame.skill)
    if not entry or not ai:isFriend(entry.from) then return "" end
    local card = entry.from:getVirtualEquip(entry.cardId) or Fk:getCardById(entry.cardId)
    return pay(1, Board.equipScore(card), function(id) return id ~= entry.cardId end)
  elseif key == "#qiao__skill_wei022_1-card" then
    local move = wanweiMove(ai, playerAt(ai, fields, 3))
    if not move then return "" end
    return pay(1, 2, function(id)
      return (move.moveReason ~= fk.ReasonDiscard or not ai.player:prohibitDiscard(id))
        and not table.find(move.moveInfo, function(info) return info.cardId == id end)
    end)
  elseif key == "#qiao__skill_qun023_2-invoke" then
    if not fudiScore(ai, playerAt(ai, fields, 3)) then return "" end
    return pay(1, 1.5)
  elseif key == "#qiao__retinue_skill_hucheer-use" then
    if not Cost.select(ai, 1, nil, function(id)
      local card = Fk:getCardById(id)
      return card.type == Card.TypeEquip and Cards.priority(ai, card) ~= nil
    end) then return "" end
    return Requests.targets(ai, function(target) if target == ai.player then return 1 end end)
  elseif key == "#qiao__skill_shu023_1-give" then
    if ai.player:getHandcardNum() <= 2 then return "" end
    if not Cost.select(ai, 1, 4, function(id)
      local card = Fk:getCardById(id)
      return ai.room:getCardArea(id) == Card.PlayerHand and card.type == Card.TypeEquip
    end) then return "" end
    local card = Fk:getCardById(ai:getSelectedCards()[1])
    return Requests.targets(ai, function(target)
      if ai:isFriend(target) and target:hasEmptyEquipSlot(card.sub_type) then return 3 - math.min(target.hp, 2) end
    end)
  elseif key == "#qiao__skill_shu024_1-give" then
    if not Cost.select(ai, 2, 4) then return "" end
    local slash = Fk:cloneCard("qiao__slash")
    return Requests.targets(ai, function(target)
      if ai:isFriend(target) and not target:isHandAreaSealed() and table.find(ai.room:getPresentPlayers(), function(victim)
        return ai:isEnemy(victim) and target:canUseTo(slash, victim, { bypass_distances = true, bypass_times = true })
      end) then return 4 / (1 + target:getHandcardNum()) end
    end)
  elseif key == "#qiao__skill_wei021b_1-return" then
    local id, value = Cost.cheapest(ai, function(cardId) return Fk:getCardById(cardId).type ~= Card.TypeBasic end)
    if Cost.select(ai, 2, value, function(cardId) return Fk:getCardById(cardId).type == Card.TypeBasic end) then
      return Requests.reply(ai)
    end
    ai:unSelectAllCards()
    if id then ai:selectCard(id, true) end
    return Requests.reply(ai)
  end
end

function M.choice(ai, choices, fields)
  local key = fields[1]
  if key == "#qiao__skill_han021_2-choice" then
    local target = playerAt(ai, fields, 3)
    return ai:isEnemy(target) and "#qiao__skill_han021_2-discard" or "#qiao__skill_han021_2-draw"
  elseif key == "#qiao__skill_jin018_2-choose" then
    local source = playerAt(ai, fields, 2)
    local player = ai.player
    local outcome = normalDamage(ai, player, source)
    if not outcome.unsafe and (outcome.direct <= player.shield or (player.hp >= 3
      and player:getHandcardNum() >= 5 and outcome.balance >= -2)) then return "#qiao__skill_jin018_2-damage" end
    return "#qiao__skill_jin018_2-open"
  elseif key == "#qiao__skill_wu019_2-adapt" then
    return "#qiao__skill_wu019_2-gain"
  elseif key == "#qiao__skill_wu022_1-action" then
    local player = ai.player
    if not player:isHandAreaSealed() and player:canSkip(Player.Play)
      and M.diaoduCard(ai, player, player:getCardIds("e")) then return "#qiao__skill_wu022_1-obtain" end
    return "Cancel"
  elseif key == "#qiao__skill_shu024_1-choose" then
    local target = playerAt(ai, fields, 3)
    local plain = table.find(choices, function(name)
      return name == "qiao__slash" and Cards.safeDamage(ai, Fk:cloneCard(name), target)
    end)
    if plain then return plain end
    return table.find(choices, function(name)
      return Fk.all_card_types[name] and Cards.safeDamage(ai, Fk:cloneCard(name), target)
    end) or "#qiao__skill_shu024_1-return"
  end
end

function M.damageDialog(ai, component)
  local prop = component and component.model and component.model.prop
  if not prop or not (prop.prompt or ""):startsWith("#qiao__skill_han024_1-discard:") then return end
  local damage = trigger(ai)
  if not damage or not damage.from or not damage.to then return end
  local player, target = ai.player, damage.to
  local options = { source = damage.from, card = damage.card, alreadyChained = damage.chain }
  local before = Damage.assess(ai, target, damage.damage, damage.damageType, options)
  local delta = target == player and -1 or ai:isEnemy(target) and 1
  if not delta then return end
  local after = Damage.assess(ai, target, damage.damage + delta, damage.damageType, options)
  if after.unsafe or after.balance <= before.balance then return end
  local budget = delta > 0 and 2 or before.unsafe and 7 or 2.5
  local chosen, price
  for _, id in ipairs(prop.cards or {}) do
    if not table.contains(prop.disabledCards or {}, id) then
      local value = Cost.value(ai, id)
      if value <= budget and (not price or value < price or (value == price and id < chosen)) then
        price, chosen = value, id
      end
    end
  end
  if chosen then return { cards = { chosen }, choice = "#qiao__skill_han024_1-" .. (delta > 0 and "plus" or "minus") } end
end

function M.chooseEquip(ai, target, ids)
  local best, score
  for _, id in ipairs(ids) do
    local card = target:getVirtualEquip(id) or Fk:getCardById(id)
    local value = Board.equipScore(card) + (ai.player:hasEmptyEquipSlot(card.sub_type) and 1 or 0)
    if not score or value > score or (value == score and id < best) then best, score = id, value end
  end
  return best
end

function M.lowestZoneCard(ai, ids)
  local best, value
  for _, id in ipairs(ids) do
    local card = ai.player:getVirtualEquip(id) or Fk:getCardById(id)
    local score = ai.room:getCardArea(id) == Card.PlayerJudge and Board.harmfulDelay(card) and -5 or Cost.value(ai, id)
    if not value or score < value or (score == value and id < best) then best, value = id, score end
  end
  return best
end

function M.jubaoCard(ai, target, areas)
  if ai:isEnemy(target) then return Removal.pick(ai, target, areas, true) end
  local best, value
  for _, id in ipairs(target:getCardIds("e")) do
    local card = target:getVirtualEquip(id) or Fk:getCardById(id)
    local score = card.name == WuLord.PEARL and 10 or Board.equipScore(card)
    if not value or score < value or (score == value and id < best) then best, value = id, score end
  end
  return best
end

function M.jueyanAllocation(ai, prop)
  local player = ai.player
  local normal = Slash.plan(ai, { future = true, safe = Cards.safeDamage })
  local best, value
  for _, option in ipairs(prop.options or {}) do
    local attacks = math.max(0, math.min(option.slash, normal.normal - normal.limit))
    local draw = player:canSkip(Player.Draw) and 3 * option.draw or 0
    local score = draw + 4 * attacks
    if option.range > 0 and player:canSkip(Player.Play) then
      for _, target in ipairs(ai.room:getOtherPlayers(player, false)) do
        if ai:isEnemy(target) and not player:inMyAttackRange(target)
          and player:distanceTo(target) <= player:getAttackRange() + option.range
          and table.find(player:getCardIds("h"), function(id)
            local card = Fk:getCardById(id)
            return card.trueName == "slash" and Cards.safeDamage(ai, card, target)
              and player:canUseTo(card, target, { bypass_distances = true, bypass_times = true })
          end) then
          score = score + 4
          break
        end
      end
    end
    if not value or score > value or (score == value and option.draw > best.draw) then best, value = option, score end
  end
  return best
end

local play = {}

function play.qiao__skill_shu022_1(ai)
  if Cost.discard(ai, 1, 2) then return Requests.targets(ai, function(target) return damageScore(ai, target) end) end
end

function play.qiao__skill_jin018_2(ai)
  if not Cost.discard(ai, 1, 1.5) then return end
  return Requests.targets(ai, function(target)
    if target:getMark(Visibility.WUDU_OPEN) == 0 and target:getHandcardNum() >= 2 then
      return ai:hostileScore(target, target:getHandcardNum())
    end
  end)
end

function play.qiao__retinue_skill_feixiongjun(ai)
  local snatch = Fk:cloneCard("qiao__snatch")
  local slash = Fk:cloneCard("qiao__slash")
  local bypass = { bypass_distances = true, bypass_times = true }
  local player = ai.player
  return Requests.targets(ai, function(target)
    local _, value = Removal.pick(ai, target, "hej", true)
    if value and value >= 5 and player:canUseTo(snatch, target, bypass) and player:canUseTo(slash, target, bypass)
      and Cards.safeDamage(ai, slash, target) then return ai:hostileScore(target, value + 4 - target.hp) end
  end)
end

function play.qiao__skill_wei020_1(ai)
  local player = ai.player
  local hand = player:getCardIds("h")
  if #hand ~= 1 or Cost.value(ai, hand[1]) > 2 or player:isHandAreaSealed() then return end
  local card = Fk:cloneCard("qiao__foresight")
  card:addSubcards(hand)
  card.skillName = "qiao__skill_wei020_1"
  if not player:canUse(card) or #card:getAvailableTargets(player) ~= 1 then return end
  ai.handler:updateInteraction("qiao__foresight")
  return Requests.reply(ai)
end

function play.qiao__skill_wei021b_1(ai)
  if ai.player:isHandAreaSealed() or not Cost.select(ai, 1, 2.5, function(id)
    return Fk:getCardById(id).type == Card.TypeBasic
  end) then return end
  return Requests.targets(ai, function(target)
    if target:isKongcheng() and #target:getCardIds("e") > 0 and not target:isHandAreaSealed() then
      return ai:hostileScore(target, 5)
    end
  end)
end

function play.qiao__skill_wei021b_2(ai)
  local player = ai.player
  if not player.faceup or player:isHandAreaSealed() or player:getMaxCards() <= 0 then return end
  if not table.every(player:getCardIds("h"), function(id) return Cost.value(ai, id) <= 3 end) then return end
  if player.maxHp < 3 then return end
  return Requests.targets(ai, function(target) if target == player then return 1 end end)
end

function play.qiao__skill_shu023_1(ai)
  local friends, vulnerable = 0, 0
  for _, target in ipairs(ai.room:getPresentPlayers()) do
    if ai:isFriend(target) then
      friends = friends + 1
      if target.hp <= 2 and canHeal(target) then vulnerable = vulnerable + 1 end
    end
  end
  if friends >= 3 or vulnerable > 0 or (friends >= 2 and ai.player:isKongcheng()) then
    return Requests.reply(ai)
  end
end

function play.qiao__skill_qun022a_1(ai)
  local player = ai.player
  if player:isHandAreaSealed() or not Cost.discard(ai, 1, 2) then return end
  return Requests.targets(ai, function(target)
    if not ai:isFriend(target) then return end
    local valuable = table.find(target:getAllSkills(), function(skill)
      return skill.name ~= "qiao__skill_qun022a_1" and skill:hasTag(Skill.Limited)
        and target:usedSkillTimes(skill.name, Player.HistoryGame) > 0
    end)
    if target.hp >= 3 and (target.shield > 0 or valuable) then return 3 + target.hp end
  end)
end

function play.qiao__skill_jin020_2(ai)
  local player = ai.player
  if player:isHandAreaSealed() or table.find(player:getCardIds("h"), function(id)
    return #((Fk:getCardById(id).extra_data or {}).qiao_adaptation or {}) > 0
  end) then return end
  if Cost.select(ai, 1, 1.5, function(id) return Fk:getCardById(id).suit == Card.Spade end) then
    return Requests.targets(ai, function(target) if target == player then return 1 end end)
  end
end

function play.qiao__skill_wu021_2(ai)
  if Board.worthMoving(ai, "e", function(from, to, id) return Bian.canMoveEquipTo(from, to, id, ai.player) end) then
    return Requests.reply(ai)
  end
end

function play.qiao__skill_wu024_2(ai)
  local best, bestScore
  for _, enemy in ipairs(ai:getEnabledTargets()) do
    if ai:isEnemy(enemy) and not Cost.effectable(enemy, "qiao__skill_wu008_2") then
      ai:selectTarget(enemy, true)
      local equipment = enemy:getCardIds("e")
      for _, ally in ipairs(ai:getEnabledTargets()) do
        if ai:isFriend(ally) and #ally:getCardIds("e") == 0 and #equipment > 0
          and table.every(equipment, function(id) return Bian.canMoveEquipTo(enemy, ally, id, ai.player) end) then
          local value = ai:supportScore(ally, ai:hostileScore(enemy, #equipment * 3 - ally.hp))
          if not bestScore or value > bestScore then best, bestScore = { enemy, ally }, value end
        end
      end
      ai:unSelectAllTargets()
    end
  end
  if not best then return end
  for _, target in ipairs(best) do ai:selectTarget(target, true) end
  return Requests.reply(ai)
end

play[WeiLord.HUIBIAN] = function(ai)
  return Requests.targets(ai, function(first)
    if not ai:isFriend(first) or first:isHandAreaSealed() or first.shield == 0 then return end
    local outcome = normalDamage(ai, first)
    if outcome.unsafe or outcome.direct > first.shield then return end
    local second = table.find(ai.room:getPresentPlayers(), function(target)
      return target ~= first and target.kingdom == "wei" and ai:isFriend(target) and canHeal(target)
    end)
    if second then return ai:supportScore(first, 5 + first.shield - first:getHandcardNum() * 0.25) end
  end)
end

function M.play(ai, name)
  if not play[name] then return end
  if name == "qiao__skill_wei020_1" and ai.player:getHandcardNum() ~= 1 then return end
  ai:selectSkill(name, true)
  local result = play[name](ai)
  if result and result ~= "" then return result end
  ai:unSelectAll()
end

return M
