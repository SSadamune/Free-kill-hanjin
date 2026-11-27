-- 权包普通翼从 · 无当飞军（王平统领【杀】）
-- 当你使用【杀】造成伤害时，你可以防止受伤角色本回合下一次回复体力，
-- 当前回合结束时，若其未触发此效果，其弃置每区域各一张牌。
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_wudang_feijun",
}
skill.qiaoImplemented = true

local function triggerEach(self, event, target, player, data)
  if #R.instancesForSkill(player, skill.name) == 0 then
    return self:doCost(event, target, player, data)
  end
  return R.triggerEach(self, event, target, player, data)
end

skill:addEffect(fk.DamageCaused, {
  anim_type = "offensive",
  on_trigger = triggerEach,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.from == player and data.card ~= nil and data.card.trueName == "slash"
      and data.to ~= nil and RemovedTargets.isPresent(data.to)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_wudang_feijun-invoke::" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    if data.to ~= nil and RemovedTargets.isPresent(data.to) then
      Quan.addWudangEffect(player.room, data.to)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "无当飞军",
  [":" .. skill.name] = "当你使用【杀】造成伤害时，你可以防止受伤角色本回合下一次回复体力，当前回合结束时，若其未触发此效果，其弃置每区域各一张牌。",
  ["#qiao__retinue_skill_wudang_feijun-invoke"] = "无当飞军：是否防止 %dest 本回合下一次回复体力？",
}

return skill
