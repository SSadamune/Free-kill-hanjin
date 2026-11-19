-- SHU019 马岱·潜袭的回合结束清理。
--
-- 与限制状态技分开注册，确保房间只把潜袭静态规则当作 ProhibitSkill 安装；
-- 回合结束时清理全部目标标记，使限制严格只持续本回合。
local Q = require "packages.qiao.pkg.qiao_generals.util.shu019_qianxi"

local skill = fk.CreateSkill {
  name = Q.CLEANUP_SKILL,
}

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player ~= nil and player.room ~= nil
  end,
  on_refresh = function(self, event, target, player)
    Q.clear(player.room)
  end,
})

return skill
