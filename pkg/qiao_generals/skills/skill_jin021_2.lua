-- JIN021 卫瓘 · 追诛
-- 轮次技，当一名角色受到致命伤害时，你可以对其发起“军令”。
-- 若其执行，你可以防止此伤害；若其不执行，此伤害翻倍。
local Junling = require "packages.qiao.pkg.qiao_mode.rules.junling"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin021_2",
}
skill.qiaoImplemented = true

skill:addEffect(fk.DamageInflicted, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target == data.to
      and RemovedTargets.isPresent(target)
      and RemovedTargets.isPresent(player)
      and player:hasSkill(skill.name)
      and player:usedSkillTimes(skill.name, Player.HistoryRound) == 0
      and not data.prevented and data.damage >= target.hp
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin021_2-invoke::" .. target.id .. ":" .. data.damage,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if player.dead or not RemovedTargets.isPresent(target) then return end
    local executed = Junling.ask(player, target, skill.name)
    if target.dead then
      data:preventDamage()
      return
    end
    if executed then
      if RemovedTargets.isPresent(player) and room:askToSkillInvoke(player, {
        skill_name = skill.name,
        prompt = "#qiao__skill_jin021_2-prevent::" .. target.id .. ":" .. data.damage,
      }) then
        data:preventDamage()
      end
    else
      data.damage = data.damage * 2
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "追诛",
  [":" .. skill.name] = "轮次技，当一名角色受到致命伤害时，你可以对其发起“军令”。若其执行，你可以防止此伤害；若其不执行，此伤害翻倍。",
  ["#qiao__skill_jin021_2-invoke"] = "追诛：是否对受到 %arg 点致命伤害的 %dest 发起“军令”？",
  ["#qiao__skill_jin021_2-prevent"] = "追诛：%dest 已执行军令，是否防止此 %arg 点伤害？",
}

return skill
