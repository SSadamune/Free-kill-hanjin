local C = require "packages.hanjin.pkg.hanjin_mode.rules.commander_retinue"
local H = require "packages.hegemony.util"

-- 模式级公共规则。related_skills 保证上游国战规则仍然加载。
local skill = fk.CreateSkill {
  name = C.RULE_SKILL,
  related_skills = { "heg_rule", "#hanjin_exchange_history" },
}

skill:addEffect(fk.GameStart, {
  priority = 100,
  can_trigger = function(self, event, target, player)
    return player.seat == 1
  end,
  on_trigger = function(self, event, target, player)
    local room = player.room
    C.reset(room)
    for _, p in ipairs(room.players) do C.grantAbility(p) end
    C.refreshAvailability(room)
  end,
})

skill:addEffect(fk.GeneralShown, {
  global = true,
  priority = 0,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    C.onGeneralShown(player.room, player, data)
  end,
})

skill:addEffect(fk.GeneralHidden, {
  global = true,
  priority = 0,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    C.onGeneralHidden(player.room, player, data)
  end,
})

skill:addEffect(fk.AfterPropertyChange, {
  global = true,
  priority = -10,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    C.onAfterPropertyChange(player.room, player, data)
  end,
})

skill:addEffect(H.GeneralRemoved, {
  global = true,
  priority = -10,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    C.onGeneralRemoved(player.room, player, data)
  end,
})

skill:addEffect(fk.Death, {
  global = true,
  priority = -10,
  can_trigger = function(self, event, target, player, data)
    return target == player
  end,
  on_trigger = function(self, event, target, player, data)
    C.onDeath(player.room, player)
  end,
})

Fk:loadTranslationTable {
  [C.RULE_SKILL] = "汉晋统领规则",
}

return skill
