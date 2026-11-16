-- WU005 周瑜 · 英姿
--
-- 规则基线：rules/standard-generals.md 吴区 WU005。
-- 锁定技：摸牌阶段多摸一张；手牌上限等于体力上限（覆盖基础的手牌上限）。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu005_1",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

skill:addEffect(fk.DrawNCards, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
  end,
  on_use = function(self, event, target, player, data)
    data.n = data.n + 1
  end,
})

skill:addEffect("maxcards", {
  fixed_func = function(self, player)
    if player:hasSkill(skill.name) then
      return player.maxHp
    end
  end,
})

return skill
