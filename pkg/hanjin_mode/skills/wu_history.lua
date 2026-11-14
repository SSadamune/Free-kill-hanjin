-- 度势的全局弃牌花色记录器（模式级）。
--
-- 由 mode.lua 在 logic:start 之前安装到房间，因此不依赖度势武将是否已选、
-- 是否明置、之后是否换将。只把公开的“花色集合”写入同步玩家标记。
local H = require "packages.hanjin.pkg.hanjin_mode.rules.wu_history"

local skill = fk.CreateSkill {
  name = H.HISTORY_SKILL,
}

skill:addEffect(fk.AfterCardUseDeclared, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    -- 全局效果会为每名角色各触发一次；只由使用者本人记录一次。
    return data ~= nil and data.from ~= nil and data.from == player and data.card ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    H.recordUsed(data.from.room, data.from, data.card)
  end,
})

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if player == nil then return false end
    for _, move in ipairs(data or {}) do
      if move.toArea == Card.DiscardPile then return true end
    end
    return false
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    for _, move in ipairs(data or {}) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local card = Fk:getCardById(info.cardId, true)
          if card ~= nil then H.record(room, card.suit) end
        end
      end
    end
  end,
})

skill:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target ~= nil
  end,
  on_refresh = function(self, event, target, player)
    H.clear(target.room)
  end,
})

skill:addEffect(fk.GameStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player)
    H.clear(player.room)
  end,
})

return skill
