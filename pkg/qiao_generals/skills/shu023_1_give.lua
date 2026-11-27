-- SHU023 王平 · 将略 辅助分牌骨架（选择一张未分配牌与一名未分配同势力队友）
local skill = fk.CreateSkill {
  name = "#qiao__skill_shu023_1_give",
}

skill:addEffect("active", {
  can_use = Util.FalseFunc,
  card_num = 1,
  target_num = 1,
  card_filter = function(self, player, to_select, selected)
    if #selected > 0 then return false end
    local excluded = self.qiao_excluded_cards or {}
    return not table.contains(excluded, to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    if #selected > 0 then return false end
    local validTargets = self.qiao_valid_targets or {}
    return table.contains(validTargets, to_select.id)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "将略",
}

return skill
