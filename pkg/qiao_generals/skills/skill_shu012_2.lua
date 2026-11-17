-- SHU012 姜维 · 天覆
-- 主将阵法技：当前回合角色实际位于姜维队列时，全场攻击范围+2。
-- 具体数值由独立 AttackRange 静态规则动态读取队列/明置/存活关系。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu012_2",
  tags = { Skill.MainPlace },
}
skill.qiaoImplemented = true

local RULE = "qiao__skill_shu012_2_rule"

local function ensureRule(room)
  local rule = Fk.skills[RULE]
  if rule ~= nil and not room:hasSkill(RULE) then room:addSkill(rule) end
end

skill:addEffect(fk.GameStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player ~= nil and player:hasSkill(skill.name)
  end,
  on_refresh = function(self, event, target, player)
    ensureRule(player.room)
  end,
})

skill:addEffect(fk.EventAcquireSkill, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and player:hasSkill(skill.name)
  end,
  on_refresh = function(self, event, target, player)
    ensureRule(player.room)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu012_2"] = "天覆",
  [":qiao__skill_shu012_2"] = "主将技，阵法技，你队列的角色的回合内，所有角色的攻击范围+2。",
}

return skill
