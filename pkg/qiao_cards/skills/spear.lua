local skill = fk.CreateSkill {
  name = "qiao__spear_skill",
  attached_equip = "qiao__spear",
}

skill:addEffect("viewas", {
  prompt = "#qiao__spear_skill",
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
    local c = Fk:cloneCard("qiao__slash")
    c.skillName = "qiao__spear_skill"
    c:addSubcards(cards)
    return c
  end,
})

Fk:loadTranslationTable {
  ["qiao__spear_skill"] = "丈八蛇矛",
  ["#qiao__spear_skill"] = "你可以将两张牌当【杀】使用或打出",
}

return skill
