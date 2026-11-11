local skill = fk.CreateSkill {
  name = "hanjin__five_elements_fan_skill",
  attached_equip = "hanjin__five_elements_fan",
}

Fk:loadTranslationTable {
  ["hanjin__five_elements_fan_skill"] = "五行鹤翎扇",
}

local function hanjinSlashChoices()
  local choices = {}
  for name, card in pairs(Fk.all_card_types) do
    if card.package and card.package.name == "hanjin_cards"
      and card.type == Card.TypeBasic and card.trueName == "slash"
      and name ~= "hanjin__slash" then
      table.insert(choices, name)
    end
  end
  table.sort(choices)
  return choices
end

skill:addEffect(fk.AfterCardUseDeclared, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card.name ~= "hanjin__slash" and data.card.trueName == "slash"
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local all_choices = hanjinSlashChoices()
    local choices = table.simpleClone(all_choices)
    table.removeOne(choices, data.card.name)
    if #choices > 0 and room:askToSkillInvoke(player, { skill_name = skill.name }) then
      local choice = room:askToChoice(player, {
        choices = choices,
        skill_name = skill.name,
        all_choices = all_choices,
      })
      event:setCostData(self, { choice = choice })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local card = Fk:cloneCard(event:getCostData(self).choice, data.card.suit, data.card.number)
    for k, v in pairs(data.card) do
      if card[k] == nil then card[k] = v end
    end
    if data.card:isVirtual() then
      card.subcards = data.card.subcards
    else
      card.id = data.card.id
    end
    card.skillNames = data.card.skillNames
    card.skillName = "hanjin__five_elements_fan_skill"
    -- A transformed card must not inherit another physical card's HanJin
    -- adaptation entry or 孤军/合纵 marker.
    card.extra_data = nil
    data.card = card
  end,
})

return skill
