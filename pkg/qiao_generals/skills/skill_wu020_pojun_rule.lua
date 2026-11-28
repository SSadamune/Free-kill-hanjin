-- WU020 徐盛·破军移出游戏牌的回合末回归。
local skill = fk.CreateSkill { name = "qiao__wu020_pojun_rule" }
local Pojun = require "packages.qiao.pkg.qiao_mode.rules.pojun"

local function turnId(room)
  local current = room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  return turn and turn.id or 0
end

skill:addEffect(fk.TurnEnd, {
  global = true,
  priority = -100,
  can_trigger = function(self, event, target, player)
    return player == player.room.alive_players[1] and #(player.room:getTag(Pojun.PENDING) or {}) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player)
    local room = player.room
    local turn = turnId(room)
    local function returnCards()
      local entries, rest = {}, {}
      for _, entry in ipairs(room:getTag(Pojun.PENDING) or {}) do
        table.insert(entry.turn == turn and entries or rest, entry)
      end
      room:setTag(Pojun.PENDING, rest)
      for _, entry in ipairs(entries) do
        local to = room:getPlayerById(entry.target)
        local ids = table.filter(entry.ids or {}, function(id)
          return room:getCardArea(id) == Card.Void
        end)
        if #ids > 0 then
          if to == nil or to.dead then
            room:moveCards {
              ids = ids, toArea = Card.DiscardPile,
              moveReason = fk.ReasonPutIntoDiscardPile, moveVisible = true,
            }
          else
            room:obtainCard(to, ids, false, fk.ReasonPrey, nil, "qiao__skill_wu020_2")
          end
        end
        if to then Pojun.refresh(room, to) end
      end
    end
    -- 所有普通 TurnEnd 结算及角色移回完成后，才移回牌。
    local current=room.logic:getCurrentEvent()
    local turnEvent=current and current:findParent(GameEvent.Turn,true)
    if turnEvent then turnEvent:addExitFunc(returnCards) else returnCards() end
  end,
})

return skill
