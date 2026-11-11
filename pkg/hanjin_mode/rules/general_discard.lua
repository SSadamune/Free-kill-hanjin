-- 武将弃牌堆 for 客将 redraw.
--
-- A successfully redrawn guest leaves the game for the rest of the room's
-- game. Every later general draw must skip it and the return-to-pile flow must
-- not put it back. The engine has several draw entry points (`getNGenerals`,
-- `findGeneral`, `findGenerals`, `askToChooseIniticalGeneral`) and several
-- return paths, all of which eventually read or write `Room.general_pile`.
-- We keep the discard set in a room tag, remove discarded names from the pile,
-- and wrap the engine's generic entry points only for `hanjin_heg_mode`.
local M = {}

M.key = "hanjin_general_discard_v1"
M.mode = "hanjin_heg_mode"
M.installed = false

local function active(room)
  return room and type(room.getSettings) == "function"
    and room:getSettings("gameMode") == M.mode
end

---@param room Room
---@return string[]
function M.list(room)
  return room:getTag(M.key) or {}
end

---@param room Room
---@param name string
---@return boolean
function M.contains(room, name)
  return table.contains(M.list(room), name)
end

---@param room Room
---@param names string[]
---@return string[]
function M.filter(room, names)
  local discarded = M.list(room)
  return table.filter(names, function(name) return not table.contains(discarded, name) end)
end

---Move names into the room's general discard pile. They are simultaneously
---hidden from same-name conversion and later random general requests.
---@param room Room
---@param names string[]
---@return string[] @ names newly discarded
function M.add(room, names)
  local discarded = M.list(room)
  local added = {}
  for _, name in ipairs(names) do
    if not table.contains(discarded, name) then
      table.insert(discarded, name)
      table.insert(added, name)
    end
    table.insertIfNeed(room.disabled_generals, name)
    table.removeOne(room.general_pile, name)
  end
  room:setTag(M.key, discarded)
  return added
end

---Remove every discarded name from the live pile. Called before each draw in
---case another module inserted a name directly instead of using the return API.
---@param room Room
function M.purge(room)
  local discarded = M.list(room)
  if #discarded == 0 then return end
  for i = #room.general_pile, 1, -1 do
    if table.contains(discarded, room.general_pile[i]) then
      table.remove(room.general_pile, i)
    end
  end
end

---@param room Room
function M.reset(room)
  room:setTag(M.key, {})
end

---Install the engine entry-point guards once per process. The guards are inert
---outside HanJin rooms, so other modes and upstream regressions keep working.
function M.install()
  if M.installed then return true end
  -- The package entry point is also loaded in contexts where the server Room
  -- class does not exist yet. Installation is therefore deferred to the first
  -- server-side chooseGenerals call.
  if type(Room) ~= "table" or type(Room.returnToGeneralPile) ~= "function" then return false end
  M.installed = true

  local originalReturn = Room.returnToGeneralPile
  function Room:returnToGeneralPile(generals, position)
    if active(self) then
      generals = M.filter(self, generals)
      if #generals == 0 then return true end
    end
    return originalReturn(self, generals, position)
  end

  local originalDraw = Room.getNGenerals
  function Room:getNGenerals(n, position)
    if active(self) then M.purge(self) end
    return originalDraw(self, n, position)
  end

  local originalFind = Room.findGeneral
  function Room:findGeneral(name)
    if active(self) then M.purge(self) end
    return originalFind(self, name)
  end

  local originalFindMany = Room.findGenerals
  function Room:findGenerals(func, n)
    if active(self) then M.purge(self) end
    return originalFindMany(self, func, n)
  end

  local originalInitial = Room.askToChooseIniticalGeneral
  function Room:askToChooseIniticalGeneral(player, params)
    if active(self) and params and params.generals then
      local copy = table.clone(params)
      copy.generals = M.filter(self, params.generals)
      return originalInitial(self, player, copy)
    end
    if active(self) then M.purge(self) end
    return originalInitial(self, player, params)
  end
end

return M
