local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Removal = require "packages.qiao.pkg.qiao_mode.ai.removal"
local Board = require "packages.qiao.pkg.qiao_mode.ai.board"
local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"
local Adaptation = require "packages.qiao.pkg.qiao_mode.ai.adaptation"
local ExtraTargets = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"
local CardTargets = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Shi = require "packages.qiao.pkg.qiao_bingqing.shi"
local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local Slash = require "packages.qiao.pkg.qiao_mode.ai.slash_supply"
local Edict = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"

local M = {}
local slash, collateral = "qiao__slash", "qiao__collateral"
local pindi = "qiao__skill_wei035_1"
local chuming, huFen = "qiao__skill_jin037_2", "qiao_heg__jin066"

local function eventTarget(ai, name)
  local context = Requests.context(ai, name)
  return context and context.target
end

local function targetFromPrompt(ai, fields)
  return tonumber(fields[3]) and ai.room:getPlayerById(tonumber(fields[3]))
end

local function equipGain(ai, owner, id)
  local card = owner:getVirtualEquip(id) or Fk:getCardById(id)
  local dual = Fk.packages.qiao_cards.qiao_cards.isDualMount(card)
  local empty = ai.player:hasEmptyEquipSlot(card.sub_type)
    and (not dual or ai.player:hasEmptyEquipSlot(Card.SubtypeOffensiveRide))
  return 2 * Board.equipScore(card) + (empty and 2 or 0)
end

local function bestQieting(ai, owner, ids)
  if not ai:isEnemy(owner) then return end
  return Requests.bestCard(ids, function(id)
    if not Wu.isPubliclyProtectedTreasure(owner, ai.player, id) and owner:canMoveCardInBoardTo(ai.player, id) then
      return equipGain(ai, owner, id) - (Cost.effectable(owner, "qiao__skill_wu008_2") and 2 or 0)
    end
  end)
end

