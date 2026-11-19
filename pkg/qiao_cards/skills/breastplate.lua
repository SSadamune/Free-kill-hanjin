-- 护心镜：出牌阶段可将手牌中的此牌置入其他角色的空防具栏（特殊使用入口，
-- 不经过装备使用流程，实际移动原因为“置入”）；受到致命伤害或大于 1 点的
-- 伤害时，只有先将装备区里的此牌实际置入弃牌堆，才防止该伤害。
local skill = fk.CreateSkill {
  name = "qiao__breastplate_skill",
  attached_equip = "qiao__breastplate",
}

--- 本次技能是否真的完成了一次“置入弃牌堆”的移动。
-- 以当次移动记录为准：只看候选牌或被技能过滤掉的移动都不算完成。
local function movedToDiscard(room, skillName, ids)
  local wanted = {}
  for _, id in ipairs(ids) do wanted[id] = true end
  local events = room.logic:getEventsByRule(GameEvent.MoveCards, 1, function(e)
    if e.interrupted then return false end
    for _, move in ipairs(e.data or {}) do
      if move.toArea == Card.DiscardPile and move.skillName == skillName then
        local hit = 0
        for _, info in ipairs(move.moveInfo or {}) do
          if wanted[info.cardId] and info.fromArea ~= Card.DiscardPile then
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

skill:addEffect(fk.DamageInflicted, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and (data.damage > 1 or data.damage >= player.hp)
  end,
  on_cost = function(self, event, target, player)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__breastplate-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cards = table.filter(player:getCardIds("e"), function(id)
      return Fk:getCardById(id).name == skill.attached_equip
    end)
    if #cards == 0 then return end
    room:moveCardTo(cards, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      skill.name, nil, true, player)
    -- 实际置入弃牌堆后才防止伤害。
    if not movedToDiscard(room, skill.name, cards) then return end
    data:preventDamage()
  end,
})

-- 出牌阶段的特殊使用入口：将手牌中的此牌置入其他角色的空防具栏。它不经过
-- “使用装备牌”的结算，实际移动原因为置入；栏位被占用、不存在或被废除时不可选。
local place = fk.CreateSkill { name = "qiao__breastplate_place" }

place:addEffect("active", {
  prompt = "#qiao__breastplate-place",
  target_num = 1,
  can_use = function(self, player) return true end,
  target_filter = function(self, player, to_select, selected, selected_cards, card, extra_data)
    if #selected > 0 or to_select == player then return false end
    local id = selected_cards and selected_cards[1]
    if id == nil then return false end
    return to_select:hasEmptyEquipSlot(Card.SubtypeArmor)
      and not player:isProhibited(to_select, Fk:getCardById(id))
  end,
  on_use = function(self, room, effect)
    local from = effect.from
    local to = effect.tos and effect.tos[1]
    local cards = effect.cards or {}
    if from == nil or from.dead or to == nil or to.dead or #cards == 0 then return end
    -- 结算时复核空置且可用的防具栏，并只移动仍在自己手里的那张实体牌。
    if not to:hasEmptyEquipSlot(Card.SubtypeArmor) then return end
    if room:getCardOwner(cards[1]) ~= from
      or room:getCardArea(cards[1]) ~= Card.PlayerHand then
      return
    end
    room:moveCardTo(cards, Card.PlayerEquip, to, fk.ReasonPut, skill.name, nil, true, from)
  end,
})

-- 同一文件内的第二个骨架需要自行创建并登记；cards.lua 的 special_skills 引用它。
local placeSkill = place:createSkill()
Fk.skills[placeSkill.name] = Fk.skills[placeSkill.name] or placeSkill

Fk:loadTranslationTable {
  ["qiao__breastplate_skill"] = "护心镜",
  ["qiao__breastplate_place"] = "护心镜",
  ["#qiao__breastplate-invoke"] = "护心镜：你可以将护心镜置入弃牌堆，防止此伤害",
  ["#qiao__breastplate-place"] = "护心镜：选择一名防具栏为空的其他角色，将此牌置入其装备区",
}

return skill
