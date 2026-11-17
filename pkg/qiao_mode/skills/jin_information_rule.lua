-- JIN003 昭然的房间级可见性来源。由负责人接线后，即使司马昭之后失去昭然，
-- 本阶段已经公开的手牌仍保持可见。
local skill = fk.CreateSkill {
  name = "qiao__jin_information_rule",
}

local OPEN = "qiao_jin003_1_open-phase"

skill:addEffect("visibility", {
  card_visible = function(self, viewer, card)
    local room = Fk:currentRoom()
    if room == nil or card == nil then return nil end
    local owner = room:getCardOwner(card.id)
    if owner ~= nil and owner:getMark(OPEN) > 0
      and room:getCardArea(card.id) == Card.PlayerHand then return true end
    return nil
  end,
})

return skill
