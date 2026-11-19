local Flags = require "packages.qiao.pkg.qiao_mode.rules.lord_flag_display"

local skill = fk.CreateSkill { name = "qiao__lord_flag_display" }

local refresh = {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player or (event == fk.GameStart and player.seat == 1)
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    for _, holder in ipairs(target and { target } or room.players) do
      for name in pairs(Flags.flags) do Flags.refresh(holder, name) end
    end
  end,
}

for _, event in ipairs({
  fk.GameStart, fk.EventAcquireSkill, fk.EventLoseSkill, fk.Death,
  fk.GeneralRevealed, fk.GeneralHidden, fk.GeneralShown,
}) do
  skill:addEffect(event, refresh)
end

return skill
