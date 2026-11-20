-- 主动置入坐骑允许替换；移动到场上或置于空栏的效果不经过这个入口。
local M = {}
M.REPLACE = "qiao_replace_ride"

local function dual(card)
  return Fk.packages.qiao_cards.qiao_cards.isDualMount(card)
end

function M.canPut(player, id)
  local room = Fk:currentRoom()
  local owner = room:getCardOwner(id)
  local card = (owner and owner:getVirtualEquip(id)) or Fk:getCardById(id)
  if not card or player.dead or player:isRemoved() or (owner == player and room:getCardArea(id) == Card.PlayerEquip) then
    return false
  end
  if not dual(card) then return player:canMoveCardIntoEquip(card, true) end
  return #player:getAvailableEquipSlots(Card.SubtypeOffensiveRide) > 0
    and #player:getAvailableEquipSlots(Card.SubtypeDefensiveRide) > 0
end

function M.put(room, player, id, skillName)
  if not M.canPut(player, id) then return end
  local owner = room:getCardOwner(id)
  local card = owner and owner:getVirtualEquip(id)
  room:moveCards {
    ids = { id }, from = owner, to = player, toArea = Card.PlayerEquip,
    moveReason = fk.ReasonPut, skillName = skillName, proposer = player,
    moveVisible = true, virtualEquip = card, extra_data = { [M.REPLACE] = true },
  }
end

return M
