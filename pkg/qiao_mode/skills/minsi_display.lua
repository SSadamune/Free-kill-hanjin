local Minsi = require "packages.qiao.pkg.qiao_generals.util.minsi"

local skill = fk.CreateSkill { name = "#qiao_minsi_display" }

-- Track the marked cards for ordinary and extra Minsi uses independently of
-- the active skill, whose hidden-general button must not offer prelighting.
skill:addEffect(fk.AfterCardsMove, {
  can_refresh = function(self, event, target, player)
    return player == player.room.players[1]
  end,
  on_refresh = function(self, event, target, player, data)
    Minsi.refreshDisplay(player.room, data)
  end,
})

return skill
