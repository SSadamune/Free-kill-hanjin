-- SHU018B 费祎 · 生息
--
-- 结束阶段，若其于本回合未造成过伤害，可以摸两张牌。伤害事实读取本回合
-- 实际 GameEvent.Damage 历史，因此包括技能尚未取得或武将暗置时发生的伤害；
-- 被防止至零的伤害不算造成过伤害。
local skill = fk.CreateSkill {
  name = "hanjin__skill_shu018b_1",
}
skill.hanjinImplemented = true

--- 本回合 player 是否实际造成过伤害。
---@param player ServerPlayer
---@return boolean
local function causedDamageThisTurn(player)
  local logic = player.room.logic
  if logic == nil then return false end
  local events = logic:getActualDamageEvents(1, function(event)
    local data = event.data
    return data ~= nil and data.from == player and not data.prevented
      and (data.damage or 0) > 0
  end, Player.HistoryTurn)
  return #events > 0
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.phase == Player.Finish
      and not causedDamageThisTurn(player)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_shu018b_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    if player.dead then return end
    player:drawCards(2, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_shu018b_1"] = "生息",
  [":hanjin__skill_shu018b_1"] = "结束阶段，若你于本回合未造成过伤害，你可以摸两张牌。",
  ["#hanjin__skill_shu018b_1-invoke"] = "生息：你可以摸两张牌",
}

return skill
