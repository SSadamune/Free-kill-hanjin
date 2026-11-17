-- 晋将公开用牌历史规则。
-- 仅由汉晋模式入口在 GameStart 后安装；不依赖杜预是否已取得/明置武库。
-- 记录每名角色本回合实际“使用”的基本牌和普通锦囊牌，供武库客户端公开读取。
-- 需要主批在模式创建/GameStart 位置 room:addSkill(Fk.skills[RULE])；不自行跨模式安装。
local U = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"

local RULE = "#qiao_zhen_shi_jin_history"

local skill = fk.CreateSkill {
  name = RULE,
}

skill:addEffect(fk.AfterCardUseDeclared, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and U.isBasicOrNormalTrick(data.card)
  end,
  on_refresh = function(self, event, target, player, data)
    U.recordUse(player, data.card.trueName or data.card.name)
  end,
})

skill:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player
  end,
  on_refresh = function(self, event, target, player)
    U.resetTurn(player)
  end,
})

Fk:loadTranslationTable {
  [RULE] = "汉晋晋将用牌历史",
}

return skill
