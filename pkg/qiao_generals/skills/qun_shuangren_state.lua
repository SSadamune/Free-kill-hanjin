-- QUN015 纪灵 · 双刃「没赢」后的已建立效果入口。
--
-- 双刃没赢后的效果同时包含“限制”和“转换权限”：手牌中的【杀】只能当
-- 【借刀杀人】使用。二者都必须在失去双刃技能本体后继续存在到本回合结束，
-- 因此转换入口不能挂在双刃本体上（否则失去本体后只剩限制、无法使用）。
-- 本文件是独立状态骨架：
--   * 由 pkg/qiao_generals/init.lua 的 loadSkillSkelsByPath 随包自动加载；
--   * 双刃在建立没赢效果时以 handleAddLoseSkills(player, STATE, STATE, ...)
--     把它挂到角色上，来源不绑双刃本体；
--   * 它只复用公共 only-as 的 shuangren 来源（实体牌牌名不改、只开放“使用”、
--     借刀杀人仍按该牌自身规则真实选择主目标与副目标）；
--   * 仍显示为“双刃”，不新增面向玩家的“只能当”技能；
--   * 回合结束时移除本骨架；限制来源由公共 only-as 规则的 TurnEnd 清理。
local OnlyAs = require "packages.qiao.pkg.qiao_mode.rules.only_as"

local STATE = "qiao__qun_shuangren_state"

local skill = fk.CreateSkill {
  name = STATE,
}

OnlyAs.addViewAsEffect(skill, "shuangren", "#qiao__qun_shuangren_state-prompt")

-- 权限只持续到建立它的那个回合结束；届时移除本骨架。限制来源不在此处清理，
-- 由 only-as 公共规则统一处理，避免两处状态互相覆盖。
skill:addEffect(fk.TurnEnd, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    player.room:handleAddLoseSkills(player, "-" .. STATE, STATE, false, true)
  end,
})

Fk:loadTranslationTable {
  [STATE] = "双刃",
  [":" .. STATE] = "出牌阶段开始时，你可以与一名角色拼点：若你赢，你视为对包含其在内的至多两名角色使用一张【杀】；若你没赢，本回合你手牌中的【杀】只能当【借刀杀人】使用。",
  ["#qiao__qun_shuangren_state-prompt"] = "双刃：将手牌中的【杀】当【借刀杀人】使用",
}

return skill
