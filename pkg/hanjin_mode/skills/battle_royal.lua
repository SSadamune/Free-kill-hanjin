local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"
local BattleRoyal = require "packages.hanjin.pkg.hanjin_mode.rules.battle_royal"

-- 鏖战本身提供桃当杀/闪的转换；“只能当”只是该效果的描述语法。
local skill = fk.CreateSkill { name = BattleRoyal.SKILL }
O.addViewAsEffect(skill, "battle_royal", "#hanjin_battle_royal")

Fk:loadTranslationTable {
  [BattleRoyal.SKILL] = "鏖战",
  [":" .. BattleRoyal.SKILL] = "【桃】只能当【杀】或【闪】使用或打出。",
  ["#hanjin_battle_royal"] = "鏖战：将【桃】当【杀】或【闪】使用或打出",
}

return skill
