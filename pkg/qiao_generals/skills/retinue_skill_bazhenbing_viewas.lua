-- 八阵兵本次结算中的临时 viewAs：将一张【杀】当【无懈可击】使用。
-- 仅在当前【调虎离山】结算窗口、由公开 mark 控制；结算 finally 撤来源。
local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_bazhenbing_viewas",
}
skill.qiaoImplemented = true

local MARK = "@@qiao_bazhen_viewas"

skill:addEffect("viewas", {
  anim_type = "defensive",
  pattern = "nullification",
  prompt = "#qiao__retinue_skill_bazhenbing_viewas-prompt",
  handly_pile = true,
  filter_pattern = { min_num = 1, max_num = 1, pattern = "slash" },
  enabled_at_response = function(self, player, response)
    return not response and player:getMark(MARK) > 0
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard("qiao__nullification")
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
})

Fk:loadTranslationTable {
  ["qiao__retinue_skill_bazhenbing_viewas"] = "八阵兵",
  [":qiao__retinue_skill_bazhenbing_viewas"] = "本次【调虎离山】结算中，你可以将一张【杀】当【无懈可击】使用。",
  ["#qiao__retinue_skill_bazhenbing_viewas-prompt"] = "八阵兵：将一张【杀】当【无懈可击】使用",
}

return skill
