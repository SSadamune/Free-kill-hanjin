-- 临筱玉舆进出装备区的当前回合者效果。以单个 MoveCards 事件判定“本次确有
-- 坐骑被替换”，不使用跨事件房间布尔；同一事件只执行一次。
local skill = fk.CreateSkill { name = "qiao__linxiao_yuyu_rule" }
local CARD = "qiao__linxiao_yuyu"

local function cardName(info)
  local card = info.beforeCard or Fk:getCardById(info.cardId, true)
  return card and card.name or nil
end

local function isRide(info)
  local card = info.beforeCard or Fk:getCardById(info.cardId, true)
  if card == nil or card.type ~= Card.TypeEquip then return false end
  return card.sub_type == Card.SubtypeOffensiveRide
    or card.sub_type == Card.SubtypeDefensiveRide
end

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local done = player.room:getTag("qiao_linxiao_after")
    if done == event.id then return false end
    for _, move in ipairs(data or {}) do
      for _, info in ipairs(move.moveInfo or {}) do
        if cardName(info) == CARD then
          if (move.toArea == Card.PlayerEquip and move.to ~= nil)
            or (info.fromArea == Card.PlayerEquip and move.toArea ~= Card.PlayerEquip) then
            return true
          end
        end
      end
    end
    return false
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if room:getTag("qiao_linxiao_after") == event.id then return end
    room:setTag("qiao_linxiao_after", event.id)
    local current = room.current or room:getCurrent()
    if current == nil or current.dead then return end
    local entering, leaving, owner = false, false, nil
    for _, move in ipairs(data or {}) do
      for _, info in ipairs(move.moveInfo or {}) do
        if cardName(info) == CARD then
          if move.toArea == Card.PlayerEquip then
            entering = true
            owner = move.to
          elseif info.fromArea == Card.PlayerEquip and move.toArea ~= Card.PlayerEquip then
            leaving = true
            owner = move.from
          end
        end
      end
    end
    local replaced = false
    local linId = nil
    for _, move in ipairs(data or {}) do
      for _, info in ipairs(move.moveInfo or {}) do
        if cardName(info) == CARD then linId = info.cardId end
      end
    end
    local staged = room:getTag("qiao_linxiao_replaced")
    if type(staged) == "table" and staged.card == linId then
      replaced = true
      room:setTag("qiao_linxiao_replaced", nil)
    end
    for _, move in ipairs(data or {}) do
      for _, info in ipairs(move.moveInfo or {}) do
        if isRide(info) and cardName(info) ~= CARD then
          if entering and owner ~= nil and move.from == owner and info.fromArea == Card.PlayerEquip then
            replaced = true
          end
          if leaving and owner ~= nil and move.to == owner and move.toArea == Card.PlayerEquip then
            replaced = true
          end
        end
      end
    end
    if replaced then
      room:recover { who = current, num = 1, recoverBy = current,
        skillName = "qiao__linxiao_yuyu_skill" }
    else
      current:drawCards(1, "qiao__linxiao_yuyu_skill")
    end
  end,
})

return skill