local function pindiTarget(ai, to, count)
  local _, loss = Removal.pick(ai, to, "he", false)
  local score = ai:isEnemy(to) and loss and loss + 2 * (math.min(count, to:getHandcardNum() + #to:getCardIds("e")) - 1)
    or (ai:isFriend(to) and not to:isHandAreaSealed() and 3 * count or nil)
  if not score then return end
  return score - (to:isWounded() and not ai.player.chained and 1 or 0)
end

local function choosePindi(ai)
  local count = #ai.player:getTableMark("qiao_pindi_types-turn") + 1
  local id, cost = Cost.cheapest(ai)
  if not id then return "" end
  ai:selectCard(id, true)
  return Requests.targets(ai, function(to)
    local value = pindiTarget(ai, to, count)
    if value and value > cost + 0.5 then return value end
  end)
end

local function hostileSlash(ai, from, to)
  local card = Fk:cloneCard(slash)
  return Cards.safeDamage(ai, card, to, nil, from)
    and table.contains(CardTargets.effectCandidates(ai.room, from, card, CardTargets.bypassDistance()), to)
end

local function bestCollateralVictim(ai, to, targets)
  return Cards.bestCandidate(ai, targets, function(victim)
    if ai:isEnemy(victim) then return ai:hostileScore(victim, 10 - victim.hp) end
  end)
end

local function generalValue(ai, name, to, deputy)
  local general = Fk.generals[name]
  if not general or Exchange.isSoldier(name) then return 0 end
  local value, hand = 2, to:getHandcardNum()
  for _, id in ipairs(general:getSkillNameList(true)) do
    local skill = Fk.skills[id]
    if skill and Exchange.cardProvidesSkill(ai.room, name, id)
      and not skill:hasTag(deputy and Skill.MainPlace or Skill.DeputyPlace, false) then
      local weight = 1
      if id == "qiao__skill_wu032_1" then
        weight = hand == to.hp and 3 or 1.5
      elseif id == "qiao__skill_jin066_1" then
        weight = 2 + (hand >= to:getMaxCards() and 1 or 0)
      elseif id == "qiao__skill_jin066_2" then
        weight = 3
      elseif id == "qiao__skill_wu027_1" or id == "qiao__skill_wei035_1" then
        weight = hand >= 3 and 2 or 0.5
      elseif id == "qiao__skill_shu091_2" then
        weight = -1
      end
      value = value + weight
    end
  end
  return value
end

local function exchangeValue(ai, first, second, saveFromDying)
  local side = ai:isFriend(first.player) and 1 or ai:isEnemy(first.player) and -1 or 0
  if side == 0 or side == 1 and not ai:isFriend(second.player) or side == -1 and not ai:isEnemy(second.player) then return end
  local a, b = first.player, second.player
  local beforeA = generalValue(ai, first.general, a, first.isDeputy)
  local beforeB = generalValue(ai, second.general, b, second.isDeputy)
  local afterA = generalValue(ai, second.general, a, first.isDeputy)
  local afterB = generalValue(ai, first.general, b, second.isDeputy)
  local weightA = saveFromDying and a.hp <= 0 and 0.25 or 1
  local weightB = saveFromDying and b.hp <= 0 and 0.25 or 1
  return side * ((afterA - beforeA) * weightA + (afterB - beforeB) * weightB)
end

local function exchangeScore(ai, a, b, dying)
  local score
  for _, pair in ipairs(Shi.pairs(ai.room, a, b)) do
    local value = exchangeValue(ai, pair[1], pair[2], dying)
    if value and (not score or value > score) then score = value end
  end
  if score and score >= 1.5 then return score end
end

function M.invoke(ai, name, fields)
  local target = eventTarget(ai, name)
  if name == "qiao__skill_wei035_2" then return ai:isFriend(target) end
  if name == "qiao__skill_jin066_1" then return true end
  if name == "qiao__skill_qun033_1" then return not ai.player:isHandAreaSealed() or target and bestQieting(ai, target, target:getCardIds("e")) ~= nil end
  if name == "qiao__skill_wu032_2" then
    local hand = ai.player:getCardIds("h")
    local first = hand[1] and Fk:getCardById(hand[1]).color
    return first ~= nil and first ~= Card.NoColor and not ai.player:isHandAreaSealed()
      and table.every(hand, function(id) return Fk:getCardById(id).color == first end)
  end
  if fields[1] == "#qiao__han001_zhuanpeng-invoke" then
    local frame = Requests.context(ai, name)
    return frame ~= nil and ai:isEnemy(frame.data.from)
  end
end

local function avoidDamageBudget(ai, aim)
  if not aim or not aim.from or not aim.card or not ai:isEnemy(aim.from) then return end
  local player, card = ai.player, aim.card
  local lethal = Damage.cardAmount(card, aim.use, aim.from) >= player.hp + player.shield
  local defense = card.trueName == "slash" and not aim.disresponsive and table.find(player:getCardIds("h"), function(id)
    local jink = Fk:getCardById(id)
    return jink.trueName == "jink" and not player:prohibitUse(jink)
  end)
  if not defense then return lethal and 7 or 3 end
end

local function jingchu(ai, to)
  local present, player = ai.room:getPresentPlayers(), ai.player
  if not ai:isEnemy(to) or #present < 3 then return end
  if #present == 3 then
    local remaining = table.find(present, function(p) return p ~= player and p ~= to end)
    if ai:isFriend(remaining) then return 8 end
  end
end

function M.active(ai, key, fields, extra)
  local name, player = extra.skillName, ai.player
  if key == "#qiao_shi_pindi" then return choosePindi(ai) end
  if key == "#qiao__skill_han047_2-remove" then
    return Requests.targets(ai, function(to) return jingchu(ai, to) end)
  end
  if key == "#qiao_zhuanzheng" then
    -- Swapping changes which positional skill can trigger. Require both
    -- visible cards and enough distance for the deputy attack to matter.
    local attack = player.general == huFen and Slash.cardCapacity(ai, Fk:cloneCard(slash), { future = true, far = true })
    local roomLeft = player:getHandcardNum() < player:getMaxCards()
    local want = (attack and attack > 0 and player.hp > 1 and roomLeft)
      or (player.deputyGeneral == huFen and (player.hp <= 1 or not roomLeft))
    return Requests.targets(ai, function(to)
      if to == player then return want and 2 or nil end
      if not ai:isFriend(to) then return end
      local pair = Shi.pairs(ai.room, player, to, player.deputyGeneral, to.deputyGeneral)[1]
      local value = pair and exchangeValue(ai, pair[1], pair[2])
      if value and value >= 1.5 then return value end
    end)
  end
  if key == "#qiao_suoling-black" then
    local to = targetFromPrompt(ai, fields)
    local enemy = ai:isEnemy(to)
    local safety = to and player.hp <= 2 and not ai:isFriend(to)
    local budget = enemy and 6 or (safety and 3)
    if budget and Cost.select(ai, 2, budget) then return Requests.reply(ai) end
    return ""
  end
  if key == "#qiao_xizhen-cost" then
    local enemies = #table.filter(ai.room:getPresentPlayers(), function(to) return ai:isEnemy(to) end)
    local attack = Slash.plan(ai, { safe = Cards.safeDamage })
    local budget = (attack.free + math.min(attack.normal, attack.limit) > 0) and math.min(4, 1 + enemies * 2)
      or (enemies >= 3 and 2)
    if budget and Cost.discard(ai, 1, budget) then return Requests.reply(ai) end
    return ""
  end
  if key == "#qiao__han001_zhuanpeng-pay" or key == "#qiao__han001_zhuanpeng-give" then
    local frame = Requests.context(ai, name)
    local aim = frame and frame.data
    local budget
    if key == "#qiao__han001_zhuanpeng-pay" then
      budget = avoidDamageBudget(ai, aim)
    elseif aim and ai:isEnemy(aim.to) then
      budget = Damage.cardAmount(aim.card, aim.use, player) >= aim.to.hp + aim.to.shield and 5 or 2.5
    end
    if budget and Cost.select(ai, 1, budget) then return Requests.reply(ai) end
    return ""
  end
  if key == "#qiao_bingzheng-give" or key == "#qiao__skill_han047_2-give" then
    local target = targetFromPrompt(ai, fields)
    if (key ~= "#qiao_bingzheng-give" or (ai:isFriend(target) and target:getHandcardNum() <= 2)) and
      Cost.select(ai, 1, key == "#qiao_bingzheng-give" and 2 or nil) then return Requests.reply(ai) end
    return ""
  end
  if key == "#qiao__wei044_discard" or key == "#qiao_pindi-discard" or key == "#qiao_bingzheng-discard" then
    if Cost.discard(ai, extra.min_num or 1) then return Requests.reply(ai) end
    return ""
  end
  if key == "#qiao_shandi-second" then
    local first = targetFromPrompt(ai, fields)
    return Requests.targets(ai, function(to) return exchangeScore(ai, first, to) end)
  end
  if key ~= "#qiao_bingqing_choose_players" then return end
  if name == "qiao__skill_han051_2" or name == "qiao__skill_wu032_2" or name == "qiao__skill_wu027_1" then
    return Requests.targets(ai, function(to)
      if ai:isFriend(to) and not to:isHandAreaSealed() then return 8 - to:getHandcardNum() + (to == player and 10 or 0) end
    end, extra.num)
  end
  if name == "qiao__skill_shu048_1" then
    return Requests.targets(ai, function(to)
      local size = to:getHandcardNum()
      if ai:isFriend(to) and not to:isHandAreaSealed() then return 3 + (size + 1 == to.hp and 3 or 0) end
      if ai:isEnemy(to) and size > 0 then return 3 + (size - 1 == to.hp and 3 or 0) end
    end)
  end
  if name == "qiao__skill_shu048_2" then
    local context = Requests.context(ai, name)
    local use = context and context.data.use
    if not use then return "" end
    local cost = context.event and context.event:getCostData(context.skill)
    if cost and cost.pending then
      local victim = bestCollateralVictim(ai, ai:getEnabledTargets())
      return Requests.targets(ai, function(to) if to == victim then return 1 end end)
    end
    return Requests.targets(ai, function(to)
      if table.contains(use.tos, to) then
        return Adaptation.targetScore(ai, use.card, to, "#qiao_adaptation_remove_target", use)
      end
      if use.card.name ~= collateral then return Cards.scoreTarget(ai, use.card, to, use) end
      if ai:isEnemy(to) and bestCollateralVictim(ai, ExtraTargets.subCandidates(ai.room, use, to)) then
        return ai:hostileScore(to, 4)
      end
    end)
  end
  if name == "qiao__skill_qun033_2" then
    local reply = Requests.targets(ai, function(to) return ai:hostileScore(to, 20 - to.hp) end, extra.num)
    if reply ~= "" then return reply end
    -- An ally or human may already have given the equipment. A compulsory
    -- victim with no known enemy in range should take the least harmful hit.
    return Requests.targets(ai, function(to)
      return (ai:isFriend(to) and 0 or 10) + math.min(6, to.hp + to.shield)
    end)
  end
  if name == chuming then
    return Requests.targets(ai, function(to) return ai:hostileScore(to, 20 - to.hp) end)
  end
  if name == "qiao__skill_shu091_2" then
    return Requests.targets(ai, function(to)
      if ai:isFriend(to) then return 3 + math.max(0, to.hp - player.hp) end
    end)
  end
  if name == "qiao__skill_qun079_2" then
    local damaged = {}
    for _, event in ipairs(ai.room.logic:getActualDamageEvents(math.huge, Util.TrueFunc, Player.HistoryTurn)) do
      if Shi.present(event.data.to) then table.insertIfNeed(damaged, event.data.to) end
    end
    return Requests.targets(ai, function(to)
      local _, value = Cards.bestCandidate(ai, damaged, function(other)
        if other ~= to then return exchangeScore(ai, to, other) end
      end)
      return value
    end)
  end
  if name == "qiao__skill_wei044_2" then
    local dying = eventTarget(ai, name)
    return Requests.targets(ai, function(to) return exchangeScore(ai, to, dying, true) end)
  end
end

function M.choice(ai, name, choices, fields)
  local key, player = fields[1], ai.player
  if key == "#qiao__han001_pick_trick" then
    for _, tactic in ipairs({ "qiao__strengthen_state", "qiao__restore_heartland", "qiao__command_world" }) do
      if table.contains(choices, tactic) then return tactic end
    end
    return choices[1]
  end
  if name == pindi then
    local _, effect = Requests.context(ai, name)
    local to = effect and ((effect.tos or {})[1] or (effect.cost_data and (effect.cost_data.targets or {})[1]))
    local prefix = ai:isFriend(to) and "qiao_pindi_draw" or "qiao_pindi_discard"
    return table.find(choices, function(choice) return choice:startsWith(prefix) end)
  end
  if name == "qiao__skill_shu048_1" then
    local _, effect = Requests.context(ai, name)
    local to = effect and effect.cost_data and effect.cost_data.to
    return ai:isFriend(to) and "draw1" or "discard1"
  end
  if name == "qiao__skill_qun033_1" then
    local target = eventTarget(ai, name) or ai.room.current
    local id, value
    if target then id, value = bestQieting(ai, target, target:getCardIds("e")) end
    return id and (value > 3 or player:isHandAreaSealed()) and "qiao_qieting_equip" or "draw1"
  end
  if name == "qiao__skill_qun079_1" then
    local current = ai.room.current
    if current and current ~= player and not ai:isFriend(current) and
      (player.hp <= 2 or player:getHandcardNum() > 0 and current:getHandcardNum() > 1) then return "discard" end
    return "qiao_xizhen_ban"
  end
  if key == "#qiao_duduan" then
    if table.contains(choices, "jink") then
      local hit = Damage.effect(ai, player)
      if hit and Damage.acceptIncoming(ai, hit, 0) then return "jink" end
      return "Cancel"
    end
    local frame = Requests.context(ai, name)
    if frame and frame.data and not frame.data.eventData
      and not table.find(player:getCardIds("h"), function(id) return Fk:getCardById(id).trueName == "slash" end) then return "slash" end
    return "Cancel"
  end
  if key == "#qiao__wei044_prompt" then
    local context = Requests.context(ai, name)
    local source = context and context.data.from
    local diff = source and source:getHandcardNum() - player:getHandcardNum() or 0
    if player:isWounded() and (player.hp <= 0 or (player.hp == 1 and diff >= 3 and ai:isEnemy(source)))
      and table.contains(choices, "qiao__wei044_remove") then return "qiao__wei044_remove" end
    if diff > 0 then return "qiao__wei044_draw" end
    return "Cancel"
  end
  if name == chuming then
    local _, effect = Requests.context(ai, "qiao__chuming_other&")
    local target = effect and effect.tos[1]
    if target and table.contains(choices, collateral) then
      local use = { from = player, card = Fk:cloneCard(collateral) }
      if bestCollateralVictim(ai, ExtraTargets.subCandidates(ai.room, use, target)) then return collateral end
    end
    return "qiao__dismantlement"
  end
  if choices[1] and choices[1]:startsWith("qiao_shi_exchange:") then
    local frame, effect = Requests.context(ai, name)
    local data = effect and effect.cost_data or {}
    local first, second = data.first, data.second
    if name == "qiao__skill_wei044_2" then first, second = player, frame and frame.target end
    if name == "qiao__skill_jin066_3" then first, second = effect and effect.from, player end
    if name == "qiao__skill_shu091_2" then first = player end
    if name == "qiao__skill_wu027_1" or name == "qiao__skill_han047_2" then first, second = player, effect and effect.from end
    local best, score
    for _, selected in ipairs(choices) do
      local entries = selected:split(":")
      if entries[4] and first then
        local owner = second or table.find(ai.room:getPresentPlayers(), function(to)
          return to ~= first and (to.general == entries[5] or to.deputyGeneral == entries[5])
        end)
        if owner then
          local value = exchangeValue(ai,
            { player = first, general = entries[4], isDeputy = first.deputyGeneral == entries[4] },
            { player = owner, general = entries[5], isDeputy = owner.deputyGeneral == entries[5] },
            name == "qiao__skill_wei044_2")
          if value and (not score or value > score) then best, score = selected, value end
        end
      end
    end
    if table.contains(choices, "Cancel") then return score and score >= 1.5 and best or "Cancel" end
    return best or choices[1]
  end
end

function M.chosen(ai, key, target, areas)
  if key == "#qiao_qieting-equip" then return bestQieting(ai, target, Requests.publicCards(areas)) end
  if key == "#qiao_xizhen-card" and type(areas) == "string" then return Removal.pick(ai, target, areas, false) end
end

local play = {}

function M.consumeEdict(ai)
  local skill = Fk.skills[Edict.CONSUME]
  -- The dashboard omits the skill. Its mark submits this standard reply.
  if ai.player:hasSkill(Edict.CONSUME) and skill:isEffectable(ai.player) and skill:canUse(ai.player)
    and ai.player:usedSkillTimes(Edict.CONSUME, Player.HistoryPhase) == 0 then
    return { card = { skill = Edict.CONSUME, subcards = {} }, targets = {} }
  end
end

play[Edict.BANNER] = function(ai)
  local holder = Edict.availableHolder(ai.room, ai.player)
  if not holder or not ai:isFriend(holder) then return "" end
  local suits = Edict.pileSuits(holder:getPile(Edict.PILE))
  if #suits == 4 or #Edict.trickNames(ai.room) == 0 then return "" end
  while true do
    local budget = #suits >= 3 and 3.5 or (ai.player:getHandcardNum() > ai.player:getMaxCards() and 3 or 2)
    local id = Cost.cheapest(ai, function(cardId)
      local suit = Fk:getCardById(cardId, true).suit
      return suit >= Card.Spade and suit <= Card.Diamond and not table.contains(suits, suit)
        and Cost.value(ai, cardId) <= budget
    end)
    if not id then break end
    ai:selectCard(id, true)
    table.insert(suits, Fk:getCardById(id, true).suit)
  end
  return Requests.reply(ai)
end

function play.qiao__skill_wei035_1(ai)
  return choosePindi(ai)
end

function play.qiao__skill_han051_1(ai)
  local id, cost = Cost.cheapest(ai)
  if not id or cost > 3 then return "" end
  ai:selectCard(id, true)
  -- Gift to a teammate who can attack, or start with an enemy who must
  -- either spend two cards or risk the counterattack from another enemy.
  local first, second, best
  for _, to in ipairs(ai:getEnabledTargets()) do
    if ai:isFriend(to) or ai:isEnemy(to) and to:getHandcardNum() <= 2 then
      ai:selectTarget(to, true)
      local victim, score = Cards.bestCandidate(ai, ai:getEnabledTargets(), function(other)
        if other ~= ai.player and hostileSlash(ai, to, other) then
          if ai:isFriend(to) and to:getHandcardNum() < 1 then return end
          if ai:isEnemy(to) and not hostileSlash(ai, other, to) then return end
          return 10 - other.hp + (ai:isFriend(to) and 3 or 0)
        end
      end)
      ai:selectTarget(to, false)
      if score and (not best or score > best) then first, second, best = to, victim, score end
    end
  end
  if not first then return "" end
  ai:selectTarget(first, true)
  ai:selectTarget(second, true)
  return Requests.reply(ai)
end

function play.qiao__skill_qun033_2(ai)
  local player = ai.player
  local count = #player:getCardIds("e")
  if count == 0 or player.hp > 2 or not player:isWounded() then return "" end
  return Requests.targets(ai, function(to)
    if not ai:isFriend(to) or to:isHandAreaSealed() then return end
    local victims = #table.filter(ai.room:getPresentPlayers(), function(victim)
      return ai:isEnemy(victim) and to:inMyAttackRange(victim)
    end)
    if victims >= 1 and (count <= 2 or player.hp == 1) then return math.min(count, victims) end
  end)
end

function play.qiao__skill_shu091_1(ai)
  local plan = Slash.plan(ai, { safe = Cards.safeDamage })
  if plan.free + math.min(plan.normal, plan.limit) == 0 and ai.player:getHandcardNum() <= 4 then return Requests.reply(ai) end
  return ""
end

play["qiao__chuming_other&"] = function(ai)
  local id, cost = Cost.cheapest(ai)
  if not id or cost > 2.5 then return "" end
  ai:selectCard(id, true)
  return Requests.targets(ai, function(to)
    if not ai:isEnemy(to) then return end
    local _, value = Removal.pick(ai, to, "he", false)
    if value and value >= 5.5 then return ai:hostileScore(to, value) end
    local use = { from = ai.player, card = Fk:cloneCard(collateral) }
    if bestCollateralVictim(ai, ExtraTargets.subCandidates(ai.room, use, to)) then
      return ai:hostileScore(to, 4)
    end
  end)
end

function M.play(ai, name)
  if not play[name] then return end
  ai:selectSkill(name, true)
  local reply = play[name](ai)
  if reply ~= "" then return reply end
  ai:unSelectAll()
end

return M
