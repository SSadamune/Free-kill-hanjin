-- 吴区阶段与用牌历史组共享工具：克己、谋断、度势、短兵、奋迅共用。
--
-- 本模块只提供：
--   * 从真实 GameEvent 事件树读取“本回合/出牌阶段使用过哪些牌”；
--   * 复用引擎公共的两步式场上移牌；
--   * 当前房间与小势力判断所需的公开信息。
-- 不在此推断规则；调用方负责时机、消耗与效果。
local H = require "packages.hegemony.util"
local History = require "packages.hanjin.pkg.hanjin_mode.rules.wu_history"

local M = {}

--- 取房间。客户端 ClientPlayer 没有 room 字段，退回当前房间。
---@param player ServerPlayer | ClientPlayer
---@return Room | Client
function M.currentRoom(player)
  return (player and player.room) or Fk:currentRoom()
end

--- 本回合由 player 真实使用过的牌记录（花色/类别/颜色/使用阶段）。
--- 只统计真实使用声明；纯“打出”的响应牌不算“使用”。记录由模式级
--- wu_history 监听 fk.AfterCardUseDeclared 写入同步标记。
---@param player ServerPlayer
---@return table[]
function M.usedThisTurn(player)
  return History.used(player)
end

--- 本回合 player 的出牌阶段内真实使用的牌记录。
---@param player ServerPlayer
---@return table[]
function M.playPhaseUsed(player)
  return table.filter(M.usedThisTurn(player), function(record)
    return record.phase == Player.Play
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

--- 公共两步式“移动场上一张牌”：先由引擎筛出确有可移动关系的两名角色，
--- 再由 askToMoveCardInBoard 在其中一人的装备/判定区选牌移动。
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
    prompt = "#hanjin_wu_move_board",
    cancelable = true,
  })
  if targets == nil or #targets < 2 then return nil end
  return room:askToMoveCardInBoard(player, {
    target_one = targets[1],
    target_two = targets[2],
    skill_name = skillName,
    flag = flag,
  })
end

--- 是否为小势力角色（复用 hegemony 公共定义）。
---@param player ServerPlayer
---@return boolean
function M.isSmallKingdom(player)
  return H.isSmallKingdomPlayer(player) == true
end

-- 涉猎的正式整理界面规则：客户端安排到“获得”区的牌必须花色互不相同。
-- 这样客户端直接表达合法选择；服务端仍会复核，不依赖客户端过滤。
Fk:addPoxiMethod {
  name = "hanjin_shelie",
  card_filter = function()
    return true
  end,
  feasible = function(selected, data)
    local chosen = data and data[2] or {}
    local seen = {}
    for _, id in ipairs(chosen) do
      local card = Fk:getCardById(id)
      if card == nil or card.suit == Card.NoSuit or seen[card.suit] then return false end
      seen[card.suit] = true
    end
    return true
  end,
  prompt = function()
    return "#hanjin_shelie-choose"
  end,
  default_choice = function()
    return {}
  end,
}

Fk:loadTranslationTable {
  ["#hanjin_wu_move_board"] = "选择两名角色，然后移动其中一人场上的一张牌",
  ["#hanjin_shelie-choose"] = "选择获得其中任意张花色各不相同的牌",
}

return M
