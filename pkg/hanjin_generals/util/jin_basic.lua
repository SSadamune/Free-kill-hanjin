-- 晋势力标准包常规辅助：弘训的势力判断、膂力的补至／回复至与全弃手牌。
--
-- 这里只放跨技能重复、且不改变规则含义的公共操作；时机、消耗与选项合法性
-- 仍由各技能自行判断。客户端可能调用其中的纯查询函数，因此不读取
-- `player.room` 私有字段，势力比较复用 hegemony 公共工具。
local H = require "packages.hegemony.util"

local M = {}

--- 国战势力相同；自己与自己视为相同。未知势力由公共工具判定为不同。
---@param a Player
---@param b Player
---@return boolean
function M.sameKingdom(a, b)
  if a == nil or b == nil then return false end
  return a == b or H.compareKingdomWith(a, b)
end

--- 将手牌补至当前体力值；手牌已不少于体力值时不摸牌（补至的差额）。
---@param player ServerPlayer
---@param skillName string
function M.drawHandToHp(player, skillName)
  if player == nil or player.dead then return end
  local num = player.hp - #player:getCardIds(Player.Hand)
  if num > 0 then
    player:drawCards(num, skillName)
  end
end

--- 手牌区是否有一张以上、且全部可弃置的牌。空手不能执行“弃置所有手牌”。
---@param player ServerPlayer
---@return boolean
function M.canDiscardAllHand(player)
  if player == nil or player.dead then return false end
  local ids = player:getCardIds(Player.Hand)
  if #ids == 0 then return false end
  for _, id in ipairs(ids) do
    if player:prohibitDiscard(id) then return false end
  end
  return true
end

--- 实际弃置全部手牌，返回实际弃置张数；不满足全弃时不做部分弃置。
---@param room Room
---@param player ServerPlayer
---@param skillName string
---@return integer
function M.discardAllHand(room, player, skillName)
  if room == nil or not M.canDiscardAllHand(player) then return 0 end
  local ids = player:getCardIds(Player.Hand)
  room:throwCard(ids, skillName, player, player)
  return #ids
end

--- 将体力回复至 targetHp：受体力上限限制，且不低于当前体力。
--- 当前体力已不小于目标值时，按“回复至”不执行回复，也不降低体力。
---@param player ServerPlayer
---@param targetHp integer
---@param skillName string
function M.recoverHpTo(player, targetHp, skillName)
  if player == nil or player.dead then return end
  local capped = math.min(targetHp, player.maxHp)
  if player.hp < capped then
    player.room:recover {
      who = player,
      num = capped - player.hp,
      recoverBy = player,
      skillName = skillName,
    }
  end
end

return M
