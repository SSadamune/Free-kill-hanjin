local skill = fk.CreateSkill {
  name = "qiao__skill_shu004_2",
  tags = { Skill.MainPlace },
}
skill.qiaoImplemented = true

local KONG = "@@qiao__skill_shu004_2_kong"

function skill.protectsFrom(player, card)
  return player:getMark(KONG) > 0 and card ~= nil
    and (card.trueName == "slash" or card.trueName == "duel")
end

Fk:loadTranslationTable {
  ["qiao__skill_shu004_2"] = "空城",
  [KONG] = "空城",
  [":qiao__skill_shu004_2"] = "主将技，当你失去手牌后，若你没有手牌，你可以令【杀】和【决斗】对你无效，直到你下次摸牌。",
  ["#qiao__skill_shu004_2-invoke"] = "空城：是否令【杀】和【决斗】对你无效，直到下次摸牌？",
}

skill:addEffect(fk.AfterCardsMove, {
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or player:getMark(KONG) > 0 then return false end
    if not player:isKongcheng() then return false end
    local lost = 0
    for _, move in ipairs(data or {}) do
      if move.from == player then
        for _, info in ipairs(move.moveInfo or {}) do
          if info.fromArea == Card.PlayerHand then lost = lost + 1 end
        end
      end
    end
    return lost > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu004_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    player.room:addPlayerMark(player, KONG, 1)
  end,
})

return skill
