local skill = fk.CreateSkill {
  name = "qiao__skill_shu014_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local NANMAN = "savage_assault"

Fk:loadTranslationTable {
  ["qiao__skill_shu014_1"] = "祸首",
  [":qiao__skill_shu014_1"] = "锁定技，【南蛮入侵】对你无效；当【南蛮入侵】指定目标后，你成为此牌的伤害来源。",
}

-- 南蛮对自己无效（仍可成为目标，不是禁止目标）。
skill:addEffect(fk.TargetConfirmed, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and data.card ~= nil
      and data.card.trueName == NANMAN
  end,
  on_use = function(self, event, target, player, data)
    data:setNullified(player)
  end,
})

-- 南蛮指定目标后记录祸首为本次伤害来源；不改 AimData.from（使用者）。
skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target ~= player and player:hasSkill(skill.name) and data.card ~= nil
      and data.card.trueName == NANMAN and data.use ~= nil
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local current = room.logic:getCurrentEvent()
    local useEvent = current and current:findParent(GameEvent.UseCard, true)
    local use = useEvent and useEvent.data
    if use ~= nil then
      use.extra_data = use.extra_data or {}
      use.extra_data["qiao__skill_shu014_1_source"] = player
    end
  end,
})

return skill
