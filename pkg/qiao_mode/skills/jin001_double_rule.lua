-- EM(JIN001) 首次双亮全局记账：即使当前没有太康/持旗者也记录，
-- 之后获得旗或再次双亮不补领。仅做纯状态，不进入玩家选择。
local First = require "packages.qiao.pkg.qiao_generals.util.jin_first_reveal"

local MARK = "qiao_jin001_first_double"

local skill = fk.CreateSkill { name = "qiao__em_jin001_double_rule" }

skill:addEffect(fk.GeneralRevealed, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and target ~= nil and target.general ~= "anjiang"
      and target.deputyGeneral ~= "anjiang" and target.general ~= ""
      and target.deputyGeneral ~= "" and target:getMark(MARK) == 0
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(target, MARK, 1)
    First.remember(event)
  end,
})

return skill
