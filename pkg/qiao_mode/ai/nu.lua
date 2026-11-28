local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Removal = require "packages.qiao.pkg.qiao_mode.ai.removal"
local Board = require "packages.qiao.pkg.qiao_mode.ai.board"
local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"
local Slash = require "packages.qiao.pkg.qiao_mode.ai.slash_supply"
local CardTargets = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local Placement = require "packages.qiao.pkg.qiao_mode.rules.mount_placement"
local ExtraTargets = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Nu = require "packages.qiao.pkg.qiao_bingqing.nu"

local M = {}
local tijun, shizhong = "qiao__skill_jin067_1", "qiao__skill_jin067_2"
local gongqi, chiyuan, shanji = "qiao__skill_wu028_1", "qiao__skill_wu028_2", "qiao__skill_wu048_1"
local jiefanwei, youque = "qiao__retinue_skill_jiefanwei", "qiao__skill_qun139_2"

local function cardFor(ai, id)
  local owner = ai.room:getCardOwner(id)
  return owner and owner:getVirtualEquip(id) or Fk:getCardById(id)
end

local function equipmentValue(ai, to, id)
  local card, player = cardFor(ai, id), ai.player
  local kits = Fk.packages.qiao_cards.qiao_cards
  local types = kits.isDualMount(card) and { Card.SubtypeOffensiveRide, Card.SubtypeDefensiveRide } or { card.sub_type }
  local replaces = {}
  for _, subtype in ipairs(types) do
    if not to:hasEmptyEquipSlot(subtype) then
      for _, old in ipairs(to:getEquipments(subtype)) do table.insertIfNeed(replaces, old) end
    end
  end
  local value = 1 + Board.equipScore(card) + (kits.isDualMount(card) and 1.5 or 0)
  for _, old in ipairs(replaces) do value = value - 1 - Board.equipScore(cardFor(ai, old)) end
  if to ~= player and ai.room:getCardArea(id) == Card.PlayerEquip and ai.room:getCardOwner(id) == player then
    value = value - 2 - Board.equipScore(card)
  end
  return value
end

local function pickEquipment(ai, owner, ids, temporary)
  return Requests.bestCard(ids, function(id)
    if not Placement.canPut(ai.player, id) then return end
    local card = cardFor(ai, id)
    local value = equipmentValue(ai, ai.player, id)
    if ai:isEnemy(owner) then
      value = value + Board.equipScore(card) - (Cost.effectable(owner, "qiao__skill_wu008_2") and 2 or 0)
    elseif owner and owner ~= ai.player then
      value = value - 2 - Board.equipScore(card)
    end
    if temporary then
      if card.sub_type == Card.SubtypeArmor and ai:isEnemy(owner) then return value + 2 end
      if card.sub_type == Card.SubtypeWeapon and ai:isEnemy(owner) then return value + 0.5 end
      return value - 3
    end
    return value
  end)
end

local function tijunEquipScore(ai, to, id)
  if not ai:isFriend(to) or not Placement.canPut(to, id, ai.player) then return end
  local value = equipmentValue(ai, to, id)
  if value > 0 then return ai:supportScore(to, value) end
end

local function tijunCardScore(ai, id)
  local owner = ai.room:getCardOwner(id)
  if ai.room:getCardArea(id) == Card.PlayerJudge then
    if ai:isFriend(owner) and owner:canMoveCardInBoardTo(ai.player, id)
      and Board.harmfulDelay(cardFor(ai, id)) then return 5 end
    return
  end
  if owner ~= ai.player or cardFor(ai, id).type ~= Card.TypeEquip then return end
  local _, value = Cards.bestCandidate(ai, ai.room:getPresentPlayers(), function(to) return tijunEquipScore(ai, to, id) end)
  return value
end

local function caixingScore(ai, id)
  local kits = Fk.packages.qiao_cards.qiao_cards
  if not kits.isRideCard(cardFor(ai, id)) then return end
  local owner = ai.room:getCardOwner(id)
  local _, score = pickEquipment(ai, owner, { id })
  return score
end

local function ciValue(ai, general)
  local card = Fk.generals[general]
  if not card then return 0 end
  if card.maxHp >= 4 then return 4 + math.max(0, 4 - ai.player:getHandcardNum()) end
  return 2
end

