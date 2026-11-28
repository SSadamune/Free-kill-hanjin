local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Reactions = require "packages.qiao.pkg.qiao_mode.ai.damage_reactions"
local ReactiveReveal = require "packages.qiao.pkg.qiao_mode.ai.reactive_reveal"
local Command = require "packages.qiao.pkg.qiao_mode.ai.command"
local Removal = require "packages.qiao.pkg.qiao_mode.ai.removal"
local Expansion = require "packages.qiao.pkg.qiao_mode.ai.expansion"
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Triggers = require "packages.qiao.pkg.qiao_mode.ai.trigger_policies"
local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"
local Play = require "packages.qiao.pkg.qiao_mode.ai.play_policies"
local SkillEffects = require "packages.qiao.pkg.qiao_mode.ai.skill_effects"
local Judgment = require "packages.qiao.pkg.qiao_mode.ai.judgment"
local Board = require "packages.qiao.pkg.qiao_mode.ai.board"
local WuPhases = require "packages.qiao.pkg.qiao_generals.util.wu_phases"
local ShiVector = require "packages.qiao.pkg.qiao_mode.ai.shi_vector"
local Nu = require "packages.qiao.pkg.qiao_mode.ai.nu"

local Adaptation = require "packages.qiao.pkg.qiao_mode.ai.adaptation"

local M = {}

local free = {
  ["#qiao__skill_han002_1-invoke"] = true, -- 诗怨
  ["#qiao__skill_han001_1-invoke"] = true, -- 天命无可弃手牌
  ["#qiao__skill_han012_1-black"] = true, -- 铸典亮黑牌后摸牌
  ["#qiao__skill_han022_2-invoke"] = true, -- 安境
  ["#qiao__skill_jin014_2-invoke"] = true, -- 夺气
  ["#qiao__skill_qun003_2-invoke"] = true, -- 闭月
  ["#qiao__skill_qun005_1-retrieve"] = true, -- 双雄取牌
  ["#qiao__skill_qun081_2-invoke"] = true, -- 杀绝
  ["#qiao__skill_shu004_2-invoke"] = true, -- 空城
  ["#qiao__skill_shu018b_1-invoke"] = true, -- 生息
  ["#qiao__skill_shu021_3-invoke"] = true, -- 存嗣的获得牌部分
  ["#qiao__skill_wei001_1-invoke"] = true, -- 奸雄的摸牌部分
  ["#qiao__skill_wei007_2-invoke"] = true, -- 洛神
  ["#qiao__skill_wei007_2-repeat"] = true,
  ["#qiao__skill_wei014_1-invoke"] = true, -- 行殇
  ["#qiao__skill_wei032_1-invoke"] = true, -- 精策
  ["#qiao__skill_wu008_2-invoke"] = true, -- 枭姬
  ["#qiao__skill_wu010_1-invoke"] = true, -- 激昂
  ["#qiao__skill_wu010_3-invoke"] = true, -- 魂殇
  ["#qiao__skill_wu012_2-invoke"] = true, -- 酣战
  ["#qiao__breastplate-invoke"] = true, -- 引擎已限定致命或至少两点伤害
  ["#qiao__jinxiu_zhengpao-invoke"] = true,
}

-- Each slot is the index of the affected player in the prompt.
local hostile = {
  ["#qiao__skill_wei002_1-invoke"] = 2, -- 狼顾
  ["#qiao__skill_wei003_1-invoke"] = 2, -- 刚烈
  ["#qiao__wei023-invoke"] = 3, -- 横江
  ["#qiao__skill_wu020_2-invoke"] = 2, -- 破军
  ["#qiao__dragon_phoenix-slash"] = 3,
  ["#qiao__dragon_phoenix-dying"] = 3,
  ["#qiao__retinue_skill_baima_yicong-invoke"] = 2,
  ["#qiao__retinue_skill_xiliang_jingqi-discard"] = 2,
}

function M.promptTarget(ai, fields, index)
  local id = tonumber(fields[index])
  return id and ai.room:getPlayerById(id)
end

local function parentData(ai, kind)
  local event = ai.room.logic:getCurrentEvent()
  local parent = event and event:findParent(kind, true)
  return parent and parent.data
end

function M.retaliationTarget(ai)
  local use = parentData(ai, GameEvent.UseCard)
  return use and use.from
end

