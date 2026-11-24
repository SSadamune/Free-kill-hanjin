-- 临筱玉舆进出装备区后由当前回合角色受益。替换须在同一个 MoveCards 事件
-- 关联进入的坐骑和离开的坐骑，主动置入由双栏规则记录导致替换的牌。
local skill = fk.CreateSkill { name = "qiao__linxiao_yuyu_rule" }
local Placement = require "packages.qiao.pkg.qiao_mode.rules.mount_placement"
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

local function isReplacementDiscard(move, incomingMove, incomingId)
  if move.from ~= incomingMove.to or move.toArea ~= Card.DiscardPile
    or move.moveReason ~= fk.ReasonPutIntoDiscardPile then return false end
  local replacement = move.extra_data and move.extra_data[Placement.REPLACEMENT_CARD]
  if replacement ~= nil then return replacement == incomingId end
  return incomingMove.moveReason == fk.ReasonUse and (move.skillName == nil or move.skillName == DUAL_RULE)
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

local function replacesLinxiao(data)
  for _, move in ipairs(data or {}) do
    if move.toArea == Card.PlayerEquip and move.to ~= nil then
      for _, incoming in ipairs(move.moveInfo or {}) do
        if isRide(incoming) then
          for _, discard in ipairs(data) do
            if isReplacementDiscard(discard, move, incoming.cardId) then
              for _, outgoing in ipairs(discard.moveInfo or {}) do
                if outgoing.fromArea == Card.PlayerEquip and isRide(outgoing)
                  and (isLinxiao(incoming) or isLinxiao(outgoing)) then return true end
              end
            end
          end
        end
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
    if replacesLinxiao(data) then
      room:recover { who = current, num = 1, recoverBy = current,
        skillName = "qiao__linxiao_yuyu_skill" }
    else
      current:drawCards(1, "qiao__linxiao_yuyu_skill")
    end
  end,
})

return skill
