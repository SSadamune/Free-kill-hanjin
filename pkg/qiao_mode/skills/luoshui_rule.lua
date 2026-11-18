-- 洛水之誓的“置回判定区 + 下一个阶段改为判定阶段”接线。
--
-- 规则依据：docs/rules/card-deck.md「势力锦囊的结算审阅 · 洛水之誓」。非黑桃
-- 2～9 的分支要求“于该阶段开始前将原实体置回目标判定区，并把该阶段改为判定
-- 阶段”。判定结算时只在处理区保留原实体并登记待办；真正的置回与阶段改写都在
-- 该阶段准备点（`fk.EventPhaseChanging`，Phase:main 之前）完成，阶段队列长度与
-- 原有调度不变。已跳过、回合结束、目标离场或原实体已不在处理区时，按共用规则
-- 把原实体移出游戏。
local skill = fk.CreateSkill {
  name = "qiao__luoshui_rule",
  tags = { Skill.Compulsory },
}

local PENDING_TAG = "qiao_luoshui_pending"

local function pendingOf(room)
  local pending = room:getTag(PENDING_TAG)
  if type(pending) ~= "table" then return nil end
  return pending
end

local function clearPending(room)
  room:setTag(PENDING_TAG, nil)
end

--- 原实体按延时锦囊共用收尾：移入弃牌堆（势力锦囊规则再移出游戏）。
local function retireCard(room, id)
  if id == nil then return end
  room:moveCardTo(id, Card.DiscardPile, nil, fk.ReasonPut, skill.name, nil, true)
end

local function currentTurn(room)
  local current = room.logic:getCurrentEvent()
  return current and current:findParent(GameEvent.Turn, true)
end

-- 本次自用已有待重判时，不让原实体被原生延时入区或 UseCard:clear 移出处理区。
-- 只在该次用牌的上下文中拦截，不影响其他移动。
skill:addEffect(fk.BeforeCardsMove, {
  global = true,
  late_refresh = true,
  can_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    local pending = pendingOf(room)
    if pending == nil or pending.use == nil then return false end
    local current = room.logic:getCurrentEvent()
    local use = current and current:findParent(GameEvent.UseCard, true)
    if use == nil or use.id ~= pending.use then return false end
    for _, move in ipairs(data or {}) do
      for _, info in ipairs(move.moveInfo or {}) do
        if info.cardId == pending.card and info.fromArea == Card.Processing then
          return true
        end
      end
    end
    return false
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    local pending = pendingOf(room)
    if pending == nil then return end
    for _, move in ipairs(data or {}) do
      local keep = {}
      for _, info in ipairs(move.moveInfo or {}) do
        if not (info.cardId == pending.card and info.fromArea == Card.Processing) then
          table.insert(keep, info)
        end
      end
      move.moveInfo = keep
    end
  end,
})

-- 下一个阶段的准备点：复核仍持有处理区原实体，实际置回判定区成功才改写阶段。
skill:addEffect(fk.EventPhaseChanging, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    local pending = pendingOf(room)
    if pending == nil or data == nil then return false end
    local turn = currentTurn(room)
    if turn == nil or turn.id ~= pending.turn then return false end
    return (turn.data.phase_index or 0) == pending.index
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    local pending = pendingOf(room)
    if pending == nil then return end
    clearPending(room)
    local target = room:getPlayerById(pending.target)
    local inProcessing = pending.card ~= nil and room:getCardArea(pending.card) == Card.Processing
    if data.skipped == true or not inProcessing or target == nil
      or target.dead or target:isRemoved() then
      retireCard(room, pending.card)
      return
    end
    room:moveCardTo(pending.card, Card.PlayerJudge, target, fk.ReasonPut, skill.name, nil, true)
    if room:getCardArea(pending.card) ~= Card.PlayerJudge
      or room:getCardOwner(pending.card) ~= target then
      retireCard(room, pending.card)
      return
    end
    -- 只改这一个阶段的类型：阶段对象、队列长度与原调度保持不变。
    data.phase = Player.Judge
  end,
})

-- 已经越过绑定的阶段（例如该阶段被跳过）仍留有实体时：按共用规则移出游戏。
skill:addEffect(fk.EventPhaseEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    local pending = pendingOf(room)
    if pending == nil then return false end
    local turn = currentTurn(room)
    if turn == nil or turn.id ~= pending.turn then return true end
    return (turn.data.phase_index or 0) >= pending.index
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    local pending = pendingOf(room)
    if pending == nil then return end
    clearPending(room)
    retireCard(room, pending.card)
  end,
})

-- 回合结束时仍未处理的待办：原实体按共用规则移出游戏。
skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return pendingOf(Fk:currentRoom()) ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    local pending = pendingOf(room)
    if pending == nil then return end
    clearPending(room)
    retireCard(room, pending.card)
  end,
})

Fk:loadTranslationTable {
  ["qiao__luoshui_rule"] = "洛水之誓规则",
}

return skill
