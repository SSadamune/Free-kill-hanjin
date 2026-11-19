-- 魏区阶段组共享工具：轻辎/神速/设变/巧变共用。
--
-- 这里的函数只做两件事：
--   * 用公共的 canSkip/skip 接口判断与执行阶段跳过，不手写回合阶段表；
--   * 以“选两名角色 → 公开候选选场上牌 → 移动”完成“移动场上一张牌”，
--     选牌走引擎的 askToChooseCards（AskForPoxi），移动沿用引擎同源的区域、
--     原因与技能来源。不在此模块中推断规则；调用方负责时机、消耗与效果。
local H = require "packages.hegemony.util"

local M = {}

M.GOD_SPEED = "qiao__skill_wei008_1"

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
  return table.filter(room:getPresentPlayers(), function(p)
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

--- 拆出真正参与移牌关系的角色：froms 至少有牌可移出，tos 至少能接收一张。
--- 引擎的 target_filter 只保证“第一个选中者名下有牌”，把这两个列表传给
--- askToChooseToMoveCardInBoard，可避免把完全没有场上牌的角色列入第一步。
---@param room Room
---@param flag? "e" | "j"
---@return ServerPlayer[] froms, ServerPlayer[] tos
function M.boardMoveParticipants(room, flag)
  local froms, tos = {}, {}
  for _, from in ipairs(room.alive_players) do
    for _, to in ipairs(room.alive_players) do
      if from ~= to and from:canMoveCardsInBoardTo(to, flag, {}) then
        table.insertIfNeed(froms, from)
        table.insertIfNeed(tos, to)
      end
    end
  end
  return froms, tos
end

--- 两名角色之间当前可移动的场上牌，按来源角色分组（装备区与判定区合并）。
--- 与引擎 askToMoveCardInBoard 的筛选一致：装备牌看目标是否有空装备栏，判定牌
--- 看目标是否被禁止，双向都收集，虚拟装备同样按 canMoveCardInBoardTo 判断。
--- 分组标题用座位键，由客户端按公开信息翻译，不暴露暗置武将。
---@param one ServerPlayer
---@param two ServerPlayer
---@param flag? "e" | "j"
---@return table[] groups
function M.movableBoardCardGroups(one, two, flag)
  local groups = {}
  local function collect(owner, other)
    local ids = {}
    if not flag or flag == "e" then
      for _, id in ipairs(owner:getCardIds(Player.Equip)) do
        if owner:canMoveCardInBoardTo(other, id) then table.insert(ids, id) end
      end
    end
    if not flag or flag == "j" then
      for _, id in ipairs(owner:getCardIds(Player.Judge)) do
        if owner:canMoveCardInBoardTo(other, id) then table.insert(ids, id) end
      end
    end
    if #ids > 0 then
      table.insert(groups, { "seat#" .. tostring(owner.seat), ids })
    end
  end
  collect(one, two)
  collect(two, one)
  return groups
end

--- 公共两步式“移动场上一张牌”：先由引擎的两步式选人筛出确有可移动牌的两名
--- 角色，再由公开的 askToChooseCards 候选面板在其中一人的装备/判定区选牌，
--- 最后按引擎同样的区域、原因、技能来源执行移动。取消第一步或第二步都不移动。
--- 第二步只列出两人之间当前真正可移动的牌；没有候选时不询问。
---@param room Room
---@param player ServerPlayer
---@param skillName string
---@param flag? "e" | "j"
---@param prompt? string
---@return { card: Card, from: ServerPlayer, to: ServerPlayer }?
function M.moveCardInBoard(room, player, skillName, flag, prompt)
  local froms, tos = M.boardMoveParticipants(room, flag)
  if #froms == 0 or #tos == 0 then return nil end
  local targets = room:askToChooseToMoveCardInBoard(player, {
    flag = flag,
    skill_name = skillName,
    prompt = prompt or "#qiao_wei_move_board",
    cancelable = true,
    froms = froms,
    tos = tos,
  })
  if type(targets) ~= "table" or #targets < 2 then return nil end
  local targetOne, targetTwo = targets[1], targets[2]
  -- 选人与选牌之间若状态变化，这一对可能已无可移动牌；此时结束询问。
  local groups = M.movableBoardCardGroups(targetOne, targetTwo, flag)
  local offered = {}
  for _, group in ipairs(groups) do
    table.insertTable(offered, group[2])
  end
  if #offered == 0 then return nil end

  local chosen = room:askToChooseCards(player, {
    target = player,
    flag = { card_data = groups },
    min = 1,
    max = 1,
    skill_name = skillName,
    prompt = "#qiao_move_board_pick",
    cancelable = true,
  })
  if type(chosen) ~= "table" or #chosen ~= 1 then return nil end
  local id = chosen[1]
  if not table.contains(offered, id) then return nil end

  -- 确认选牌到执行之间再校验一次：牌仍在场上、仍属所选两人之一，且仍可移到另一人。
  local area = room:getCardArea(id)
  if area ~= Card.PlayerEquip and area ~= Card.PlayerJudge then return nil end
  local from = room:getCardOwner(id)
  if from == nil then return nil end
  local to = from == targetOne and targetTwo or (from == targetTwo and targetOne or nil)
  if to == nil or not from:canMoveCardInBoardTo(to, id) then return nil end

  -- 与引擎 askToMoveCardInBoard 同源：虚拟装备取虚拟牌，区域、原因、技能来源、
  -- 操作者保持一致。
  local cardToMove = from:getVirtualEquip(id) or Fk:getCardById(id)
  if cardToMove == nil then return nil end
  room:moveCardTo(
    cardToMove,
    cardToMove.type == Card.TypeEquip and Player.Equip or Player.Judge,
    to,
    fk.ReasonPut,
    skillName,
    nil,
    true,
    player
  )
  return { card = cardToMove, from = from, to = to }
end

Fk:loadTranslationTable {
  ["#qiao_wei_move_board"] = "选择两名角色，然后移动其中一人场上的一张牌",
  ["#qiao_move_board_pick"] = "选择要移动的场上牌",
}

return M
