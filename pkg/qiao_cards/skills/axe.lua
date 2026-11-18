-- 贯石斧：使用【杀】被目标角色使用【闪】抵消后，可以弃置两张牌并令此【杀】
-- 依然生效。消耗与后续效果都以服务端真实状态复核：只有两张当前仍属于发动者、
-- 且本次实际完成“弃置→弃牌堆”的牌，才令【杀】继续生效；仅选中、被其他效果取消
-- 或被替换成非本人牌的选择都不能令【杀】继续生效。
local skill = fk.CreateSkill {
  name = "qiao__axe_skill",
  attached_equip = "qiao__axe",
}

--- 本次技能是否真的完成了一次“弃置→弃牌堆”的移动。
-- 以本次已经执行完的 MoveCards 记录为准：被 BeforeCardsMove 取消的整次移动会
-- 标记 interrupted，不能把其留下的数据当作已弃置；弃置后立刻被其他技能获得，
-- 只产生新的移动记录，不影响本次记录的成立。
local function discardedThisTime(room, player, skillName, ids)
  local wanted = {}
  for _, id in ipairs(ids) do wanted[id] = true end
  local events = room.logic:getEventsByRule(GameEvent.MoveCards, 1, function(e)
    if e.interrupted then return false end
    for _, move in ipairs(e.data or {}) do
      if move.from == player and move.toArea == Card.DiscardPile
        and move.moveReason == fk.ReasonDiscard and move.skillName == skillName then
        local hit = 0
        for _, info in ipairs(move.moveInfo or {}) do
          if wanted[info.cardId]
            and (info.fromArea == Card.PlayerHand or info.fromArea == Card.PlayerEquip) then
            hit = hit + 1
          end
        end
        if hit == #ids then return true end
      end
    end
    return false
  end)
  return events[1] ~= nil
end

--- 可作为本次弃置的两张牌：不能弃置的牌与贯石斧自身除外。
local function discardCandidates(player)
  local cards = {}
  for _, id in ipairs(player:getCardIds("he")) do
    if not player:prohibitDiscard(id)
      and not (table.contains(player:getEquipments(Card.SubtypeWeapon), id)
        and (player:getVirtualEquip(id) or Fk:getCardById(id)).name == skill.attached_equip) then
      table.insert(cards, id)
    end
  end
  return cards
end

--- 服务端复核消耗：必须是两张当前仍属于发动者、且仍可作为本次弃置的牌。
-- 不把客户端选择当作移动前的最终依据，避免过期或非本人的牌直接进入弃牌移动。
local function legalCostCards(room, player, ids)
  if type(ids) ~= "table" or #ids ~= 2 or ids[1] == ids[2] then return false end
  local candidates = {}
  for _, id in ipairs(discardCandidates(player)) do candidates[id] = true end
  for _, id in ipairs(ids) do
    if not candidates[id] or room:getCardOwner(id) ~= player then return false end
  end
  return true
end

skill:addEffect(fk.CardEffectCancelledOut, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and data.from == player
      and data.card.trueName == "slash" and not data.to.dead
      and #discardCandidates(player) > 1
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local cards = room:askToDiscard(player, {
      min_num = 2,
      max_num = 2,
      include_equip = true,
      skill_name = skill.name,
      cancelable = true,
      pattern = tostring(Exppattern { id = discardCandidates(player) }),
      prompt = "#axe-invoke::" .. data.to.id,
      skip = true,
    })
    if #cards == 2 and legalCostCards(room, player, cards) then
      event:setCostData(self, { cards = cards })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local cards = cost and cost.cards
    -- 消耗在执行前再次复核；不合格的选择不移动牌，也不恢复【杀】的效果。
    if not legalCostCards(room, player, cards) then return end
    room:throwCard(cards, skill.name, player, player)
    -- 实际完成本次弃置后，此【杀】才依然生效。只认本次已执行的移动记录；
    -- 不能回头看当前区域：弃置后可能立刻被其他技能取走。
    if not discardedThisTime(room, player, skill.name, cards) then return end
    data.isCancellOut = false
    data.disresponsive = true
  end,
})

Fk:loadTranslationTable {
  ["qiao__axe_skill"] = "贯石斧",
}

return skill
