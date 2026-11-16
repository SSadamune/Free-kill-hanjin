-- 晋应变批次：已建立用牌属性的房间级结算。
--
-- 乘流在 PreCardUse 给本次伤害牌写入 use.extra_data.hanjin_damage_type；本次使用
-- 中途即使王濬失去乘流或死亡，已经建立的“此牌造成雷电伤害”仍应生效。因此
-- 雷伤改写不能依赖技能持有者当前是否仍有乘流，而由本房间规则只按本次 use 标记
-- 执行。规则由乘流在赋条目时按需加入房间；模式也可在开局统一 addSkill，二者
-- 都以房间是否已有同名技能去重。
local J = require "packages.hanjin.pkg.hanjin_generals.util.jin_adaptation"

local skill = fk.CreateSkill {
  name = "hanjin__jin_adaptation_rule",
  tags = { Skill.Compulsory },
}

skill:addEffect(fk.PreDamage, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return J.useDamageType(player.room, data) ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    data.damageType = J.useDamageType(player.room, data) or data.damageType
  end,
})

Fk:loadTranslationTable {
  ["hanjin__jin_adaptation_rule"] = "晋应变结算",
}

return skill
