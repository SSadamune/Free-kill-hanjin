local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local M = {}
local otherSelectionSources = {
  fire_attack_skill = true,
  ["#double_swords_skill"] = true,
  ["#qiao_adaptation_rule"] = true,
}

-- The native selector already enforces its own cardinality and eligibility.
-- Use it for cancellable HanJin selections, including auxiliary skill requests.
function M.applies(name, extra, cancelable)
  local source = extra and extra.skillName or name
  local skill = Fk.skills[name]
  return cancelable ~= false and type(source) == "string"
    and (source:startsWith("qiao__") or source:startsWith("#qiao__") or otherSelectionSources[source])
    and skill ~= nil and not skill.immediate_sub
    and (skill:isInstanceOf(ActiveSkill) or name == "virtual_viewas")
end

local installed = false

function M.install(room)
  if room.qiaoTriggerSelectionInstalled then return end
  room.qiaoTriggerSelectionInstalled = true

  if not installed then
    local TriggerSkill = require "ltk.core.skill_type.trigger"
    local doCost = TriggerSkill.doCost
    function TriggerSkill:doCost(event, target, player, data)
      local current = player.room
      if not Modes.inRoom(current) then return doCost(self, event, target, player, data) end
      local previous = current.qiaoTriggerSelection
      local previousCost = current.current_cost_skill
      current.qiaoTriggerSelection = { skill = self, player = player }
      local ok, result = pcall(doCost, self, event, target, player, data)
      current.qiaoTriggerSelection = previous
      if (previous and previousCost == previous.skill) or not ok then
        current.current_cost_skill = previousCost
      end
      if not ok then error(result, 0) end
      return result
    end
    installed = true
  end

  local askUseCard = room.askToUseCard
  function room:askToUseCard(player, params)
    local frame = self.qiaoTriggerSelection
    local use = askUseCard(self, player, params)
    if use and frame and frame.player == player and self.current_cost_skill == frame.skill
      and params.extra_data and params.extra_data.qiao_trigger_use then
      frame.confirmed = true
    end
    return use
  end

  local askActive = room.askToUseActiveSkill
  function room:askToUseActiveSkill(player, params)
    local frame = self.qiaoTriggerSelection
    local success, result = askActive(self, player, params)
    if success and frame and frame.player == player
      and self.current_cost_skill == frame.skill
      and M.applies(params.skill_name, params.extra_data, params.cancelable) then
      frame.confirmed = true
    end
    return success, result
  end

  local askInvoke = room.askToSkillInvoke
  function room:askToSkillInvoke(player, params)
    local frame = self.qiaoTriggerSelection
    -- TriggerSkill adds a second reveal confirmation for fast fake-skill costs.
    -- A confirmed selector already represents an explicit invocation.
    if frame and frame.confirmed and frame.player == player and self.current_cost_skill == frame.skill
      and params.skill_name == frame.skill.name and params.prompt == nil then
      return true
    end
    return askInvoke(self, player, params)
  end
end

return M
