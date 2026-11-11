local skill = fk.CreateSkill {
  name = "hanjin__ice_slash_skill",
}

Fk:loadTranslationTable {
  ["hanjin_ice_damage_skill"] = "冰冻伤害",
  ["#hanjin_ice_damage_skill-invoke"] = "你可以防止对 %dest 造成的冰冻伤害，改为依次弃置其两张牌",
}

local slashSkill = Fk.skills["slash_skill"]

skill:addEffect("cardskill", {
  prompt = function(self, player, selected_cards)
    local card = Fk:cloneCard("hanjin__ice__slash")
    card:addSubcards(selected_cards)
    local max_num = self:getMaxTargetNum(player, card)
    if max_num > 1 then
      local num = #table.filter(Fk:currentRoom().alive_players, function(p)
        return p ~= player and not player:isProhibited(p, card)
      end)
      max_num = math.min(num, max_num)
    end
    return max_num > 1 and "#hanjin__ice_slash_skill_multi:::" .. max_num
      or "#hanjin__ice_slash_skill"
  end,
  max_phase_use_time = 1,
  target_num = 1,
  can_use = slashSkill and slashSkill.canUse or nil,
  mod_target_filter = slashSkill and slashSkill.modTargetFilter or nil,
  target_filter = slashSkill and slashSkill.targetFilter or Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    room:damage({
      from = effect.from,
      to = effect.to,
      card = effect.card,
      damage = 1,
      damageType = fk.IceDamage,
      skillName = skill.name,
    })
  end,
})

skill:addEffect(fk.DamageCaused, {
  global = true,
  priority = 0,
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and data.damageType == fk.IceDamage
      and not data.chain and not data.to:isNude() and not player.dead
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if room:askToSkillInvoke(player, {
      skill_name = "hanjin_ice_damage_skill",
      prompt = "#hanjin_ice_damage_skill-invoke::" .. data.to.id,
    }) then
      event:setCostData(self, { tos = { data.to } })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    data:preventDamage()
    for _ = 1, 2 do
      if data.to:isNude() or data.to.dead or player.dead then break end
      local card = room:askToChooseCard(player, {
        target = data.to,
        flag = "he",
        skill_name = "hanjin_ice_damage_skill",
      })
      room:throwCard(card, "hanjin_ice_damage_skill", data.to, player)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__ice_slash_skill"] = "冰杀",
  ["#hanjin__ice_slash_skill"] = "选择攻击范围内的一名角色，对其造成1点冰冻伤害",
  ["#hanjin__ice_slash_skill_multi"] = "选择攻击范围内的至多%arg名角色，对这些角色各造成1点冰冻伤害",
}

return skill
