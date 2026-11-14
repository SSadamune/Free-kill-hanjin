-- 度势的公共事实层：本回合已置入过弃牌堆的花色。
--
-- 事实必须由模式级全局记录器在开局安装，不能依赖度势武将是否在场/明置/换将。
-- 记录以同步的玩家标记暴露给客户端与服务器：度势的转化技在客户端筛选“本回合
-- 未置入过弃牌堆的花色”，不能读取服务端私有事件树。
--
-- 标记写在每名角色身上（内容相同），客户端读取自己或任一角色的同一标记即可。
-- `-turn` 后缀由引擎在回合结束时清理；TurnStart/GameStart 再显式清空。
local M = {}

M.MARK = "hanjin_wu_discard_suits-turn"

--- 本回合使用过的牌（花色/类别/颜色/使用时的阶段）。
--- 只公开牌名本身已经公开的信息，供克己与谋断读取。
M.USED_MARK = "hanjin_wu_used_cards-turn"

--- 全局记录器技能名；由 mode.lua 在游戏启动前安装到房间。
M.HISTORY_SKILL = "hanjin__wu_history"

--- 奋迅的持续距离技能名；由 mode.lua 安装，读取 `-turn` 标记。
M.DISTANCE_SKILL = "hanjin__wu_distance_effects"
-- 角色自身的中性本回合状态名；不得带技能来源前缀，避免交换公共机制迁移。
M.FENXUN_MARK = "hanjin_wu_fenxun_target-turn"

local function validSuit(suit)
  return suit == Card.Spade or suit == Card.Heart or suit == Card.Club or suit == Card.Diamond
end

--- 某角色可见的本回合已置入弃牌堆花色集合（同步标记）。
---@param player Player
---@return integer[]
function M.suits(player)
  if player == nil then return {} end
  return player:getTableMark(M.MARK)
end

---@param player Player
---@param suit integer
---@return boolean
function M.hasSuit(player, suit)
  return validSuit(suit) and table.contains(M.suits(player), suit)
end

--- 四种花色是否均已置入过弃牌堆。
---@param player Player
---@return boolean
function M.allSuits(player)
  return #M.suits(player) >= 4
end

--- 本回合使用过的牌记录（同步标记）。
---@param player Player
---@return table[]
function M.used(player)
  if player == nil then return {} end
  return player:getTableMark(M.USED_MARK)
end

--- 记录一次真实使用（声明使用后）。只记录公开的牌面信息与使用阶段。
--- 同一张牌在结算中被重复使用/多次生效时仍只按一次声明记录。
---@param room Room
---@param player Player
---@param card Card
function M.recordUsed(room, player, card)
  if room == nil or player == nil or card == nil then return end
  local list = player:getTableMark(M.USED_MARK)
  table.insert(list, {
    suit = card.suit,
    type = card.type,
    color = card.color,
    phase = player.phase,
  })
  room:setPlayerMark(player, M.USED_MARK, list)
end

--- 记录一张真实进入弃牌堆的牌的花色。幂等。
---@param room Room
---@param suit integer
function M.record(room, suit)
  if room == nil or not validSuit(suit) then return end
  local list
  for _, player in ipairs(room.players) do
    list = player:getTableMark(M.MARK)
    if table.contains(list, suit) then return end
  end
  list = list or {}
  table.insert(list, suit)
  for _, player in ipairs(room.players) do
    room:setPlayerMark(player, M.MARK, table.simpleClone(list))
  end
end

--- 清空所有角色的本回合弃牌花色集合。
---@param room Room
function M.clear(room)
  if room == nil then return end
  for _, player in ipairs(room.players) do
    room:setPlayerMark(player, M.MARK, {})
    room:setPlayerMark(player, M.USED_MARK, {})
  end
end

return M
