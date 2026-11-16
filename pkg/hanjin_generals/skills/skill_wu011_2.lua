-- WU011 小乔 · 红颜
--
-- 锁定技，你的黑桃牌和黑桃判定牌视为红桃牌。用锁视（filter）实现：手牌、
-- 装备区和判定牌在花色相关结算中呈现为红桃；判定事件额外允许非自己拥有的
-- 判定牌。黑桃牌离开小乔后按新持有者重新过滤，不会把红桃身份带走。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu011_2",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

local function ownedByPlayer(player, id)
  return table.contains(player:getCardIds(Player.Hand), id)
    or table.contains(player:getCardIds(Player.Equip), id)
end

skill:addEffect("filter", {
  mute = true,
  card_filter = function(self, card, player, isJudgeEvent)
    if card == nil or card.suit ~= Card.Spade or player == nil then return false end
    if not player:hasSkill(skill.name) then return false end
    return isJudgeEvent or ownedByPlayer(player, card.id)
  end,
  view_as = function(self, player, card)
    return card:clone(Card.Heart, card.number)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu011_2"] = "红颜",
  [":hanjin__skill_wu011_2"] = "锁定技，你的黑桃牌和黑桃判定牌视为红桃牌。",
}

return skill
