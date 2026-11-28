local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__skill_han055_1", tags = { Skill.Compulsory } }
local function drawn(p)
  local n = 0
  p.room.logic:getEventsOfScope(GameEvent.MoveCards, 1, function(e)
    for _, move in ipairs(e.data) do
      if move.to == p and move.toArea == Card.PlayerHand and move.moveReason == fk.ReasonDraw then n = n + #move.moveInfo end
    end
    return n >= 3
  end, Player.HistoryTurn)
  return n
end
skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, p, data)
    return p:hasSkill(skill.name) and data.phase == Player.Finish and S.allies(p, target)
  end,
  on_use = function(self, event, target, p)
    if drawn(target) < 3 then
      p.room:loseHp(target, 1, skill.name)
      if S.present(target) then target:drawCards(2, skill.name) end
    else
      p:drawCards(1, skill.name)
      if p ~= target and S.present(p) and S.present(target) and not p:isNude() then
        S.give(p, target, p.room:askToCards(p, { min_num = 1, max_num = 1, include_equip = true, skill_name = skill.name,
          cancelable = false, prompt = "#qiao_lizhi-give::" .. target.id }), skill.name)
      end
    end
  end,
})
Fk:loadTranslationTable { ["#qiao_lizhi-give"] = "厉治：选择一张牌交给 %dest" }
return skill
