local skill = fk.CreateSkill { name = "#hanjin_session_history" }
local Session = require "packages.hanjin.pkg.hanjin_mode.rules.session"

-- Global only to discard stale HanJin metadata when another mode starts in the room.
skill:addEffect(fk.GamePrepared, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player == player.room.players[1]
  end,
  on_refresh = function(self, event, target, player)
    Session.clearForeignGame(player.room)
  end,
})
skill:addEffect(fk.GameFinished, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player == player.room.players[1] and player.room:getSettings("gameMode") == Session.mode
  end,
  on_refresh = function(self, event, target, player, data)
    Session.finish(player.room, data.players)
  end,
})
return skill
