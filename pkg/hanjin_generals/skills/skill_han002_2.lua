-- HAN002 刘辩 · 毒逝
--
-- 锁定技：其他角色不能将【桃】指定给你；你死亡时，死亡来源获得此技能。
-- 禁止通过 ProhibitSkill 的目标合法性入口实现，避免只取消已宣告的目标。
-- 死亡时用 global 触发绕过死亡角色的 hasSkill 门；来源暗置也照常登记。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han002_2",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

skill:addEffect("prohibit", {
  is_prohibited = function(self, from, to, card)
    return from ~= nil and from ~= to and card ~= nil
      and card.trueName == "peach" and to:hasSkill(skill.name)
  end,
})

skill:addEffect(fk.Death, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name, false, true)
      and data.killer ~= nil and data.killer ~= player
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    player.room:handleAddLoseSkills(data.killer, skill.name, nil, false, true)
  end,
})

return skill
