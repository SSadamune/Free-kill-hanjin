-- 0.5.25 单亮复用同一份事件数据，双亮重新构造含 m、d 的数据。
-- 只记录真正翻开的糜夫人；联合事件中列出的另一张已明置武将牌不取得资格。
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local M = {}
local GENERAL = "qiao_heg__shu021"
local SKILL = "qiao__skill_shu021_1"
local states = setmetatable({}, { __mode = "k" })
local installed = false

local function flow(event)
  return event == GameEvent.Phase or event == GameEvent.Turn or event == GameEvent.Round
end

local function installCombined()
  if installed then return end
  installed = true
  local class = require "ltk.server.serverplayer"
  local original = class.revealGenerals
  function class:revealGenerals()
    local state = states[self.room]
    if not state or (self:getMark("__heg_general") ~= GENERAL and self:getMark("__heg_deputy") ~= GENERAL) then
      return original(self)
    end
    local previous, batch = state.collecting[self], {}
    state.collecting[self] = batch
    local ok, err = pcall(original, self)
    state.collecting[self] = previous
    if not ok then error(err, 0) end
    -- 引擎在当前结算事件退出时按登记顺序依次发放双亮的联合事件。
    if not batch.delivered then
      state.queue[self] = state.queue[self] or {}
      table.insert(state.queue[self], batch)
    end
  end
end

function M.install(room)
  if states[room] then return end
  installCombined()
  local state = { collecting = {}, queue = {}, active = {}, tickets = setmetatable({}, { __mode = "k" }),
    windows = setmetatable({}, { __mode = "k" }) }
  states[room] = state
  local logic = room.logic
  local original = logic.trigger
  local function dispatch(ticket, event, player, data, refreshOnly)
    local previous = state.active[player]
    state.active[player] = ticket
    local ok, result, trigger = pcall(original, logic, event, player, data, refreshOnly)
    state.active[player] = previous
    if not ok then error(result, 0) end
    return result, trigger
  end
  function logic:trigger(event, player, data, refreshOnly)
    if event == fk.GeneralShown and (data.m == GENERAL or data.d == GENERAL) then
      local current = self:getCurrentEvent()
      local ticket = state.active[player]
      if not ticket then
        local key = data
        if current and current.event ~= GameEvent.Game and not flow(current.event) then
          while current.parent and not flow(current.parent.event) do current = current.parent end
          key = current
        end
        state.windows[key] = state.windows[key] or {}
        ticket = state.windows[key][player]
        if not ticket then
          ticket = { eligible = not player.dead and Exchange.cardProvidesSkill(room, GENERAL, SKILL)
            and Fk.skills[SKILL]:isEffectable(player) }
          state.windows[key][player] = ticket
        end
      end
      state.tickets[data] = ticket
      if state.collecting[player] then state.collecting[player].ticket = ticket end
      return dispatch(ticket, event, player, data, refreshOnly)
    elseif event == fk.GeneralRevealed then
      local ticket = state.tickets[data]
      if data.m and data.d and (data.m == GENERAL or data.d == GENERAL) then
        local batch = state.collecting[player] or table.remove(state.queue[player] or {}, 1)
        if batch then batch.delivered = true; ticket = batch.ticket end
      end
      if data.m == GENERAL or data.d == GENERAL then
        return dispatch(ticket, event, player, data, refreshOnly)
      end
    end
    return original(self, event, player, data, refreshOnly)
  end
end

function M.take(player)
  local state = states[player.room]
  local ticket = state and state.active[player]
  if not ticket or ticket.paid or not ticket.eligible then return false end
  ticket.paid = true
  return not player.dead
end

return M
