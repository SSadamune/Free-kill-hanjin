-- WU022 吕范 · 调度
-- 准备阶段，你可以获得或移动与你势力相同的角色装备区一张牌。
-- 每回合首次有牌置入每名与你势力相同的角色装备区后，其摸一张牌。
local H = require "packages.hegemony.util"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local Bian = require "packages.qiao.pkg.qiao_generals.util.bian_common"
local Board = require "packages.qiao.pkg.qiao_generals.util.wei_phases"
local WuLord = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu022_1",
}
skill.qiaoImplemented = true

local OPT_OBTAIN = "#qiao__skill_wu022_1-obtain"
local OPT_MOVE = "#qiao__skill_wu022_1-move"

--- 调度准备阶段的获得与移动均为非弃置移牌，均排除已明置【聚宝】保护的宝物牌（保留同装备区其余合法装备）。
local function selectableEquipIds(from, player)
  if from == nil then return {} end
  return table.filter(from:getCardIds(Player.Equip), function(id)
    if from ~= player and from:hasShownSkill(WuLord.JUBAO)
      and WuLord.isProtectedTreasure(from, player, id) then
      return false
    end
    return true
  end)
end

local function sameKingdomWithEquip(room, player)
  return table.filter(room:getPresentPlayers(), function(p)
    return H.compareKingdomWith(p, player) and #selectableEquipIds(p, player) > 0
  end)
end

local function moveFilter(player)
  return function(from, to, id)
    return H.compareKingdomWith(from, player) and Bian.canMoveEquipTo(from, to, id, player)
  end
end

-- 效果一：准备阶段获得或移动同势力角色装备区一张牌。
skill:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player.phase == Player.Start
      and not player.dead and player:hasSkill(skill.name)
      and #sameKingdomWithEquip(player.room, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = sameKingdomWithEquip(room, player)
    if #targets == 0 then return false end
    local choices = { OPT_OBTAIN }
    local froms = Board.boardMoveParticipants(room, "e", moveFilter(player))
    if #froms > 0 then table.insert(choices, OPT_MOVE) end
    local action = Selection.askOption(room, player, {
      choices = choices, all_choices = { OPT_OBTAIN, OPT_MOVE }, buttons = true,
      skill_name = skill.name, prompt = "#qiao__skill_wu022_1-action", cancelable = true,
    })
    if not action then return false end
    event:setCostData(self, { action = action })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if event:getCostData(self).action == OPT_MOVE then
      Board.moveCardInBoard(room, player, skill.name, "e", "#qiao__skill_wu022_1-move-pair",
        { allowed = moveFilter(player), cancelable = false })
      return
    end
    local targets = sameKingdomWithEquip(room, player)
    if #targets == 0 then return end
    local chosen = room:askToChoosePlayers(player, {
      targets = targets, min_num = 1, max_num = 1, skill_name = skill.name,
      prompt = "#qiao__skill_wu022_1-choose", cancelable = false,
    })
    local from = chosen and chosen[1]
    if not table.contains(targets, from) or not RemovedTargets.isPresent(from) then return end
    local validIds = selectableEquipIds(from, player)
    if #validIds == 0 then return end
    local allEquips = from:getCardIds(Player.Equip)
    local flag = (#validIds == #allEquips) and "e" or { card_data = { { "$Equip", validIds } } }
    local cardId = room:askToChooseCard(player, {
      target = from,
      flag = flag,
      skill_name = skill.name,
      prompt = "#qiao__skill_wu022_1-card::" .. from.id,
    })
    if cardId == nil or not table.contains(validIds, cardId) then return end

    if table.contains(selectableEquipIds(from, player), cardId) then
      room:obtainCard(player, cardId, true, fk.ReasonPrey, player, skill.name)
    end
  end,
})

local function firstEquipReceiversThisTurn(room, player, data)
  local current = room.logic:getCurrentEvent()
  if current == nil then return {} end
  local receivers = {}
  for _, move in ipairs(data or {}) do
    if move.to ~= nil and move.toArea == Card.PlayerEquip and #(move.moveInfo or {}) > 0
      and RemovedTargets.isPresent(move.to) and H.compareKingdomWith(move.to, player) then
      table.insertIfNeed(receivers, move.to)
    end
  end
  if #receivers == 0 then return {} end
  local result = {}
  for _, dest in ipairs(receivers) do
    local firstEvents = room.logic:getEventsOfScope(GameEvent.MoveCards, 1, function(e)
      for _, move in ipairs(e.data or {}) do
        if move.to == dest and move.toArea == Card.PlayerEquip and #(move.moveInfo or {}) > 0 then
          return true
        end
      end
      return false
    end, Player.HistoryTurn)
    if #firstEvents == 1 and firstEvents[1] == current then
      table.insert(result, dest)
    end
  end
  if #result > 1 then room:sortByAction(result) end
  return result
end

-- 效果二：每回合首次有牌置入每名同势力角色装备区后，其摸一张牌。
skill:addEffect(fk.AfterCardsMove, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if player.dead or not player:hasSkill(skill.name) then return false end
    local receivers = firstEquipReceiversThisTurn(player.room, player, data)
    if #receivers == 0 then return false end
    event:setCostData(self, { tos = receivers })
    return true
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local tos = (event:getCostData(self) or {}).tos or {}
    for _, dest in ipairs(tos) do
      if RemovedTargets.isPresent(dest) then
        room:doIndicate(player.id, { dest.id })
        dest:drawCards(1, skill.name)
      end
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "调度",
  [":" .. skill.name] = "准备阶段，你可以获得或移动与你势力相同的角色装备区一张牌。每回合首次有牌置入每名与你势力相同的角色装备区后，其摸一张牌。",
  ["#qiao__skill_wu022_1-choose"] = "调度：选择一名与你势力相同的角色，获得其装备区一张牌",
  ["#qiao__skill_wu022_1-card"] = "调度：选择 %dest 装备区的一张牌",
  ["#qiao__skill_wu022_1-action"] = "调度：获得或移动同势力角色装备区的一张牌",
  ["#qiao__skill_wu022_1-move-pair"] = "调度：选择两名角色，移动同势力角色装备区的一张牌",
  [OPT_OBTAIN] = "获得",
  [OPT_MOVE] = "移动",
}

return skill
