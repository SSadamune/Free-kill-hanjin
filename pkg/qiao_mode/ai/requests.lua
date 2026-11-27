local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"

local M = {}

function M.reply(ai)
  if not ai:okButtonEnabled() then return "" end
  local name = ai.handler.skill_name
  local skill = name and Fk.skills[name]
  return {
    card = { skill = name, subcards = ai:getSelectedCards() },
    targets = table.map(ai:getSelectedTargets(), Util.IdMapper),
    interaction_data = skill and skill.interaction and skill.interaction.data,
  }
end

function M.targets(ai, score, limit)
  for _ = #ai:getSelectedTargets() + 1, limit or 1 do
    local target = Cards.bestTarget(ai, score)
    if not target then break end
    ai:selectTarget(target, true)
  end
  if table.every(ai:getSelectedTargets(), function(target) return score(target) ~= nil end) then
    return M.reply(ai)
  end
  return ""
end

return M
