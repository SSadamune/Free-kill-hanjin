local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Heg = require "packages.hegemony.util"
local Junling = require "packages.qiao.pkg.qiao_mode.rules.junling"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local M = {}

local changling = "qiao__skill_wei024_1"
local yujue = "qiao__skill_han003_1"
local yongsi = "qiao__skill_qun021_1"
local buyi = "qiao__skill_wu024_1"
local zhuizhu = "qiao__skill_jin021_2"

local function commandData(ai)
  local current = ai.room.logic:getCurrentEvent()
  local event = current and current:findParent(Heg.GameEvent.Command, true)
  return event and event.data
end

local function supported(name)
  return name == changling or name == yujue or name == yongsi or name == buyi or name == zhuizhu
end

local function sourceWeight(ai, from)
  if ai:isFriend(from) then return -1 end
  if not ai:isEnemy(from) then return 0.6 end
  return math.max(0.35, math.min(1.25, 0.8 - 0.3 * ai:attitude(from)))
end

local function mayDraw(ai, from)
  if from:isHandAreaSealed() then return false end
  local event = ai.room.logic:getCurrentEvent()
  local turn = event and event:findParent(GameEvent.Turn, true)
  return not turn or (ai.room.current == from and from:canSkip(Player.Draw))
end

local function transferCost(ai, source)
  local canDraw = not ai.player:isHandAreaSealed()
  if source == ai.player then return canDraw and -3 or 0 end
  local prices = canDraw and { 3 } or {}
  for _, id in ipairs(ai.player:getCardIds("he")) do table.insert(prices, Cost.value(ai, id)) end
  table.sort(prices)
  return (prices[1] or 0) + (prices[2] or 0) - (canDraw and 3 or 0)
    + 1.25 * math.min(2, #prices) * sourceWeight(ai, source)
end

local function defenseLockCost(ai)
  local player = ai.player
  if player:getMark("@@command4_effect-turn") > 0 then return 0 end
  if ai.room.current == player then return 9 end
  local defenses = 0
  for _, id in ipairs(player:getCardIds("h")) do
    local card = Fk:getCardById(id)
    if card.trueName == "slash" or card.trueName == "jink" or card.trueName == "peach"
      or card.trueName == "nullification" or card.trueName == "analeptic" then defenses = defenses + 1 end
  end
  local count = #table.filter(player:getAllSkills(), function(skill)
    return not skill.attached_equip and not skill:hasTag(Skill.Compulsory) and skill:isEffectable(player)
  end)
  local low = player.hp <= 2 and defenses > 0 and (player.hp == 1 and 5 or 2) or 0
  return math.min(3, defenses) + math.min(2, count) + low
end

local function trimCost(ai, area)
  local total, keep, count = 0, 0, 0
  for _, id in ipairs(ai.player:getCardIds(area)) do
    if not ai.player:prohibitDiscard(id) then
      local value = Cost.value(ai, id)
      total, keep, count = total + value, math.max(keep, value), count + 1
    end
  end
  if area == "e" and Cost.effectable(ai.player, "qiao__skill_wu008_2") and not ai.player:isHandAreaSealed() then
    total = total - math.max(0, count - 1) * (ai.room.current == ai.player and 3 or 6)
  end
  return math.max(0, total - keep)
end

local function executionCost(ai, data)
  local player, from = ai.player, data.from
  if data.command == "command1" then
    local targets = data.command_data and data.command_data.tos
    local target = targets and targets[1]
    if not target or target.dead then return 0 end
    local result = Damage.assess(ai, target, 1, fk.NormalDamage, { source = player })
    return result.unsafe and math.huge or -result.balance
  elseif data.command == "command2" then
    return transferCost(ai, from)
  elseif data.command == "command3" then
    if player.hp <= 1 then return math.huge end
    if Cost.zhaxiangTrade(player) then return -3 end
    return player.hp == 2 and 7 or 4.5
  elseif data.command == "command4" then
    return defenseLockCost(ai)
  elseif data.command == "command5" then
    local locksHealing = player:getMark("@@command5_effect-turn") == 0
    local context = Junling.context(ai.room, data)
    local protected = data.skillName == zhuizhu and ai:isFriend(data.from) and context and context.damage
    if player.hp <= 1 and locksHealing and not protected then return math.huge end
    return (player.faceup and 8 or 0) + (locksHealing and player:isWounded() and 2 or 0)
  elseif data.command == "command6" then
    return 0.65 * (trimCost(ai, "h") + trimCost(ai, "e"))
  end
  return math.huge
end

