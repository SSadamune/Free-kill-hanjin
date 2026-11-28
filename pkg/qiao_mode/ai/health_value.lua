local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"
local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"

local M = {}

M.pointsPerHp = 6
local damageBias = { aggressive = 1, conservative = -0.5 }
local recoveryBias = { aggressive = -0.5, conservative = 1, supportive = 1 }

function M.baseUnit(ai)
  return M.pointsPerHp + (BattleRoyal.inBattleRoyal(ai.room, ai.player) and 4 or 0)
end

function M.damage(ai, amount)
  return amount * (M.baseUnit(ai) + (damageBias[ai.personality] or 0))
end

function M.recoveryUnit(ai)
  return M.baseUnit(ai) + (recoveryBias[ai.personality] or 0)
end

function M.canRecover(player)
  return player and player:isAlive() and not player:isRemoved() and player:isWounded()
    and player:getMark("@@command5_effect-turn") == 0 and player:getMark(Quan.WUDANG_PENDING_MARK) == 0
end

function M.recovery(ai, player, amount)
  if not M.canRecover(player) then return 0 end
  return M.recoveryUnit(ai) * math.min(amount, player:getLostHp())
end

-- Shield absorbs damage before the dying check. Later HP loss bypasses shield.
function M.harm(ai, player, damage, hpLoss)
  local hpLost = math.max(0, damage - player.shield) + (hpLoss or 0)
  local dying = hpLost > 0 and hpLost >= player.hp
  return M.damage(ai, damage + (hpLoss or 0)) + (dying and 4 or 0), dying
end

return M
