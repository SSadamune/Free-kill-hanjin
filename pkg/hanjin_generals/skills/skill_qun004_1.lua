-- QUN004 袁绍 · 乱击
--
-- 规则基线：rules/standard-generals.md 群区 QUN004、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 两张手牌当【万箭齐发】，不要求两素材同花色；仅排除「本回合此前发动乱击
-- 时已经选择过」的花色，因此同一次选择的两张可以同花色。响应摸牌由实际
-- 打出【闪】的同势力角色自己选择；该段是已建立的牌效果，由模式级
-- qun_cards_rule 的独立延后监听完成，不依赖袁绍仍持有本技能。
local ARCHERY = "hanjin__archery_attack"
local SUIT_MARK = "@[hanjin_luanji_suits]"

local skill = fk.CreateSkill {
  name = "hanjin__skill_qun004_1",
}
skill.hanjinImplemented = true
-- 花色记录随提供乱击的武将牌移动；换将不会刷新本回合已用花色。
skill.hanjin_exchange_marks = { SUIT_MARK }

local function usedSuits(player)
  local mark = player:getTableMark(SUIT_MARK)
  return type(mark) == "table" and mark or {}
end

local function usableHand(player)
  local used = usedSuits(player)
  return table.filter(player:getCardIds("h"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and not table.contains(used, card.suit)
  end)
end

skill:addEffect("viewas", {
  anim_type = "offensive",
  pattern = ARCHERY,
  prompt = "#hanjin__skill_qun004_1-prompt",
  card_filter = function(self, player, to_select, selected)
    if #selected >= 2 then return false end
    if not table.contains(player:getCardIds("h"), to_select) then return false end
    local card = Fk:getCardById(to_select)
    return card ~= nil and not table.contains(usedSuits(player), card.suit)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 2 then return nil end
    local card = Fk:cloneCard(ARCHERY)
    card.skillName = skill.name
    card:addSubcards(cards)
    return card
  end,
  before_use = function(self, player, use)
    if use == nil or use.card == nil then return skill.name end
    local ids = Card:getIdList(use.card)
    if #ids ~= 2 then return skill.name end
    local used = usedSuits(player)
    local suits = {}
    for _, id in ipairs(ids) do
      local card = Fk:getCardById(id)
      if card == nil or table.contains(used, card.suit) then return skill.name end
      if card.suit ~= Card.NoSuit then table.insertIfNeed(suits, card.suit) end
    end
    for _, suit in ipairs(suits) do table.insertIfNeed(used, suit) end
    player.room:setPlayerMark(player, SUIT_MARK, used)
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play and #usableHand(player) >= 2
  end,
  enabled_at_response = function() return false end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_qun004_1-prompt"] = "乱击：将两张手牌当【万箭齐发】使用（不能选择本回合此前乱击已选择过的花色）",
  ["#hanjin__qun_cards_rule_luanji_draw"] = "乱击：你可以摸一张牌",
}

return skill
