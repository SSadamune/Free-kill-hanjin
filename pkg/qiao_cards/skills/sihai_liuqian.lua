-- 四海流钱：出牌阶段空闲时，选择距离终值大于1且至少有两张可获得牌的角色，
-- 预先选定其恰好两张手牌/装备，然后将此宝物交到其手牌区，并取得所选牌。
-- 两个转移在同一次 moveCards 中完成，分别保留给牌／获得原因。
local skill = fk.CreateSkill {
  name = "qiao__sihai_liuqian_skill",
  attached_equip = "qiao__sihai_liuqian",
}

local EXCHANGE_TAG = "qiao_sihai_exchange"

local function treasureId(player)
  for _, id in ipairs(player:getCardIds(Player.Equip)) do
    local card = Fk:getCardById(id)
    if card ~= nil and card.name == skill.attached_equip then return id end
  end
end


-- BeforeCardsMove 的普通触发可以逐张取消本次移动；late_refresh 在所有普通
-- 触发之后复核同一动作的三张牌，任一已不在原区域就把本次三张全部过滤掉。
skill:addEffect(fk.BeforeCardsMove, {
  late_refresh = true,
  can_refresh = function(self, event, target, player, data)
    return Fk:currentRoom():getTag(EXCHANGE_TAG) == true
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    local total = 0
    for _, move in ipairs(data or {}) do
      if move.skillName == skill.name then
        local kept = {}
        for _, info in ipairs(move.moveInfo or {}) do
          if room:getCardArea(info.cardId) == info.fromArea
            and room:getCardOwner(info.cardId) == move.from then
            table.insert(kept, info)
          end
        end
        move.moveInfo = kept
        total = total + #kept
      end
    end
    if total ~= 3 then
      for _, move in ipairs(data or {}) do
        if move.skillName == skill.name then move.moveInfo = {} end
      end
    end
  end,
})local function chooseCard(room, player, target, prompt)
  return room:askToChooseCard(player, {
    target = target,
    flag = "he",
    skill_name = skill.name,
    prompt = prompt,
  })
end

skill:addEffect("active", {
  anim_type = "control",
  target_num = 1,
  can_use = function(self, player)
    return player:hasSkill(skill.name) and treasureId(player) ~= nil
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    return to_select ~= player and not to_select.dead and not to_select:isRemoved()
      and not to_select:isHandAreaSealed()
      and player:distanceTo(to_select) > 1
      and #to_select:getCardIds("he") >= 2
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or target.dead then return end
    if player:distanceTo(target) <= 1 or #target:getCardIds("he") < 2 then return end
    local treasure = treasureId(player)
    if treasure == nil or target:isHandAreaSealed() then return end

    -- 先固定恰好两张牌；两次选择都在任何移动之前完成。
    local first = chooseCard(room, player, target, "#qiao__sihai_liuqian-first")
    if first == nil then return end
    local hand, equip = {}, {}
    for _, id in ipairs(target:getCardIds(Player.Hand)) do
      if id ~= first then table.insert(hand, id) end
    end
    for _, id in ipairs(target:getCardIds(Player.Equip)) do
      if id ~= first then table.insert(equip, id) end
    end
    if #hand + #equip < 1 then return end
    local second = room:askToChooseCard(player, {
      target = target,
      flag = { card_data = { { "$Hand", hand }, { "$Equip", equip } } },
      skill_name = skill.name,
      prompt = "#qiao__sihai_liuqian-second",
    })
    if second == nil or second == first then return end
    if room:getCardOwner(first) ~= target or room:getCardOwner(second) ~= target then return end
    if player:distanceTo(target) <= 1 or target:isHandAreaSealed()
      or player:isHandAreaSealed() then return end

    -- “并”：一次移动同时完成交给与取得，原因分别保留。
    room:setTag(EXCHANGE_TAG, true)
    room:moveCards(
      {
        ids = { treasure },
        from = player,
        to = target,
        toArea = Card.PlayerHand,
        moveReason = fk.ReasonGive,
        skillName = skill.name,
        proposer = player,
      },
      {
        ids = { first, second },
        from = target,
        to = player,
        toArea = Card.PlayerHand,
        moveReason = fk.ReasonPrey,
        skillName = skill.name,
        proposer = player,
      }
    )
    room:setTag(EXCHANGE_TAG, false)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "四海流钱",
  ["#qiao__sihai_liuqian-first"] = "四海流钱：选择目标一张手牌或装备",
  ["#qiao__sihai_liuqian-second"] = "四海流钱：再选择目标一张手牌或装备",
  [":qiao__sihai_liuqian_skill"] = "出牌阶段内的空闲时间点，你可以选择距离大于1的一名角色，"
    .. "将其两张手牌或装备与装备区里的此牌交换。",
}

return skill
