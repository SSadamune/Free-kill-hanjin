local skill = fk.CreateSkill {
  name = "hanjin__taigong_tactics_skill",
  attached_equip = "hanjin__taigong_tactics",
}

Fk:loadTranslationTable {
  ["hanjin__taigong_tactics_skill"] = "太公阴符",
  ["#hanjin__taigong_tactics-choose"] = "太公阴符：你可以横置或重置一名角色",
  ["#hanjin__taigong_tactics-recast"] = "太公阴符：你可以重铸一张手牌",
}

skill:addEffect(fk.EventPhaseStart, {
  mute = true,
  can_trigger = function(self, event, target, player)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Play
  end,
  on_cost = function(self, event, target, player)
    local room = player.room
    local to = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = room.alive_players,
      skill_name = skill.name,
      prompt = "#hanjin__taigong_tactics-choose",
      cancelable = true,
    })
    if #to > 0 then
      event:setCostData(self, { tos = to })
      return true
    end
  end,
  on_use = function(self, event, target, player)
    local to = event:getCostData(self).tos[1]
    to:setChainState(not to.chained)
  end,
})

skill:addEffect(fk.EventPhaseEnd, {
  mute = true,
  can_trigger = function(self, event, target, player)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Play
      and not player:isKongcheng()
  end,
  on_cost = function(self, event, target, player)
    local room = player.room
    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = skill.name,
      prompt = "#hanjin__taigong_tactics-recast",
      cancelable = true,
    })
    if #cards > 0 then
      event:setCostData(self, { cards = cards })
      return true
    end
  end,
  on_use = function(self, event, target, player)
    player.room:recastCard(event:getCostData(self).cards, player, skill.name)
  end,
})

return skill
