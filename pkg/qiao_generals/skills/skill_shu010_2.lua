local skill = fk.CreateSkill {
  name = "qiao__skill_shu010_2",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

Fk:loadTranslationTable {
  ["qiao__skill_shu010_2"] = "涅槃",
  [":qiao__skill_shu010_2"] = "限定技，当你处于濒死状态时，你可以弃置区域里的所有牌，复原武将牌，摸三张牌，将体力回复至3点。",
  ["#qiao__skill_shu010_2-invoke"] = "涅槃：是否弃置区域内所有牌、复原武将牌并摸三张牌？",
}

skill:addEffect(fk.EnterDying, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu010_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cards = player:getCardIds("hej")
    for _, ids in pairs(player.special_cards or {}) do
      table.insertTable(cards, ids)
    end
    if #cards > 0 then
      room:throwCard(cards, skill.name, player, player)
    end
    player:reset()
    room:drawCards(player, 3, skill.name)
    local targetHp = math.min(3, player.maxHp)
    if player.hp < targetHp then
      room:recover {
        who = player,
        num = targetHp - player.hp,
        recoverBy = player,
        skillName = skill.name,
      }
    end
  end,
})

return skill
