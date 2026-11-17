-- SHU018B 费祎 · 守成
--
-- 每回合每名角色限一次：与费祎势力相同的角色在其回合外失去手牌后，若其没有
-- 手牌，费祎可以令其摸两张牌，然后其弃置一张牌。限次按“发动者来源 + 受益
-- 角色 + 当前回合”记录；不同持有者互不占用，技能失去、重新取得或武将明暗置
-- 都不会清除本回合已经发生的发动历史。一次移动批量失去手牌只按受益角色触发一次。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu018b_2",
}
skill.qiaoImplemented = true

local H = require "packages.hegemony.util"

local USED_MARK = "qiao__skill_shu018b_2-turn"

--- 当前回合事件的唯一 id；真实房间中用于区分“本回合”和旧记录。
---@param player ServerPlayer
---@return integer|nil
local function currentTurnId(player)
  local logic = player.room.logic
  local current = logic and logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  return turn and turn.id or nil
end

--- 该次移动是否让目标从有手牌变为空手。
---@param move MoveCardsData
---@return boolean
local function emptiedHand(move)
  local target = move.from
  if target == nil or not target:isAlive() or target:isRemoved() then return false end
  if #target:getCardIds(Player.Hand) > 0 then return false end
  for _, info in ipairs(move.moveInfo or {}) do
    if info.fromArea == Player.Hand then return true end
  end
  return false
end

--- 同一势力的受益角色；费祎自己也在“与你势力相同”的范围内。
---@param holder ServerPlayer
---@param target ServerPlayer
---@return boolean
local function sameKingdom(holder, target)
  return holder == target or H.compareKingdomWith(holder, target)
end

--- 该持有者本回合是否已对受益角色发动过守成。
---@param target ServerPlayer
---@param holder ServerPlayer
---@param turn integer|nil
---@return boolean
local function usedBy(target, holder, turn)
  turn = turn or 0
  for _, record in ipairs(target:getTableMark(USED_MARK)) do
    if record.turn == turn and record.source == holder.id then return true end
  end
  return false
end

--- 记录该持有者本回合对受益角色的发动；不同持有者各自保留。
---@param room Room
---@param target ServerPlayer
---@param holder ServerPlayer
---@param turn integer|nil
local function markUsed(room, target, holder, turn)
  turn = turn or 0
  local records = table.filter(target:getTableMark(USED_MARK), function(record)
    return record.turn == turn
  end)
  table.insert(records, { turn = turn, source = holder.id })
  room:setPlayerMark(target, USED_MARK, records)
end

--- 本次移动中所有满足条件、且该持有者本回合尚未对之发动过守成的角色。
---@param holder ServerPlayer
---@param data MoveCardsData[]
---@return ServerPlayer[]
local function candidates(holder, data)
  local room = holder.room
  local turn = currentTurnId(holder)
  local seen, result = {}, {}
  for _, move in ipairs(data or {}) do
    local target = move.from
    if target ~= nil and not seen[target.id] and emptiedHand(move)
      and room.current ~= target and sameKingdom(holder, target) then
      if not usedBy(target, holder, turn) then
        seen[target.id] = true
        table.insert(result, target)
      end
    end
  end
  room:sortByAction(result)
  return result
end

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return not player.dead and player:hasSkill(skill.name)
      and #candidates(player, data) > 0
  end,
  -- 每个受益角色分别询问一次发动；不能把多名角色合并为一次全体询问。
  on_trigger = function(self, event, target, player, data)
    for _, to in ipairs(candidates(player, data)) do
      if player.dead or not player:hasSkill(skill.name) then break end
      if to:isAlive() and not to:isRemoved() then
        event:setCostData(self, { tos = { to } })
        self:doCost(event, target, player, data)
      end
    end
  end,
  on_cost = function(self, event, target, player, data)
    local cost = event:getCostData(self)
    local to = cost and cost.tos and cost.tos[1]
    if to == nil or to.dead or to:isRemoved() then return false end
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu018b_2-invoke::" .. to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local to = cost and cost.tos and cost.tos[1]
    if to == nil or to.dead or to:isRemoved() then return end

    -- 先记录再摸牌，避免摸牌过程中的嵌套移动再次触发同一受益角色。
    local turn = currentTurnId(player)
    markUsed(room, to, player, turn)
    to:drawCards(2, skill.name)
    if to.dead or to:isRemoved() or #to:getCardIds("he") == 0 then return end
    room:askToDiscard(to, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_shu018b_2-discard",
      cancelable = false,
    })
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu018b_2"] = "守成",
  [":qiao__skill_shu018b_2"] = "每回合每名角色限一次，与你势力相同的角色于其回合外失去手牌后，若其没有手牌，你可以令其摸两张牌，然后其弃置一张牌。",
  ["#qiao__skill_shu018b_2-invoke"] = "守成：你可以令 %dest 摸两张牌，然后其弃置一张牌",
  ["#qiao__skill_shu018b_2-discard"] = "守成：弃置一张牌",
}

return skill
