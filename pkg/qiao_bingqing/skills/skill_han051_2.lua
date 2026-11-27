local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local skill = fk.CreateSkill { name = "qiao__skill_han051_2" }
local function partners(player, moves)
  local found = {}
  for _, m in ipairs(moves) do
    local other
    if m.toArea == Card.PlayerHand and m.from and m.to and m.from ~= m.to
      and table.find(m.moveInfo, function(i) return i.fromArea == Card.PlayerHand or i.fromArea == Card.PlayerEquip end) then
      if m.from == player and m.moveReason == fk.ReasonGive then other = m.to
      elseif m.to == player then other = m.from end
    end
    if S.present(other) and player:getHandcardNum() > other:getHandcardNum() then table.insertIfNeed(found, other) end
  end
  return found
end
skill:addEffect(fk.AfterCardsMove, {
  can_trigger = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and player:usedSkillTimes(skill.name, Player.HistoryTurn) == 0 and #partners(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local to = S.pick(player.room, player, partners(player, data), skill.name, true)[1]
    event:setCostData(self, { to = to })
    return to ~= nil
  end,
  on_use = function(self, event, target, player)
    local targets = { player, event:getCostData(self).to }
    player.room:sortByAction(targets)
    for _, to in ipairs(targets) do if S.present(to) then to:drawCards(1, skill.name) end end
  end,
})
return skill
