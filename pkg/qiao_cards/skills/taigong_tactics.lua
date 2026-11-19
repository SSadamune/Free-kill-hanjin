local skill = fk.CreateSkill {
  name = "qiao__taigong_tactics_skill",
  attached_equip = "qiao__taigong_tactics",
}

Fk:loadTranslationTable {
  ["qiao__taigong_tactics_skill"] = "太公阴符",
  ["#qiao__taigong_tactics-choose"] = "太公阴符：你可以横置或重置一名角色",
  ["#qiao__taigong_tactics-recast"] = "太公阴符：你可以重铸一张手牌",
}

skill:addEffect(fk.EventPhaseStart, {
  mute = true,
  can_trigger = function(self, event, target, player)
    return target == player and player:hasSkill(skill.name)
      and not player:isRemoved() and player.phase == Player.Play
  end,
  on_cost = function(self, event, target, player)
    local room = player.room
    -- 移出游戏的角色视为不存在，不能成为“一名角色”的候选。
    local targets = table.filter(room:getPresentPlayers(), function(p)
      return not p:isRemoved()
    end)
    local to = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = targets,
      skill_name = skill.name,
      prompt = "#qiao__taigong_tactics-choose",
      cancelable = true,
    })
    if #to > 0 then
      event:setCostData(self, { tos = to })
      return true
    end
  end,
  on_use = function(self, event, target, player)
    local to = event:getCostData(self).tos[1]
    if to == nil or to.dead or to:isRemoved() then return end
    to:setChainState(not to.chained)
  end,
})

skill:addEffect(fk.EventPhaseEnd, {
  mute = true,
  can_trigger = function(self, event, target, player)
    return target == player and player:hasSkill(skill.name)
      and not player:isRemoved() and player.phase == Player.Play
      and not player:isKongcheng()
  end,
  on_cost = function(self, event, target, player)
    local room = player.room
    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = false,
      skill_name = skill.name,
      prompt = "#qiao__taigong_tactics-recast",
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
