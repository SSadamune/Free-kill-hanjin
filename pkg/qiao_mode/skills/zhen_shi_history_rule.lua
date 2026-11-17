-- 阵/势包公共回合历史：记录本回合明置的武将牌。
-- 由模式在 logic:start 安装；不依赖任何武将是否持有或已明置。
local H = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_history"

local skill = fk.CreateSkill {
  name = "qiao__zhen_shi_history_rule",
}

skill:addEffect(fk.GeneralRevealed, {
  can_refresh = function(self, event, target, player, data)
    return target ~= nil and target == player and data ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    H.record(player.room, data)
  end,
})

-- 每个真实回合开始清空，修体只数本回合记录；避免依赖事件上下文 turn id，
-- 非 Turn 夹具也不会读到上回合残留。
skill:addEffect(fk.AfterCardUseDeclared, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target ~= nil and target == player
  end,
  on_refresh = function(self, event, target, player)
    H.recordCard(player.room, player, "use")
  end,
})

skill:addEffect(fk.CardResponding, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target ~= nil and target == player
  end,
  on_refresh = function(self, event, target, player)
    H.recordCard(player.room, player, "play")
  end,
})

skill:addEffect(fk.TurnStart, {
  can_refresh = function(self, event, target, player)
    return target ~= nil and target == player
  end,
  on_refresh = function(self, event, target, player)
    H.clear(player.room)
  end,
})

return skill
