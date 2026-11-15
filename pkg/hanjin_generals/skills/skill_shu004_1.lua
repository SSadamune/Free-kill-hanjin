local skill = fk.CreateSkill {
  name = "hanjin__skill_shu004_1",
}
skill.hanjinImplemented = true

local GUANX = "hanjin__skill_shu004_1_finish-turn"

Fk:loadTranslationTable {
  ["hanjin__skill_shu004_1"] = "观星",
  [":hanjin__skill_shu004_1"] = "准备阶段，你可以卜算5（角色数小于4时改为3），若此次卜算牌均置于牌堆底，本回合结束阶段，你再执行此流程。",
  ["#hanjin__skill_shu004_1-invoke"] = "观星：是否卜算？",
  ["#hanjin__skill_shu004_1-finish"] = "观星：结束阶段再卜算一次",
}

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Start
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_shu004_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local n = #room.alive_players < 4 and 3 or 5
    local result = room:askToGuanxing(player, {
      cards = room:getNCards(n),
      skill_name = skill.name,
    })
    local top = result and (result.top or result[1]) or {}
    local bottom = result and (result.bottom or result[2]) or {}
    if #top == 0 and #bottom == n then
      room:addPlayerMark(player, GUANX, 1)
    end
  end,
})

return skill
