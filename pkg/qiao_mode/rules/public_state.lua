local M = {}

-- 公开状态包含数组和字典，数组顺序也会影响客户端显示。
local function sameValue(before, after)
  if before == after then return true end
  if type(before) ~= "table" or type(after) ~= "table" then return false end
  for key, value in pairs(before) do
    if not sameValue(value, after[key]) then return false end
  end
  for key in pairs(after) do
    if before[key] == nil then return false end
  end
  return true
end

function M.setPlayerMark(room, player, mark, value)
  if not sameValue(player:getMark(mark), value) then
    room:setPlayerMark(player, mark, value)
  end
end

function M.setBanner(room, name, value)
  if not sameValue(room:getBanner(name), value) then
    room:setBanner(name, value)
  end
end

return M
