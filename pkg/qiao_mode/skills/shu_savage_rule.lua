-- 祸首：本次南蛮的伤害来源记录在使用数据上，失技不撤销；
-- 来源本人死亡后剩余伤害无来源。由固定存活玩家执行一次，避免依赖可能死亡的来源。
local skill = fk.CreateSkill { name = "qiao__shu_savage_rule" }

local SOURCE = "qiao__skill_shu014_1_source"
local RED = "qiao__shu_red_discard-turn"

-- 全场本回合进入弃牌堆红色牌事实计数（回合内累计；房间每测新建）。
skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player == player.room.alive_players[1]
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    local current = room.current
    if current == nil then return end
    local count = 0
    for _, move in ipairs(data or {}) do
      if move.toArea == Card.DiscardPile then
        for _, info in ipairs(move.moveInfo or {}) do
          local card = Fk:getCardById(info.cardId)
          if card ~= nil and (card.suit == Card.Heart or card.suit == Card.Diamond) then
            count = count + 1
          end
        end
      end
    end
    if count > 0 then room:addPlayerMark(current, RED, count) end
  end,
})

skill:addEffect(fk.DamageCaused, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player == player.room.alive_players[1] and data.card ~= nil
      and data.card.trueName == "savage_assault"
  end,
  on_refresh = function(self, event, target, player, data)
    local current = player.room.logic:getCurrentEvent()
    local useEvent = current and current:findParent(GameEvent.UseCard, true)
    local use = useEvent and useEvent.data
    if use == nil or use.card ~= data.card then return end
    local source = use.extra_data and use.extra_data[SOURCE]
    if source == nil then return end
    if source.dead then
      data.from = nil
    else
      data.from = source
    end
  end,
})

return skill
