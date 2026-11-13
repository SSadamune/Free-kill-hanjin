-- WEI011 曹仁 · 励战
--
-- 规则基线：rules/standard-generals.md 魏区 WEI011。
-- 结束阶段，令任意名已受伤的角色各摸一张牌。目标包含自己；至少选择一名
-- 已受伤角色。全部摸牌在同一效果结算内完成。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei011_2",
}

---@param room Room
---@return ServerPlayer[]
local function woundedPlayers(room)
  return table.filter(room.alive_players, function(p)
    return not p:isRemoved() and p:isWounded()
  end)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
      and player.phase == Player.Finish and #woundedPlayers(player.room) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei011_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local targets = woundedPlayers(room)
    if #targets == 0 then return end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = #targets,
      targets = targets,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei011_2-target",
      cancelable = false,
    })
    for _, to in ipairs(chosen) do
      if to:isAlive() and not to:isRemoved() then
        to:drawCards(1, skill.name)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei011_2"] = "励战",
  [":hanjin__skill_wei011_2"] = "结束阶段，你可以令任意名已受伤的角色各摸一张牌。",
  ["#hanjin__skill_wei011_2-invoke"] = "励战：你可以令任意名已受伤的角色各摸一张牌",
  ["#hanjin__skill_wei011_2-target"] = "励战：选择已受伤的角色",
}

skill.hanjinImplemented = true

return skill
