-- WU020 徐盛·破军移出游戏牌的回合末回归。
local skill = fk.CreateSkill { name = "qiao__wu020_pojun_rule" }
local PENDING = "qiao_wu020_pojun_pending"

local function turnId(room)
  local current = room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  return turn and turn.id or 0
end

skill:addEffect(fk.TurnEnd, {
  global = true,
  priority = -100,
  can_trigger = function(self, event, target, player)
    return player == player.room.alive_players[1] and #(player.room:getTag(PENDING) or {}) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    local room = player.room
    local turn, list = turnId(room), room:getTag(PENDING) or {}
    local rest = {}
    room:setTag(PENDING, {})
    local function returnCards()
    for _, entry in ipairs(list) do
      if entry.turn ~= turn then
        table.insert(rest, entry)
      else
        local to = room:getPlayerById(entry.target)
        local ids = table.filter(entry.ids or {}, function(id)
          return room:getCardArea(id) == Card.Void
        end)
        if to == nil or to.dead then
          if #ids > 0 then
            room:moveCards {
              ids = ids, toArea = Card.DiscardPile,
              moveReason = fk.ReasonPutIntoDiscardPile, moveVisible = true,
            }
          end
        elseif #ids > 0 then
          room:obtainCard(to, ids, false, fk.ReasonPrey, nil,
            "qiao__skill_wu020_2")
        end
      end
    end
      if #rest > 0 then
        local pending=room:getTag(PENDING) or {}
        table.insertTable(pending,rest)
        room:setTag(PENDING,pending)
      end
    end
    -- 所有普通 TurnEnd 结算及角色移回完成后，才移回牌。
    local current=room.logic:getCurrentEvent()
    local turnEvent=current and current:findParent(GameEvent.Turn,true)
    if turnEvent then turnEvent:addExitFunc(returnCards) else returnCards() end
  end,
})

return skill
