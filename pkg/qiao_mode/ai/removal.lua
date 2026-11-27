local Cost = require "packages.qiao.pkg.qiao_mode.ai.costs"

local M = {}

local removal = { qiao__dismantlement = true, qiao__snatch = true, qiao__chasing_near = true }

function M.isCard(card)
  return removal[card.name]
end

function M.handPressure(ai, target)
  local size = target:getHandcardNum()
  if size > 0 then return ai:hostileScore(target, 10 / size) end
end

local function enemyRetrial(ai)
  return table.find(ai.room:getPresentPlayers(), function(player)
    return ai:isEnemy(player)
      and ((not player:isKongcheng() and Cost.effectable(player, "qiao__skill_wei002_2"))
        or (Cost.effectable(player, "qiao__skill_qun010_2") and (not player:isKongcheng()
          or table.find(player:getCardIds("e"), function(id) return Fk:getCardById(id).color == Card.Black end))))
  end)
end

function M.judgeValue(ai, owner, card)
  local name = card.trueName
  local ally = ai:isFriend(owner)
  if ally and (name == "indulgence" or name == "supply_shortage") then
    return name == "indulgence" and 8 or 7
  end
  if name == "lightning" and (ally or ai:isEnemy(owner)) and enemyRetrial(ai) then return 7.5 end
end

function M.pick(ai, target, areas, obtains, refundSpade)
  local friend, enemy = ai:isFriend(target), ai:isEnemy(target)
  if not friend and not enemy then return end
  local best, value
  local function offer(id, score)
    if score and (not best or score > value or (score == value and id < best)) then best, value = id, score end
  end
  if enemy and areas:find("h", 1, true) and not target:isKongcheng() then
    offer(-1, (obtains and 2 or 0) + 3 + 1.5 / target:getHandcardNum() - (refundSpade and 0.5 or 0))
  end
  if enemy and areas:find("e", 1, true) then
    for _, id in ipairs(target:getCardIds("e")) do
      if obtains or not target:prohibitDiscard(id) then
        local card = target:getVirtualEquip(id) or Fk:getCardById(id)
        local score = card.sub_type == Card.SubtypeArmor and 7
          or card.sub_type == Card.SubtypeDefensiveRide and 5.5
          or card.sub_type == Card.SubtypeWeapon and 4.5 or 3.5
        if Cost.effectable(target, "qiao__skill_wu008_2") then score = score - 1.5 end
        if refundSpade and card.suit == Card.Spade then score = score - 3 end
        offer(id, score + (obtains and 2 or 0))
      end
    end
  end
  if areas:find("j", 1, true) then
    for _, id in ipairs(target:getCardIds("j")) do
      local card = target:getVirtualEquip(id) or Fk:getCardById(id)
      if obtains or not target:prohibitDiscard(id) then offer(id, M.judgeValue(ai, target, card)) end
    end
  end
  return best, value
end

function M.chooseJudge(ai, groups)
  local best, value
  for _, group in ipairs(groups) do
    for _, id in ipairs(group[2]) do
      local owner = ai.room:getCardOwner(id)
      local score = owner and M.judgeValue(ai, owner, owner:getVirtualEquip(id) or Fk:getCardById(id))
      if score and (not value or score > value) then best, value = id, score end
    end
  end
  return best and { best } or {}
end

function M.effectValue(ai, card, target)
  local obtains = card.name == "qiao__snatch"
    or (card.name == "qiao__chasing_near" and ai.player:distanceTo(target) == 1)
  local _, value = M.pick(ai, target, "hej", obtains)
  return value
end

return M
