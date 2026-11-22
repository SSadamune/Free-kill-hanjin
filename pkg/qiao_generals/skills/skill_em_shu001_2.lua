-- EM(SHU001) 刘备 · 天钺
-- 其他角色的飞龙夺凤置入场上/弃牌堆时，只拆出该牌改由刘备获得；
-- 刘备非因使用失去飞龙夺凤时，展示、置牌堆底并摸2。独立牌名识别。
local skill = fk.CreateSkill {
  name = "qiao__skill_em_shu001_2",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local CARD = "qiao__dragon_phoenix"
local GUARD = "qiao_em_shu001_tianyi_guard"

local function ownedDragon(info)
  if info.fromArea ~= Card.PlayerHand and info.fromArea ~= Card.PlayerEquip then return false end
  local card = Fk:getCardById(info.cardId, true)
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
          if ownedDragon(info) then return true end
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
          if ownedDragon(info) then table.insert(taken, info)
          else table.insert(keep, info) end
        end
        if #taken > 0 then
          move.moveInfo = keep
          if #keep == 0 then table.remove(data, index) end
          table.insert(data, MoveCardsData:new {
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

local function lostBy(move, player)
  return move.from == player and move.moveReason ~= fk.ReasonUse
    and not (move.to == player and (move.toArea == Card.PlayerHand or move.toArea == Card.PlayerEquip))
end

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player == nil or player.dead or not player:hasSkill(skill.name) then return false end
    if player:getMark(GUARD) > 0 then return false end
    for _, move in ipairs(data or {}) do
      if lostBy(move, player) then
        for _, info in ipairs(move.moveInfo or {}) do
          if ownedDragon(info) then return true end
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
      if lostBy(move, player) then
        for _, info in ipairs(move.moveInfo or {}) do
          if ownedDragon(info) then
            local id = info.cardId
            room:showCards({ id }, player, player)
            if room.draw_pile[#room.draw_pile] ~= id then
              local owner = room:getCardOwner(id)
              room:moveCards {
                ids = { id }, from = owner, toArea = Card.DrawPile,
                drawPilePosition = -1, moveReason = fk.ReasonPut,
                moveVisible = false,
              }
            end
            if not player.dead then player:drawCards(2, skill.name) end
          end
        end
      end
    end
    room:setPlayerMark(player, GUARD, 0)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_em_shu001_2"] = "天钺",
  [":qiao__skill_em_shu001_2"] = "锁定技，其他角色的【飞龙夺凤】置入场上或弃牌堆时，改为你获得之；你不因使用【飞龙夺凤】而失去此牌时，你展示之并置于牌堆底，摸两张牌。",
}

return skill