local function refusalCost(ai, data)
  local name, player = data.skillName, ai.player
  if name == changling then
    return (mayDraw(ai, data.from) and 6 or -3) * sourceWeight(ai, data.from)
  elseif name == yujue then
    local penalty = 0
    if Quan.hasHiddenGeneral(player) then
      penalty = player.faceup and 8 or 0
    elseif Quan.canHideGeneralPosition(player, false) or Quan.canHideGeneralPosition(player, true) then
      penalty = 4
    end
    local canAttack = ai.room.current == player and table.find(player:getCardIds("h"), function(id)
      local card = Fk:getCardById(id)
      return card.is_damage_card and table.find(card:getAvailableTargets(player), function(target)
        return ai:isEnemy(target)
      end) ~= nil
    end)
    local reward = canAttack and not player:isHandAreaSealed() and data.command ~= "command4" and 3 or 0
    return penalty + reward
  elseif name == yongsi then
    if ai:isFriend(data.from) or data.from:isHandAreaSealed() then return 0 end
    local hand, total = player:getCardIds("h"), 0
    for _, id in ipairs(hand) do total = total + Cost.value(ai, id) end
    return math.max(0, total - #hand * 2) * sourceWeight(ai, data.from)
  end
  local context = Junling.context(ai.room, data)
  if name == buyi then
    local target = context and context.recoveryTarget
    if not target or not target:isAlive() or not target:isWounded()
      or target:getMark("@@command5_effect-turn") > 0 then return 0 end
    return (target.hp <= 1 and 5 or 3) * sourceWeight(ai, target)
  elseif name == zhuizhu then
    local damage = context and context.damage
    if not damage then return end
    if ai:isFriend(data.from) and damage.damage > player.shield then return 25 end
    return math.min(10, 3 * damage.damage)
  end
end

function M.choice(ai, choices)
  local data = commandData(ai)
  if not data or not supported(data.skillName) or not table.contains(data.tos, ai.player)
    or not table.contains(choices, data.command) or not table.contains(choices, "Cancel") then return end
  local refusal = refusalCost(ai, data)
  if refusal ~= nil then return executionCost(ai, data) < refusal and data.command or "Cancel" end
end

local function damageTargetScore(ai, actor, target)
  if not actor or target == actor then return end
  local result = Damage.assess(ai, target, 1, fk.NormalDamage, { source = actor })
  return result.balance - (result.unsafe and 30 or 0)
end

function M.damageTargetScore(ai, target)
  local data = commandData(ai)
  if not data or data.from ~= ai.player or not supported(data.skillName) then return end
  return damageTargetScore(ai, data.tos[1], target)
end

function M.issueChoice(ai, skillName, choices)
  if not supported(skillName) then return end
  -- Native Command:prepare prompts before the event is pushed onto the stack.
  local pending = Junling.pending(ai.room)
  if not pending or pending.from ~= ai.player or pending.skillName ~= skillName then return end
  local actor = pending.to
  local best, bestScore
  local friend = ai:isFriend(actor)
  for _, command in ipairs(choices) do
    local score
    if command == "command1" then
      for _, target in ipairs(ai.room:getPresentPlayers()) do
        local value = damageTargetScore(ai, actor, target)
        if value then score = math.max(score or value, value) end
      end
      score = score or 0
    elseif command == "command2" then
      score = actor == ai.player and 5 or (friend and -1 or 4)
    elseif command == "command3" then
      score = friend and -10 or (actor.hp <= 2 and 8 or 5)
    elseif command == "command4" then
      score = (friend and -1 or 1) * (ai.room.current == actor and 7 or 2)
    elseif command == "command5" then
      score = (friend and -1 or 1) * (actor.faceup and 8 or (actor:isWounded() and 2 or 0))
    elseif command == "command6" then
      local count = math.max(0, actor:getHandcardNum() - 1) + math.max(0, #actor:getCardIds("e") - 1)
      score = (friend and -1 or 1) * math.min(10, 2.5 * count)
    end
    if score and (not bestScore or score > bestScore) then best, bestScore = command, score end
  end
  return best
end

function M.keep(ai)
  while not ai:okButtonEnabled() do
    local best, score
    for _, id in ipairs(ai:getEnabledCards()) do
      local value = Cost.value(ai, id)
      if not ai.player:prohibitDiscard(id) and (not best or value > score or (value == score and id < best)) then
        best, score = id, value
      end
    end
    -- The native request still requires a selection from an area containing
    -- only cards that cannot be discarded.
    best = best or ai:getEnabledCards()[1]
    if not best then return false end
    ai:selectCard(best, true)
  end
  return true
end

return M