function M.invoke(ai, name, fields)
  local player, key = ai.player, fields[1]
  if name == tijun then
    for _, to in ipairs(ai.room:getPresentPlayers()) do
      if table.find(to:getCardIds("j"), function(id) return tijunCardScore(ai, id) ~= nil end) then return true end
    end
    return table.find(player:getCardIds("he"), function(id) return tijunCardScore(ai, id) ~= nil end) ~= nil
  end
  if name == shizhong then
    local frame = Requests.context(ai, name)
    local use = frame and frame.data
    if not use then return false end
    local counts = {}
    if not player:isHandAreaSealed() and #use.tos > 0 and table.every(use.tos, function(to)
      local count = Nu.boardCards(to)
      if counts[count] then return false end
      counts[count] = true
      return true
    end) then return true end
    return Nu.boardCards(player) > 0 and table.find(ExtraTargets.candidates(ai.room, use), function(to)
      return Cards.safeDamage(ai, use.card, to, use)
    end) ~= nil
  end
  if name == "qiao__skill_jin076_2" or name == "qiao__retinue_skill_suwei_zhongjun" then
    local frame = Requests.context(ai, name)
    local to = frame and frame.target
    if name == "qiao__skill_jin076_2" then return ai:isFriend(to) and not to:isHandAreaSealed() end
    local slash = Fk:cloneCard("qiao__slash")
    return Cards.safeDamage(ai, slash, to) and table.contains(
      CardTargets.effectCandidates(ai.room, player, slash, CardTargets.bypassDistance()), to)
  end
  if name == "qiao__skill_qun029_2" then
    local to = tonumber(fields[3]) and ai.room:getPlayerById(tonumber(fields[3]))
    local frame = Requests.context(ai, name)
    if not to and frame then to = frame.data.from == player and frame.data.to or frame.data.from end
    if not ai:isEnemy(to) then return false end
    local _, value = pickEquipment(ai, to, to:getCardIds("e"), true)
    return value ~= nil and value > 2
  end
  if name == "qiao__skill_shu054_1" then
    return table.find(player:getHandlyIds(), function(id)
      local card = Fk:getCardById(id)
      if card.trueName == "slash" then return (Slash.cardCapacity(ai, card, { future = true, safe = Cards.safeDamage }) or 0) > 0 end
      if card.trueName == "peach" then return player:isWounded() end
      return Cards.priority(ai, card) ~= nil and card.trueName ~= "analeptic" and player:canUse(card)
    end) ~= nil
  end
  if name == "qiao__retinue_skill_wudang_feijun" then
    local to = tonumber(fields[3]) and ai.room:getPlayerById(tonumber(fields[3]))
    return ai:isEnemy(to)
  end
  if key == "#qiao__jin001_caixing-invoke" then
    local mounts = table.simpleClone(ai.room.discard_pile)
    for _, to in ipairs(ai.room:getPresentPlayers()) do table.insertTable(mounts, to:getCardIds("e")) end
    local id, value = Requests.bestCard(mounts, function(i)
      if ai.room:getCardArea(i) == Card.DiscardPile and Fk:getCardById(i).name ~= "qiao__linxiao_yuyu" then return end
      return caixingScore(ai, i)
    end)
    local useful = #table.filter(player:getCardIds("h"), function(i)
      local card = Fk:getCardById(i)
      return Cards.priority(ai, card) and card.trueName ~= "analeptic" and player:canUse(card)
    end)
    return id ~= nil and value >= 3 + 2.5 * useful
  end
  if key == "#qiao__jin001_dingfei-invoke" then
    return player.hp <= 2 or player:isKongcheng() or #Ci.cards(player) >= 2
  end
  if key == "#qiao__jin001_banner-invoke" then return true end
  if key == "#qiao__jin001_banner-transfer" then
    local to = tonumber(fields[3]) and ai.room:getPlayerById(tonumber(fields[3]))
    return ai:isFriend(to) and #Ci.cards(player) >= 2 and #Ci.cards(to) == 0
  end
  if key == "#qiao__jin001_banner-prevent-skip" then
    local frame = Requests.context(ai, Ci.SKILL)
    local phase = frame and frame.data.phase
    return phase == Player.Draw or (phase == Player.Play and player:getHandcardNum() >= 2)
  end
end

