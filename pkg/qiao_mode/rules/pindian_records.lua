local U = require "packages.utility.utility"
local R = { prefix = "qiao_pindian_record_" }

local function shownCard(player, card)
  local id = card:getEffectiveId()
  local printed = id and Fk:getCardById(id, true)
  return {
    seat = player.seat, name = card.name, suit = card:getSuitString(),
    rank = (printed or card):getNumberStr(), points = card.number,
  }
end

function R.publish(room, data)
  local record = {
    reason = data.reason, source = shownCard(data.from, data.fromCard), targets = {},
    joint = data.class ~= nil and data:isInstanceOf(U.JointPindianData) or false,
  }
  for _, to in ipairs(data.tos) do
    local result = data.results[to]
    if result and result.toCard then
      local row = shownCard(to, result.toCard)
      row.winner = result.winner and result.winner.seat or 0
      table.insert(record.targets, row)
    end
  end
  if #record.targets == 0 then return end
  if record.joint then record.winner = data.winner and data.winner.seat or 0 end
  record.sequence = (room:getTag("qiao_pindian_count") or 0) + 1
  room:setTag("qiao_pindian_count", record.sequence)
  -- 每次只广播这一条。公开 banner 随重连快照恢复，同局早先的拼点可再次查看。
  room:setBanner(R.prefix .. record.sequence, record)
end

function R.history(room)
  local records = {}
  local record = room:getBanner(R.prefix .. 1)
  while record do
    table.insert(records, record)
    record = room:getBanner(R.prefix .. (#records + 1))
  end
  return records
end

return R
