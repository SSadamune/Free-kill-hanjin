-- WEI018 曹洪 · 鹤翼
--
-- 规则依据：rules/generals/wei018-caohong.md、rules/commander-retinue.md 及
-- rules/zhen-shi-generals.md。阵法技：真实队列存在时，队列全体（含自己）
-- 拥有飞影；没有队列时不因自己与自己同势力而获得。来源按每个鹤翼持有者
-- 独立登记，多个来源可叠加存在、互不删除；明置、失技、死亡、改势力、
-- 移出游戏及队列变化都即时重算。
local F = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_formation"
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_wei018_2",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local function refresh(room)
  F.refreshFormationSources(room)
end

--- 任何可能改变队列、明置或来源的事件都在同一刷新通道重算。
--- target 存在时只由该事件的目标触发一次，避免同一事件按玩家重复刷新。
local spec = {
  global = true,
  can_refresh = function(self, event, target, player)
    return player ~= nil and player.room ~= nil
      and (target == nil or target == player)
  end,
  on_refresh = function(self, event, target, player)
    refresh(player.room)
  end,
}

skill:addEffect(fk.GeneralRevealed, spec)
skill:addEffect(fk.GeneralHidden, spec)
skill:addEffect(fk.EventAcquireSkill, spec)
skill:addEffect(fk.EventLoseSkill, spec)
skill:addEffect(fk.Death, spec)
skill:addEffect(fk.AfterPropertyChange, spec)
skill:addEffect(fk.TurnStart, spec)
skill:addEffect(H.PlayerRemoved, spec)

-- 阵法召唤：汉晋 FAQ 采用出牌阶段限一次；公共 ArraySummonSkill 已按
-- HistoryPhase 计次，且阵法身份/效果不因人数少而失效。正式入口只需确保
-- 本技能在将池中即可出现召唤入口。
skill:addEffect("arraysummon", {
  array_type = "formation",
})

Fk:loadTranslationTable {
  ["qiao__skill_wei018_2"] = "鹤翼",
  [":qiao__skill_wei018_2"] = "阵法技，你队列的角色拥有“飞影”。",
}

return skill
