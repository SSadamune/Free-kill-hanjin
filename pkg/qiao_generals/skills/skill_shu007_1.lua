-- SHU007 黄月英 · 集智
--
-- 规则基线：rules/standard-generals.md 蜀区 SHU007；牌范围已由用户确认，见
-- rules/generals/shu007-huangyueying.md。
-- 当你使用有对应实体牌且未经转化的锦囊牌时，可以摸一张牌：
--   * 包含普通锦囊与延时锦囊（Card.TypeTrick 覆盖两者）；
--   * 排除转化牌（isConverted：虚拟牌 id=0 且带子卡）；
--   * 排除无对应实体牌的视为使用（isRuleVirtual：虚拟牌且无子卡）。
-- 直接使用的实体锦囊牌 id 非 0，满足“有对应实体牌”。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu007_1",
}
skill.qiaoImplemented = true

skill:addEffect(fk.CardUsing, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) or data.card == nil then
      return false
    end
    local card = data.card
    return card.type == Card.TypeTrick and not card:isConverted()
      and not card:isRuleVirtual()
  end,
  on_use = function(self, event, target, player, data)
    player:drawCards(1, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu007_1"] = "集智",
  [":qiao__skill_shu007_1"] = "当你使用非转化且非虚拟的锦囊牌时，你可以摸一张牌。",
}

return skill
