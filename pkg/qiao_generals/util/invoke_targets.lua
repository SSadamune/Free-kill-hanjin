local M = {}

-- A cancellable target request is the invocation. If there is only one
-- legal target, use the same prompt to confirm it without a redundant click.
function M.ask(room, player, params)
  local targets = params.targets
  if #targets == 0 then return {} end
  if #targets == 1 and params.min_num == 1 then
    if room:askToSkillInvoke(player, {
      skill_name = params.skill_name,
      prompt = params.invoke_prompt or params.prompt,
    }) then return targets end
    return {}
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
