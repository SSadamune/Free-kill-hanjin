-- 私密标记只发给操作者本人；旁观者即使借用该座位生成快照也不能看到。
local M = {}

function M.notify(player, mark, value)
  local owner = player._splayer
  if owner:getState() ~= fk.Player_Robot then
    owner:doNotify("SetPlayerMark", cbor.encode { player.id, mark, value })
  end
end

-- read(room, viewer) 只返回该座位重连时应补回的值。公开标记仍由引擎同步。
function M.register(room, mark, read)
  if room.qiaoPrivateMarkReaders then
    room.qiaoPrivateMarkReaders[mark] = read
    return
  end
  local readers = { [mark] = read }
  room.qiaoPrivateMarkReaders = readers
  local observing = false
  local serialize = room.serialize
  function room:serialize(viewer)
    local snapshot = serialize(self, viewer)
    if observing or not viewer then return snapshot end
    local data = snapshot.players[viewer.id]
    local marks
    for name, reader in pairs(readers) do
      local value = reader(self, viewer)
      if value ~= nil then
        marks = marks or cbor.decode(data.mark)
        marks[name] = value
      end
    end
    if marks then data.mark = cbor.encode(marks) end
    return snapshot
  end
  local tellRoomToObserver = room.tellRoomToObserver
  function room:tellRoomToObserver(observer)
    local previous = observing
    observing = true
    local ok, err = pcall(tellRoomToObserver, self, observer)
    observing = previous
    if not ok then error(err, 0) end
  end
end

return M
