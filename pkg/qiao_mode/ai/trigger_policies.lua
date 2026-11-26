local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
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
  if key == "#qiao__skill_jin002_2-invoke" then
    local damage = currentData(ai)
    local to = damage and damage.to
    if not ai:isEnemy(to) or damage.chain then return false end
    local required = to.hp + to.shield
    return damage.damage < required and damage.damage * 2 >= required
      and (damage.damageType == fk.NormalDamage or not to.chained)
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
  if allyDrawTargets[key] then
    return function(target)
      local cap = key == "#qiao__skill_wei013_2-choose" and math.min(5, target.maxHp) or target.maxHp
      local missing = cap - target:getHandcardNum()
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
    local thunder = Fk:cloneCard("qiao__thunder__slash")
    return function(target)
      if Cards.safeDamage(ai, thunder, target) then return 20 - target.hp end
    end
  end
  if enemyDamageTargets[key] then
    return function(target)
      if ai:isEnemy(target) then return 20 - target.hp end
    end
  end
  if key == "#qiao__skill_qun016_1-target" or key == "#qiao__skill_qun016_1-invoke" then
    return function(target)
      if ai:isEnemy(target) and not target:isNude() then
        return target:getHandcardNum() + 2 * #target:getCardIds("e")
      end
    end
  end
  if key == "#qiao__skill_jin012_1-targets" and use and use.card then
    return function(target)
      if M.protects(ai, use, target) then return 20 - target.hp end
    end, true
  end
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
  if key == "#qiao__skill_han015_2-choice" then
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
