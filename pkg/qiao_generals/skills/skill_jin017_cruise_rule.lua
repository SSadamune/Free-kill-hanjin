-- JIN017 王浑 · 遄征的独立回合奖惩规则。
-- 由遄征实际发动时安装到房间；不依赖遄征技能是否仍被持有，也不依赖
-- 角色公开副将是否为 anjiang。离开本回合即清除奖励标记。
local RULE = "#qiao_jin017_cruise"
local MARK = "qiao_jin017_2_cruise"

local skill = fk.CreateSkill {
  name = RULE,
}

skill:addEffect(fk.Death, {
  global = true,
  priority = 100,
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and not player.dead
      and player:getMark(MARK) > 0
      and data ~= nil and data.killer == player
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data.extra_data = data.extra_data or {}
    data.extra_data.ignorePunishment = true
    player:drawCards(3, RULE)
  end,
})

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    if player:getMark(MARK) ~= 0 then
      player.room:setPlayerMark(player, MARK, 0)
    end
  end,
})

return skill
