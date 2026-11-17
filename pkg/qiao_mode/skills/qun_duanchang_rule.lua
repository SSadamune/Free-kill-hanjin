-- 群势力标准包：断肠（QUN012）的明置兜底。
--
-- 由模式在 logic:start 时以 `room:addSkill("qiao__qun_duanchang_rule")` 接入；
-- 不设 global 触发，避免进入非汉晋房间。真正的失技询问在打印技能
-- qiao__skill_qun012_2 上；本规则只在武将牌明置时核对断肠记录：
--   * 已失去的技能不得因明置重新授回；
--   * 引擎 revealGeneral 的 tolose 可能误删另一张牌仍提供的同名技能，明置后补回。
local Q = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"

local skill = fk.CreateSkill {
  name = Q.RULE_SKILL,
  tags = { Skill.Compulsory },
}

skill:addEffect(fk.GeneralShown, {
  priority = -1,
  can_trigger = function(self, event, target, player, data)
    return target == player and Q.shownHasLost(player.room, player, data)
  end,
  on_trigger = function(self, event, target, player, data)
    Q.enforceShown(target, data)
  end,
})

return skill
