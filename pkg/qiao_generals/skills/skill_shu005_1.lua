-- SHU005 赵云 · 龙胆
--
-- 规则基线：rules/standard-generals.md 蜀区 SHU005；鏖战兼容见
-- rules/battle-royal.md。
-- 四组互转，均可使用或打出：
--   【杀】→【闪】、【闪】→【杀】、【桃】→【酒】、【酒】→【桃】。
-- 属性【杀】（火/雷/冰）按 trueName 视为【杀】。
-- 非普通转换（桃当酒、酒当桃）同样通过 ViewAs 入口：鏖战只限制实体桃的直接
-- 用途，不改变其他转化技能；龙胆的桃→酒仍按龙胆条件成立（同 FAQ 例4）。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu005_1",
}
skill.qiaoImplemented = true

local SLASH = "qiao__slash"
local JINK = "qiao__jink"
local PEACH = "qiao__peach"
local ANALEPTIC = "qiao__analeptic"

skill:addEffect("viewas", {
  anim_type = "defensive",
  pattern = table.concat({ SLASH, JINK, PEACH, ANALEPTIC }, ","),
  prompt = "#qiao__skill_shu005_1-prompt",
  handly_pile = true,
  filter_pattern = function(self, player, card_name, selected)
    local pattern
    if card_name == SLASH then
      pattern = "jink"
    elseif card_name == JINK then
      pattern = "slash"
    elseif card_name == PEACH then
      pattern = "analeptic"
    elseif card_name == ANALEPTIC then
      pattern = "peach"
    else
      return nil
    end
    return { min_num = 1, max_num = 1, pattern = pattern }
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local material = Fk:getCardById(cards[1])
    if material == nil then return nil end
    local target
    if material.trueName == "slash" then
      target = JINK
    elseif material.trueName == "jink" then
      target = SLASH
    elseif material.trueName == "peach" then
      target = ANALEPTIC
    elseif material.trueName == "analeptic" then
      target = PEACH
    else
      return nil
    end
    local card = Fk:cloneCard(target)
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu005_1"] = "龙胆",
  [":qiao__skill_shu005_1"] = "你可以将【杀】当【闪】、【闪】当【杀】、【桃】当【酒】、【酒】当【桃】使用或打出。",
  ["#qiao__skill_shu005_1-prompt"] = "龙胆：将【杀】当【闪】、【闪】当【杀】、【桃】当【酒】或【酒】当【桃】使用或打出",
}

return skill
