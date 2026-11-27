local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_han055_2", tags = { Skill.Compulsory } }
skill:addEffect(fk.EnterDying, {
  can_trigger = function(self, event, target, p)
    return p == target and p:hasSkill(skill.name) and not p:isNude() and #p.room:getPresentPlayers() > 1
  end,
  on_use = function(self, event, target, p)
    local ids = p:getCardIds("he")
    local n = math.min(3, #ids)
    local targets = table.filter(p.room:getPresentPlayers(), function(to) return to ~= p end)
    local result = p.room:askToYiji(p, { cards = ids, targets = targets, min_num = n, max_num = n, skill_name = skill.name, skip = true })
    local moves, total = {}, 0
    for _, to in ipairs(targets) do
      local cards = result[to.id] or {}
      if #cards > 0 then
        total = total + #cards
        table.insert(moves, { from = p, to = to, ids = cards, toArea = Card.PlayerHand, moveReason = fk.ReasonGive, skillName = skill.name, proposer = p })
      end
    end
    if #moves > 0 then p.room:moveCards(table.unpack(moves)) end
    if total == 3 and p:getMark("qiao_zhouyou-turn") == 0 then
      p.room:setPlayerMark(p, "qiao_zhouyou-turn", 1)
      if not p.dead then p.room:recover { who = p, num = 1, recoverBy = p, skillName = skill.name } end
    end
  end,
})
return skill
