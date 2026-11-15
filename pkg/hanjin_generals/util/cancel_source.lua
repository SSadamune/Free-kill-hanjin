-- 共享：确认某次卡牌效果的实际抵消者。
--
-- 不使用“响应牌当前持有者”：响应牌使用后进入弃牌堆，owner 变为 nil，会错误
-- 退回被取消牌的目标。这里从真实 UseCard 事件关联（use.responseToEvent 指向
-- 被取消的效果）取得实际使用响应牌的角色，覆盖实体/虚拟闪与无懈可击。
local M = {}

---@param room Room
---@param data CardEffectData
---@return ServerPlayer?
function M.canceller(room, data)
  if room == nil or data == nil or room.logic == nil then return nil end
  local events = room.logic.event_recorder[GameEvent.UseCard] or {}
  for i = #events, 1, -1 do
    local event = events[i]
    local use = event.data
    if use ~= nil and use.responseToEvent ~= nil and use.from ~= nil then
      if use.responseToEvent == data then return use.from end
      -- 部分取消事件在数据重建后不是同一张表；按被取消牌/来源/目标复核。
      local re = use.responseToEvent
      if re.card ~= nil and re.card == data.card and re.to == data.to
        and re.from == data.from then
        return use.from
      end
    end
  end
  return nil
end

return M
