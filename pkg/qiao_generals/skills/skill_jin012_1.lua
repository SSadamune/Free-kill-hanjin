-- JIN012 羊徽瑜 · 慈威
--
-- 规则基线：docs/rules/generals/jin012-yanghuiyu.md。
-- 其他角色在其自己回合内使用第二张牌时触发。“第二张”按本回合真实的
-- UseCard 事件计数，包含响应中的实际使用与装备，纯“打出”的 RespondCard
-- 不计入。弃置一张牌后：基本牌或普通锦囊只令所选目标无效（不是取消目标，
-- 也不是取消整张牌）；装备牌或延时锦囊则横置该使用者。
--
-- 发动确认并入这一次弃牌请求，不再另发 askToSkillInvoke：取消请求即不发动，
-- 请求未返回恰好一张牌也不发动。弃牌仍在 on_use 支付（skip=true）。
local skill = fk.CreateSkill {
  name = "qiao__skill_jin012_1",
}

--- 可弃置的自己的牌（手牌区或装备区）。
---@param player ServerPlayer
---@return boolean
local function hasDiscardableCard(player)
  return table.find(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id)
  end) ~= nil
end

--- 基本牌或普通锦囊牌；延时锦囊归入“否则”分支。
---@param card Card
---@return boolean
local function isBasicOrCommonTrick(card)
  if card == nil then return false end
  if card.type == Card.TypeBasic then return true end
  return card.type == Card.TypeTrick and card.sub_type ~= Card.SubtypeDelayedTrick
end

--- 本回合当前使用者真实使用过的牌数（含本次正在进行的使用事件）。
---@param room Room
---@param user ServerPlayer
---@return integer
local function usedCardCountThisTurn(room, user)
  local logic = room.logic
  local current = logic and logic:getCurrentEvent()
  if current == nil then return 0 end
  return #logic:getEventsOfScope(GameEvent.UseCard, 3, function(e)
    return e.data ~= nil and e.data.from == user
  end, Player.HistoryTurn)
end

skill:addEffect(fk.AfterCardUseDeclared, {
  anim_type = "control",
  -- 触发事件的使用者可能是其他角色，必须作为全局触发再由 can_trigger 筛选。
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == player or target == nil or player.dead or not player:hasSkill(skill.name) then
      return false
    end
    if data == nil or data.card == nil or data.from ~= target then return false end
    local room = player.room
    if room == nil or room.current ~= target then return false end
    if not hasDiscardableCard(player) then return false end
    return usedCardCountThisTurn(room, target) == 2
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    -- 弃牌请求本身即发动确认；取消请求即不发动。提示保留第二张牌的使用者。
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin012_1-discard::" .. target.id,
      cancelable = true,
      skip = true,
    })
    if cards == nil or #cards == 0 then return false end
    event:setCostData(self, { cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local cards = table.filter(cost.cards or {}, function(id)
      return table.contains(player:getCardIds("he"), id)
    end)
    if #cards == 0 then return end
    room:throwCard(cards, skill.name, player, player)
    if target.dead or data.card == nil then return end

    if isBasicOrCommonTrick(data.card) then
      local tos = table.filter(data.tos or {}, function(p)
        return p:isAlive() and not p:isRemoved()
      end)
      if #tos == 0 then return end
      -- 任意个目标，允许不选；不能强制取消至少一名。
      local chosen = room:askToChoosePlayers(player, {
        min_num = 0,
        max_num = #tos,
        targets = tos,
        skill_name = skill.name,
        prompt = "#qiao__skill_jin012_1-targets",
        cancelable = true,
      })
      if chosen == nil or #chosen == 0 then return end
      data.nullifiedTargets = data.nullifiedTargets or {}
      for _, to in ipairs(chosen) do
        table.insertIfNeed(data.nullifiedTargets, to)
      end
    else
      if target:isAlive() and not target:isRemoved() and not target.chained then
        target:setChainState(true)
      end
    end
  end,
})

skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["#qiao__skill_jin012_1-discard"] = "慈威：弃置一张牌发动，令 %dest 使用的第二张牌无效或横置其",
  ["#qiao__skill_jin012_1-targets"] = "慈威：选择此牌任意个目标，令此牌对其无效",
}

return skill
