-- 伪溃的“本回合计算与其距离视为 1”公共距离效果（模式级）。
--
-- 固定距离是已经确定的时效状态，不应因发动者之后失去伪溃技能而提前失效。
-- 本技能随模式安装，只读取同步到客户端的 `-turn` 标记，不检查玩家当前是否
-- 仍拥有伪溃；标记在回合结束由引擎清除。
local H = require "packages.hanjin.pkg.hanjin_mode.rules.wei_history"

local skill = fk.CreateSkill {
  name = H.WEIKUI_DISTANCE_SKILL,
}

skill:addEffect("distance", {
  fixed_func = function(self, from, to)
    if from == nil or to == nil or from == to then return nil end
    if from:getMark(H.WEIKUI_DISTANCE_MARK) == to.id then return 1 end
  end,
})

return skill
