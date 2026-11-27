local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local M = {}
local incomingExchanges = setmetatable({}, { __mode = "k" })

-- 选牌时可预计 outgoing 腾出的栏位。批量落栏时为已接受的牌预留相应栏位。
local function canReceive(player, card, outgoing, reserved)
  local slots = { card.sub_type }
  if Fk.packages.qiao_cards.qiao_cards.isDualMount(card) then
    slots = { Card.SubtypeOffensiveRide, Card.SubtypeDefensiveRide }
  end
  for _, subtype in ipairs(slots) do
    local equips = player:getEquipments(subtype)
    local remaining = #equips - (table.contains(equips, outgoing) and 1 or 0)
    if remaining + (reserved and reserved[subtype] or 0) >= #player:getAvailableEquipSlots(subtype) then
      return false
    end
  end
  if reserved then
    for _, subtype in ipairs(slots) do reserved[subtype] = (reserved[subtype] or 0) + 1 end
  end
  return true
end

local function canExchangeBetween(a, b)
  return a ~= nil and b ~= nil and a ~= b and a:isAlive() and b:isAlive()
    and not a:isRemoved() and not b:isRemoved()
end

local function canMoveEquip(chooser, owner, id)
  return not Wu.isPubliclyProtectedTreasure(owner, chooser, id)
end

local function secondCandidates(chooser, a, b, idA)
  if not table.contains(a:getCardIds("e"), idA) or not canMoveEquip(chooser, a, idA) then return {} end
  local cardA = a:getVirtualEquip(idA) or Fk:getCardById(idA)
  return table.filter(b:getCardIds("e"), function(idB)
    local cardB = b:getVirtualEquip(idB) or Fk:getCardById(idB)
    return canMoveEquip(chooser, b, idB) and canReceive(b, cardA, idB) and canReceive(a, cardB, idA)
  end)
end

local function firstCandidates(chooser, a, b)
  return table.filter(a:getCardIds("e"), function(idA)
    return #secondCandidates(chooser, a, b, idA) > 0
  end)
end

--- 查询两名角色是否有一对可交换的装备牌。客户端和服务端共用。
function M.canSwapOneEach(chooser, a, b)
  return chooser ~= nil and chooser:isAlive() and canExchangeBetween(a, b)
    and #firstCandidates(chooser, a, b) > 0
end

local function chooseEquip(room, chooser, owner, ids, skillName, promptKey)
  if #ids <= 1 then return ids[1] end
  local prompt = promptKey and (promptKey .. "::" .. owner.id .. ":" .. skillName)
    or ("#AskForChooseCard:" .. owner.id .. "::" .. skillName)
  local id = room:askToChooseCard(chooser, {
    target = owner,
    flag = { card_data = { { "$Equip", ids } } },
    skill_name = skillName,
    prompt = prompt,
  })
  if table.contains(ids, id) then return id end
end

-- 每张牌单独结算能否落入对方装备区。未落栏且仍在处理区的牌由交换清理。
local function moveIncoming(room, moves)
  if #moves == 0 then return end
  local previous = incomingExchanges[room]
  local cards = {}
  for _, move in ipairs(moves) do cards[move.ids[1]] = move.skillName end
  incomingExchanges[room] = cards
  local ok, err = pcall(room.moveCards, room, table.unpack(moves))
  incomingExchanges[room] = previous
  if not ok then error(err, 0) end
end

--- 执行已选定的装备交换。两侧先同时离场，再将仍在处理区的牌置入对方可用栏位。
function M.swapEquips(room, chooser, a, b, idsA, idsB, skillName)
  local transfers, allIds = {}, {}
  local function collect(from, to, ids)
    for _, id in ipairs(ids) do
      table.insert(transfers, { from = from, to = to, id = id, virtual = from:getVirtualEquip(id) })
      table.insert(allIds, id)
    end
  end
  collect(a, b, idsA)
  collect(b, a, idsB)
  if #allIds == 0 then return end
  local outgoing, incoming = {}, {}
  for _, transfer in ipairs(transfers) do
    table.insert(outgoing, {
      from = transfer.from, ids = { transfer.id }, toArea = Card.Processing,
      moveReason = fk.ReasonExchange, proposer = chooser, skillName = skillName, moveVisible = true,
    })
  end
  room:moveCards(table.unpack(outgoing))
  local reserved = { [a] = {}, [b] = {} }
  for _, transfer in ipairs(transfers) do
    local to = transfer.to
    if room:getCardArea(transfer.id) == Card.Processing and to:isAlive() and not to:isRemoved()
      and canReceive(to, transfer.virtual or Fk:getCardById(transfer.id), nil, reserved[to]) then
      table.insert(incoming, {
        ids = { transfer.id }, fromArea = Card.Processing, to = to, toArea = Card.PlayerEquip,
        virtualEquip = transfer.virtual, moveReason = fk.ReasonExchange, proposer = chooser,
        skillName = skillName, moveVisible = true,
      })
    end
  end
  moveIncoming(room, incoming)
  room:cleanProcessingArea(allIds, skillName)
end

--- 由 chooser 从 a、b 的装备区里各选一张装备牌并交换。
function M.swapOneEach(room, chooser, a, b, skillName, promptKey)
  if not chooser or not chooser:isAlive() or not canExchangeBetween(a, b) then return false end
  local idA = chooseEquip(room, chooser, a, firstCandidates(chooser, a, b), skillName, promptKey)
  if not idA or not chooser:isAlive() or not canExchangeBetween(a, b) then return false end
  local idB = chooseEquip(room, chooser, b, secondCandidates(chooser, a, b, idA), skillName, promptKey)
  if not idB or not chooser:isAlive() or not canExchangeBetween(a, b)
    or not table.contains(secondCandidates(chooser, a, b, idA), idB) then return false end
  M.swapEquips(room, chooser, a, b, { idA }, { idB }, skillName)
  return true
end

function M.installServer(logic)
  local trigger = logic.trigger
  function logic:trigger(event, target, data, refreshOnly)
    local broken, detail = trigger(self, event, target, data, refreshOnly)
    local room = self.room
    local cards = incomingExchanges[room]
    if event == fk.BeforeCardsMove and cards then
      -- 等普通触发和所有延后 refresh 完成。接下来引擎才会应用这一批移动。
      local reserved = {}
      room:cancelMove(data, nil, function(move, info)
        local skillName = cards[info.cardId]
        if not skillName or skillName ~= move.skillName or info.fromArea ~= Card.Processing
          or move.toArea ~= Card.PlayerEquip or move.moveReason ~= fk.ReasonExchange then return false end
        local to = move.to
        if not to or not to:isAlive() or to:isRemoved() or room:getCardArea(info.cardId) ~= Card.Processing then
          return true
        end
        reserved[to] = reserved[to] or {}
        return not canReceive(to, info.virtualEquip or Fk:getCardById(info.cardId), nil, reserved[to])
      end)
    end
    return broken, detail
  end
end

return M
