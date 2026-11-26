local M = {}

local function copies(ai, card)
  local selected = (ai.command == "AskForUseActiveSkill" or ai.command == "PlayCard")
    and ai:getSelectedCards() or {}
  return #table.filter(ai.player:getCardIds("h"), function(id)
    return not table.contains(selected, id) and Fk:getCardById(id).trueName == card.trueName
  end)
end

function M.value(ai, id)
  local card = Fk:getCardById(id)
  if ai.room:getCardArea(id) == Card.PlayerEquip then return 6 end
  if card.trueName == "peach" then return 9 end
  if card.trueName == "nullification" then return 7 end
  if card.trueName == "analeptic" then return 5 end
  if card.trueName == "jink" then return copies(ai, card) > 1 and 3 or 6 end
  if card.trueName == "slash" then return copies(ai, card) > 1 and 2 or 4 end
  if card.type == Card.TypeEquip then
    return ai.player:hasEmptyEquipSlot(card.sub_type) and 4 or 1
  end
  if card.name == "qiao__foresight" or card.name == "qiao__strengthen_state" then return 6 end
  if card.name == "qiao__lightning" or card.name == "qiao__lure_tiger" then return 1 end
  return 3
end

function M.select(ai, count, budget, accepts)
  for _ = 1, count do
    local best, bestValue
    for _, id in ipairs(ai:getEnabledCards()) do
      if not accepts or accepts(id) then
        local value = M.value(ai, id)
        if not bestValue or value < bestValue or (value == bestValue and id < best) then
          best, bestValue = id, value
        end
      end
    end
    if not best or (budget and bestValue > budget) then return false end
    if budget then budget = budget - bestValue end
    ai:selectCard(best, true)
  end
  return true
end

return M
