-- JIN024 贾南风 · 伤败
-- 当你对其他角色造成伤害后，你可以令其弃置每个区域各一张牌。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin024_1",
}
skill.qiaoImplemented = true

skill:addEffect(fk.Damage, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and data.from == player
      and RemovedTargets.isPresent(player) and player:hasSkill(skill.name)
      and data.to ~= nil and data.to ~= player
      and RemovedTargets.isPresent(data.to)
      and Quan.hasDiscardableInAnyArea(data.to)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_jin024_1-invoke::" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    if data.to ~= nil and RemovedTargets.isPresent(data.to) then
      Quan.discardOnePerArea(player.room, data.to, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "伤败",
  [":" .. skill.name] = "当你对其他角色造成伤害后，你可以令其弃置每个区域各一张牌。",
  ["#qiao__skill_jin024_1-invoke"] = "伤败：是否令 %dest 弃置每个区域各一张牌？",
}

return skill