function M.invoke(ai, data)
  local name, prompt = data[1], data[2] or ""
  local fields = prompt:split(":")
  local key, player = fields[1], ai.player
  local expansion = Expansion.invoke(ai, key, fields)
  if expansion ~= nil then return expansion end
  if key == "#qiao__skill_wu024_1-invoke" then
    local source, target = M.promptTarget(ai, fields, 2), M.promptTarget(ai, fields, 3)
    return ai:isEnemy(source) and ai:isFriend(target) and target:isWounded()
      and target:getMark("@@command5_effect-turn") == 0
  end
  if key == "#qiao__skill_jin021_2-invoke" then
    return ai:isFriend(M.promptTarget(ai, fields, 3))
  end
  if key == "#qiao__skill_jin021_2-prevent" then
    return ai:isFriend(M.promptTarget(ai, fields, 3))
  end
  if free[key] or key == "#qiao__zhoujun-invoke" then return true end
  if key == "#qiao__skill_jin005_2-invoke" then return Triggers.shunliuWorth(ai) end
  if key == "#qiao__skill_qun008_2-invoke" then
    local frame = Selection.currentCost(player)
    local aim = frame and frame.data
    return aim ~= nil and aim.card ~= nil and Cards.safeDamage(ai, aim.card, aim.to, aim.use)
      and Removal.pick(ai, aim.to, "e", false) ~= nil
  end
  if hostile[key] then return ai:isEnemy(M.promptTarget(ai, fields, hostile[key])) end
  if key == "#qiao__skill_han019_2-invoke" then
    local target = M.promptTarget(ai, fields, 3)
    return ai:isEnemy(target) and target.hp <= 0
  end
  if key == "#qiao__skill_wei008_2-invoke" or key == "#qiao__retinue_skill_huweijun-invoke" then
    return Board.worthMoving(ai)
  end
  if key == "#qiao__skill_wu003_2-invoke" then
    local suits, types = WuPhases.mouduanConditions(player)
    return (suits and types and not player:hasSkill("qiao__skill_wu003_3")) or Board.worthMoving(ai)
  end
  if key == "#qiao__skill_wei017_2-invoke" or key == "#qiao__retinue_skill_fuxin_sishi-give-invoke" then
    return ai:isFriend(M.promptTarget(ai, fields, key == "#qiao__skill_wei017_2-invoke" and 3 or 2))
  end
  local skill = type(name) == "string" and Fk.skills[name]
  local skeleton = skill and skill:getSkeleton()
  local original = skeleton and skeleton.name or name
  if prompt == "" then
    local reveal = ReactiveReveal.invoke(ai, original, Selection.currentCost(player))
    if reveal ~= nil then return reveal end
  end
  local pack = ShiVector.invoke(ai, original, fields)
  if pack == nil then pack = Nu.invoke(ai, original, fields) end
  if pack ~= nil then return pack end
  local decision = Triggers.invoke(ai, original, fields)
  if decision ~= nil then return decision end
  if original == "qiao__eight_diagram_skill" then return true end
  if original == "qiao__kylin_bow_skill" then
    local damage = parentData(ai, GameEvent.Damage)
    return damage ~= nil and ai:isEnemy(damage.to)
  end
  if key == "#qiao__skill_shu016_2-invoke" then
    local hand = player:getCardIds("h")
    return player.hp == 1 and player:isWounded() and #hand == 1 and Cost.value(ai, hand[1]) <= 3
  end
  if key == "#qiao_ice_damage_skill-invoke" then
    local target = M.promptTarget(ai, fields, 3)
    local damage = parentData(ai, GameEvent.Damage)
    if not ai:isEnemy(target) or target.hp < 3 or #target:getCardIds("e") < 2
      or not damage or damage.damage ~= 1 then return false end
    local outcome = Damage.assess(ai, target, damage.damage, damage.damageType, { alreadyChained = damage.chain, source = damage.from })
    return not (outcome.propagates and Damage.worth(outcome))
  end
  if key == "#qiao__skill_jin015_1-invoke" then
    return table.find(player:getCardIds("h"), function(id)
      local card = Fk:getCardById(id)
      if card.trueName ~= "slash" then return false end
      return table.find(card:getAvailableTargets(player, { bypass_distances = true, bypass_times = true }), function(target)
        return Cards.safeDamage(ai, card, target)
      end) ~= nil
    end) ~= nil
  end
end

local chooseTargets = Requests.targets

