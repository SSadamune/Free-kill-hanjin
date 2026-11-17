-- 龙飞共享实例的房间级刷新规则；只由 zhen_shi_longfei.ensureRule 安装。
local L = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_longfei"
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = L.RULE,
}

local function refresh(player)
  if player ~= nil and player.room ~= nil then L.refresh(player.room) end
end

local spec = {
  global = true,
  priority = -20,
  can_refresh = function(self, event, target, player)
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    refresh(player)
  end,
}

skill:addEffect(fk.GeneralRevealed, spec)
skill:addEffect(fk.GeneralHidden, spec)
skill:addEffect(fk.AfterPropertyChange, spec)
skill:addEffect(H.GeneralRemoved, spec)
skill:addEffect(fk.Death, spec)
skill:addEffect(fk.EventAcquireSkill, spec)
skill:addEffect(fk.EventLoseSkill, spec)

return skill
