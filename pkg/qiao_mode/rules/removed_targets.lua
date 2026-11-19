local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local AbstractRoom = require "ltk.core.room.abstract_room"

local M = {}

function M.isRemoved(player)
  return player ~= nil and not player.dead and player:isRemoved()
end

function M.inMode(room)
  return room ~= nil and type(room.getSettings) == "function"
    and Modes.inRoom(room)
end

--- Use for fixed or delayed effects that do not ask the player for targets.
function M.isPresent(player)
  return player ~= nil and player:isAlive() and not M.isRemoved(player)
end

local function withoutRemoved(players)
  return table.filter(players, function(player) return not M.isRemoved(player) end)
end

--- The physical roster remains available to game flow and victory rules.
--- Gameplay queries use this fresh snapshot on both client and server.
function AbstractRoom:getPresentPlayers()
  return table.filter(self.alive_players, M.isPresent)
end

local function eligibleTargets(params, targets)
  if not table.find(targets, M.isRemoved) and params.targets == targets then return params end
  local filtered = table.simpleClone(params)
  filtered.targets = withoutRemoved(targets)
  return filtered
end

local function hasRemovedTarget(room, reply)
  return type(reply) == "table" and table.find(reply.targets or {}, function(id)
    return M.isRemoved(room:getPlayerById(id))
  end) ~= nil
end

local serverGuardsInstalled = false

local function installServerGuards()
  if serverGuardsInstalled then return end
  local Request = require "server.request"
  local TriggerSkill = require "ltk.core.skill_type.trigger"
  local getResult = Request.getResult
  function Request:getResult(player)
    local result = getResult(self, player)
    -- Active requests consume this reply directly, bypassing handleUseCardReply.
    if self.command == "AskForUseActiveSkill" and M.inMode(self.room)
      and (M.isRemoved(player) or hasRemovedTarget(self.room, result)) then
      return ""
    end
    return result
  end
  local doCost = TriggerSkill.doCost
  function TriggerSkill:doCost(event, target, player, data)
    if not self.global and M.inMode(player.room) and M.isRemoved(player) then
      event:setSkillData(self, "cancel_cost", true)
      return false
    end
    return doCost(self, event, target, player, data)
  end
  serverGuardsInstalled = true
end

function M.installServer(room)
  if room.qiaoRemovedTargetsInstalled then return end
  room.qiaoRemovedTargetsInstalled = true
  installServerGuards()

  local alivePlayers = room.getAlivePlayers
  function room:getAlivePlayers(sortBySeat)
    return table.filter(alivePlayers(self, sortBySeat), M.isPresent)
  end

  local choosePlayers = room.askToChoosePlayers
  function room:askToChoosePlayers(player, params)
    if M.isRemoved(player) then return {} end
    params = eligibleTargets(params, params.targets)
    if #params.targets == 0 then return {} end
    return choosePlayers(self, player, params)
  end

  local chooseCardsAndPlayers = room.askToChooseCardsAndPlayers
  function room:askToChooseCardsAndPlayers(player, params)
    if M.isRemoved(player) then return {}, {}, false end
    params = eligibleTargets(params, params.targets)
    if #params.targets == 0 and params.min_num > 0 then return {}, {}, false end
    return chooseCardsAndPlayers(self, player, params)
  end

  local distribute = room.askToYiji
  function room:askToYiji(player, params)
    if M.isRemoved(player) then return {} end
    params = eligibleTargets(params, params.targets or self:getAlivePlayers(false))
    if #params.targets == 0 then return {} end
    return distribute(self, player, params)
  end

  local askActive = room.askToUseActiveSkill
  function room:askToUseActiveSkill(player, params)
    if M.isRemoved(player) then return false end
    return askActive(self, player, params)
  end

  local handleReply = room.handleUseCardReply
  function room:handleUseCardReply(player, data, params)
    -- The normal play request dispatches active skills and special card
    -- actions here, before any skill history or effect is applied.
    if M.isRemoved(player) or hasRemovedTarget(self, data) then return nil end
    return handleReply(self, player, data, params)
  end
end

return M
