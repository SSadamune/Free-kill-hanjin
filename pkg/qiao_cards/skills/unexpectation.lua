local skill = fk.CreateSkill { name = "qiao__unexpectation_skill" }

Fk:loadTranslationTable {
  ["qiao__unexpectation_skill"] = "出其不意",
  ["#qiao__unexpectation_skill"] = "选择一名有手牌的其他角色，展示其一张手牌，若花色与此牌不同则对其造成伤害",
  ["#qiao__unexpectation-show"] = "出其不意：选择 %dest 的一张手牌展示",
}

skill:addEffect("cardskill", {
  prompt = "#qiao__unexpectation_skill",
  target_num = 1,
  mod_target_filter = function(self, player, to_select)
    return to_select ~= player and not to_select:isKongcheng()
  end,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    local player, target = effect.from, effect.to
    if target:isKongcheng() then return end
    local card = room:askToChooseCard(player, {
      target = target,
      flag = "h",
      skill_name = skill.name,
      prompt = "#qiao__unexpectation-show::" .. target.id .. ":" .. skill.name,
    })
    target:showCards(card)
    card = Fk:getCardById(card)
    if target.dead then return end
    if card:compareSuitWith(effect.card, true) then
      room:damage {
        from = player,
        to = target,
        card = effect.card,
        damage = 1,
        skillName = skill.name,
      }
    end
  end,
})

return skill
