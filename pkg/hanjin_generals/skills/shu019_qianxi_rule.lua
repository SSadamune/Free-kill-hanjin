-- SHU019 马岱·潜袭的静态回合限制。
--
-- 由潜袭成功建立限制后安装到房间，读取目标的中性标记；不检查马岱是否仍有
-- 潜袭，也不检查来源技能是否明置。只禁止使用/打出，不禁止弃置、给予等操作。
local Q = require "packages.hanjin.pkg.hanjin_generals.util.shu019_qianxi"

local skill = fk.CreateSkill {
  name = Q.RULE_SKILL,
  tags = { Skill.Compulsory },
}

skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    return Q.prohibited(player, card)
  end,
  prohibit_response = function(self, player, card)
    return Q.prohibited(player, card)
  end,
})

return skill
