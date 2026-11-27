local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local M = {}
local otherSelectionSources = {
  fire_attack_skill = true,
  ["#double_swords_skill"] = true,
  ["#qiao_adaptation_rule"] = true,
}

function M.confirm(room, player)
  local frame = room.qiaoTriggerSelection
  if frame and frame.player == player and room.current_cost_skill == frame.skill then
    frame.confirmed = true
  end
end

-- Native single-choice requests display every option and submit on the click.
-- Keep the visible list even when only one option is available, so the engine
-- cannot auto-return it and disabled alternatives are still explained.
function M.askOption(room, player, params)
  if #params.choices == 0 then return end
  local choices = table.simpleClone(params.choices)
  local all = table.simpleClone(params.all_choices or params.choices)
  local cancelable = params.cancelable ~= false
  local choice
  if params.buttons then
    -- The option bar has its own Cancel button and returns an empty reply on cancellation.
    choice = room:askToOptions(player, {
      options = choices, all_options = all, cancelable = cancelable,
      skill_name = params.skill_name, prompt = params.prompt,
      min_num = 1, max_num = 1, single = true,
    })[1]
  else
    choice = room:askToChoice(player, {
      choices = choices, all_choices = all, detailed = params.detailed, cancelable = cancelable,
      skill_name = params.skill_name, prompt = params.prompt,
    })
  end
  if choice == "Cancel" or not table.contains(params.choices, choice) then return end
  M.confirm(room, player)
  return choice
end

-- For small sets, each permitted combination can itself be chosen in one click.
-- The order of the members follows the original option order.
function M.optionSets(all, available, max)
  local choices, allChoices, sets = {}, {}, {}
  local function add(members)
    local label
    if #members == 1 then
      label = members[1]
    elseif #members == 2 then
      label = "qiao_option_pair:::" .. table.concat(members, ":")
    else
      label = "qiao_option_triple:::" .. table.concat(members, ":")
    end
    sets[label] = members
    table.insert(allChoices, label)
    if table.every(members, function(choice) return table.contains(available, choice) end) then
      table.insert(choices, label)
    end
  end
  for _, option in ipairs(all) do add({ option }) end
  if max >= 2 then
    for i, first in ipairs(all) do
      for j = i + 1, #all do add({ first, all[j] }) end
    end
  end
  if max >= 3 then
    for i, first in ipairs(all) do
      for j = i + 1, #all do
        for k = j + 1, #all do add({ first, all[j], all[k] }) end
      end
    end
  end
  return choices, allChoices, sets
end

function M.optionButtons(skeleton, options)
  skeleton.qiaoDirectOptions = options
  return function(self, player)
    local available, all = options(player)
    return UI.OptionBox { options = available, all_options = all, direct_send = true }
  end
end

function M.validDirectOption(skill, player, reply)
  local skeleton = skill and skill:getSkeleton()
  local options = skeleton and skeleton.qiaoDirectOptions
  if options == nil then return true end
  local available = options(player)
  return table.contains(available, reply.interaction_data)
    and #(reply.card.subcards or {}) == 0 and #(reply.targets or {}) == 0
end

Fk:loadTranslationTable {
  ["qiao_option_pair"] = "%arg＋%arg2",
  ["qiao_option_triple"] = "%arg＋%arg2＋%arg3",
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

-- Server-side facts for a pending invocation. Keep them off the wire.
function M.currentCost(player)
  local room = player.room
  local frame = room.qiaoTriggerSelection
  if frame and frame.player == player and frame.skill == room.current_cost_skill then
    return frame
  end
end

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
      current.qiaoTriggerSelection = { skill = self, player = player, event = event, target = target, data = data }
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
