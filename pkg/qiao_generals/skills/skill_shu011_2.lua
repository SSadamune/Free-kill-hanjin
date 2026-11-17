-- SHU011 诸葛亮（卧龙） · 火计
--
-- 规则基线：rules/standard-generals.md 蜀区 SHU011。
-- 你可以将一张红色手牌当【火攻】使用；只授权手牌，不开放装备区。
-- 目标条件与结算全部交给正式汉晋【火攻】牌技能，技能内不复制牌面流程。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu011_2",
}
skill.qiaoImplemented = true

skill:addEffect("viewas", {
  anim_type = "offensive",
  pattern = "qiao__fire_attack",
  prompt = "#qiao__skill_shu011_2-prompt",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".|.|red|^equip",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard("qiao__fire_attack")
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu011_2"] = "火计",
  [":qiao__skill_shu011_2"] = "你可以将一张红色手牌当【火攻】使用。",
  ["#qiao__skill_shu011_2-prompt"] = "火计：将一张红色手牌当【火攻】使用",
}

return skill
