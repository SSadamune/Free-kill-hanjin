-- JIN009 权变的阶段限制。由模式安装，读取中性花色标记；即使司马懿之后
-- 失去权变，本阶段已经建立的手牌使用限制仍然存在。只禁止“使用”该花色手牌，
-- 不禁止打出，也不限制装备区等非手牌来源。
local D = require "packages.qiao.pkg.qiao_generals.util.jin_deck"

local skill = fk.CreateSkill {
  name = D.RULE_SKILL,
}

-- 已使用的牌是公开信息。即使权变尚未明置，也保留本阶段此前的花色。
skill:addEffect(fk.AfterCardUseDeclared, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player.phase == Player.Play
      and D.validSuit(data.card.suit) and data:isUsingHandcard(player)
      and not table.contains(player:getTableMark(D.USED_SUITS), data.card.suit)
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:addTableMarkIfNeed(player, D.USED_SUITS, data.card.suit)
  end,
})

skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    if player == nil or card == nil then return false end
    local suits = D.bannedSuits(player)
    if #suits == 0 or not table.contains(suits, card.suit) then return false end
    return D.isHandCard(player, card)
  end,
})

return skill
