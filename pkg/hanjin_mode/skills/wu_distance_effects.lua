-- 奋迅的“本回合你与该角色距离视为 1”公共距离效果（模式级）。
--
-- 固定距离是已经确定的时效状态，不因发动者之后失去奋迅而提前失效。
-- 本技能随模式安装，只读取同步到客户端的 `-turn` 标记；标记在回合结束由
-- 引擎清理。距离是双向的：任一方标记指向对方时都视为 1。
local H = require "packages.hanjin.pkg.hanjin_mode.rules.wu_history"

local skill = fk.CreateSkill {
  name = H.DISTANCE_SKILL,
}

skill:addEffect("distance", {
  fixed_func = function(self, from, to)
    if from == nil or to == nil or from == to then return nil end
    if from:getMark(H.FENXUN_MARK) == to.id then return 1 end
    if to:getMark(H.FENXUN_MARK) == from.id then return 1 end
  end,
})

return skill
