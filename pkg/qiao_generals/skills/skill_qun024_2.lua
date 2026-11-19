-- QUN024 张任 · 龙飞
-- 阵法技：自己队列的其他角色也拥有自己的翼从。共享实例由公共工具登记，
-- 不传播队友借得的 shared 实例，关系/失技/死亡变化时重算。
local L = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_longfei"

local skill = fk.CreateSkill {
  name = L.LONG_FEI,
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local function ensure(room)
  L.ensureRule(room)
  L.refresh(room)
end

skill:addEffect(fk.GameStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player)
    ensure(player.room)
  end,
})

skill:addEffect(fk.EventAcquireSkill, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and data ~= nil and data.skill ~= nil
      and data.skill.name == skill.name
  end,
  on_refresh = function(self, event, target, player)
    ensure(player.room)
  end,
})

skill:addEffect(fk.GeneralRevealed, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    ensure(player.room)
  end,
})

Fk:loadTranslationTable {
  [L.LONG_FEI] = "龙飞",
  [":" .. L.LONG_FEI] = "阵法技，你队列的其他角色也拥有你的翼从。",
}

return skill
