-- 单亮沿用事件数据，双亮合并。一个房间共用明置事件入口，各武将独立记录。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local rooms = setmetatable({}, { __mode = "k" })
local installed = false

local function matching(trackers, main, deputy)
  local result = {}
  local first, second = trackers[main], trackers[deputy]
  if first then table.insert(result, first) end
  if second and second ~= first then table.insert(result, second) end
  return result
end

local function installCombinedReveal()
  if installed then return end
  installed = true
  local class = require "ltk.server.serverplayer"
  local original = class.revealGenerals
  function class:revealGenerals()
    local trackers = rooms[self.room]
    if not trackers then return original(self) end
    local states = matching(trackers, self:getMark("__heg_general"), self:getMark("__heg_deputy"))
    if #states == 0 then return original(self) end

    local previous = {}
    for _, state in ipairs(states) do
      previous[state] = state.collecting[self]
      state.collecting[self] = {}
    end
    local ok, err = pcall(original, self)
    for _, state in ipairs(states) do
      local batch = state.collecting[self]
      state.collecting[self] = previous[state]
      -- 延后发出的双亮事件仍按原登记顺序领取各自的记录。
      if ok and not batch.delivered then
        state.queue[self] = state.queue[self] or {}
        table.insert(state.queue[self], batch)
      end
    end
    if not ok then error(err, 0) end
  end
end

local function isFlow(event)
  return event == GameEvent.Phase or event == GameEvent.Turn or event == GameEvent.Round
end

local function recordShown(room, state, player, data)
  local ticket = state.active[player]
  if not ticket then
    local current = room.logic:getCurrentEvent()
    local key = data
    if current and current.event ~= GameEvent.Game and not isFlow(current.event) then
      while current.parent and not isFlow(current.parent.event) do current = current.parent end
      key = current
    end
    state.windows[key] = state.windows[key] or {}
    ticket = state.windows[key][player]
    if not ticket then
      local skill = state.skillAt(data.d == state.general)
      ticket = { skill = skill, eligible = not player.dead and Exchange.cardProvidesSkill(room, state.general, skill)
        and Fk.skills[skill]:isEffectable(player) }
      state.windows[key][player] = ticket
    end
  end
  state.tickets[data] = ticket
  if state.collecting[player] then state.collecting[player].ticket = ticket end
  return ticket
end

local function revealedTicket(state, player, data)
  if data.m and data.d then
    local batch = state.collecting[player] or table.remove(state.queue[player] or {}, 1)
    if batch then
      batch.delivered = true
      return batch.ticket
    end
  end
  return state.tickets[data]
end

local function installRoom(room, trackers)
  installCombinedReveal()
  local original = room.logic.trigger
  function room.logic:trigger(event, player, data, refreshOnly)
    if event ~= fk.GeneralShown and event ~= fk.GeneralRevealed then
      return original(self, event, player, data, refreshOnly)
    end
    local states = matching(trackers, data.m, data.d)
    if #states == 0 then return original(self, event, player, data, refreshOnly) end

    local previous = {}
    for _, state in ipairs(states) do
      previous[state] = state.active[player]
      local ticket
      if event == fk.GeneralShown then
        ticket = recordShown(room, state, player, data)
      else
        ticket = revealedTicket(state, player, data)
      end
      state.active[player] = ticket
    end
    local ok, result, trigger = pcall(original, self, event, player, data, refreshOnly)
    for _, state in ipairs(states) do state.active[player] = previous[state] end
    if not ok then error(result, 0) end
    return result, trigger
  end
end

local function tracker(general, skillAt)
  local M = {}
  function M.install(room)
    local trackers = rooms[room]
    if not trackers then
      trackers = {}
      rooms[room] = trackers
      installRoom(room, trackers)
    end
    trackers[general] = trackers[general] or {
      general = general, skillAt = skillAt, collecting = {}, queue = {}, active = {},
      tickets = setmetatable({}, { __mode = "k" }), windows = setmetatable({}, { __mode = "k" }),
    }
  end

  local function pending(player, skill)
    local trackers = rooms[player.room]
    local state = trackers and trackers[general]
    local ticket = state and state.active[player]
    if not ticket or (skill and ticket.skill ~= skill) or ticket.paid or not ticket.eligible or player.dead then return end
    return ticket
  end

  function M.available(player, skill) return pending(player, skill) ~= nil end

  function M.take(player, skill)
    local ticket = pending(player, skill)
    if not ticket then return false end
    ticket.paid = true
    return not player.dead
  end
  return M
end

return tracker
