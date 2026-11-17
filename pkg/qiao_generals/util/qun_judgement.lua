-- 群包判定公共小工具。
--
-- 判定统一走 room:judge，保留正式判定流程（鬼道等改判、判定牌展示与移动）。
-- room:judge 的返回值不是 JudgeData：判定结果写回传入的 judge 表，因此这里
-- 读完原表再返回最终判定牌。
-- 判定结束后判定牌通常已在弃牌堆，取得时须复核实际区域；叠置/平置是定向
-- 操作（平置→叠置、叠置→平置），已叠置再次叠置不产生变化。
local M = {}

--- 进行一次正式判定并返回最终判定牌。
---@param room Room
---@param who ServerPlayer
---@param reason string
---@param pattern? string|table
---@return Card?
function M.judge(room, who, reason, pattern)
  if room == nil or who == nil then return nil end
  local data = {
    who = who,
    reason = reason or "",
    pattern = pattern or ".",
  }
  room:judge(data)
  return data.card
end

--- 令 player 获得一张判定牌；牌须仍在处理区或弃牌堆。
---@param room Room
---@param player ServerPlayer?
---@param card Card?
---@param skillName string
---@return boolean
function M.obtainJudgeCard(room, player, card, skillName)
  if room == nil or player == nil or card == nil or player.dead then return false end
  local id = card:getEffectiveId()
  if id == nil then return false end
  local area = room:getCardArea(id)
  if area ~= Card.DiscardPile and area ~= Card.Processing then return false end
  room:obtainCard(player, id, true, fk.ReasonJustMove, player, skillName)
  return true
end

--- 定向叠置：仅把平置改为叠置；已叠置不翻回。
---@param player ServerPlayer?
---@return boolean 是否实际发生变化
function M.stack(player)
  if player == nil or player.dead then return false end
  if player.faceup then
    player:turnOver()
    return true
  end
  return false
end

return M
