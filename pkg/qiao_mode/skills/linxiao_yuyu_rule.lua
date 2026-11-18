-- 临筱玉舆进出装备区的当前回合者效果。以单个 MoveCards 事件判定“本次确有
-- 坐骑因正常使用装备牌被实际替换”，不使用跨事件房间布尔，也不把同事件内
-- 无关的坐骑移动算作替换；同一事件只执行一次。
local skill = fk.CreateSkill { name = "qiao__linxiao_yuyu_rule" }
local CARD = "qiao__linxiao_yuyu"
local DUAL_RULE = "qiao__dual_mount_rule"

local function cardOf(info)
  return info.beforeCard or Fk:getCardById(info.cardId)
end

local function isLinxiao(info)
  local card = cardOf(info)
  return card ~= nil and card.name == CARD
end

local function isRide(info)
  local card = cardOf(info)
  if card == nil or card.type ~= Card.TypeEquip then return false end
  return card.sub_type == Card.SubtypeOffensiveRide
    or card.sub_type == Card.SubtypeDefensiveRide
end

--- 使用装备牌替换坐骑时，引擎与双栏规则产生的置入弃牌堆移动。
local function isReplacementDiscard(move, owner)
  return move.from == owner and move.toArea == Card.DiscardPile
    and move.moveReason == fk.ReasonPutIntoDiscardPile
    and (move.skillName == nil or move.skillName == DUAL_RULE)
end

local function hasLinMove(data)
  for _, move in ipairs(data or {}) do
    for _, info in ipairs(move.moveInfo or {}) do
      if isLinxiao(info) then
        local entering = move.toArea == Card.PlayerEquip and move.to ~= nil
        local leaving = info.fromArea == Card.PlayerEquip
          and move.toArea ~= Card.PlayerEquip
        if entering or leaving then return true end
      end
    end
  end
  return false
end

--- 临筱玉舆进入时，只有“本次使用装备牌替换下的坐骑”才构成实际替换。
local function enteredByReplacement(data, owner)
  for _, move in ipairs(data or {}) do
    for _, info in ipairs(move.moveInfo or {}) do
      if isLinxiao(info) and move.moveReason == fk.ReasonUse
        and move.toArea == Card.PlayerEquip and move.to == owner then
        for _, other in ipairs(data or {}) do
          if isReplacementDiscard(other, owner) then
            for _, oleave in ipairs(other.moveInfo or {}) do
              if oleave.fromArea == Card.PlayerEquip and isRide(oleave) then
                return true
              end
            end
          end
        end
      end
    end
  end
  return false
end

--- 临筱玉舆离开时，只有“本次正常使用的坐骑进入同一角色装备区”才算被替换。
local function leftByReplacement(data, owner)
  local leavingLinxiao = false
  for _, move in ipairs(data or {}) do
    for _, info in ipairs(move.moveInfo or {}) do
      if isLinxiao(info) and info.fromArea == Card.PlayerEquip
        and move.toArea ~= Card.PlayerEquip
        and isReplacementDiscard(move, owner) then
        leavingLinxiao = true
      end
    end
  end
  if not leavingLinxiao then return false end
  for _, move in ipairs(data or {}) do
    if move.moveReason == fk.ReasonUse and move.toArea == Card.PlayerEquip
      and move.to == owner then
      for _, info in ipairs(move.moveInfo or {}) do
        if isRide(info) then return true end
      end
    end
  end
  return false
end

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    if room:getTag("qiao_linxiao_after") == event.id then return false end
    return hasLinMove(data)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    if room:getTag("qiao_linxiao_after") == event.id then return end
    room:setTag("qiao_linxiao_after", event.id)
    local current = room.current or room:getCurrent()
    if current == nil or current.dead then return end
    local entering, leaving, owner = false, false, nil
    for _, move in ipairs(data or {}) do
      for _, info in ipairs(move.moveInfo or {}) do
        if isLinxiao(info) then
          if move.toArea == Card.PlayerEquip and move.to ~= nil then
            entering = true
            owner = move.to
          elseif info.fromArea == Card.PlayerEquip and move.toArea ~= Card.PlayerEquip then
            leaving = true
            owner = move.from
          end
        end
      end
    end
    local replaced = (entering and enteredByReplacement(data, owner))
      or (leaving and leftByReplacement(data, owner))
    if replaced then
      room:recover { who = current, num = 1, recoverBy = current,
        skillName = "qiao__linxiao_yuyu_skill" }
    else
      current:drawCards(1, "qiao__linxiao_yuyu_skill")
    end
  end,
})

return skill
