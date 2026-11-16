-- SHU010 庞统 · 连环（重铸辅助技能）
--
-- 引擎同一技能只能有一个 active/viewas 效果，连环的使用入口必须是 ViewAs，
-- 因此重铸作为独立辅助技能随连环授予。它不进入武将数据或选将技能列表，
-- 只由 hanjin__skill_shu010_1 在获得/失去时挂接与移除。
-- 独立文件保证客户端与服务端都在加载期注册同一技能。
local skill = fk.CreateSkill {
  name = "hanjin__skill_shu010_1_recast",
}

local function clubHandCards(player)
  return table.filter(player:getCardIds("h"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and card.suit == Card.Club
  end)
end

skill:addEffect("active", {
  anim_type = "drawcard",
  prompt = "#hanjin__skill_shu010_1-recast_prompt",
  min_card_num = 1,
  max_card_num = 1,
  include_equip = false,
  target_num = 0,
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    local card = Fk:getCardById(to_select)
    return card ~= nil and card.suit == Card.Club
      and table.contains(player:getCardIds("h"), to_select)
  end,
  can_use = function(self, player)
    return player.phase == Player.Play
      and player:hasShownSkill("hanjin__skill_shu010_1")
      and #clubHandCards(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local cards = effect.cards or {}
    if player == nil or player.dead or #cards ~= 1 then return end
    local card = Fk:getCardById(cards[1])
    if card == nil or card.suit ~= Card.Club then return end
    if not table.contains(player:getCardIds("h"), cards[1]) then return end
    room:recastCard({ cards[1] }, player, "hanjin__skill_shu010_1")
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_shu010_1_recast"] = "连环",
  [":hanjin__skill_shu010_1_recast"] = "你可以将一张梅花手牌当【铁索连环】使用或重铸。",
  ["#hanjin__skill_shu010_1-recast_prompt"] = "连环：重铸一张梅花手牌",
}

return skill
