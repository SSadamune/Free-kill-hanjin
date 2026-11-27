local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local skill = fk.CreateSkill { name = "qiao__skill_shu048_1" }
local function candidates(player)
  return table.filter(player.room:getPresentPlayers(), function(p) return p:getHandcardNum() ~= p.hp end)
end
skill:addEffect(fk.TurnEnd, {
  can_trigger = function(self, event, target, p)
    return target == p and p:hasSkill(skill.name) and #candidates(p) > 0
  end,
  on_cost = function(self, event, target, p)
    local to = S.pick(p.room, p, candidates(p), skill.name, true)[1]
    event:setCostData(self, { to = to })
    return to ~= nil
  end,
  on_use = function(self, event, target, p)
    local room, to = p.room, event:getCostData(self).to
    if not S.present(to) then return end
    local legal = table.find(to:getCardIds("h"), function(id) return not to:prohibitDiscard(id) end)
    if legal and room:askToChoice(p, { choices = { "draw1", "discard" }, skill_name = skill.name }) == "discard" then
      room:askToDiscard(to, { min_num = 1, max_num = 1, include_equip = false, skill_name = skill.name, cancelable = false })
    else
      to:drawCards(1, skill.name)
    end
    if not S.present(to) or not S.present(p) or to:getHandcardNum() ~= to.hp then return end
    p:drawCards(1, skill.name)
    if p ~= to and S.present(p) and S.present(to) and not p:isNude() then
      S.give(room, p, to, room:askToCards(p, { min_num = 1, max_num = 1, include_equip = true, skill_name = skill.name, cancelable = true }), skill.name)
    end
  end,
})
return skill
