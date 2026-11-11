local M = {}

M.key = "hanjin_wolves"

function M.enabled(room)
  return room:getSettings(M.key) == true
end

function M.apply(room)
  local enabled = M.enabled(room)
  -- The upstream entry point reads this setting when entering battle royal.
  -- Normalize it per room so the optional variant has one authoritative switch.
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
