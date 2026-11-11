local skill = fk.CreateSkill {
  name = "hanjin__spear_skill",
  attached_equip = "hanjin__spear",
}

skill:addEffect("viewas", {
  prompt = "#hanjin__spear_skill",
  pattern = "slash",
  mute_card = false,
  handly_pile = true,
  filter_pattern = {
    min_num = 2,
    max_num = 2,
    pattern = ".|.|.|^equip",
  },
  view_as = function(self, player, cards)
    if #cards ~= 2 then return nil end
    local c = Fk:cloneCard("hanjin__slash")
    c.skillName = "hanjin__spear_skill"
    c:addSubcards(cards)
    return c
  end,
})

Fk:loadTranslationTable {
  ["hanjin__spear_skill"] = "丈八蛇矛",
  ["#hanjin__spear_skill"] = "你可以将两张牌当【杀】使用或打出",
}

return skill
