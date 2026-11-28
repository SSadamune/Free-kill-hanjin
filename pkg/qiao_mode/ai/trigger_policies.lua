local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Reactions = require "packages.qiao.pkg.qiao_mode.ai.damage_reactions"
local Removal = require "packages.qiao.pkg.qiao_mode.ai.removal"
local Chain = require "packages.qiao.pkg.qiao_generals.util.jin_chain"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local M = {}

local function playerAt(ai, fields, index)
  local id = tonumber(fields[index])
  return id and ai.room:getPlayerById(id)
end

local function currentData(ai)
  local frame = Selection.currentCost(ai.player)
  return frame and frame.data
end

local function usableRescue(player)
  return #table.filter(player:getCardIds("h"), function(id)
    local card = Fk:getCardById(id)
    return (card.trueName == "peach" or card.trueName == "analeptic") and not player:prohibitUse(card)
  end)
end

function M.xingtuMaterial(ai, id)
  return ai.room:getCardArea(id) == Card.PlayerHand and Fk:getCardById(id).type == Card.TypeEquip
    and Cost.value(ai, id) <= 2
end

function M.xingtuTarget(ai, target)
  if ai:isFriend(target) and target.hp <= 1 and target:isWounded() then
    local peach = Fk:cloneCard("qiao__peach")
    if not ai.player:prohibitUse(peach) and not ai.player:isProhibited(target, peach) then return 10 - target.hp end
  end
end

