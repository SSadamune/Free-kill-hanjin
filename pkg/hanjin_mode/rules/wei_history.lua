-- 长驱的公共事实层：本回合“某来源实际伤害过哪些目标”。
--
-- 事实必须由模式级全局记录器在开局安装，不能依赖长驱武将是否在场/明置/后来换将。
-- 记录以同步的玩家标记暴露，只包含规则允许公开的“目标 id 集合”：
--   * 客户端与服务器的 targetmod 都读同一份标记，不再读取 server 私有 room tag；
--   * 标记只在真实伤害（fk.Damage、伤害量 > 0）后刷新；
--   * 每回合开始清空；来源可以是任何角色，与是否拥有长驱无关。
local M = {}

M.MARK = "hanjin_wei_damage_targets"

--- 全局记录器技能名；由 mode.lua 在游戏启动前安装到房间。
M.HISTORY_SKILL = "hanjin__wei_damage_history"

--- 伪溃固定距离：模式级距离技能与发动者写入的 `-turn` 标记。
M.WEIKUI_DISTANCE_SKILL = "hanjin__wei_distance_effects"
M.WEIKUI_DISTANCE_MARK = "hanjin__skill_wei011_1_target-turn"

--- 某来源本回合伤害过的目标 id 集合（同步标记，客户端可用）。
---@param player Player
---@return integer[]
function M.targets(player)
  if player == nil then return {} end
  return player:getTableMark(M.MARK)
end

---@param player Player
---@param targetId integer
---@return boolean
function M.damaged(player, targetId)
  return table.contains(M.targets(player), targetId)
end

--- 记录一次真实伤害。幂等：同一目标本回合只出现一次。
---@param room Room
---@param from Player
---@param to Player
function M.record(room, from, to)
  if room == nil or from == nil or to == nil then return end
  local list = from:getTableMark(M.MARK)
  if table.contains(list, to.id) then return end
  table.insert(list, to.id)
  room:setPlayerMark(from, M.MARK, list)
end

--- 清空所有角色的本回合伤害集合。
---@param room Room
function M.clear(room)
  if room == nil then return end
  for _, player in ipairs(room.players) do
    room:setPlayerMark(player, M.MARK, {})
  end
end

return M
