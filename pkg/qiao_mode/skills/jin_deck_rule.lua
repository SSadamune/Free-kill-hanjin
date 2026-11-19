-- JIN009 权变的阶段限制。由模式安装，读取中性花色标记；即使司马懿之后
-- 失去权变，本阶段已经建立的手牌使用限制仍然存在。只禁止“使用”该花色手牌，
-- 不禁止打出，也不限制装备区等非手牌来源。
local D = require "packages.qiao.pkg.qiao_generals.util.jin_deck"

local skill = fk.CreateSkill {
  name = D.RULE_SKILL,
}

skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    if player == nil or card == nil then return false end
    local suits = D.bannedSuits(player)
    if #suits == 0 or not table.contains(suits, card.suit) then return false end
    return D.isHandCard(player, card)
  end,
})

return skill