function M.luoyiWorth(ai)
  local player = ai.player
  if not player:canSkip(Player.Play) then return false end
  return table.find(player:getCardIds("h"), function(id)
    local card = Fk:getCardById(id)
    if card.trueName ~= "slash" and card.trueName ~= "duel" then return false end
    return table.find(card:getAvailableTargets(player), function(target)
      return target.hp + target.shield == 2 and target:isKongcheng()
        and Cards.safeDamage(ai, card, target)
        and (card.trueName == "duel" or #target:getEquipments(Card.SubtypeArmor) == 0)
    end) ~= nil
  end) ~= nil
end

function M.invoke(ai, original, fields)
  local key, player = fields[1], ai.player
  if original == "qiao__skill_shu007_1" then return true end -- 集智没有自定义提示
  if key == "#qiao__skill_shu004_1-invoke" or key == "#qiao__skill_wei017_1-invoke" then
    return ai.room.current == player and #player:getCardIds("j") == 0
  end
  if key == "#qiao__skill_em_shu001_3-invoke" or key == "#qiao__skill_shu010_2-invoke" then
    return player.hp <= 0 and usableRescue(player) < 1 - player.hp
  end
  if key == "#qiao__skill_em_shu001_3-draw" then return true end
  if key == "#qiao__skill_shu018b_2-invoke" then return ai:isFriend(playerAt(ai, fields, 3)) end
  if key == "#qiao__skill_shu002_1-invoke" then
    return Cards.safeDamage(ai, Fk:cloneCard("qiao__drowning"), playerAt(ai, fields, 2))
  end
  if key == "#qiao__skill_jin001_1-invoke" then
    local target = playerAt(ai, fields, 3)
    return ai:isEnemy(target) and not target:hasSkill("qiao__skill_wu008_2")
  end
  if key == "#qiao__skill_jin002_2-invoke" then
    local damage = currentData(ai)
    local to = damage and damage.to
    if not ai:isEnemy(to) or damage.chain then return false end
    local required = to.hp + to.shield
    return damage.damage < required and damage.damage * 2 >= required
      and Damage.worth(Damage.assess(ai, to, damage.damage * 2, damage.damageType, { source = damage.from }))
  end
  if key == "#qiao__skill_jin009_1-invoke" then
    local suit = tonumber(fields[2])
    local use = currentData(ai)
    if not use or not use.card or not suit then return false end
    local used = Card:getIdList(use.card)
    return not table.find(player:getCardIds("h"), function(id)
      return not table.contains(used, id) and Fk:getCardById(id).suit == suit
    end)
  end
  if key == "#qiao__skill_wu014_1-invoke" then
    local draw = currentData(ai)
    return draw ~= nil and type(draw.n) == "number" and draw.n + 2 + player:getHandcardNum() <= 5
  end
  if key == "#qiao__skill_wu003_3-invoke" then
    return not Cost.effectable(player, "qiao__skill_wu005_1")
      and not (player:getHandcardNum() <= 1 and Cost.effectable(player, "qiao__skill_wu014_1"))
  end
  if key == "#qiao__skill_shu011_3-view" then
    return ai:isEnemy(ai.room.current) and not ai.room.current:isKongcheng()
  end
  if key == "#qiao__skill_wei006_2-invoke" then
    local score = M.targetScore(ai, "#qiao__skill_wei006_2-give")
    return table.find(ai.room:getPresentPlayers(), function(target) return score(target) ~= nil end) ~= nil
  end
  if key == "#qiao__skill_em_qun010_2-invoke" then
    return ai.room.current == player and player.phase < Player.Draw and #player:getCardIds("j") == 0
  end
  if key == "#qiao__skill_qun006_1-invoke" then
    local gains = false
    for _, other in ipairs(ai.room:getOtherPlayers(player, false)) do
      if #other:getCardIds("hej") > 0 then
        if not Removal.pick(ai, other, "hej", true) then return false end
        gains = true
      end
    end
    return gains
  end
  if key == "#qiao__skill_wei014_2-invoke" then
    local score = M.targetScore(ai, key)
    return table.find(ai.room:getOtherPlayers(player, false), function(target) return score(target) ~= nil end) ~= nil
  end
  if key == "#qiao__skill_han018_1-invoke" then
    local count = tonumber(fields[4])
    if not count or count < 1 or player:isHandAreaSealed() then return false end
    local dealt = 0
    for _, event in ipairs(ai.room.logic:getActualDamageEvents(math.huge, function(damage)
      return damage.data.from == player
    end, Player.HistoryTurn)) do
      dealt = dealt + event.data.damage
    end
    return dealt >= count or Cost.zhaxiangTrade(player) or (player.hp >= 3 and count >= 3)
  end
end

local allyDrawTargets = {
  ["#qiao__skill_han015_3-target"] = true, -- 修体
  ["#qiao__skill_wei013_2-choose"] = true, -- 节命
}
local allyMultiTargets = {
  ["#qiao__skill_wei011_2-target"] = true, -- 励战
  ["#qiao__skill_shu014_2-choose"] = true, -- 再起
}
local enemyDamageTargets = {
  ["#qiao__skill_shu005_2-target"] = true, -- 突阵
  ["#qiao__skill_shu005_2-invoke"] = true,
  ["#qiao__skill_jin011_1-damage"] = true,
}

function M.protects(ai, use, player)
  return Cards.isHarmful(use.card) and player:isAlive() and ai:isFriend(player)
    and not table.contains(use.nullifiedTargets or {}, player)
end

function M.targetScore(ai, key, use)
  if key == "#qiao__skill_han011_2-target" or key == "#qiao__skill_han011_2-invoke" then
    -- The death skill already restricts the candidates to its owner's faction.
    return function(target)
      if not target:isHandAreaSealed() then return 1 / (1 + target:getHandcardNum()) end
    end
  end
  if key == "#qiao__skill_qun002_2-extra" then
    return function(target)
      if use and use.card and ai:isFriend(use.from) and target:isKongcheng()
        and Cards.safeDamage(ai, use.card, target, use) then
        return ai:hostileScore(target, 20 - target.hp)
      end
    end, true
  end
  if key == "#qiao__skill_jin008_1-owner" or key == "#qiao__skill_jin008_1-invoke"
    or key == "#qiao__skill_wu015a_2-owner" or key == "#qiao__skill_wu015a_2-invoke" then
    local yishi = key:startsWith("#qiao__skill_jin008_1")
    local moves = currentData(ai)
    return function(target)
      if not moves or (yishi and not ai:isFriend(target)) then return end
      local values = {}
      for _, move in ipairs(moves) do
        if (yishi and move.proposer or not yishi and move.from) == target
          and move.toArea == Card.DiscardPile and move.moveReason == fk.ReasonDiscard then
          for _, info in ipairs(move.moveInfo or {}) do
            if ai.room:getCardArea(info.cardId) == Card.DiscardPile then
              table.insert(values, Cost.value(ai, info.cardId))
            end
          end
        end
      end
      table.sort(values)
      if ai:isFriend(target) and not target:isHandAreaSealed() and #values > 0 then return values[#values] end
      if not ai.player:isHandAreaSealed() and #values > 1 then
        local gain = 0
        for index = #values, math.max(2, #values - (yishi and 0 or 2)), -1 do gain = gain + values[index] end
        if target == ai.player or target:isHandAreaSealed() or gain > values[1] + 1 then return gain end
      end
    end
  end
  if key == "#qiao__skill_han016_1-target" or key == "#qiao__skill_han016_1-invoke" then
    local slash = Fk:cloneCard("qiao__slash")
    return function(target) return Cards.scoreTarget(ai, slash, target) end
  end
  if key == "#qiao__skill_jin013_1-turn" or key == "#qiao__skill_jin013_1-turn-invoke" then
    return function(target)
      if not target.chained then return ai:hostileScore(target, 20 - target.hp) end
    end, true
  end
  if key == "#qiao__skill_wei006_2-give" or key == "#qiao__skill_wei006_2-rest" then
    return function(target)
      if ai:isFriend(target) and not target:isHandAreaSealed() then
        return target == ai.player and 20 or 1 / (target:getHandcardNum() + 1)
      end
    end
  end
  if key == "#qiao__skill_wei014_2-choose" or key == "#qiao__skill_wei014_2-invoke" then
    return function(target)
      if ai:isFriend(target) and target ~= ai.player and not target.faceup
        and not target:isHandAreaSealed() then return 20 - target:getHandcardNum() end
      if target.faceup and #target:getCardIds("e") + target:getHandcardNum() <= 1 then
        return ai:hostileScore(target, 8)
      end
    end
  end
  if key == "#qiao__skill_wu016_1-extra" then
    return function(target)
      if use and use.card and Cards.safeDamage(ai, use.card, target, use) then
        return ai:hostileScore(target, 20 - target.hp)
      end
    end
  end
  if key == "#qiao__skill_wei018_1-target" or key == "#qiao__skill_wei018_1-invoke" then
    return function(target)
      local _, score = Removal.pick(ai, target, "hej", false)
      if score then return ai:isEnemy(target) and ai:hostileScore(target, score) or score end
    end
  end
  if key == "#qiao__skill_han009_1-target" or key == "#qiao__skill_han009_1-invoke" then
    return function(target)
      local _, score = Removal.pick(ai, target, "he", false)
      return ai:hostileScore(target, score or 0)
    end
  end
  if key == "#qiao__skill_wu013_2-target" or key == "#qiao__skill_wu013_2-invoke" then
    local trade = Cost.zhaxiangTrade(ai.player)
    return function(target)
      local hand = target:getHandcardNum()
      if trade and ai:isFriend(target) and hand <= 1 then return 2 - hand end
    end
  end
  if key == "#qiao__retinue_skill_xiyuanjun-target" or key == "#qiao__retinue_skill_xiyuanjun-invoke" then
    local frame = Selection.currentCost(ai.player)
    local current = frame and frame.target
    return function(target)
      if ai:isFriend(current) and current:inMyAttackRange(target) then
        return ai:hostileScore(target, 20 - target.hp)
      end
    end
  end
  if allyDrawTargets[key] then
    return function(target)
      local missing = key == "#qiao__skill_wei013_2-choose" and Reactions.jiemingMissing(target)
        or target.maxHp - target:getHandcardNum()
      if ai:isFriend(target) and missing > 0 then return missing end
    end, key == "#qiao__skill_han015_3-target"
  end
  if allyMultiTargets[key] then
    return function(target)
      if ai:isFriend(target) then return 20 - target:getHandcardNum() end
    end, true
  end
  if key == "#qiao__skill_shu016_1-target" or key == "#qiao__skill_shu016_1-invoke" then
    return function(target)
      if ai:isFriend(target) then return 30 - target.hp end
    end
  end
  if key == "#qiao__skill_qun010_1-target" then
    return function(target)
      if ai:isEnemy(target) and Damage.worth(Damage.assess(ai, target, 2, fk.ThunderDamage, { source = ai.player })) then
        return ai:hostileScore(target, 20 - target.hp)
      end
    end
  end
  if enemyDamageTargets[key] then
    return function(target)
      return ai:hostileScore(target, 20 - target.hp)
    end
  end
  if key == "#qiao__skill_han008_2-target" or key == "#qiao__skill_han008_2-invoke" then
    local aim = currentData(ai)
    return function(target)
      if aim and aim.card and Cards.safeDamage(ai, aim.card, target, aim.use) then
        return ai:hostileScore(target, 20 - target.hp)
      end
    end
  end
  if key == "#qiao__skill_qun016_1-target" or key == "#qiao__skill_qun016_1-invoke" then
    return function(target)
      local _, payoff = Removal.pick(ai, target, "he", false)
      if ai:isEnemy(target) and payoff then return ai:hostileScore(target, payoff) end
    end
  end
  if key == "#qiao__skill_jin012_1-targets" and use and use.card then
    return function(target)
      if M.protects(ai, use, target) then return 20 - target.hp end
    end, true
  end
end

function M.shangshiMaterial(ai, target, id)
  local card = Fk:cloneCard("qiao__ice__slash")
  card.skillName = "qiao__skill_jin010_1"
  card:addSubcard(id)
  return Cards.safeDamage(ai, card, target) and not ai.player:prohibitUse(card)
    and not ai.player:isProhibited(target, card)
end

function M.slashChoice(ai, fields, use)
  local target = playerAt(ai, fields, 2)
  if fields[1] == "#qiao__skill_shu008_1-choice" then
    local noResponse = "#qiao__skill_shu008_1-disresponsive"
    if not use or not use.card or not ai:isEnemy(target) then return noResponse end
    local nature = Damage.cardNature(use.card, use)
    local amount = Damage.cardAmount(use.card, use, ai.player)
    local boosted = Damage.assess(ai, target, amount + 1, nature, { source = ai.player, card = use.card })
    if target:isKongcheng() and Damage.worth(boosted) then return "#qiao__skill_shu008_1-damage" end
    return noResponse
  end
  local nullify = "#qiao__skill_shu013_1-nullify"
  if not use or not use.card or not Cards.safeDamage(ai, use.card, target, use) then return nullify end
  local budget = target.hp + target.shield <= Damage.cardAmount(use.card, use, ai.player) and 4 or 2
  if table.find(ai.player:getCardIds("he"), function(id)
    return Fk:getCardById(id).type == Card.TypeBasic and not ai.player:prohibitDiscard(id)
      and Cost.value(ai, id) <= budget
  end) then return "#qiao__skill_shu013_1-discard" end
  return nullify
end

function M.yingyang(ai, pindian)
  if not pindian or not pindian.fromCard then return end
  local player = ai.player
  local function swing(own, other)
    return own and other and own.number <= other.number and math.min(13, own.number + 3) >= other.number
      and (own.number < other.number or own.number < 13)
  end
  local useful
  if pindian.from == player then
    for target, result in pairs(pindian.results or {}) do
      if ai:isEnemy(target) and swing(pindian.fromCard, result.toCard) then useful = true end
    end
  elseif ai:isEnemy(pindian.from) then
    local result = pindian.results and pindian.results[player]
    useful = result and swing(result.toCard, pindian.fromCard)
  end
  if useful then return "qiao__skill_wu010_2-plus3" end
end

function M.shunliuWorth(ai)
  local damage = currentData(ai)
  if not damage or not ai:isEnemy(damage.to) then return false end
  local targets = Chain.chainedAlivePlayers(ai.room)
  table.insertIfNeed(targets, damage.to)
  local worthwhile = false
  for _, target in ipairs(targets) do
    if not target:isNude() then
      if not ai:isEnemy(target) then return false end
      worthwhile = worthwhile or Removal.pick(ai, target, "he", false) ~= nil
    end
  end
  return worthwhile
end

function M.ciweiBudget(ai)
  local use = currentData(ai)
  if not use or not use.card or not ai:isEnemy(use.from) then return end
  local card = use.card
  if card.type ~= Card.TypeBasic and (card.type ~= Card.TypeTrick or card.sub_type == Card.SubtypeDelayedTrick) then
    -- Hengzhi alone saves no immediate resource, so keep this opportunity for protection.
    return
  end
  if table.find(use.tos or {}, function(target) return M.protects(ai, use, target) end) then return 2 end
end

function M.choice(ai, choices, fields)
  local key, player = fields[1], ai.player
  if key == "#qiao__skill_han011_2-choice" then
    local total = 0
    for _, id in ipairs(player:getCardIds("he")) do total = total + Cost.value(ai, id) end
    return total > 9 and "qiao__skill_han011_2-cards" or "qiao__skill_han011_2-draw"
  elseif key == "#qiao__skill_jin011_1-branch" then
    local equipment = "qiao__skill_jin011_1-equip:" .. fields[2]
    local hand = "qiao__skill_jin011_1-hand:" .. fields[2]
    if not table.contains(choices, hand) then return equipment end
    if not table.contains(choices, equipment) then return hand end
    if ai.player:getHandcardNum() >= 3 or not Cost.effectable(player, "qiao__skill_wu008_2") then return hand end
    return equipment
  elseif key == "#qiao__skill_jin006_1-choice" then
    if ai.room.current == player and Cost.effectable(player, "qiao__skill_jin006_2")
      and table.find(player:getCardIds("h"), function(id) return Cost.value(ai, id) <= 3 end)
      and table.find(Fk:cloneCard("qiao__unexpectation"):getAvailableTargets(player), function(target)
        return ai:isEnemy(target)
      end) then return "qiao__skill_jin006_1-restore" end
    return "qiao__skill_jin006_1-draw"
  elseif key == "#qiao__skill_qun016_2-choice" then
    local value = 0
    for _, id in ipairs(player:getCardIds("h")) do value = value + Cost.value(ai, id) end
    if player.hp > 1 and (value >= (player.hp == 2 and 11 or 8)
      or (value > 0 and Cost.zhaxiangTrade(player))) then return "#qiao__skill_qun016_2-losehp" end
    return "#qiao__skill_qun016_2-discard"
  elseif key == "#qiao__skill_jin010_1-choice" then
    local draw = "#qiao__skill_jin010_1-draw"
    if table.contains(choices, draw) then return draw end
    local target = playerAt(ai, fields, 3)
    if table.find(player:getCardIds("h"), function(id)
      return Cost.value(ai, id) <= 2 and M.shangshiMaterial(ai, target, id)
    end) then return "#qiao__skill_jin010_1-slash" end
  elseif key == "#qiao__skill_jin001_2-choice" then
    local heal = "qiao__skill_jin001_2-option_equip"
    if table.contains(choices, heal)
      and table.find(player:getCardIds("h"), function(id) return M.xingtuMaterial(ai, id) end)
      and table.find(ai.room:getPresentPlayers(), function(target) return M.xingtuTarget(ai, target) ~= nil end) then
      return heal
    end
    return "qiao__skill_jin001_2-option_draw"
  elseif key == "#qiao__skill_han015_2-choice" then
    local target = playerAt(ai, fields, 3)
    if ai:isFriend(target) then return "qiao__skill_han015_2-draw" end
    if ai:isEnemy(target) then return "qiao__skill_han015_2-discard" end
  elseif key == "#qiao__skill_shu006_2-ask" then
    local target = playerAt(ai, fields, 3)
    if not ai:isEnemy(target) then return end
    local main, deputy = "#qiao__skill_shu006_2-main", "#qiao__skill_shu006_2-deputy"
    local function skills(name)
      if name == "anjiang" or not Fk.generals[name] then return 0 end
      return #table.filter(Fk.generals[name]:getSkillNameList(true), function(id)
        return Fk.skills[id] and not Fk.skills[id]:hasTag(Skill.Compulsory)
      end)
    end
    if not table.contains(choices, main) or skills(target.deputyGeneral) > skills(target.general) then
      return table.contains(choices, deputy) and deputy or main
    end
    return main
  elseif key == "#qiao__skill_han019_1-amount" then
    local target = playerAt(ai, fields, 3)
    if ai:isFriend(target) and (target.hp <= 0 or player.phase == Player.Finish) then
      return table.contains(choices, "qiao__skill_han019_1-heal2") and "qiao__skill_han019_1-heal2"
        or "qiao__skill_han019_1-heal1"
    end
  elseif key == "#qiao__skill_shu009_1-choice" then
    local recovery = "#qiao__skill_shu009_1-recover"
    return table.contains(choices, recovery) and recovery or "#qiao__skill_shu009_1-draw"
  elseif key == "#qiao__skill_shu016_1-choice" then
    local target = playerAt(ai, fields, 2)
    if target and target.hp <= 2 and target:isWounded() then return "#qiao__skill_shu016_1-recover" end
    return "#qiao__skill_shu016_1-draw"
  elseif key == "#qiao__skill_shu014_2-choice" then
    local recover = table.find(choices, function(choice) return choice:startsWith("#qiao__skill_shu014_2-recover:") end)
    local owner = recover and playerAt(ai, recover:split(":"), 2)
    if owner and ai:isFriend(owner) and owner.hp <= 2 then return recover end
    return "#qiao__skill_shu014_2-draw"
  elseif key == "#qiao__skill_jin014_1-choice" then
    local hand = player:getCardIds("h")
    if player.hp == 1 and player:isWounded() and #hand >= 2 and #hand <= 3
      and table.every(hand, function(id) return Cost.value(ai, id) <= 2 end) then
      return "qiao__skill_jin014_1-recover"
    end
    return "qiao__skill_jin014_1-draw"
  end
end

return M
