local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

-- The exchange rule needs to know which general card produced each skill use,
-- because the engine only keeps an aggregate per character and skill name.
-- This hidden mode skill mirrors every use into the per-card ledger and clears
-- the same scopes as Room:clearHistory.  It runs only in qiao_heg_mode.
local skill = fk.CreateSkill { name = "#qiao_exchange_history" }

local function inQiao(player)
  local room = player.room
  return room ~= nil and Modes.inRoom(room)
end

skill:addEffect(fk.SkillEffect, {
  global = true,
  priority = 1000,
  can_trigger = function(self, event, target, player, data)
    return target == player and inQiao(player)
  end,
  on_trigger = function(self, event, target, player, data)
    Exchange.recordSkillEffect(player, data)
  end,
})

for _, spec in ipairs {
  { fk.EventPhaseStart, Player.HistoryPhase },
  { fk.PreTurnStart, Player.HistoryTurn },
  { fk.RoundStart, Player.HistoryRound },
} do
  local event, scope = spec[1], spec[2]
  skill:addEffect(event, {
    global = true,
    priority = 1000,
    can_trigger = function(self, old_event, target, player, data)
      return target == player and inQiao(player)
    end,
    on_trigger = function(self, old_event, target, player, data)
      Exchange.clearLedgerScope(player.room, scope)
    end,
  })
end

return skill
