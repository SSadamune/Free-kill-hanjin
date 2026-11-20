-- 四海流钱：出牌阶段空闲时，选择距离终值大于1且至少有两张可获得牌的角色，
-- 通过一次原生选牌请求预先选定其恰好两张手牌/装备，然后将此宝物交到其手牌区，
-- 并取得所选牌。选牌交给引擎的 askToChooseCards，隐藏手牌由它按询问者可见性
-- 打乱并附带 visible_data，客户端不会把未公开手牌当作已知牌。
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
})

local function isSelectable(room, target, id)
  if room:getCardOwner(id) ~= target then return false end
  local area = room:getCardArea(id)
  return area == Card.PlayerHand or area == Card.PlayerEquip
end

skill:addEffect("active", {
  anim_type = "control",
  card_num = 0,
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

    -- 一次请求选完两张：flag 用 "he" 让引擎按询问者可见性生成
    -- visible_data 并按手牌、装备分组。恰好两张时引擎直接返回唯一组合。
    local chosen = room:askToChooseCards(player, {
      target = target,
      flag = "he",
      min = 2,
      max = 2,
      skill_name = skill.name,
      prompt = "#qiao__sihai_liuqian-choose",
    })
    if type(chosen) ~= "table" or #chosen ~= 2 then return end
    local first, second = chosen[1], chosen[2]
    if first == second then return end
    -- 只接受目标当前手牌区或装备区的牌：判定区、私人牌堆及第三张都不合法。
    if not isSelectable(room, target, first) then return end
    if not isSelectable(room, target, second) then return end

    -- 询问期间状态可能改变，移动前重新核对距离、手牌区与宝物。
    if treasureId(player) ~= treasure or target.dead or target:isRemoved()
      or player.dead or player:isRemoved() or player:distanceTo(target) <= 1
      or target:isHandAreaSealed() or player:isHandAreaSealed() then return end

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
  ["#qiao__sihai_liuqian-choose"] = "四海流钱：选择目标两张手牌或装备",
  [":qiao__sihai_liuqian_skill"] = "出牌阶段内的空闲时间点，你可以选择距离大于1的一名角色，"
    .. "将其两张手牌或装备与装备区里的此牌交换。",
}

return skill
