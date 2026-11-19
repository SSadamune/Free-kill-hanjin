-- JIN017 王浑 · 献捷（由遄征永久获得）
-- 一张非伤害牌当带〈富甲→目标+1〉的【铁索连环】使用；材料可为手牌或装备。
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin017_3",
}
skill.qiaoImplemented = true

local CHAIN = "qiao__iron_chain"

skill:addEffect("viewas", {
  pattern = CHAIN,
  prompt = "#qiao__skill_jin017_3-prompt",
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    local card = Fk:getCardById(to_select)
    return card ~= nil and card.is_damage ~= true
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local source = Fk:getCardById(cards[1])
    if source == nil or source.is_damage == true then return nil end
    local card = Fk:cloneCard(CHAIN)
    if card == nil then return nil end
    card.skillName = skill.name
    card:addSubcard(cards[1])
    A.setCardEntries(card, {
      { condition = "fujia", effect = "add_target" },
    })
    return card
  end,
  enabled_at_play = function(self, player)
    return #table.filter(player:getCardIds("he"), function(id)
      local card = Fk:getCardById(id)
      return card ~= nil and card.is_damage ~= true
    end) > 0
  end,
  enabled_at_response = function() return false end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin017_3"] = "献捷",
  [":qiao__skill_jin017_3"] = "你可以将一张非伤害牌当【铁索连环】〈富甲→目标+1〉使用。",
  ["#qiao__skill_jin017_3-prompt"] = "献捷：将一张非伤害牌当【铁索连环】使用（富甲：目标+1）",
}

return skill
