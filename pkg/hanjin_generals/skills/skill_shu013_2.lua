local skill = fk.CreateSkill {
  name = "hanjin__skill_shu013_2",
}
skill.hanjinImplemented = true

local FQ = "hanjin__skill_shu013_2_turn-turn"

Fk:loadTranslationTable {
  ["hanjin__skill_shu013_2"] = "放权",
  [":hanjin__skill_shu013_2"] = "轮次技，你可以跳过出牌阶段。若如此做，此回合结束时，你可以弃置一张手牌并选择一名其他角色，令其获得一个额外的回合。",
  ["#hanjin__skill_shu013_2-invoke"] = "放权：是否跳过出牌阶段？",
  ["#hanjin__skill_shu013_2-discard"] = "放权：弃置一张手牌，令一名其他角色获得额外回合",
  ["#hanjin__skill_shu013_2-choose"] = "放权：选择获得额外回合的角色",
}

skill:addEffect(fk.EventPhaseChanging, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.phase == Player.Play and not data.skipped
      and player:getMark(skill.name .. "-round") == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_shu013_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data.skipped = true
    room:addPlayerMark(player, skill.name .. "-round", 1)
    room:addPlayerMark(player, FQ, 1)
  end,
})

return skill
