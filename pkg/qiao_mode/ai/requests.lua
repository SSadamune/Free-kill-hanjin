local Cards = require "packages.qiao.pkg.qiao_mode.ai.cards"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local M = {}

function M.context(ai, name)
  local frame = Selection.currentCost(ai.player)
  if frame and frame.skill:getSkeleton().name == name then return frame end
  local event = ai.room.logic:getCurrentEvent()
  local effect = event and event:findParent(GameEvent.SkillEffect, true)
  if effect and effect.data.skill:getSkeleton().name == name then
    return effect.data.skill_data.trigger_event, effect.data.skill_data
  end
end

function M.bestCard(ids, score)
  local best, value
  for _, id in ipairs(ids) do
    local candidate = score(id)
    if candidate and (not value or candidate > value or (candidate == value and id < best)) then
      best, value = id, candidate
    end
  end
  return best, value
end

function M.publicCards(areas)
  local ids = {}
  for _, group in ipairs(type(areas) == "table" and areas.card_data or {}) do
    table.insertTable(ids, group[2])
  end
  return ids
end

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
