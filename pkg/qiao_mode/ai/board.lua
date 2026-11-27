local Requests = require "packages.qiao.pkg.qiao_mode.ai.requests"

local M = {}

function M.harmfulDelay(card)
  return card.trueName == "indulgence" or card.trueName == "supply_shortage"
end

function M.equipScore(card)
  if card.sub_type == Card.SubtypeArmor then return 3 end
  if card.sub_type == Card.SubtypeDefensiveRide then return 2 end
  return 1
end

local function moveScore(ai, from, id)
  local card = from:getVirtualEquip(id) or Fk:getCardById(id)
  local area = ai.room:getCardArea(id)
  if area == Card.PlayerJudge and ai:isFriend(from) and M.harmfulDelay(card) then return 4 end
  if area == Card.PlayerEquip and ai:isEnemy(from) and not from:hasSkill("qiao__skill_wu008_2") then
    return M.equipScore(card)
  end
end

local function pairScore(ai, from, to, zone, allowed)
  if from == to then return end
  local area
  if ai:isEnemy(from) and ai:isFriend(to) then area = Player.Equip end
  if ai:isFriend(from) and ai:isEnemy(to) then area = Player.Judge end
  if not area or (zone == "e" and area ~= Player.Equip) then return end
  local best
  for _, id in ipairs(from:getCardIds(area)) do
    local score = moveScore(ai, from, id)
    if score and (not best or score > best)
      and (allowed and allowed(from, to, id) or not allowed and from:canMoveCardInBoardTo(to, id)) then best = score end
  end
  if best then
    local enemy, friend = from, to
    if area == Player.Judge then enemy, friend = to, from end
    return ai:hostileScore(enemy, ai:supportScore(friend, best))
  end
end

function M.worthMoving(ai, zone, allowed)
  local players = ai.room:getPresentPlayers()
  return table.find(players, function(from)
    return table.find(players, function(to) return pairScore(ai, from, to, zone, allowed) ~= nil end) ~= nil
  end) ~= nil
end

function M.choosePlayers(ai, zone, allowed)
  local bestFrom, bestTo, best
  for _, from in ipairs(ai:getEnabledTargets()) do
    ai:selectTarget(from, true)
    for _, to in ipairs(ai:getEnabledTargets()) do
      local score = pairScore(ai, from, to, zone, allowed)
      if score and (not best or score > best) then bestFrom, bestTo, best = from, to, score end
    end
    ai:unSelectAllTargets()
  end
  if not bestFrom then return "" end
  ai:selectTarget(bestFrom, true)
  ai:selectTarget(bestTo, true)
  return Requests.reply(ai)
end

function M.chooseCard(ai, groups)
  local best, bestScore
  -- The two selected roles are confirmed opponents, and the engine supplies
  -- only cards that can move to the other role. The owner fixes the direction.
  for _, group in ipairs(groups) do
    for _, id in ipairs(group[2]) do
      local from = ai.room:getCardOwner(id)
      local score = from and moveScore(ai, from, id)
      if score and (not bestScore or score > bestScore) then best, bestScore = id, score end
    end
  end
  return best and { best } or {}
end

return M
