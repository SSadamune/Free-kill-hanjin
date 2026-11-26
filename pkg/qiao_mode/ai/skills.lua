local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Triggers = require "packages.qiao.pkg.qiao_mode.ai.trigger_policies"
local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"
local Play = require "packages.qiao.pkg.qiao_mode.ai.play_policies"
local Judgment = require "packages.qiao.pkg.qiao_mode.ai.judgment"
local Board = require "packages.qiao.pkg.qiao_mode.ai.board"
local WuPhases = require "packages.qiao.pkg.qiao_generals.util.wu_phases"

local Adaptation = require "packages.qiao.pkg.qiao_mode.ai.adaptation"

local M = {}

local free = {
  ["#qiao__skill_han002_1-invoke"] = true, -- 诗怨
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

function M.invoke(ai, data)
  local name, prompt = data[1], data[2] or ""
  local fields = prompt:split(":")
  local key, player = fields[1], ai.player
  if free[key] then return true end
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
    return ai:isEnemy(target) and target.hp >= 3 and #target:getCardIds("e") >= 2
      and damage ~= nil and damage.damage == 1
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
  if skill == "#qiao__skill_han007_1_aux" then return Play.minsi(ai) end
  if skill == "#qiao__skill_wu009_1_choose" then return Play.yinghun(ai) end
  if skill == "choose_players_to_move_card_in_board" and (key == "#qiao_wei_move_board" or key == "#qiao_wu_move_board") then
    return Board.choosePlayers(ai)
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
        return Cards.safeDamage(ai, card, ai.room:getPlayerById(targetId))
      end) ~= nil
    end) then return "" end
    return chooseTargets(ai, function(target)
      if Cards.safeDamage(ai, card, target) then return 20 - target.hp end
    end)
  end
  if skill == "choose_players_skill" then
    local use = key == "#qiao__skill_jin012_1-targets" and parentData(ai, GameEvent.UseCard)
    local score, extend = Triggers.targetScore(ai, key, use)
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
      return Adaptation.targetScore(ai, use.card, target, key)
    end)
  end
  if key == "#qiao__skill_wei004_1-choose" or key == "#qiao__skill_wei004_1-invoke" then
    return chooseTargets(ai, function(target)
      if ai:isEnemy(target) then return target:getHandcardNum() end
    end, extra.num)
  end
  if skill == "discard_skill" or skill == "choose_cards_skill" then
    if key == "#axe-invoke" then
      local target = M.promptTarget(ai, fields, 3)
      local effect = parentData(ai, GameEvent.CardEffect)
      local damage = 1 + (effect and effect.additionalDamage or 0)
      if not ai:isEnemy(target) or (effect and not Cards.safeDamage(ai, effect.card, target))
        or (target.hp > damage and damage < 2) then return "" end
      budget = 4
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
      if damage.damageType ~= fk.NormalDamage and damage.to.chained
        and table.find(ai.room:getPresentPlayers(), function(target)
          return target.chained and not ai:isEnemy(target)
        end) then return "" end
      budget = 2
    elseif key == "#qiao__skill_wei001_1-discard" then
      local damage = parentData(ai, GameEvent.Damage)
      local card = damage and damage.card
      if not card then return "" end
      budget = card:getEffectiveId() and Cost.value(ai, card:getEffectiveId()) - 1 or 2
    elseif key == "#fire_attack-discard" then
      local target = M.promptTarget(ai, fields, 2)
      if not Cards.safeDamage(ai, Fk:cloneCard("qiao__fire_attack"), target) then return "" end
      budget = target.hp <= 1 and 3 or 2
    elseif cancelable and extra.skillName ~= "phase_discard" then
      return
    end
    if Cost.select(ai, extra.min_num or 1, budget) then return Requests.reply(ai) end
    return ""
  end
  if key == "#qiao__triblade-invoke" then
    if not Cost.select(ai, 1, 3) then return "" end
    return chooseTargets(ai, function(target)
      if ai:isEnemy(target) and (target.hp <= 1 or
        (target.hp == 2 and ai.player:getHandcardNum() > ai.player:getMaxCards())) then
        return 20 - target.hp
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
      if Cards.safeDamage(ai, slash, target) then return 20 - target.hp end
    end)
  end
end

function M.play(ai)
  local buttons = ai:getEnabledSkills()
  table.sort(buttons)
  for _, name in ipairs(buttons) do
    local reply = Play.play(ai, name)
    if reply then return reply end
  end
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
  if not target or type(areas) ~= "string" or not ai:isEnemy(target) then return end
  local fields = (prompt or ""):split(":")
  local key = fields[1]
  local removal = key == "#qiao__chasing_near-choose-prey" or key == "#qiao__chasing_near-choose-discard"
    or key == "#qiao__skill_qun016_1-card"
    or key == "#qiao_ice_damage_skill-discard" or key == "#qiao_adaptation_discard_equip"
    or (key == "#AskForChooseCard" and (fields[4] == "dismantlement_skill" or fields[4] == "snatch_skill"))
  if removal and areas:find("e", 1, true) then
    local best, bestValue
    for _, id in ipairs(target:getCardIds("e")) do
      local card = target:getVirtualEquip(id) or Fk:getCardById(id)
      local value = card.sub_type == Card.SubtypeArmor and 3
        or card.sub_type == Card.SubtypeDefensiveRide and 2 or 1
      if not bestValue or value > bestValue then best, bestValue = id, value end
    end
    if best then return best end
  end
  if (removal or key == "#qiao__unexpectation-show" or key == "#qiao__skill_wei004_1-take"
      or key == "#qiao__retinue_skill_xiyuanjun-card")
    and areas:find("h", 1, true) and not target:isKongcheng() then
    return -1 -- The engine randomly chooses the hidden hand card.
  end
end

function M.choice(ai, data)
  local choices, _, limits, _, skillName, prompt = table.unpack(data)
  local pick = Triggers.choice(ai, choices, (prompt or ""):split(":"))
  if skillName == "trigger" then
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
  elseif skillName == "qiao__drowning" and ai.player.hp > 2 and #ai.player:getCardIds("e") > 1
    and not ai.player.chained then
    pick = table.find(choices, function(choice) return choice:startsWith("qiao__drowning_damage:") end)
  end
  if pick and table.contains(choices, pick) and limits[1] == 1 then return { pick } end
end

return M
