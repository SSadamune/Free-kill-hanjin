-- WU011 小乔 · 红颜
--
-- 锁定技，你的黑桃牌和黑桃判定牌视为红桃牌。用锁视（filter）实现：手牌、
-- 装备区和判定牌在花色相关结算中呈现为红桃；判定事件额外允许非自己拥有的
-- 判定牌。黑桃牌离开小乔后按新持有者重新过滤，不会把红桃身份带走。
local skill = fk.CreateSkill {
  name = "qiao__skill_wu011_2",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

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
    -- 与上游红颜同样按注册牌型克隆，保留实体牌所属包及技能／装备特性。
    -- 逐实体汉晋信息（牌位、应变、合纵等）只挂在 extra_data 上，不随牌型
    -- 注册：显式复制一份，锁视牌读取时不触及原实体。
    local newCard = Fk:cloneCard(card.name, Card.Heart, card.number)
    if card.extra_data then
      newCard.extra_data = table.simpleClone(card.extra_data)
    end
    return newCard
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu011_2"] = "红颜",
  [":qiao__skill_wu011_2"] = "锁定技，你的黑桃牌和黑桃判定牌视为红桃牌。",
}

return skill
