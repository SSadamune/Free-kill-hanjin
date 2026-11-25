local M = {
  collection = "qiao_heg_mode",
  free = "qiao_free_mode",
  locked = "qiao_locked_mode",
}

M.names = { M.collection, M.free, M.locked }

function M.isHanjin(name)
  return table.contains(M.names, name)
end

function M.inRoom(room)
  return room ~= nil and type(room.getSettings) == "function"
    and M.isHanjin(room:getSettings("gameMode"))
end

return M
