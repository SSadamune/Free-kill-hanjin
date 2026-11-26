-- WEI021B 毛玠 · 征辟 辅助选牌骨架（目标选择 1 张非基本牌或 2 张基本牌交还）
local skill = fk.CreateSkill {
  name = "#qiao__skill_wei021b_1_return",
}

skill:addEffect("active", {
  can_use = Util.FalseFunc,
  target_num = 0,
  min_card_num = 1,
  max_card_num = 2,
  card_filter = function(self, player, to_select, selected)
    local card = Fk:getCardById(to_select)
    if card == nil then return false end
    if #selected == 0 then
      if card.type == Card.TypeBasic then
        local basics = table.filter(player:getCardIds("h"), function(id)
          local c = Fk:getCardById(id)
          return c ~= nil and c.type == Card.TypeBasic
        end)
        return #basics >= 2
      end
      return true
    elseif #selected == 1 then
      local first = Fk:getCardById(selected[1])
      return first ~= nil and first.type == Card.TypeBasic and card.type == Card.TypeBasic
    end
    return false
  end,
  feasible = function(self, player, selected, selected_cards)
    if #selected_cards == 1 then
      local c = Fk:getCardById(selected_cards[1])
      return c ~= nil and c.type ~= Card.TypeBasic
    elseif #selected_cards == 2 then
      local c1, c2 = Fk:getCardById(selected_cards[1]), Fk:getCardById(selected_cards[2])
      return c1 ~= nil and c2 ~= nil and c1.type == Card.TypeBasic and c2.type == Card.TypeBasic
    end
    return false
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "征辟",
}

return skill
