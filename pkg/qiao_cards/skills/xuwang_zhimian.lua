-- 虚妄之冕：锁定技，装备者在自己的摸牌阶段多摸两张牌；手牌上限-1。
-- 修正随装备状态即时生效，离开装备区即失去。
local skill = fk.CreateSkill {
  name = "qiao__xuwang_zhimian_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__xuwang_zhimian",
}

skill:addEffect(fk.DrawNCards, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and player.phase == Player.Draw
  end,
  on_use = function(self, event, target, player, data)
    data.n = data.n + 2
  end,
})

skill:addEffect("maxcards", {
  correct_func = function(self, player)
    if player:hasSkill(skill.name) then return -1 end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "虚妄之冕",
  [":" .. skill.name] = "锁定技，你在自己的摸牌阶段多摸两张牌；你的手牌上限-1。",
}

return skill
