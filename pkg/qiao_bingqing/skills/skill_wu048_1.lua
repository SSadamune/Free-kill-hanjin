local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_wu048_1" }
skill:addEffect("active", {
  card_num = 1, target_num = 1, max_phase_use_time = 1,
  card_filter = function(self, p, id, selected) return #selected == 0 and table.contains(S.discardable(p), id) end,
  target_filter = function(self, p, to, selected) return #selected == 0 and to ~= p and S.present(to) and not to:isNude() end,
  on_use = function(self, room, effect)
    local p, to, first = effect.from, effect.tos[1], effect.cards[1]
    local second = room:askToChooseCard(p, { target = to, flag = "he", skill_name = skill.name })
    local before = to:inMyAttackRange(p)
    room:moveCards(
      { ids = { first }, from = p, toArea = Card.DiscardPile, moveReason = fk.ReasonDiscard, proposer = p, skillName = skill.name },
      { ids = { second }, from = to, toArea = Card.DiscardPile, moveReason = fk.ReasonDiscard, proposer = p, skillName = skill.name })
    if not S.present(p) or (Fk:getCardById(first).trueName ~= "jink" and Fk:getCardById(second).trueName ~= "jink"
      and not (before and not to:inMyAttackRange(p))) then return end
    local available = {}
    room.logic:getEventsOfScope(GameEvent.MoveCards, 1, function(e)
      for _, m in ipairs(e.data) do
        if m.from == to then
          for _, info in ipairs(m.moveInfo) do
            if (info.fromArea == Card.PlayerHand or info.fromArea == Card.PlayerEquip) and room:getCardArea(info.cardId) == Card.DiscardPile then
              table.insertIfNeed(available, info.cardId)
            end
          end
        end
      end
      return false
    end, Player.HistoryTurn)
    if #available > 0 then
      local chosen = room:askToChooseCard(p, { target = p, flag = { card_data = {{ "$DiscardPile", available }} }, skill_name = skill.name })
      if table.contains(available, chosen) and room:getCardArea(chosen) == Card.DiscardPile then room:obtainCard(p, chosen, true, fk.ReasonPrey, p, skill.name) end
    end
  end,
})
return skill
