-- 汉晋标准将包·本组公用的“本回合得到牌”查询。
--
-- 规则依据：rulebook/terms/card-op-terms/gain.md——牌移至一名角色的手牌区，
-- 即其“得到”这些牌；装备区不算法定“得到”。这里直接读取本回合实际发生的
-- GameEvent.MoveCards 历史，而不是在某个技能获得时安装记录器，因此：
--   * 暗置、晚获得技能或技能失效都不会漏掉本回合此前的得牌；
--   * 不创建/注册房间技能对象，也不存在同名对象重复注册的分叉风险；
--   * 每个新回合以当前 GameEvent.Turn 为边界，不跨回合累计。
local M = {}

-- 仅测试用：把查询下界固定到当前事件 id，便于在同一房间内构造明确的
-- “本回合从此刻开始”的夹具。正式游戏不会调用。
M.FLOOR_TAG = "hanjin_han_history_floor"

--- 测试夹具用：从当前事件之后重新累计。
---@param room Room
function M.clear(room)
  if room == nil or type(room.setTag) ~= "function" then return end
  local logic = room.logic
  room:setTag(M.FLOOR_TAG, logic and logic.current_event_id or 0)
end

--- 本回合某角色得到过的牌数（按进入手牌区的牌张数累计）。
---@param room Room
---@param player ServerPlayer | ClientPlayer
---@return integer
function M.count(room, player)
  if room == nil or player == nil then return 0 end
  local logic = room.logic
  if logic == nil or logic.event_recorder == nil then return 0 end

  local floor = room:getTag(M.FLOOR_TAG) or 0
  local current = logic.getCurrentEvent and logic:getCurrentEvent() or nil
  local turn = current and current:findParent(GameEvent.Turn, true) or nil
  if turn == nil then
    local turns = logic.event_recorder[GameEvent.Turn] or {}
    turn = turns[#turns]
  end
  local start_id = floor > 0 and floor or (turn and turn.id or 0)
  local end_id = logic.current_event_id or (current and current.id) or start_id

  local total = 0
  local events = logic.event_recorder[GameEvent.MoveCards] or {}
  for i = #events, 1, -1 do
    local event = events[i]
    if event.id <= start_id then break end
    if event.id <= end_id then
      for _, move in ipairs(event.data or {}) do
        if move.toArea == Card.PlayerHand and move.to == player then
          total = total + #(move.moveInfo or {})
        end
      end
    end
  end
  return total
end

return M
