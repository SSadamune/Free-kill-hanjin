local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"
local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"
local Heg = require "packages.hegemony.util"
local Diplomacy = require "packages.qiao.pkg.qiao_mode.ai.diplomacy"

local M = {}

local function ally(ai, player, other)
  if player == ai.player then return ai:isFriend(other) end
  local faction = Diplomacy.publicFaction(player)
  return player == other or (type(faction) == "string" and faction == Diplomacy.publicFaction(other)
    and Heg.compareKingdomWith(player, other))
end

local function enemy(ai, player, other)
  if player == ai.player then return ai:isEnemy(other) end
  if other == ai.player then return ai:isEnemy(player) end
  local own, theirs = Diplomacy.publicFaction(player), Diplomacy.publicFaction(other)
  return player ~= other and own ~= nil and theirs ~= nil and own ~= theirs
end

local function canDraw(player)
  return player and player:isAlive() and not player:isRemoved() and not player:isHandAreaSealed()
end

function M.jiemingMissing(player)
  return canDraw(player) and math.max(0, math.min(5, player.maxHp) - player:getHandcardNum()) or 0
end

local function jiemingBenefit(ai, player, amount)
  local missing = {}
  for _, other in ipairs(ai.room:getPresentPlayers()) do
    if ally(ai, player, other) then table.insert(missing, M.jiemingMissing(other)) end
  end
  table.sort(missing, function(a, b) return a > b end)
  local benefit = 0
  for i = 1, math.min(amount, #missing) do
    benefit = benefit + 2 * missing[i]
  end
  return benefit
end

-- Values are from the recipient's faction's perspective. Use public states
-- and the trigger conditions of the supported policies, never hidden hands.
function M.benefit(ai, player, source, amount)
  if amount <= 0 or not player:isAlive() then return 0 end
  local result = 0
  if canDraw(player) and Cost.effectable(player, "qiao__skill_wei001_1") then
    result = result + 3
  end
  if Cost.effectable(player, "qiao__skill_wei013_2") then
    result = result + jiemingBenefit(ai, player, amount)
  end
  local anjing = "qiao__skill_han022_2"
  if Cost.effectable(player, anjing) and player:usedSkillTimes(anjing, Player.HistoryTurn) == 0 then
    for _, other in ipairs(ai.room:getPresentPlayers()) do
      if canDraw(other) and Heg.compareKingdomWith(player, other) then result = result + 2 end
    end
  end
  if source and source ~= player and source:isAlive() and not source:isRemoved() then
    if enemy(ai, player, source) then
      if not source:isNude() and canDraw(player) and Cost.effectable(player, "qiao__skill_wei002_1") then
        result = result + 4
      end
      if Cost.effectable(player, "qiao__skill_wei003_1") then
        result = result + (source:isNude() and 1.5 or 3)
      end
    elseif ally(ai, player, source) and canDraw(player) and canDraw(source)
      and Cost.effectable(player, "qiao__skill_wei017_2") then
      result = result + 4
    end
  end
  return math.min(result, 10)
end

function M.responseCost(ai, reply)
  if type(reply) ~= "table" then return end
  if type(reply.card) == "number" then return Cost.value(ai, reply.card) end
  local value = 0
  for _, id in ipairs(reply.card and reply.card.subcards or {}) do
    value = value + Cost.value(ai, id)
  end
  return value
end

function M.equipmentLoss(ai)
  local player = ai.player
  local equips = player:getCardIds("e")
  local loss = 0
  for _, id in ipairs(equips) do loss = loss + Cost.value(ai, id) end
  if canDraw(player) and Cost.effectable(player, "qiao__skill_wu008_2") then
    loss = loss - #equips * (ai.room.current == player and 3 or 6)
  end
  return math.max(0, loss)
end

function M.accept(ai, source, amount, defenseCost)
  local player = ai.player
  local lostHp = math.max(0, amount - player.shield)
  local remaining = player.hp - lostHp
  if defenseCost == nil or remaining < 1 or lostHp > 1 then return false end

  local battle = BattleRoyal.entered(ai.room)
  local peaches = 0
  if not battle then
    for _, id in ipairs(player:getCardIds("h")) do
      local card = Fk:getCardById(id)
      if card.trueName == "peach" and not player:prohibitUse(card) then peaches = peaches + 1 end
    end
  end
  if remaining == 1 and peaches == 0 then return false end
  local benefit = M.benefit(ai, player, source, amount)
  if benefit <= 0 then return false end
  local harm = lostHp == 0 and 2 or 4.75
  if remaining == 2 then harm = harm + 2 end
  if remaining == 1 then harm = harm + 4 end
  harm = harm + (battle and 2 or 0) - math.min(peaches, 2)
  if ai.personality == "conservative" then harm = harm + 1.5 end
  return benefit + math.min(defenseCost * 0.5, 4) > harm
end

return M
