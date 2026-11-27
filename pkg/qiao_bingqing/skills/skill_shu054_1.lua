local skill = fk.CreateSkill { name = "qiao__skill_shu054_1" }
local used = "qiao_dianjun-turn"
skill.qiao_exchange_marks = { used }
skill:addEffect("viewas", {
  pattern = "slash", handly_pile = false,
  card_filter = function(self, p, id, selected) return #selected == 0 and table.contains(p:getCardIds("h"), id) end,
  view_as = function(self, p, ids)
    if #ids ~= 1 then return end
    local card = Fk:cloneCard("qiao__slash")
    card:addSubcard(ids[1])
    card.skillName = skill.name
    return card
  end,
  enabled_at_play = function(self, p) return p:getMark(used) == 0 end,
  enabled_at_response = function(self, p, response) return not response and p:getMark(used) == 0 end,
  before_use = function(self, p)
    if p:getMark(used) ~= 0 then return skill.name end
    p.room:setPlayerMark(p, used, 1)
    p.room:loseHp(p, 1, skill.name)
    if p.dead then return skill.name end
  end,
})
skill:addEffect(fk.TurnEnd, {
  can_trigger = function(self, event, target, p) return target == p and p:hasSkill(skill.name) end,
  on_cost = function(self, event, target, p) return p.room:askToSkillInvoke(p, { skill_name = skill.name }) end,
  on_use = function(self, event, target, p) p:gainAnExtraPhase(Player.Play, skill.name, false) end,
})
return skill