local function virtualSlash(ai, name, extra)
  local slash = Fk:cloneCard("qiao__slash")
  slash.skillName = name
  local fixed = slash:getFixedTargets(ai.player, extra)
  if fixed and (#fixed == 0 or not table.every(fixed, function(to) return Cards.safeDamage(ai, slash, to) end)) then return "" end
  local priority
  if name == "qiao__skill_wei061_1" then
    local damaged = {}
    for _, event in ipairs(Nu.damageHistory(ai.player)) do
      local to = event.data.to
      if Nu.present(to) then table.insertIfNeed(damaged, to) end
    end
    if #damaged == 1 then priority = damaged[1] end
  end
  return Requests.targets(ai, function(to)
    local value = Cards.scoreTarget(ai, slash, to)
    if value then return value + (to == priority and 5 or 0) end
  end, name == "qiao__skill_jin066_2" and 2 or 1)
end

local function jinu(ai, extra)
  for _ = 1, extra.num do
    local id = Requests.bestCard(ai:getEnabledCards(), function(cardId)
      local card = Fk:getCardById(cardId)
      if #ai:getSelectedCards() >= ai.player:getHandcardNum() - 1 and
        (ai.player.hp <= 2 or card.trueName == "jink" or card.trueName == "peach") then return end
      return Cost.value(ai, cardId) + (card.trueName == "slash" and 1 or 0)
    end)
    if not id then break end
    ai:selectCard(id, true)
  end
  return Requests.reply(ai)
end

local function zhouyou(ai, extra)
  local to = Cards.bestTarget(ai, function(target)
    if ai:isFriend(target) and not target:isHandAreaSealed() then return 20 - target:getHandcardNum() end
    if target:isHandAreaSealed() then return 0 end
    return math.min(7, target:getHandcardNum()) - (ai:isEnemy(target) and 16 or 8)
  end)
  if not to then return "" end
  ai:selectTarget(to, true)
  if Cost.select(ai, extra.max_num) then return Requests.reply(ai) end
  return ""
end

local function shizhongTargets(ai)
  local frame = Requests.context(ai, shizhong)
  local use = frame and frame.data
  if not use then return "" end
  local counts, distinct = {}, true
  for _, to in ipairs(use.tos) do
    local count = Nu.boardCards(to)
    distinct = distinct and not counts[count]
    counts[count] = true
  end
  for _ = 1, Nu.boardCards(ai.player) do
    local to = Cards.bestTarget(ai, function(target)
      if distinct and counts[Nu.boardCards(target)] then return end
      return Cards.scoreTarget(ai, use.card, target, use)
    end)
    if not to then break end
    ai:selectTarget(to, true)
    counts[Nu.boardCards(to)] = true
  end
  return Requests.reply(ai)
end

function M.active(ai, skill, key, fields, extra)
  local name = extra.skillName
  if skill == "virtual_viewas" and (name == "qiao__skill_wei034_1" or name == "qiao__skill_wei061_1"
    or name == "qiao__skill_jin066_2") then
    return virtualSlash(ai, name, extra)
  end
  if key == "#qiao_jinu-store" then return jinu(ai, extra) end
  if skill == "distribution_select_skill" and name == "qiao__skill_han055_2" then return zhouyou(ai, extra) end
  if key == "#qiao_lizhi-give" then
    if Cost.select(ai, 1) then return Requests.reply(ai) end
    return ""
  end
  if key == "#qiao_chiyuan-discard" then
    local to = tonumber(fields[3]) and ai.room:getPlayerById(tonumber(fields[3]))
    if ai:isEnemy(to) and Cost.discard(ai, 1, 2.5) then return Requests.reply(ai) end
    return ""
  end
  if key == "#qiao_xianzhenying-discard" then
    local frame = Requests.context(ai, name)
    local damage = frame and frame.data
    if not damage or not ai:isEnemy(damage.to) then return "" end
    local options = { alreadyChained = damage.chain, source = damage.from, card = damage.card }
    local before = Damage.assess(ai, damage.to, damage.damage, damage.damageType, options)
    local aftermath = Damage.assess(ai, damage.to, damage.damage + 1, damage.damageType, options)
    local lethal = aftermath.enemyDying > before.enemyDying
    if Damage.worth(aftermath) and aftermath.balance >= before.balance
      and (lethal or aftermath.direct > before.direct and before.enemyDying == 0)
      and Cost.discard(ai, 1, lethal and 5 or 3) then return Requests.reply(ai) end
    return ""
  end
  if key == "#askForPindian" and extra.reason == youque then
    local event = ai.room.logic:getCurrentEvent():findParent(GameEvent.Pindian, true)
    local number = event and event.data.fromCard and event.data.fromCard.number or 0
    local id = Requests.bestCard(ai:getEnabledCards(), function(i)
      local point = Fk:getCardById(i).number
      local lost = 0
      if point <= number then
        for _, own in ipairs(ai.player:getCardIds("h")) do
          if Fk:getCardById(own).number > point and not ai.player:prohibitDiscard(own) then lost = lost + Cost.value(ai, own) end
        end
      end
      return -Cost.value(ai, i) - lost + (point == number and 4 or 0) + (point > number and 1 or 0)
    end)
    if id then ai:selectCard(id, true); return Requests.reply(ai) end
    return ""
  end
  if key ~= "#qiao_bingqing_choose_players" then return end
  if name == "qiao__skill_han043_1" then
    return Requests.targets(ai, function(to)
      local _, value = pickEquipment(ai, to, to:getCardIds("e"))
      return value
    end)
  end
  if name == tijun then
    local frame = Requests.context(ai, name)
    local cost = frame and frame.event and frame.event:getCostData(frame.skill)
    return Requests.targets(ai, function(to)
      local value = cost and cost.id and tijunEquipScore(ai, to, cost.id)
      return value or -10 - #to:getCardIds("e")
    end)
  end
  if name == shizhong then return shizhongTargets(ai) end
  if name == "qiao__skill_qun029_1" then
    local slash = Fk:cloneCard("qiao__slash")
    return Requests.targets(ai, function(to) return Cards.scoreTarget(ai, slash, to) end, extra.num)
  end
  if name == gongqi then
    return Requests.targets(ai, function(to) return ai:hostileScore(to, select(2, Removal.pick(ai, to, "he", false)) or 0) end)
  end
end

function M.choice(ai, name, choices)
  if name == "qiao__skill_shu036_1" then
    local frame = Requests.context(ai, name)
    local aim = frame and frame.data
    local to = aim and aim.to
    if ai:isEnemy(to) and Cards.safeDamage(ai, aim.card, to, aim.use, aim.from) then
      if table.contains(choices, "0") then return "0" end
      if to:getHandcardNum() >= 2 and not aim.disresponsive then return "1" end
    elseif to == ai.player and table.contains(choices, "2") then
      local jink = table.find(to:getHandlyIds(), function(id) return Fk:getCardById(id).trueName == "jink" end)
      if not jink and not aim.disresponsive and to.hp + to.shield >= 2 then return "2" end
    end
    return "Cancel"
  end
  if name == "qiao__skill_shu054_2" then
    local frame = Requests.context(ai, name)
    local to = frame and frame.target
    if ai:isFriend(to) and table.contains(choices, "recover") then return "recover" end
    if to == ai.player and to.phase == Player.Play and to:getHandcardNum() <= 1 then
      local plan = Slash.plan(ai, { safe = Cards.safeDamage })
      if plan.free + math.min(plan.normal, plan.limit) > 0 then return "qiao_kangrui_damage" end
    end
    return "Cancel"
  end
  if name == jiefanwei then
    for _, skill in ipairs({ "qiao__skill_wu028_2", shanji, gongqi, "qiao__skill_qun033_2" }) do
      if table.contains(choices, skill) then return skill end
    end
    return choices[1]
  end
end

function M.chosen(ai, key, target, areas)
  if key == "#qiao_bajia-equip" or key == "#qiao_huanjia-equip" then
    return pickEquipment(ai, target, Requests.publicCards(areas), key == "#qiao_huanjia-equip")
  end
  if key == "#qiao_tijun-card" then return Requests.bestCard(Requests.publicCards(areas), function(id) return tijunCardScore(ai, id) end) end
  if key == "#qiao__jin001_caixing-card" then return Requests.bestCard(Requests.publicCards(areas), function(id) return caixingScore(ai, id) end) end
  if key == "#qiao_gongqi-discard" or key == "#qiao_shanji-discard" then
    if type(areas) == "string" then return Removal.pick(ai, target, areas, false) end
  end
  if key == "#qiao_shanji-obtain" then
    return Requests.bestCard(Requests.publicCards(areas), function(id) return Cost.value(ai, id) end)
  end
end

function M.dialog(ai, component)
  if not component or component.url ~= "packages/qiao/pkg/qiao_mode/qml/CiDialog.qml" then return end
  local prop = component.prop
  if prop.mode == "remove" then
    local general
    for _, name in ipairs(prop.cardNames) do
      if not general or ciValue(ai, name) < ciValue(ai, general) then general = name end
    end
    return { general = general }
  end
  if prop.mode == "give" then
    local group, best
    for _, kingdom in ipairs(prop.groupOrder) do
      local names = prop.groups[kingdom] or {}
      if #names > 0 and #names < #prop.cardNames then
        local value = 0
        for _, name in ipairs(names) do value = value + ciValue(ai, name) end
        if not best or value < best then group, best = kingdom, value end
      end
    end
    return { kingdom = group }
  end
end

local play = {}

function play.qiao__skill_qun139_2(ai)
  local id = Requests.bestCard(ai:getEnabledCards(), function(i) return -Fk:getCardById(i).number end)
  if not id or ai.player.hp <= 2 then return "" end
  local number, player = Fk:getCardById(id).number, ai.player
  if number > 3 then return "" end
  local loss = 0
  for _, hand in ipairs(player:getCardIds("h")) do
    if Fk:getCardById(hand).number > number and not player:prohibitDiscard(hand) then loss = loss + Cost.value(ai, hand) end
  end
  if loss > 3 then return "" end
  ai:selectCard(id, true)
  local slash = Fk:cloneCard("qiao__thunder__slash")
  local available = CardTargets.effectCandidates(ai.room, player, slash, CardTargets.bypassDistance())
  return Requests.targets(ai, function(to)
    if to:getHandcardNum() >= 2 and table.contains(available, to) then return Cards.scoreTarget(ai, slash, to) end
  end)
end

function play.qiao__skill_wu028_1(ai)
  local player = ai.player
  local id, value = Requests.bestCard(ai:getEnabledCards(), function(i)
    local price = Cost.value(ai, i)
    local gear = Fk:getCardById(i).type == Card.TypeEquip
    local inHand = ai.room:getCardArea(i) == Card.PlayerHand
    local benefit = 0
    if gear then
      for _, to in ipairs(ai.room:getPresentPlayers()) do
        local _, loss = Removal.pick(ai, to, "he", false)
        if loss then benefit = math.max(benefit, loss) end
      end
    end
    local attack = inHand and table.find(player:getCardIds("h"), function(slashId)
      local slash = Fk:getCardById(slashId)
      return slashId ~= i and slash.trueName == "slash" and table.find(ai.room:getPresentPlayers(), function(to)
        return ai:isEnemy(to) and not player:inMyAttackRange(to) and player:distanceTo(to) <= player:getAttackRange() + 4
          and player:canUseTo(slash, to, { bypass_distances = true }) and Cards.safeDamage(ai, slash, to)
      end)
    end)
    return benefit + (attack and 4 or 0) - price
  end)
  if id and value > 0.5 then ai:selectCard(id, true); return Requests.reply(ai) end
  return ""
end

function play.qiao__skill_wu028_2(ai)
  return Requests.targets(ai, function(to)
    if not ai:isFriend(to) or to:isHandAreaSealed() then return end
    local draws = 0
    for _, actor in ipairs(ai.room:getPresentPlayers()) do
      if actor:inMyAttackRange(to) then
        draws = draws + (ai:isFriend(actor) and 1 or (#actor:getEquipments(Card.SubtypeWeapon) == 0 and 0.75 or 0.5))
      end
    end
    if draws >= 2.5 or (to.hp <= 1 and to:isKongcheng() and draws >= 1.75) then
      return 3 * draws - 0.5 * to:getHandcardNum() - to.hp
    end
  end)
end

function play.qiao__skill_wu048_1(ai)
  local id, cost = Cost.cheapest(ai)
  if not id then return "" end
  ai:selectCard(id, true)
  return Requests.targets(ai, function(to)
    local _, value = Removal.pick(ai, to, "he", false)
    if value and value > cost + 1 then return ai:hostileScore(to, value) end
  end)
end

function play.qiao__retinue_skill_jiefanwei(ai)
  local skill = Fk.skill_skels[jiefanwei]
  if not Cost.discard(ai, 2, 6) then return "" end
  return Requests.targets(ai, function(to)
    if not ai:isFriend(to) then return end
    local scope = to == ai.player and Player.HistoryPhase or Player.HistoryGame
    local refresh = skill and #skill.qiaoRefreshOptions(to, scope) > 0
    if refresh or to.hp <= 2 then return 5 - to.hp + (refresh and 3 or 0) end
  end)
end

function play.qiao__skill_em_jin001_consume(ai, stage)
  local player = ai.player
  local action = stage == "draw" and "draw" or "maxcards"
  local count = player:getHandcardNum()
  if (action == "draw" and count > 2) or (action == "maxcards" and count <= player:getMaxCards() + 1) then return "" end
  for _, name in ipairs(Ci.cards(player)) do
    if table.contains(Ci.actionsFor(player, name, ai.room), action) then
      ai.handler:updateInteraction({ general = name, action = action })
      return Requests.reply(ai)
    end
  end
  return ""
end

function M.play(ai, name, stage)
  if not play[name] then return end
  ai:selectSkill(name, true)
  local reply = play[name](ai, stage)
  if reply ~= "" then return reply end
  ai:unSelectAll()
end

return M
