local skill = fk.CreateSkill {
  name = "hanjin__skill_shu014_2",
}
skill.hanjinImplemented = true

Fk:loadTranslationTable {
  ["hanjin__skill_shu014_2"] = "再起",
  [":hanjin__skill_shu014_2"] = "弃牌阶段结束时，你可以令至多X名角色各选择一项（X为本回合置入弃牌堆的红色牌数）：1.摸一张牌；2.令你回复1点体力。",
  ["#hanjin__skill_shu014_2-choose"] = "再起：选择至多%arg名角色",
  ["#hanjin__skill_shu014_2-choice"] = "再起：摸一张牌，或令孟获回复1点体力",
  ["#hanjin__skill_shu014_2-recover"] = "令孟获回复1点体力",
  ["#hanjin__skill_shu014_2-draw"] = "摸一张牌",
}

local function redDiscardedThisTurn(room, player)
  return player:getMark("hanjin__shu_red_discard-turn")
end

skill:addEffect(fk.EventPhaseEnd, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    local x = redDiscardedThisTurn(player.room, player)
        return target == player and player:hasSkill(skill.name) and player.phase == Player.Discard
      and x > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local x = redDiscardedThisTurn(room, player)
    local targets = {}
    for _, p in ipairs(room.alive_players) do
      if not p:isRemoved() then table.insert(targets, p) end
    end
    local tos = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = x,
      prompt = "#hanjin__skill_shu014_2-choose:::" .. x,
      skill_name = skill.name,
      cancelable = true,
    })
    if tos == nil or #tos == 0 then return false end
    room:sortByAction(tos)
    event:setCostData(self, { tos = tos })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    for _, p in ipairs(event:getCostData(self).tos or {}) do
      if p:isAlive() then
        local choices = { "#hanjin__skill_shu014_2-draw" }
        local canRecover = player:isAlive() and player.hp < player.maxHp
        if canRecover then
          table.insert(choices, "#hanjin__skill_shu014_2-recover:" .. player.id)
        end
        local choice = room:askToChoice(p, {
          choices = choices,
          skill_name = skill.name,
          prompt = "#hanjin__skill_shu014_2-choice",
        })
        if choice == "#hanjin__skill_shu014_2-draw" then
          p:drawCards(1, skill.name)
        elseif canRecover then
          room:recover {
            who = player,
            num = 1,
            recoverBy = p,
            skillName = skill.name,
          }
        end
      end
    end
  end,
})

return skill
