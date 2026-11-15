local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_xiliang_jingqi",
}
skill.hanjinImplemented = true

local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_xiliang_jingqi"] = "西凉精骑",
  [":hanjin__retinue_skill_xiliang_jingqi"] = "结束阶段，你可以使用一张【杀】；当你使用【杀】指定攻击范围内没有你的角色为目标后，你可以令其弃置一张牌。",
  ["#hanjin__retinue_skill_xiliang_jingqi-use"] = "西凉精骑：是否使用一张【杀】？",
  ["#hanjin__retinue_skill_xiliang_jingqi-discard"] = "西凉精骑：令%src弃置一张牌",
}

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Finish
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_xiliang_jingqi-use",
    })
  end,
  on_use = function(self, event, target, player, data)
    local use = C.askToUseCard(player.room, player, {
      names = { "hanjin__slash", "hanjin__fire__slash", "hanjin__thunder__slash", "hanjin__ice__slash" },
      pattern = "slash",
      skill_name = skill.name,
      cancelable = true,
      extra_data = { bypass_times = true, extraUse = true },
    })
    if use == nil or use.card == nil then return end
    use.extra_data = use.extra_data or {}
    use.extra_data.bypass_times = true
    use.extra_data.extraUse = true
    use.extraUse = true
    C.useCard(player.room, player, use)
  end,
})

skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "slash"
      and data.to ~= nil and data.to ~= player
      and not data.to:inMyAttackRange(player)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_xiliang_jingqi-discard:" .. data.to.id,
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
      prompt = "#hanjin__retinue_skill_xiliang_jingqi-discard:" .. player.id,
      cancelable = false,
    })
  end,
})

return skill
