local skill = fk.CreateSkill { name = "hanjin__foresight_skill" }

skill:addEffect("cardskill", {
  prompt = "#hanjin__foresight_skill",
  mod_target_filter = Util.TrueFunc,
  can_use = Util.CanUseToSelf,
  on_effect = function(self, room, effect)
    if effect.to.dead then return end
    room:askToGuanxing(effect.to, { cards = room:getNCards(2) })
    room:drawCards(effect.to, 2, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__foresight_skill"] = "洞烛先机",
  ["#hanjin__foresight_skill"] = "观看牌堆顶两张牌，以任意顺序置于牌堆顶或牌堆底，然后摸两张牌",
}

return skill
