local M = {}

-- The target request is the invocation. The client preselects a sole target.
function M.ask(room, player, params)
  local targets = params.targets
  if #targets == 0 then return {} end
  if #targets == 1 and params.min_num == 1 then
    params.prompt = params.invoke_prompt or params.prompt
  end
  params.cancelable = true
  local selected = room:askToChoosePlayers(player, params) or {}
  local seen = {}
  if #selected < params.min_num or #selected > params.max_num then return {} end
  for _, to in ipairs(selected) do
    if seen[to] or not table.contains(targets, to) then return {} end
    seen[to] = true
  end
  return selected
end

return M
