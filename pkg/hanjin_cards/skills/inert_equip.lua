-- Shared shell equipment skill. It is used both as the card's use skill and as
-- its equip_skill, so an unimplemented lord equipment can never be equipped and
-- silently contribute attack range, mount distance or treasure behaviour.
local skill = fk.CreateSkill { name = "hanjin__inert_equip" }

skill:addEffect("cardskill", {
  can_use = function()
    return false
  end,
  on_use = function()
  end,
})

return skill
