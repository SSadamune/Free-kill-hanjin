local skill = fk.CreateSkill {
  name = "hanjin__eight_diagram_skill",
  attached_equip = "hanjin__eight_diagram",
}

local function provideJink(self, event, target, player, data)
  local room = player.room
  local judgeData = {
    who = player,
    reason = skill.name,
    pattern = ".|.|red",
  }
  room:judge(judgeData)
  if judgeData:matchPattern() then
    local newCard = Fk:cloneCard("hanjin__jink")
    newCard.skillName = "hanjin__eight_diagram_skill"
    local result = { from = player, card = newCard }
    if event:isInstanceOf(fk.AskForCardUse) then result.tos = {} end
    data.result = result
    return true
  end
end

skill:addEffect(fk.AskForCardUse, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none")
      and not player:prohibitUse(Fk:cloneCard("hanjin__jink"))
      and (data.extraData == {} or data.extraData.not_passive ~= true)
  end,
  on_use = provideJink,
})

skill:addEffect(fk.AskForCardResponse, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and Exppattern:Parse(data.pattern):matchExp("jink|0|nosuit|none")
      and not player:prohibitResponse(Fk:cloneCard("hanjin__jink"))
  end,
  on_use = provideJink,
})

Fk:loadTranslationTable {
  ["hanjin__eight_diagram_skill"] = "八卦阵",
}

return skill
