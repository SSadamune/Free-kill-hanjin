-- EM(JIN001) 司马炎 · 採幸
-- 出牌阶段开始前：可以跳过该阶段，然后将场上一张坐骑牌或弃牌堆的
-- 【临筱玉舆】置入自己装备区；没有合适牌不撤销已支付的跳过。
local LINXIAO = "qiao__linxiao_yuyu"

local skill = fk.CreateSkill { name = "qiao__skill_em_jin001_2" }
skill.qiaoImplemented = true

local function isRide(id)
  local card = Fk:getCardById(id, true)
  return card ~= nil and card.type == Card.TypeEquip
    and (card.sub_type == Card.SubtypeOffensiveRide
      or card.sub_type == Card.SubtypeDefensiveRide
      or table.contains(card.subtypes or {}, Card.SubtypeOffensiveRide)
      or table.contains(card.subtypes or {}, Card.SubtypeDefensiveRide))
end

local function candidates(room, player)
  local list = {}
  for _, p in ipairs(room:getPresentPlayers()) do
    for _, id in ipairs(p:getCardIds(Player.Equip)) do
      if isRide(id) and player:canMoveCardIntoEquip(id, false) then table.insert(list, id) end
    end
  end
  for _, id in ipairs(room.discard_pile) do
    local card = Fk:getCardById(id, true)
    if card ~= nil and (card.name == LINXIAO
      or (card.type == Card.TypeEquip and card.sub_type == Card.SubtypeDefensiveRide
        and table.contains(card.subtypes or {}, Card.SubtypeOffensiveRide))) then
      if player:hasEmptyEquipSlot(Card.SubtypeOffensiveRide)
        and player:hasEmptyEquipSlot(Card.SubtypeDefensiveRide) then
        table.insert(list, id)
      end
    end
  end
  return list
end

skill:addEffect(fk.EventPhaseChanging, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data.phase == Player.Play and not data.skipped
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__jin001_caixing-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.skipped = true
    local list = candidates(room, player)
    if #list == 0 then return end
    local chosen
    if #list == 1 then
      chosen = list[1]
    else
      local field, discarded = {}, {}
      for _, id in ipairs(list) do
        local group = room:getCardArea(id) == Card.DiscardPile and discarded or field
        table.insert(group, id)
      end
      local groups = {}
      if #field > 0 then table.insert(groups, { "$Equip", field }) end
      if #discarded > 0 then table.insert(groups, { "弃牌堆", discarded }) end
      chosen = room:askToChooseCard(player, {
        -- The client requires a player even when displaying explicit card lists.
        target = player,
        flag = { card_data = groups },
        skill_name = skill.name,
        prompt = "#qiao__jin001_caixing-card",
      })
    end
    if not table.contains(list, chosen) or not table.contains(candidates(room, player), chosen) then return end
    room:moveCardIntoEquip(player, chosen, skill.name, false, player)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "採幸",
  [":" .. skill.name] = "你可以跳过出牌阶段，然后将场上一张坐骑牌或弃牌堆的【临筱玉舆】置入装备区。",
  ["#qiao__jin001_caixing-invoke"] = "採幸：是否跳过出牌阶段并置入一张坐骑牌",
  ["#qiao__jin001_caixing-card"] = "採幸：选择场上一张坐骑牌或弃牌堆的【临筱玉舆】",
}

return skill
