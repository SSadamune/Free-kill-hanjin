-- EM(SHU001) 刘备 · 天钺
-- 其他角色的飞龙夺凤置入场上/弃牌堆时，只拆出该牌改由刘备获得；
-- 刘备非因使用失去飞龙夺凤时，展示、置牌堆底并摸2。独立牌名识别。
local skill = fk.CreateSkill {
  name = "hanjin__skill_em_shu001_2",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

local CARD = "hanjin__dragon_phoenix"
local GUARD = "hanjin_em_shu001_tianyi_guard"

local function isDragon(id)
  local card = Fk:getCardById(id)
  return card ~= nil and card.name == CARD
end

skill:addEffect(fk.BeforeCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if player == nil or not player:hasSkill(skill.name) or player:getMark(GUARD) > 0 then
      return false
    end
    for _, move in ipairs(data or {}) do
      if move.from ~= nil and move.from ~= player
        and (move.toArea == Card.PlayerEquip or move.toArea == Card.DiscardPile) then
        for _, info in ipairs(move.moveInfo or {}) do
          if isDragon(info.cardId) then return true end
        end
      end
    end
    return false
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, GUARD, 1)
    -- 只拆出飞龙夺凤 info，其他牌保持原 move/去向。
    for index = #(data or {}), 1, -1 do
      local move = data[index]
      if move.from ~= nil and move.from ~= player
        and (move.toArea == Card.PlayerEquip or move.toArea == Card.DiscardPile) then
        local keep, taken = {}, {}
        for _, info in ipairs(move.moveInfo or {}) do
          if isDragon(info.cardId) then table.insert(taken, info)
          else table.insert(keep, info) end
        end
        if #taken > 0 then
          move.moveInfo = keep
          if #keep == 0 then table.remove(data, index) end
          table.insert(data, {
            from = move.from, to = player, toArea = Card.PlayerHand,
            moveReason = move.moveReason, proposer = move.proposer,
            moveVisible = false, moveInfo = taken,
          })
        end
      end
    end
    room:setPlayerMark(player, GUARD, 0)
  end,
})

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player == nil or player.dead or not player:hasSkill(skill.name) then return false end
    if player:getMark(GUARD) > 0 then return false end
    for _, move in ipairs(data or {}) do
      if move.from == player and move.moveReason ~= fk.ReasonUse then
        for _, info in ipairs(move.moveInfo or {}) do
          if isDragon(info.cardId) then return true end
        end
      end
    end
    return false
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:setPlayerMark(player, GUARD, 1)
    for _, move in ipairs(data or {}) do
      if move.from == player and move.moveReason ~= fk.ReasonUse then
        for _, info in ipairs(move.moveInfo or {}) do
          if isDragon(info.cardId) then
            local id = info.cardId
            local area = room:getCardArea(id)
            if area ~= Card.DrawPile then
              room:showCards({ id }, player, player)
              local owner = room:getCardOwner(id)
              room:moveCards {
                ids = { id }, from = owner, toArea = Card.DrawPile,
                drawPilePosition = -1, moveReason = fk.ReasonPut,
                moveVisible = false,
              }
              player:drawCards(2, skill.name)
            end
            room:setPlayerMark(player, GUARD, 0)
            return
          end
        end
      end
    end
    room:setPlayerMark(player, GUARD, 0)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_em_shu001_2"] = "天钺",
  [":hanjin__skill_em_shu001_2"] = "锁定技，其他角色的【飞龙夺凤】置入场上或弃牌堆时，改为你获得之；你不因使用【飞龙夺凤】而失去此牌时，你展示之并置于牌堆底，摸两张牌。",
}

return skill
