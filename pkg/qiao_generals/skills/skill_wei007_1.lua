-- WEI007 甄姬 · 倾国
--
-- 规则基线：docs/rules/standard-generals.md 魏区 WEI007。
-- 一张黑色手牌当【闪】使用或打出；只授权手牌，不额外开放装备区。
-- 使用与响应共用 ViewAs 入口，由引擎按当前请求决定是使用还是打出。
local skill = fk.CreateSkill {
  name = "qiao__skill_wei007_1",
}

skill:addEffect("viewas", {
  anim_type = "defensive",
  -- 响应请求按牌的 trueName 发 pattern（杀询问【闪】时为 "jink"），不能用
  -- 程序牌名 qiao__jink；view_as 仍构造正式牌 ID，牌面与材料不变。
  pattern = "jink",
  prompt = "#qiao__skill_wei007_1-prompt",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    -- 牌名|点数|花色|区域：黑色，且不能来自装备区（手牌内的装备牌仍可用）。
    pattern = ".|.|black|^equip",
  },
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard("qiao__jink")
    card.skillName = skill.name
    card:addSubcards(cards)
    return card
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei007_1"] = "倾国",
  [":qiao__skill_wei007_1"] = "你可以将一张黑色手牌当【闪】使用或打出。",
  ["#qiao__skill_wei007_1-prompt"] = "倾国：将一张黑色手牌当【闪】使用或打出",
}

skill.qiaoImplemented = true

return skill
