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
}

function M.protects(ai, use, player)
  return Cards.isHarmful(use.card) and player:isAlive() and ai:isFriend(player)
    and not table.contains(use.nullifiedTargets or {}, player)
end

function M.targetScore(ai, key, use)
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
  if key == "#qiao__skill_jin001_2-choice" then
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
