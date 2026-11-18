-- EM(HAN001) 君刘协 · 初平
-- 此君主牌实际明置后取得“诏书”特殊标记；同势力角色（含本人）获得诏书入口。
-- 诏书是唯一指示物：若【敕令】已把诏书交给其他角色，初平不再重复建立。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"

local skill = fk.CreateSkill { name = P.JIANPING }
skill.qiaoImplemented = true

local revealSpec = {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and target.general == P.LORD
      and target:getMark(P.MARK) == 0 and P.holder(target.room) == nil
  end,
  on_refresh = function(self, event, target, player, data)
    P.grant(player.room, target)
    P.syncTricks(player.room)
  end,
}
skill:addEffect(fk.GeneralShown, revealSpec)
skill:addEffect(fk.GeneralRevealed, revealSpec)

local syncSpec = {
  global = true,
  can_refresh = function(self, event, target, player)
    if event == fk.GameStart then return player.seat == 1 end
    return target == player
  end,
  on_refresh = function(self, event, target, player) P.sync(player.room) end,
}
skill:addEffect(fk.GameStart, syncSpec)
skill:addEffect(fk.AfterPropertyChange, syncSpec)
skill:addEffect(fk.Death, syncSpec)

skill:addAcquireEffect(function(self, player) P.sync(player.room) end)
skill:addLoseEffect(function(self, player) P.sync(player.room) end)

Fk:loadTranslationTable {
  [P.JIANPING] = "初平",
  [":" .. P.JIANPING] = "君主技，此武将牌明置后，你获得游戏外的“诏书”；你因“诏书”获得的势力锦囊由你选择。",
}

return skill
