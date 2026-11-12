local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"

-- 房间级禁止技。与按 skillNames 或手牌区判断的上游实现不同，这里检查所有
-- 合法牌区中的非转化实体牌；转化牌是虚拟牌，不受“原实体牌禁用”限制。
local skill = fk.CreateSkill {
  name = O.PROHIBIT_SKILL,
  tags = { Skill.Compulsory },
}

skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    return O.isForbidden(player, card)
  end,
  prohibit_response = function(self, player, card)
    return O.isForbidden(player, card)
  end,
})

Fk:loadTranslationTable {
  [O.PROHIBIT_SKILL] = "牌用途限制",
}

return skill
