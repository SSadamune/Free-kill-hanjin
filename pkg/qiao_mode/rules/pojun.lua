local PrivateMarks = require "packages.qiao.pkg.qiao_mode.rules.private_marks"

local M = {
  PENDING = "qiao_wu020_pojun_pending",
  COUNT = "qiao_wu020_pojun_count",
  CARDS = "qiao_wu020_pojun_cards",
}

function M.cards(room, player)
  local ids = {}
  for _, entry in ipairs(room:getTag(M.PENDING) or {}) do
    if entry.target == player.id then
      for _, id in ipairs(entry.ids) do
        if room:getCardArea(id) == Card.Void then table.insertIfNeed(ids, id) end
      end
    end
  end
  return ids
end

function M.refresh(room, player)
  local ids = M.cards(room, player)
  room:setPlayerMark(player, M.COUNT, #ids)
  PrivateMarks.notify(player, M.CARDS, #ids > 0 and ids or 0)
end

function M.install(room)
  PrivateMarks.register(room, M.CARDS, function(currentRoom, viewer)
    local ids = M.cards(currentRoom, viewer)
    if #ids > 0 then return ids end
  end)
end

return M
