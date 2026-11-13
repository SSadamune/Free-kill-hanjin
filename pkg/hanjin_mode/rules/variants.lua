local M = {}

M.key = "hanjin_wolves"

function M.enabled(room)
  return room:getSettings(M.key) == true
end

function M.apply(room)
  local enabled = M.enabled(room)
  -- The upstream entry point reads this setting when deciding whether to add
  -- the historical-event skill. 汉晋鏖战的桃用途统一由 only_as 来源提供，
  -- 因此该设置只影响事件/奇珍等附加机制，不再影响桃的转换目标。
  room.settings._mode = table.clone(room.settings._mode or {})
  room.settings._mode.old_battle_royal = not enabled
  room.settings.old_battle_royal = not enabled
  if not enabled then
    -- The only Damaged effect of heg_rule is the rare-treasure capture rule.
    -- Filter the room's registration, preserving the shared upstream skills.
    room.logic.skill_table[fk.Damaged] = table.filter(room.logic.skill_table[fk.Damaged] or {}, function(skill)
      return skill:getSkeleton().name ~= "heg_rule"
    end)
  end
end

return M
