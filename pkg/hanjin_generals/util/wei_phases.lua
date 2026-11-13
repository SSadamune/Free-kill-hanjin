-- 魏区阶段组共享工具：轻辎/神速/设变/巧变共用。
--
-- 这里的函数只做两件事：
--   * 用公共的 canSkip/skip 接口判断与执行阶段跳过，不手写回合阶段表；
--   * 复用引擎的 askToMoveCardInBoard 完成“移动场上一张牌”，服务端与客户端
--     走同一套请求。
-- 不在此模块中推断规则；调用方负责时机、消耗与效果。
local H = require "packages.hegemony.util"

local M = {}

M.GOD_SPEED = "hanjin__skill_wei008_1"

--- 取房间。客户端 ClientPlayer 没有 room 字段，退回当前房间。
---@param player ServerPlayer | ClientPlayer
---@return Room | Client
function M.currentRoom(player)
  return (player and player.room) or Fk:currentRoom()
end

--- 与技能拥有者势力相同的其他角色。
--- 势力判断复用 hegemony 的公共“明置后势力预测”机制：拥有者暗置时按本局
--- 势力标记预测明置后的势力，他人暗置时公开势力为 unknown，不纳入候选。
--- 只读取客户端同样可见的信息，不依赖服务端私有字段。
---@param room Room | Client
---@param player ServerPlayer | ClientPlayer
---@return ServerPlayer[] | ClientPlayer[]
function M.sameKingdomOthers(room, player)
  return table.filter(room.alive_players, function(p)
    return p ~= player and not p:isRemoved() and p.kingdom ~= "unknown"
      and H.compareExpectedKingdomWith(player, p) == true
  end)
end

--- 当前是否存在可移动的场上牌。
---@param room Room | Client
---@param flag? "e" | "j"
---@return boolean
function M.hasMovableBoardCard(room, flag)
  local movable = room:canMoveCardInBoard(flag, nil, {})
  return type(movable) == "table" and #movable > 0
end

--- 参与“场上一张牌可移动”关系的角色。只有这类角色才能成为两步式移牌的
--- 公共两步式“移动场上一张牌”：先由引擎的
--- `askToChooseToMoveCardInBoard` 在两阶段内筛出确有可移动牌的两名角色，
--- 再由 `askToMoveCardInBoard` 在其中一人的装备/判定区选牌移动。取消第一步
--- 则不移动。
---@param room Room
---@param player ServerPlayer
---@param skillName string
---@param flag? "e" | "j"
---@return { card: Card, from: ServerPlayer, to: ServerPlayer }?
function M.moveCardInBoard(room, player, skillName, flag)
  if not M.hasMovableBoardCard(room, flag) then return nil end
  local targets = room:askToChooseToMoveCardInBoard(player, {
    flag = flag,
    skill_name = skillName,
    prompt = "#hanjin_wei_move_board",
    cancelable = true,
  })
  if targets == nil or #targets < 2 then return nil end
  local ret = room:askToMoveCardInBoard(player, {
    target_one = targets[1],
    target_two = targets[2],
    skill_name = skillName,
    flag = flag,
  })
  return ret
end

Fk:loadTranslationTable {
  ["#hanjin_wei_move_board"] = "选择两名角色，然后移动其中一人场上的一张牌",
}

return M
