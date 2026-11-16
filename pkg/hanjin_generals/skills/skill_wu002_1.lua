-- WU002 甘宁 · 奇袭
--
-- 规则基线：rules/standard-generals.md 吴区 WU002。
-- 将一张黑色牌当【过河拆桥】使用；牌可来自手牌或装备区。颜色与牌面由
-- 公共 ViewAs 选牌规则按当前房间的有效信息判断，不在技能内改写牌名。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu002_1",
}
skill.hanjinImplemented = true

skill:addEffect("viewas", {
  anim_type = "control",
  pattern = "hanjin__dismantlement",
  prompt = "#hanjin__skill_wu002_1-prompt",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".|.|black",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard("hanjin__dismantlement")
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_response = function(self, player, response)
    return not response
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wu002_1-prompt"] = "奇袭：将一张黑色牌当【过河拆桥】使用",
}

return skill
