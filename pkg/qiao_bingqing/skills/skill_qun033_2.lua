local S = require "packages.qiao.pkg.qiao_bingqing.shi"
local skill = fk.CreateSkill { name = "qiao__skill_qun033_2", tags = { Skill.Limited } }
skill:addEffect("active", {
  card_num = 0, target_num = 1,
  can_use = function(self, p) return #p:getCardIds("e") > 0 and p:usedSkillTimes(skill.name, Player.HistoryGame) == 0 end,
  target_filter = function(self, p, to, selected) return #selected == 0 and to ~= p and S.present(to) end,
  on_use = function(self, room, effect)
    local p, to = effect.from, effect.tos[1]
    local cards = p:getCardIds("e")
    if #cards == 0 then return end
    S.give(room, p, to, cards, skill.name)
    if S.present(p) and p:isWounded() then room:recover { who = p, num = #cards, recoverBy = p, skillName = skill.name } end
    if not S.present(to) then return end
    local candidates = table.filter(room:getPresentPlayers(), function(victim) return to:inMyAttackRange(victim) end)
    local victims = S.pick(room, to, candidates, skill.name, false, #cards)
    room:sortByAction(victims)
    for _, victim in ipairs(victims) do
      if S.present(victim) and S.present(to) then room:damage { from = to, to = victim, damage = 1, skillName = skill.name } end
    end
  end,
})
return skill
