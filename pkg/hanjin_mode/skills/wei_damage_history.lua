-- 长驱的全局伤害记录器（模式级）。
--
-- 由 mode.lua 在 logic:start 之前安装到房间，因此不依赖长驱武将是否已选、
-- 是否明置、之后是否换将。只把公开的“目标 id 集合”写入同步玩家标记，
-- 供客户端 targetmod 与服务端使用。
local H = require "packages.hanjin.pkg.hanjin_mode.rules.wei_history"

local skill = fk.CreateSkill {
  name = H.HISTORY_SKILL,
}

skill:addEffect(fk.Damage, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return data ~= nil and data.from ~= nil and data.to ~= nil and (data.damage or 0) > 0
  end,
  on_refresh = function(self, event, target, player, data)
    H.record(data.from.room, data.from, data.to)
  end,
})

skill:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target ~= nil
  end,
  on_refresh = function(self, event, target, player)
    H.clear(target.room)
  end,
})

skill:addEffect(fk.GameStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player)
    H.clear(player.room)
  end,
})

return skill
