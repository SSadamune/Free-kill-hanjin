-- WEI001 曹操 · 奸雄
--
-- 当你受到伤害后，你可以摸一张牌，然后你可以弃置一张牌，获得造成此伤害的牌。
-- 先摸后弃：摸一张是发动后的固定步骤；获得伤害牌是第二个可选项，须实际弃足
-- 一张合法牌（手牌或装备区，不含判定区），且伤害牌对应的实体牌仍在处理区。
-- 没有可弃的牌时只保留摸牌，不能零弃牌取得伤害牌；伤害牌已离开处理区
-- （例如被移走或本身没有实体牌）时不能再获得。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei001_1",
}
skill.hanjinImplemented = true

skill:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei001_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    player:drawCards(1, skill.name)
    if player.dead or data.card == nil then return end
    if room:getCardArea(data.card) ~= Card.Processing then return end
    if #player:getCardIds("he") == 0 then return end

    -- 第二次“可以”：足额弃一张牌是取得伤害牌的可选消耗。
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei001_1-discard",
      cancelable = true,
    })
    if #cards == 0 or player.dead then return end
    if room:getCardArea(data.card) ~= Card.Processing then return end
    room:obtainCard(player, data.card, true, fk.ReasonJustMove, player, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wei001_1-invoke"] = "奸雄：你可以摸一张牌，然后弃置一张牌获得造成此伤害的牌",
  ["#hanjin__skill_wei001_1-discard"] = "奸雄：弃置一张牌，获得造成此伤害的牌",
}

return skill
