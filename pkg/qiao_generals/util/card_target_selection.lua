local M = {}

local function allows(extra, cardId, target)
  local targets = extra and extra.targetsByCard[tostring(cardId)]
  return targets ~= nil and (target == nil or table.contains(targets, target.id))
end

-- Callers supply eligible pairs as card ID strings mapped to target ID lists.
function M.add(skill, name, cardAreas)
  cardAreas.card_num = 1
  cardAreas.target_num = 1
  cardAreas.card_filter = function(self, _, cardId, selectedCards, selectedTargets)
    return #selectedCards == 0 and allows(self._extra_data, cardId, selectedTargets[1])
  end
  cardAreas.target_filter = function(self, _, target, selectedTargets, selectedCards)
    if #selectedTargets > 0 then return false end
    if #selectedCards > 0 then return allows(self._extra_data, selectedCards[1], target) end
    return self._extra_data ~= nil and table.contains(self._extra_data.targets, target.id)
  end
  skill:addAuxActiveSkill(name, cardAreas)
end

-- Validate the submitted pair against the candidates before skill-specific checks.
function M.ask(room, player, params)
  params.cancelable = true
  local ok, reply = room:askToUseActiveSkill(player, params)
  if not ok or not reply or #reply.cards ~= 1 or #reply.targets ~= 1 then return end
  local card, target = reply.cards[1], reply.targets[1]
  if allows(params.extra_data, card, target) then return card, target end
end

return M
