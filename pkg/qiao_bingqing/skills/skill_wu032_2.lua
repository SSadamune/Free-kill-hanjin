local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local skill = fk.CreateSkill { name = "qiao__skill_wu032_2" }
skill:addEffect(fk.AfterCardsMove, {
  can_trigger = function(self, event, target, player, moves)
    return player:hasSkill(skill.name) and not player:isKongcheng()
      and player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
      and table.find(moves, function(m)
        return m.from == player and m.moveReason == fk.ReasonDiscard and table.find(m.moveInfo, function(i)
          return i.fromArea == Card.PlayerHand or i.fromArea == Card.PlayerEquip
        end)
      end)
  end,
  on_use = function(self, event, target, player)
    local hand = player:getCardIds("h")
    if #hand == 0 then return end
    player:showCards(hand)
    local color = Fk:getCardById(hand[1]).color
    if color == Card.NoColor or not S.present(player) or not table.every(hand, function(id)
      return Fk:getCardById(id).color == color
    end) then return end
    local room = player.room
    local tos = S.pick(room, player, room:getPresentPlayers(), skill.name, false, #hand)
    room:sortByAction(tos)
    for _, p in ipairs(tos) do if S.present(p) then p:drawCards(1, skill.name) end end
  end,
})
return skill
