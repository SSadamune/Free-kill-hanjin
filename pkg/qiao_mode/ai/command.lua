local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local Damage = require "packages.qiao.pkg.qiao_mode.ai.damage"
local Heg = require "packages.hegemony.util"

local M = {}

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
    if player.hp <= 1 and player:getMark("@@command5_effect-turn") == 0 then return math.huge end
    return player.faceup and 8 or -6
  elseif data.command == "command6" then
    return 0.65 * (trimCost(ai, "h") + trimCost(ai, "e"))
  end
  return math.huge
end

function M.choice(ai, choices)
  local current = ai.room.logic:getCurrentEvent()
  local event = current and current:findParent(Heg.GameEvent.Command, true)
  local data = event and event.data
  if not data or data.skillName ~= "qiao__skill_wei024_1" or not table.contains(data.tos, ai.player)
    or not table.contains(choices, data.command) or not table.contains(choices, "Cancel") then return end
  local refusalCost = (mayDraw(ai, data.from) and 6 or -3) * sourceWeight(ai, data.from)
  return executionCost(ai, data) < refusalCost and data.command or "Cancel"
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
