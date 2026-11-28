-- 主动置入坐骑允许替换；移动到场上或置于空栏的效果不经过这个入口。
local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local M = {}
M.REPLACE = "qiao_replace_ride"
M.REPLACEMENT_CARD = "qiao_replacement_ride_id"

local function dual(card)
  return Fk.packages.qiao_cards.qiao_cards.isDualMount(card)
end

function M.canPut(player, id, proposer)
  local room = Fk:currentRoom()
  local owner = room:getCardOwner(id)
  local card = (owner and owner:getVirtualEquip(id)) or Fk:getCardById(id)
  if not card or player.dead or player:isRemoved() or (owner == player and room:getCardArea(id) == Card.PlayerEquip) then
    return false
  end
  proposer = proposer or player
  if owner and room:getCardArea(id) == Card.PlayerEquip and Wu.isPubliclyProtectedTreasure(owner, proposer, id) then return false end
  if card.sub_type == Card.SubtypeTreasure and not player:hasEmptyEquipSlot(Card.SubtypeTreasure) then
    if table.find(player:getEquipments(Card.SubtypeTreasure), function(old)
      return Wu.isPubliclyProtectedTreasure(player, proposer, old)
    end) then return false end
  end
  if not dual(card) then return player:canMoveCardIntoEquip(card, true) end
  return #player:getAvailableEquipSlots(Card.SubtypeOffensiveRide) > 0
    and #player:getAvailableEquipSlots(Card.SubtypeDefensiveRide) > 0
end

function M.put(room, player, id, skillName, proposer)
  proposer = proposer or player
  if not M.canPut(player, id, proposer) then return end
  local owner = room:getCardOwner(id)
  local card = owner and owner:getVirtualEquip(id)
  local incoming = card or Fk:getCardById(id)
  local ride = Fk.packages.qiao_cards.qiao_cards.isRideCard(incoming)
  if not ride and not player:hasEmptyEquipSlot(incoming.sub_type) then
    local equipped = player:getEquipments(incoming.sub_type)
    if #equipped == 0 then return end
    local old = #equipped == 1 and equipped[1] or room:askToChooseCard(proposer, {
      target = player, flag = { card_data = {{ "$Equip", equipped }} }, skill_name = "replaceEquip",
      prompt = "#qiao_replace_equip::" .. player.id,
    })
    if not table.contains(player:getEquipments(incoming.sub_type), old) or not M.canPut(player, id, proposer) then return end
    local extra = { qiao_equipment_replacement = { incoming = id, outgoing = old, target = player.id } }
    room:moveCards(
      { ids = { old }, from = player, toArea = Card.DiscardPile, moveReason = fk.ReasonPutIntoDiscardPile,
        proposer = proposer, skillName = skillName, extra_data = extra },
      { ids = { id }, from = owner, to = player, toArea = Card.PlayerEquip, moveReason = fk.ReasonPut,
        proposer = proposer, skillName = skillName, virtualEquip = card, extra_data = extra })
    if room:getCardOwner(id) == player and room:getCardArea(id) == Card.PlayerEquip then return { id } end
    return {}
  end
  if not ride then
    return room:moveCardIntoEquip(player, id, skillName, true, proposer)
  end
  room:moveCards {
    ids = { id }, from = owner, to = player, toArea = Card.PlayerEquip,
    moveReason = fk.ReasonPut, skillName = skillName, proposer = proposer,
    moveVisible = true, virtualEquip = card, extra_data = { [M.REPLACE] = true },
  }
end

-- 在同批置入与替换都仍有效时落栏；移牌技能可以独立取消其中一步。
function M.checkReplacement(room, moves)
  local pair, incoming, outgoing
  for _, move in ipairs(moves) do
    local replacement = (move.extra_data or {}).qiao_equipment_replacement
    if replacement then
      pair = replacement
      for _, info in ipairs(move.moveInfo) do
        if room:getCardArea(info.cardId) == info.fromArea and room:getCardOwner(info.cardId) == move.from then
          if info.cardId == pair.incoming and move.to and move.to.id == pair.target and move.toArea == Card.PlayerEquip then
            incoming = true
          elseif info.cardId == pair.outgoing and move.from and move.from.id == pair.target and move.toArea == Card.DiscardPile then
            outgoing = true
          end
        end
      end
    end
  end
  if pair and not (incoming and outgoing) then
    room:cancelMove(moves, nil, function(move, info)
      return (move.extra_data or {}).qiao_equipment_replacement ~= nil
        and ((info.cardId == pair.incoming and move.toArea == Card.PlayerEquip)
          or (info.cardId == pair.outgoing and move.toArea == Card.DiscardPile))
    end)
  end
end

Fk:loadTranslationTable { ["#qiao_replace_equip"] = "选择要替换的装备牌（%dest）" }

return M
