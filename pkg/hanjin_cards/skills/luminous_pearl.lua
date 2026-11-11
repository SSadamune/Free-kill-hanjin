local skill = fk.CreateSkill {
  name = "hanjin__luminous_pearl_skill",
  attached_equip = "hanjin__luminous_pearl",
}

skill:addEffect("active", {
  can_use = function(self, player)
    return player:usedSkillTimes(self.name, Player.HistoryPhase) == 0
  end,
  target_num = 0,
  min_card_num = 1,
  max_card_num = function(self, player) return player.maxHp end,
  card_filter = function(self, player, to_select, selected)
    return #selected < player.maxHp and not player:prohibitDiscard(Fk:getCardById(to_select))
      and Fk:getCardById(to_select).name ~= "hanjin__luminous_pearl"
  end,
  on_use = function(self, room, effect)
    local from = effect.from
    room:notifySkillInvoked(from, self.name, "drawcard")
    room:throwCard(effect.cards, self.name, from, from)
    if not from.dead then from:drawCards(#effect.cards, self.name) end
  end,
})

local function canRefresh(self, event, target, player, data)
  local usedSkill = data.skill
  return player == target
    and (usedSkill == Fk.skills["hs__zhiheng"] or usedSkill == Fk.skills["lord__zhiheng"]
      or usedSkill == Fk.skills["wk_heg__zhiheng"])
    and table.find(player:getEquipments(Card.SubtypeTreasure), function(cid)
      return Fk:getCardById(cid).name == self.attached_equip
    end)
end

skill:addEffect(fk.EventAcquireSkill, {
  can_refresh = canRefresh,
  on_refresh = function(self, event, target, player)
    player.room:handleAddLoseSkills(player, "-hanjin__luminous_pearl_skill", nil, false, true)
  end,
})

skill:addEffect(fk.EventLoseSkill, {
  can_refresh = canRefresh,
  on_refresh = function(self, event, target, player)
    player.room:handleAddLoseSkills(player, "hanjin__luminous_pearl_skill", nil, false, true)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__luminous_pearl_skill"] = "制衡",
  [":hanjin__luminous_pearl_skill"] = "出牌阶段限一次，你可弃置至多X张牌（X为你的体力上限），然后你摸等量的牌。",
}

return skill