function M.active(ai, data)
  local skill, prompt, cancelable, extra = table.unpack(data)
  extra = extra or {}
  local fields = (prompt or ""):split(":")
  local key, budget = fields[1], nil
  local pack = ShiVector.active(ai, key, fields, extra)
  if pack == nil then pack = Nu.active(ai, skill, key, fields, extra) end
  if pack ~= nil then return pack end
  local expansion = Expansion.active(ai, key, fields)
  if expansion ~= nil then return expansion end
  if skill == "choose_players_to_move_card_in_board" and key == "#qiao__skill_wu021_2-move" then
    return Board.choosePlayers(ai, "e", function(from, to, id)
      return not table.contains(extra.excludeIds or {}, id) and Bian.canMoveEquipTo(from, to, id, ai.player)
    end)
  end
  if skill == "#qiao__skill_han007_1_aux" then return Play.minsi(ai) end
  if key == "#qiao__skill_wei018_1-place" then return Play.huyuan(ai) end
  if skill == "#command_skill" and key == "#command6-select" then
    return Command.keep(ai) and Requests.reply(ai) or ""
  end
  if key == "#command1-damage" then
    return chooseTargets(ai, function(target) return Command.damageTargetScore(ai, target) end)
  end
  if key == "#qiao__wei024_ask" then
    if not ai.player:canSkip(Player.Draw) or not Cost.select(ai, 1, 1.5) then return "" end
    return chooseTargets(ai, function(target)
      if not target:isHandAreaSealed() then return ai:hostileScore(target, 2) end
    end)
  end
  if skill == "#qiao__skill_wu009_1_choose" then return Play.yinghun(ai) end
  if key == "#qiao__skill_wei006_2-give" then
    if not Cost.select(ai, math.min(2, #ai:getEnabledCards())) then return "" end
    return chooseTargets(ai, Triggers.targetScore(ai, key))
  end
  if skill == "virtual_viewas" and key == "#qiao__skill_shu001_1-basic" then
    for _, name in ipairs({ "qiao__peach", "qiao__slash" }) do
      if table.contains(extra.choices or {}, name) then
        local card = Fk:cloneCard(name)
        card.skillName = extra.skillName
        local target = Cards.bestCandidate(ai, card:getAvailableTargets(ai.player, extra), function(to)
          if name == "qiao__peach" then
            if to == ai.player and to:isWounded() then return 1 end
          else
            return Cards.scoreTarget(ai, card, to)
          end
        end)
        if target then
          return { card = { skill = skill, subcards = {} }, targets = { target.id }, interaction_data = name }
        end
      end
    end
    return ""
  end
  if key == "#qiao__skill_jin022b_2-invoke" then
    local id, cost = Cost.cheapest(ai)
    if not id or cost > 4 then return "" end
    ai:selectCard(id, true)
    local card = Fk:cloneCard("qiao__chasing_near")
    card:addSubcard(id)
    return chooseTargets(ai, function(target)
      if not ai.player:canUseTo(card, target) then return end
      local value = Removal.effectValue(ai, card, target)
      if value and value > cost + 1 then return Cards.scoreTarget(ai, card, target) end
    end)
  end
  if key == "#qiao__retinue_skill_zhoucang-give" then
    local id, score
    for _, material in ipairs(ai:getEnabledCards()) do
      local card = Fk:getCardById(material)
      local value = Cost.value(ai, material) + (card.color == Card.Red and 2 or 0)
      if not score or value > score or (value == score and material < id) then id, score = material, value end
    end
    if not id then return "" end
    ai:selectCard(id, true)
    return chooseTargets(ai, function(target)
      if ai:isFriend(target) and not target:isHandAreaSealed() then return 1 / (1 + target:getHandcardNum()) end
    end)
  end
  if key == "#qiao__skill_qun081_1-invoke" then
    local use = parentData(ai, GameEvent.UseCard)
    if not use or not use.card then return "" end
    local nature = Damage.cardNature(use.card, use)
    local amount = Damage.cardAmount(use.card, use, ai.player) + 1
    local function score(target)
      if ai:isEnemy(target) and Damage.worth(Damage.assess(ai, target, amount, nature,
        { source = ai.player, card = use.card })) then return ai:hostileScore(target, 20 - target.hp) end
    end
    local id, value
    for _, material in ipairs(ai:getEnabledCards()) do
      local owner = ai.room:getCardOwner(material)
      if owner and table.contains((extra.targetsByCard or {})[tostring(material)] or {}, owner.id) and score(owner) then
        local payoff = Board.equipScore(owner:getVirtualEquip(material) or Fk:getCardById(material))
        if not value or payoff > value or (payoff == value and material < id) then id, value = material, payoff end
      end
    end
    if not id then return "" end
    ai:selectCard(id, true)
    return chooseTargets(ai, score)
  end
  if key == "#qiao__halberd-ask" then
    local use = parentData(ai, GameEvent.UseCard)
    if not use or not use.card then return "" end
    local function likelyHit(target)
      return Cards.safeDamage(ai, use.card, target, use) and target:isKongcheng()
        and #target:getEquipments(Card.SubtypeArmor) == 0
    end
    if not table.every(use.tos, likelyHit) then return "" end
    return chooseTargets(ai, function(target)
      if likelyHit(target) then return ai:hostileScore(target, 20 - target.hp) end
    end, #extra.targets)
  end
  if skill == "choose_players_to_move_card_in_board" and (key == "#qiao_wei_move_board" or key == "#qiao_wu_move_board") then
    return Board.choosePlayers(ai)
  end
  if key == "#qiao__skill_jin001_2-use" then
    if not Cost.select(ai, 1, 2, function(id) return Triggers.xingtuMaterial(ai, id) end) then return "" end
    return chooseTargets(ai, function(target) return Triggers.xingtuTarget(ai, target) end)
  end
  if key == "#qiao__skill_wei002_2-ask" or key == "#qiao__skill_qun010_2-ask" then
    return Judgment.choose(ai, key == "#qiao__skill_qun010_2-ask") and Requests.reply(ai) or ""
  end
  if key == "#qiao__skill_wu006_2-invoke" then
    local frame = Selection.currentCost(ai.player)
    local card = frame and frame.data and frame.data.card
    if not card then return "" end
    local byCard = extra.targetsByCard or {}
    if not Cost.select(ai, 1, ai.player.hp <= 1 and 4 or 2, function(id)
      return table.find(byCard[tostring(id)] or {}, function(targetId)
        return Cards.safeDamage(ai, card, ai.room:getPlayerById(targetId), frame.data.use)
      end) ~= nil
    end) then return "" end
    return chooseTargets(ai, function(target)
      if Cards.safeDamage(ai, card, target, frame.data.use) then
        return ai:hostileScore(target, 20 - target.hp)
      end
    end)
  end
  if skill == "choose_players_skill" then
    local use = (key == "#qiao__skill_jin012_1-targets" or key == "#qiao__skill_wu016_1-extra"
      or key == "#qiao__skill_qun002_2-extra")
      and parentData(ai, GameEvent.UseCard)
    local score, extend = Triggers.targetScore(ai, key, use)
    score = score or Expansion.targetScore(ai, key, fields)
    if score then return chooseTargets(ai, score, extend and extra.num or 1) end
  end
  if key == "#qiao_adaptation_support" then
    return Adaptation.support(ai, extra) and Requests.reply(ai) or ""
  end
  if key == "#qiao_adaptation_add_target" or key == "#qiao_adaptation_remove_target"
    or key == "#qiao_adaptation_sub_target" then
    local use = parentData(ai, GameEvent.UseCard)
    if not use then return "" end
    return chooseTargets(ai, function(target)
      return Adaptation.targetScore(ai, use.card, target, key, use)
    end)
  end
  if key == "#qiao__skill_wei004_1-choose" or key == "#qiao__skill_wei004_1-invoke" then
    return chooseTargets(ai, function(target)
      return Removal.handPressure(ai, target)
    end, extra.num)
  end
  if skill == "discard_skill" or skill == "choose_cards_skill" then
    if skill == "choose_cards_skill" and key == "#askForPindian" and extra.reason == "qiao__skill_wu012_1" then
      local pindian = parentData(ai, GameEvent.Pindian)
      if pindian and pindian.from == ai.player then
        local cards = ai:getEnabledCards()
        local id = Play.tianyiCard(ai, cards, true) or Play.tianyiCard(ai, cards)
        if not id then return "" end
        ai:selectCard(id, true)
        return Requests.reply(ai)
      end
    end
    if key == "#qiao__skill_shu007_2-card" then
      local frame = Selection.currentCost(ai.player)
      local best, bestScore
      for _, id in ipairs(ai:getEnabledCards()) do
        local enemyDiscard = frame and table.find(frame.data, function(move)
          return ai:isEnemy(move.proposer) and table.find(move.moveInfo, function(info) return info.cardId == id end)
        end)
        if enemyDiscard then
          local card = ai.player:getVirtualEquip(id) or Fk:getCardById(id)
          local score = ai:hostileScore(enemyDiscard.proposer, Board.equipScore(card))
          if not bestScore or score > bestScore then best, bestScore = id, score end
        end
      end
      if not best then return "" end
      ai:selectCard(best, true)
      return Requests.reply(ai)
    elseif key == "#qiao__skill_wei005_1-discard" then
      if not Triggers.luoyiWorth(ai) then return "" end
      return Cost.select(ai, 1, 2, function(id)
        local name = Fk:getCardById(id).trueName
        return name ~= "slash" and name ~= "duel"
      end) and Requests.reply(ai) or ""
    elseif key == "#qiao__skill_han001_1-discard" then
      budget = 4
    elseif key == "#qiao__skill_han003_1-invoke" then
      local target = M.promptTarget(ai, fields, 3)
      if not ai:isEnemy(target) or not target.faceup
        or not (Quan.hasHiddenGeneral(target) or Quan.canHideGeneralPosition(target, false)
          or Quan.canHideGeneralPosition(target, true)) then return "" end
      budget = 1.5
    elseif key == "#qiao__skill_qun005_1-discard" then
      if not ai.player:canSkip(Player.Play) then return "" end
      local hand = ai.player:getCardIds("h")
      local duel = Fk:cloneCard("qiao__duel")
      local material = function(id)
        local cost = Fk:getCardById(id)
        return cost.color ~= Card.NoColor and table.find(hand, function(other)
          local card = Fk:getCardById(other)
          if card.color == Card.NoColor or card.color == cost.color or card.trueName == "duel"
            or Cost.value(ai, other) > 3 then return false end
          local converted = duel:clone()
          converted:addSubcard(other)
          return table.find(converted:getAvailableTargets(ai.player), function(target)
            return ai:isEnemy(target) and target:isKongcheng()
          end) ~= nil
        end) ~= nil
      end
      return Cost.select(ai, 1, 2, material) and Requests.reply(ai) or ""
    elseif key == "#qiao__skill_jin007_2-give" then
      if not ai:isFriend(M.promptTarget(ai, fields, 3)) or ai.player:isHandAreaSealed() then return "" end
      budget = 5
    elseif key == "#qiao__qun011-dmg" then
      budget = 2
    elseif key == "#qiao__qun011-def" or key == "#qiao__skill_jin004_2-discard" then
      local use = parentData(ai, GameEvent.UseCard)
      local target = key == "#qiao__qun011-def" and M.promptTarget(ai, fields, 3) or ai.player
      if not target or not use or not use.card or not Triggers.protects(ai, use, target) then return "" end
      if key == "#qiao__skill_jin004_2-discard" then
        if target.hp <= 1 or not ai:isEnemy(use.from) or not use.card.is_damage_card
          or Damage.cardAmount(use.card, use, use.from) <= 1 + target.shield then return "" end
        budget = 2
      end
    elseif key == "#qiao__skill_jin010_1-cards" then
      local target = M.promptTarget(ai, fields, 2)
      return Cost.select(ai, 1, 2, function(id) return Triggers.shangshiMaterial(ai, target, id) end)
        and Requests.reply(ai) or ""
    elseif key == "#qiao__skill_wu013_1-place" then
      local suits = table.map(ai.player:getPile("创"), function(id) return Fk:getCardById(id).suit end)
      if Cost.select(ai, 1, nil, function(id) return not table.contains(suits, Fk:getCardById(id).suit) end) then
        return Requests.reply(ai)
      end
    elseif key == "#qiao__retinue_skill_lujiang_shangjia-discard" then
      local isNotSlash = function(id) return Fk:getCardById(id).trueName ~= "slash" end
      local count = extra.min_num or 1
      if #table.filter(ai:getEnabledCards(), isNotSlash) >= count and Cost.select(ai, count, nil, isNotSlash) then
        return Requests.reply(ai)
      end
    elseif key == "#axe-invoke" then
      local target = M.promptTarget(ai, fields, 3)
      local effect = Damage.effect(ai, target)
        or { from = ai.player, to = target, card = Fk:cloneCard("qiao__slash") }
      budget = Triggers.axeBudget(ai, effect)
      if not budget then return "" end
    elseif key == "#qiao__skill_han012_1-recast" or key == "#qiao__taigong_tactics-recast" then
      budget = 2
    elseif key == "#qiao__retinue_skill_jinfanjun-discard" then
      budget = 3
    elseif key == "#qiao__skill_wei009_1-discard-judge" then
      local player = ai.player
      if not table.find(player:getCardIds("j"), function(id)
        return Board.harmfulDelay(player:getVirtualEquip(id) or Fk:getCardById(id))
      end) then return "" end
      budget = 2
    elseif key == "#qiao__skill_wei009_1-discard-discard" then
      if ai.player:getHandcardNum() - ai.player:getMaxCards() < 3 then return "" end
      return Cost.select(ai, 1, 2, function(id)
        return ai.room:getCardArea(id) == Card.PlayerHand
      end) and Requests.reply(ai) or ""
    elseif key == "#qiao__skill_wei016_1-discard" then
      if not ai:isEnemy(M.promptTarget(ai, fields, 3)) then return "" end
      budget = 2
    elseif key == "#qiao__skill_qun012_1-discard" then
      local frame = Selection.currentCost(ai.player)
      local damage = frame and frame.data
      if not damage or not ai:isFriend(damage.to) or not ai:isEnemy(damage.from)
        or not damage.from.faceup then return "" end
      budget = 2
    elseif key == "#qiao__skill_jin012_1-discard" then
      budget = Triggers.ciweiBudget(ai)
      if not budget then return "" end
    elseif key == "#qiao__skill_shu006_2-discard" then
      local sacrifice = ai:getEnabledCards()
      local canJink = table.find(ai.player:getCardIds("h"), function(id)
        local card = Fk:getCardById(id)
        return card.trueName == "jink" and not table.contains(sacrifice, id) and not ai.player:prohibitUse(card)
      end)
      if not canJink then return "" end
      budget = ai.player.hp <= 1 and 6 or 3
    elseif key == "#qiao__retinue_skill_huangjin_leishi-discard" then
      local frame = Selection.currentCost(ai.player)
      local damage = frame and frame.data
      if not damage or damage.chain or not ai:isFriend(damage.from) or not ai:isEnemy(damage.to)
        or damage.damage ~= damage.to.hp + damage.to.shield - 1 then return "" end
      if not Damage.worth(Damage.assess(ai, damage.to, damage.damage + 1, damage.damageType, { source = damage.from })) then return "" end
      budget = 2
    elseif key == "#qiao__skill_wei001_1-discard" then
      local damage = parentData(ai, GameEvent.Damage)
      local card = damage and damage.card
      if not card then return "" end
      budget = card:getEffectiveId() and Cost.value(ai, card:getEffectiveId()) - 1 or 2
    elseif key == "#fire_attack-discard" then
      local target = M.promptTarget(ai, fields, 2)
      if not Cards.safeDamage(ai, Fk:cloneCard("qiao__fire_attack"), target, Damage.effect(ai, target)) then return "" end
      budget = target.hp <= 1 and 3 or 2
    elseif cancelable and extra.skillName ~= "phase_discard" then
      return
    end
    local select = skill == "discard_skill" and Cost.discard or Cost.select
    if select(ai, extra.min_num or 1, budget) then return Requests.reply(ai) end
    return ""
  end
  if key == "#qiao__triblade-invoke" then
    if not Cost.select(ai, 1, 3) then return "" end
    return chooseTargets(ai, function(target)
      if target.hp <= 1 or (target.hp == 2 and ai.player:getHandcardNum() > ai.player:getMaxCards()) then
        return ai:hostileScore(target, 20 - target.hp)
      end
    end)
  end
  if key == "#qiao__taigong_tactics-choose" then
    return chooseTargets(ai, function(target)
      if ai:isFriend(target) and target.chained then return 20 - target.hp end
    end)
  end
  if key == "#qiao__retinue_skill_fuxin_sishi-slash" or key == "#qiao__retinue_skill_fuxin_sishi-slash-invoke" then
    local slash = Fk:cloneCard("qiao__slash")
    return chooseTargets(ai, function(target)
      return Cards.scoreTarget(ai, slash, target)
    end)
  end
end

function M.play(ai, stage)
  if stage == "draw" then
    local reply = ShiVector.consumeEdict(ai)
    if reply then return reply end
  end
  local buttons = ai:getEnabledSkills()
  table.sort(buttons)
  for _, name in ipairs(buttons) do
    if SkillEffects.playsAt(name, stage) then
      local reply = Play.play(ai, name, stage) or Expansion.play(ai, name)
        or ShiVector.play(ai, name) or Nu.play(ai, name, stage)
      if reply then return reply end
    end
  end
end

function M.cooperativeAlliance(ai)
  return Play.alliance(ai, true)
end

function M.fallbackAlliance(ai)
  return Play.alliance(ai, false)
end

function M.arrange(ai, data)
  if data.poxi_type == "qiao_shelie" then
    local remaining, chosen, suits = {}, {}, {}
    local cards = table.connect(table.unpack(data.cards))
    table.sort(cards, function(a, b)
      local va, vb = Cost.value(ai, a), Cost.value(ai, b)
      if va == vb then return a < b end
      return va > vb
    end)
    for _, id in ipairs(cards) do
      local suit = Fk:getCardById(id).suit
      if suit ~= Card.NoSuit and not suits[suit] and #chosen < data.capacities[2] then
        table.insert(chosen, id)
        suits[suit] = true
      else
        table.insert(remaining, id)
      end
    end
    return { remaining, chosen }
  end
  if #data.names ~= 2 or data.names[1] ~= "Top" or data.names[2] ~= "Bottom"
    or data.pattern ~= "." or data.poxi_type ~= "" or ai.room.current ~= ai.player
    or ai.player.phase == Player.Finish or #ai.player:getCardIds("j") > 0 then return end
  local cards = table.connect(table.unpack(data.cards))
  table.sort(cards, function(a, b)
    local va, vb = Cost.value(ai, a), Cost.value(ai, b)
    if va == vb then return a < b end
    return va > vb
  end)
  local top, bottom = {}, {}
  local upper = math.min(data.capacities[1], #cards - data.limits[2])
  local lower = math.max(data.limits[1], #cards - data.capacities[2])
  local topCount = math.max(lower, math.min(2, upper))
  for _, id in ipairs(cards) do
    table.insert(#top < topCount and top or bottom, id)
  end
  return { top, bottom }
end

function M.chosen(ai, data)
  local target, areas, prompt = table.unpack(data)
  if type(target) == "number" then target = ai.room:getPlayerById(target) end
  local key = (prompt or ""):split(":")[1]
  if target then
    local pack = ShiVector.chosen(ai, key, target, areas) or Nu.chosen(ai, key, target, areas)
    if pack then return pack end
  end
  if key == "#qiao__skill_wu022_1-card" and type(areas) == "string" and target then
    return Expansion.diaoduCard(ai, target, target:getCardIds(areas))
  end
  if type(areas) == "table" and target then
    local ids = {}
    if key == "#qiao__retinue_skill_hucheer-choose" or key == "#qiao__skill_wu019_1-card"
      or key == "#qiao_quan_discard_equip" or key == "#qiao_quan_discard_judge" then
      for _, group in ipairs(areas.card_data or {}) do table.insertTable(ids, group[2]) end
      if key ~= "#qiao__retinue_skill_hucheer-choose" then return Expansion.lowestZoneCard(ai, ids) end
      return Expansion.chooseEquip(ai, target, ids)
    end
  end
  if prompt == "#qiao__skill_wu015a_2-give" and type(areas) == "table" then
    local best, value
    for _, group in ipairs(areas.card_data or {}) do
      for _, id in ipairs(group[2]) do
        local score = Cost.value(ai, id)
        if not value or score < value or (score == value and id < best) then best, value = id, score end
      end
    end
    return best
  end
  if prompt == "#qiao__skill_jin001_1-choose" and ai:isEnemy(target) and type(areas) == "table" then
    local best, bestScore
    for _, group in ipairs(areas.card_data) do
      for _, id in ipairs(group[2]) do
        local score = Board.equipScore(target:getVirtualEquip(id) or Fk:getCardById(id))
        if not bestScore or score > bestScore then best, bestScore = id, score end
      end
    end
    return best
  end
  if not target then return end
  if prompt == "#qiao__skill_wei018_1-card" and target == ai.player and type(areas) == "table" then
    local id = Removal.pick(ai, target, "j", false)
    if id and table.find(areas.card_data or {}, function(group) return table.contains(group[2], id) end) then return id end
  end
  if type(areas) ~= "string" then return end
  local fields = (prompt or ""):split(":")
  key = fields[1]
  if key == "#qiao__skill_shu022_2-obtain" then
    local chosen = Removal.pick(ai, target, areas, true)
    if chosen then return chosen end
    if ai:isFriend(target) and not target:isKongcheng() then return -1 end
  elseif key == "#qiao__skill_wu021_1-discard" then
    return Removal.pick(ai, target, areas, false)
  elseif key == "#qiao__em_wu001_jubao-obtain" then
    return Expansion.jubaoCard(ai, target, areas)
  end
  if key == "#qiao__skill_qun006_1-card" then return Removal.pick(ai, target, areas, true) end
  if key == "#qiao__skill_qun008_2-ask" then return Removal.pick(ai, target, "e", false) end
  if key == "#qiao__skill_qun001_2-card" then return Removal.pick(ai, target, areas, false, true) end
  local obtains = key == "#qiao__chasing_near-choose-prey" or key == "#qiao__skill_wei002_1-choose"
    or key == "#qiao__skill_jin011_1-hand"
    or (key == "#AskForChooseCard" and fields[4] == "snatch_skill")
  local removal = obtains or key == "#qiao__chasing_near-choose-discard"
    or key == "#qiao__skill_jin011_1-equip"
    or key == "#qiao__skill_qun016_1-card" or key == "#qiao__skill_wei003_1-discard" or key == "#qiao__skill_shu012_1-discard"
    or key == "#qiao__skill_wei018_1-card" or key == "#qiao__skill_han009_1-discard"
    or key == "#qiao__skill_han009_1-counter" or key == "#qiao__skill_jin005_2-discard"
    or key == "#qiao_ice_damage_skill-discard" or key == "#qiao_adaptation_discard_equip"
    or (key == "#AskForChooseCard" and fields[4] == "dismantlement_skill")
  if removal then
    local id = Removal.pick(ai, target, areas, obtains)
    if id then return id end
  end
  if not ai:isEnemy(target) then return end
  if (removal or key == "#qiao__unexpectation-show" or key == "#qiao__skill_wei004_1-take"
      or key == "#qiao__retinue_skill_xiyuanjun-card")
    and areas:find("h", 1, true) and not target:isKongcheng() then
    return -1 -- The engine randomly chooses the hidden hand card.
  end
end

function M.choice(ai, data)
  local choices, _, limits, _, skillName, prompt = table.unpack(data)
  local fields = (prompt or ""):split(":")
  local pick = ShiVector.choice(ai, skillName, choices, fields) or Nu.choice(ai, skillName, choices)
    or Command.issueChoice(ai, skillName, choices) or Triggers.choice(ai, choices, fields)
    or Expansion.choice(ai, choices, fields)
  if fields[1] == "#qiao__skill_shu008_1-choice" or fields[1] == "#qiao__skill_shu013_1-choice" then
    pick = Triggers.slashChoice(ai, fields, parentData(ai, GameEvent.UseCard))
  elseif fields[1] == "#qiao__skill_wu010_2-choice" then
    pick = Triggers.yingyang(ai, parentData(ai, GameEvent.Pindian))
  end
  if prompt == "#qiao__skill_han009_1-options" then
    local use = parentData(ai, GameEvent.UseCard)
    local to = use and #use.tos == 1 and use.tos[1]
    local _, value
    if to then _, value = Removal.pick(ai, to, "he", false) end
    pick = value and value >= 5 and "#qiao__skill_han009_1-discard" or "#qiao__skill_han009_1-draw"
  elseif skillName == "do_command" then
    pick = Command.choice(ai, choices)
  elseif skillName == "trigger" then
    pick = choices[1]
  elseif skillName == "qiao__restore_heartland_skill" then
    pick = "restore_heartland_draw"
  elseif skillName == "qiao__retinue_skill_qingzhou_jingrui"
    and (prompt or ""):startsWith("#qiao__retinue_skill_qingzhou_jingrui-choose:") then
    local discard = "#qiao__retinue_skill_qingzhou_jingrui-option-discard"
    local damage = "#qiao__retinue_skill_qingzhou_jingrui-option-damage"
    local cheap = table.find(ai.player:getCardIds("h"), function(id)
      return not ai.player:prohibitDiscard(id) and Cost.value(ai, id) <= 4
    end)
    pick = (ai.player.hp <= 2 or cheap) and discard or damage
    if not table.contains(choices, pick) then pick = choices[1] end
  elseif skillName == "qiao__drowning" then
    local player = ai.player
    local effect = Damage.effect(ai, player)
    local loss = Reactions.equipmentLoss(ai)
    local accept, outcome
    if effect then accept, outcome = Damage.acceptIncoming(ai, effect, loss) end
    if outcome and (accept or (not outcome.propagates and not outcome.unsafe
      and player.hp > 2 and loss >= 9)) then
      pick = table.find(choices, function(choice) return choice:startsWith("qiao__drowning_damage:") end)
    else
      pick = "qiao__drowning_throw"
    end
  end
  if pick and table.contains(choices, pick) and limits[1] == 1 then return { pick } end
end

return M
