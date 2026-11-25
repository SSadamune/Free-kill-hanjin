local Records = require "packages.qiao.pkg.qiao_mode.rules.pindian_records"
local skill = fk.CreateSkill { name = "#qiao_pindian_record_rule" }

skill:addEffect(fk.PindianFinished, {
  can_refresh = function(self, event, target, player, data)
    return target == player and data.from == player and data.fromCard ~= nil and data.results ~= nil
  end,
  on_refresh = function(self, event, target, player, data)
    Records.publish(player.room, data)
  end,
})

return skill
