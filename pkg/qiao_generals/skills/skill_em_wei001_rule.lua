-- EM(WEI001) 霸者求贤状的到期规则。
-- 受益者自己的下回合开始时解除限制并撤销本次来源的临时技能；其他角色或
-- 君主回合开始不提前解除。死亡时同样清理。
local W = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"

local skill = fk.CreateSkill { name = W.RULE }

skill:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and W.record(player.room, target) ~= nil
  end,
  on_refresh = function(self, event, target, player)
    W.expire(player.room, target)
  end,
})

skill:addEffect(fk.Death, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and W.record(player.room, target) ~= nil
  end,
  on_refresh = function(self, event, target, player)
    W.expire(player.room, target)
  end,
})

return skill
