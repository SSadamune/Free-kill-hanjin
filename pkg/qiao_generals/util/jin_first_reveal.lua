-- EM(JIN001) 首次双亮事件记录。弱键按 TriggerEvent 实例保存，只服务端使用；
-- 不扩写事件 data，避免污染上游固定载荷。
local M = {}
local first = setmetatable({}, { __mode = "k" })

function M.remember(event)
  if event ~= nil then first[event] = true end
end

function M.isFirst(event)
  return event ~= nil and first[event] == true
end

function M.clear(event)
  first[event] = nil
end

return M
