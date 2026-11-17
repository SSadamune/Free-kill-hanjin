-- WU023 陈武&董袭 · 断绁
--
-- 锁定技：自己实际从横置变为重置后摸一张，若此时是自己回合内则多摸一张。
-- 用 BeforeChainStateChange 记录旧状态，避免对已重置者重复 setChainState(false)
-- 仍被误认为发生了一次重置；重置不等于平置或明置。
local skill = fk.CreateSkill {
  name = "qiao__skill_wu023_2",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local WAS_CHAINED = "qiao_wu023_2_was_chained"

skill:addEffect(fk.BeforeChainStateChange, {
  mute = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    data[WAS_CHAINED] = target.chained
  end,
})

skill:addEffect(fk.ChainStateChanged, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data[WAS_CHAINED] == true and not player.chained
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local n = player.room.current == player and 2 or 1
    player:drawCards(n, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu023_2"] = "断绁",
  [":qiao__skill_wu023_2"] = "锁定技，当你重置后，你摸一张牌，若此时是你回合内，你多摸一张牌。",
}

return skill
