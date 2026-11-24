local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_xiliang_jingqi",
}
skill.qiaoImplemented = true

local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local function triggerEach(self, event, target, player, data)
  if #R.instancesForSkill(player, skill.name) == 0 then
    return self:doCost(event, target, player, data)
  end
  return R.triggerEach(self, event, target, player, data)
end

Fk:loadTranslationTable {
  ["qiao__retinue_skill_xiliang_jingqi"] = "西凉精骑",
  [":qiao__retinue_skill_xiliang_jingqi"] = "结束阶段，你可以使用一张【杀】；当你使用【杀】指定攻击范围内没有你的角色为目标后，你可以令其弃置一张牌。",
  ["#qiao__retinue_skill_xiliang_jingqi-use"] = "西凉精骑：选择一张【杀】及其目标",
  ["#qiao__retinue_skill_xiliang_jingqi-discard"] = "西凉精骑：令%src弃置一张牌",
}

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  on_trigger = triggerEach,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Finish
  end,
  on_cost = function(self, event, target, player, data)
    local use = C.askToUseCard(player.room, player, {
      names = { "qiao__slash", "qiao__fire__slash", "qiao__thunder__slash", "qiao__ice__slash" },
      pattern = "slash",
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_xiliang_jingqi-use",
      cancelable = true,
      extra_data = { qiao_trigger_use = true },
    })
    if use == nil or use.card == nil then return false end
    event:setCostData(self, { use = use })
    return true
  end,
  on_use = function(self, event, target, player, data)
    C.useCard(player.room, player, event:getCostData(self).use)
  end,
})

skill:addEffect(fk.TargetSpecified, {
  on_trigger = triggerEach,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "slash"
      and data.to ~= nil and data.to ~= player
      and not data.to:inMyAttackRange(player)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_xiliang_jingqi-discard:" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local to = data.to
    if to == nil or to.dead or #to:getCardIds("he") == 0 then return end
    player.room:askToDiscard(to, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_xiliang_jingqi-discard:" .. player.id,
      cancelable = false,
    })
  end,
})

return skill
