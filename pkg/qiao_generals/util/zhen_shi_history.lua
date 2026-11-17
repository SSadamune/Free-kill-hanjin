-- 阵/势包本回合明置武将牌的公共历史。
-- 由模式静态技能在 GeneralRevealed 时记账，修体等技能只读取，不要求当前仍持有
-- 记账技能；按“不同将牌名”去重，同一张牌重复明置不增加。
local M = {}

M.TAG = "qiao_zhen_shi_revealed"
M.CARD_TAG = "qiao_zhen_shi_card_events"

---@param room Room
---@return integer
function M.turnId(room)
  local logic = room and room.logic
  local current = logic and logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  return turn and turn.id or 0
end

---@param room Room
---@param data table
function M.record(room, data)
  if room == nil or data == nil then return end
  local turn = M.turnId(room)
  local records = room:getTag(M.TAG) or {}
  for _, key in ipairs({ "m", "d" }) do
    local name = data[key]
    if type(name) == "string" and name ~= "" and name ~= "anjiang" then
      local exists = table.find(records, function(record) return record.name == name end)
      if exists == nil then table.insert(records, { turn = turn, name = name }) end
    end
  end
  room:setTag(M.TAG, records)
end

--- 清空本回合记录；由模式 TurnStart 调用。
---@param room Room
function M.clear(room)
  if room ~= nil then
    room:setTag(M.TAG, {})
    room:setTag(M.CARD_TAG, {})
  end
end

--- 记录一次公开的“使用”或“打出”事件（不是材料张数）。
--- @param room Room
--- @param player ServerPlayer
--- @param kind "use"|"play"
function M.recordCard(room, player, kind)
  if room == nil or player == nil then return end
  local records = room:getTag(M.CARD_TAG) or {}
  table.insert(records, {
    turn = M.turnId(room), player = player.id, kind = kind,
  })
  room:setTag(M.CARD_TAG, records)
end

--- @param room Room
--- @param player ServerPlayer
--- @return integer
function M.cardCount(room, player)
  if room == nil or player == nil then return 0 end
  local turn, count = M.turnId(room), 0
  for _, record in ipairs(room:getTag(M.CARD_TAG) or {}) do
    if record.turn == turn and record.player == player.id then count = count + 1 end
  end
  return count
end

---@param room Room
---@return integer
function M.count(room)
  if room == nil then return 0 end
  local seen, count = {}, 0
  for _, record in ipairs(room:getTag(M.TAG) or {}) do
    if not seen[record.name] then
      seen[record.name] = true
      count = count + 1
    end
  end
  return count
end

return M
