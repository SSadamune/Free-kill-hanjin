-- Shared shell card skill. Every non-Thunder-Slash formal card uses this skill
-- until its real effect is implemented. Returning false from can_use keeps the
-- card out of active use and out of response selection; there is no hidden
-- default_card_skill fallback that could make an inert trick or basic card work.
local skill = fk.CreateSkill { name = "hanjin__inert" }

skill:addEffect("cardskill", {
  can_use = function()
    return false
  end,
  on_use = function()
  end,
})

return skill
