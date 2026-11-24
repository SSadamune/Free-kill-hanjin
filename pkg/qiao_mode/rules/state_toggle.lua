local Invoke = require "packages.qiao.pkg.qiao_generals.util.invoke_targets"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local M = {}

-- 对可选的状态切换，选人即确认。已经有目标的效果可直接切换状态。
function M.ask(player, params)
  local room = player.room
  local targets = params.targets and table.filter(params.targets, RemovedTargets.isPresent)
    or room:getPresentPlayers()
  local minTargets = params.min_num or 1
  if #targets < minTargets then return {} end
  return Invoke.ask(room, player, {
    targets = targets,
    min_num = minTargets,
    max_num = math.min(params.max_num, #targets),
    skill_name = params.skill_name,
    prompt = params.prompt,
  })
end

function M.chain(target)
  if RemovedTargets.isPresent(target) then target:setChainState(not target.chained) end
end

function M.stack(target)
  if RemovedTargets.isPresent(target) then target:turnOver() end
end

return M
