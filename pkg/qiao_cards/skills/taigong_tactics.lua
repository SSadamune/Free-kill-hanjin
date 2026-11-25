local StateToggle = require "packages.qiao.pkg.qiao_mode.rules.state_toggle"

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
    local to = StateToggle.ask(player, {
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__taigong_tactics-choose",
    })
    if #to > 0 then
      event:setCostData(self, { tos = to })
      return true
    end
  end,
  on_use = function(self, event, target, player)
    StateToggle.chain(event:getCostData(self).tos[1])
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
