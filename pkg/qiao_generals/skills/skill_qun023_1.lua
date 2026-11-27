-- QUN023 张绣 · 从谏
-- 锁定技，当其他角色于你回合内造成伤害时，或你于回合外造成伤害时，此伤害+1。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun023_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

skill:addEffect(fk.DamageCaused, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not RemovedTargets.isPresent(player) or not player:hasSkill(skill.name) then return false end
    if data.from == nil or target ~= data.from then return false end
    local inMyTurn = player.room.current == player
    return (inMyTurn and data.from ~= player) or (not inMyTurn and data.from == player)
  end,
  on_use = function(self, event, target, player, data)
    data.damage = data.damage + 1
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "从谏",
  [":" .. skill.name] = "锁定技，当其他角色于你回合内造成伤害时，或你于回合外造成伤害时，此伤害+1。",
}

return skill
