local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"

-- Display skill for hanjin_heg_mode only (attached by the mode rule). It owns
-- both the physical-card marks and the card-tip callback, so no display code is
-- registered globally in other game modes.
local skill = fk.CreateSkill { name = "#hanjin_adaptation_display" }

-- Physical cards are stamped when they enter a visible area. The initial hand
-- is special because DrawInitial uses notifyMoveCards rather than
-- fk.AfterCardsMove; AfterDrawInitialCards covers it without marking the hidden
-- draw pile at GamePrepared.
skill:addEffect(fk.AfterDrawInitialCards, {
  can_refresh = function(self, event, target, player)
    return target == player and player.room:getSettings("gameMode") == "hanjin_heg_mode"
  end,
  on_refresh = function(self, event, target, player, data)
    A.stampCards(player.room, data.cards, { player })
  end,
})
skill:addEffect(fk.AfterCardsMove, {
  can_refresh = function(self, event, target, player)
    return player.seat == 1 and player.room:getSettings("gameMode") == "hanjin_heg_mode"
  end,
  on_refresh = function(self, event, target, player, data) A.stampMoved(player.room, data) end,
})

-- The card-tip callback runs on the client. `card` is the current view-as
-- result (or the selected physical card); it is authoritative even when it has
-- no adaptation entry. A tip may only appear for the card that produced it:
-- a physical result must be the hovered card, and a virtual result is shown on
-- the selected material cards, never on every other hand card.
skill:addEffect("targetmod", {
  card_tip_func = function(self, player, to_select, selected, selected_targets, card)
    local current = card
    if current == nil or type(current) ~= "table" or current.name == nil then
      current = to_select ~= nil and Fk:getCardById(to_select) or nil
    end
    if current == nil then return nil end
    if current:isVirtual() then
      local belongs = false
      for _, id in ipairs(selected or {}) do
        if id == to_select then belongs = true break end
      end
      if not belongs then return nil end
    elseif current.id ~= to_select then
      return nil
    end
    return A.cardTips(current)
  end,
})

Fk:loadTranslationTable {
  ["#hanjin_adaptation_display"] = "汉晋应变显示",
}

return skill
