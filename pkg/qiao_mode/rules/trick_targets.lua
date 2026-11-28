local M = {}
local HISTORY = "qiao_trick_targets-turn"

-- 记录角色实际进入「成为目标时」的事实。技能所属武将牌不参与记录。
function M.record(target, aim)
  if not target or not aim or not aim.card or aim.card.type ~= Card.TypeTrick then return end
  local room = target.room
  local history = room:getTag(HISTORY) or {}
  local previous = history[target.id]
  aim.qiao_first_trick_target = previous == nil
  aim.qiao_first_common_trick_target = aim.card:isCommonTrick() and previous ~= "common"
  if aim.qiao_first_trick_target or aim.qiao_first_common_trick_target then
    history[target.id] = aim.qiao_first_common_trick_target and "common" or "delayed"
    room:setTag(HISTORY, history)
  end
end

function M.hasUnspecifiedLegalTarget(target, aim)
  local use = aim.use
  if not use or not use.from or aim.toCard ~= nil then return false end
  local ok, available = pcall(aim.card.getAvailableTargets, aim.card, use.from, use.extra_data)
  if not ok or type(available) ~= "table" then return false end
  return table.find(available, function(player)
    return player ~= target and player:isAlive() and not player:isRemoved()
      and not table.contains(use.tos or {}, player)
  end) ~= nil
end

return M
