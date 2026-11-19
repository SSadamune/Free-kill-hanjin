local M = {
  collection = "qiao_heg_mode",
  free = "qiao_free_mode",
}

M.names = { M.collection, M.free }

function M.isHanjin(name)
  return name == M.collection or name == M.free
end

function M.inRoom(room)
  return room ~= nil and type(room.getSettings) == "function"
    and M.isHanjin(room:getSettings("gameMode"))
end

return M
