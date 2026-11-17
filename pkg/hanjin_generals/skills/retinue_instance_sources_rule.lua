-- 实体翼从实例同步规则。
--
-- 只由 retinue_instance_sources.ensureRule(room) 在汉晋房间安装；不在其他
-- 模式全局挂载。所有入口幂等，重复明置/属性刷新不会重复增实例。
local S = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instance_sources"
local H = require "packages.hegemony.util"
local Commander = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"

local skill = fk.CreateSkill {
  name = S.RULE_SKILL,
}

-- 派生来源在客户端和服务端预注册，不能首次授予时仅服务端动态创建。
skill:addAuxActiveSkill("#hanjin_retinue_instance_source", {
  can_use = Util.FalseFunc,
  on_use = function() end,
})

local function sync(player)
  S.syncPlayer(player)
end

skill:addEffect(fk.GameStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player.seat == 1
  end,
  on_refresh = function(self, event, target, player)
    S.ensureRule(player.room)
  end,
})

local spec = {
  global = true,
  priority = -20,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    sync(player)
  end,
}

skill:addEffect(fk.GeneralRevealed, spec)
skill:addEffect(fk.AfterPropertyChange, spec)
skill:addEffect(H.GeneralRemoved, spec)
skill:addEffect(H.GeneralTransformed, spec)

-- 士兵/翼从不是武将牌；把翼从位置按“暗置武将牌”隐藏不是常规生命周期。
-- 若引擎仍触发 GeneralHidden 且 data 是翼从兵种，不能把它当普通暗将删除
-- 重建实例（会刷新自身次数）；保留实体身份，重新明置时幂等同步。
skill:addEffect(fk.GeneralHidden, {
  global = true,
  priority = -20,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    if type(data) == "string" and Commander.isRetinue(data) then return end
    S.syncPlayer(player)
  end,
})

Fk:loadTranslationTable {
  [S.RULE_SKILL] = "汉晋实体翼从同步规则",
}

return skill
