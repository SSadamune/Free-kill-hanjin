local support = __dofile("../../../tests/support/hegemony.lua")
local skillTest = __dofile("../../../tests/support/skill_test.lua")
local Client = require "packages.qiao.pkg.qiao_mode.client"

Testqiao_room_records = {
  setup = function()
    local room = support.initQiaoRoom()
    FkTest.runInRoom(function() skillTest.installBlankGenerals(room, "han") end)
  end,
  tearDown = support.clearRoom,
}

function Testqiao_room_records:testDiscardTracksMovesAndShuffle()
  local room = FkTest.room
  local sword, peach
  FkTest.runInRoom(function()
    sword = room:printCard("qiao__chixiao_sword", Card.Heart, 9)
    peach = room:printCard("qiao__peach", Card.Diamond, 3)
    room:moveCardTo({ sword.id, peach.id }, Card.DiscardPile, nil, fk.ReasonPut, "test", nil, true)
  end)
  FkTest.runInClient(function()
    local cards = Client.discardCardsForDisplay(ClientInstance)
    lu.assertEquals(cards[1], { name = Fk:translate(peach.name), suit = "diamond", rank = "3", lord = false })
    lu.assertEquals(cards[2], { name = Fk:translate(sword.name), suit = "heart", rank = "9", lord = true })
  end)
  FkTest.runInRoom(function() room:obtainCard(room.players[1], sword, true, fk.ReasonPrey) end)
  FkTest.runInClient(function()
    lu.assertFalse(table.contains(ClientInstance.discard_pile, sword.id))
    lu.assertEquals(Client.discardCardsForDisplay(ClientInstance)[1].name, Fk:translate(peach.name))
  end)
  FkTest.runInRoom(function() room:shuffleDrawPile() end)
  FkTest.runInClient(function() lu.assertEquals(Client.discardCardsForDisplay(ClientInstance), {}) end)
end

local function giveCard(room, player, name, number)
  local card = room:printCard(name, Card.Heart, number)
  room:obtainCard(player, card, false, fk.ReasonJustMove)
  return card
end

function Testqiao_room_records:testMultiTargetThenConsecutivePindian()
  local room = FkTest.room
  local a, b, c, d = table.unpack(room.players, 1, 4)
  FkTest.runInRoom(function()
    local bonus = fk.CreateSkill { name = "#qiao_test_panel_points" }
    bonus:addEffect(fk.PindianCardsDisplayed, {
      can_refresh = function(self, event, target, player, data)
        return player == a and data.reason == "first"
      end,
      on_refresh = function(self, event, target, player, data)
        room:changePindianNumber(data, a, 3, "test")
      end,
    })
    room:addSkill(bonus:createSkill())
    room:pindian {
      from = a, tos = { b, c, d }, reason = "first", fromCard = giveCard(room, a, "qiao__slash", 6),
      results = {
        [b] = { toCard = giveCard(room, b, "qiao__peach", 8) },
        [c] = { toCard = giveCard(room, c, "qiao__jink", 9) },
        [d] = { toCard = giveCard(room, d, "qiao__slash", 13) },
      },
    }
    room:pindian {
      from = b, tos = { a }, reason = "second", fromCard = giveCard(room, b, "qiao__jink", 2),
      results = { [a] = { toCard = giveCard(room, a, "qiao__slash", 13) } },
    }
  end)
  FkTest.runInClient(function()
    local records = Client.pindianHistory(ClientInstance)
    lu.assertEquals(#records, 2)
    local first, second = records[1], records[2]
    lu.assertEquals({ first.sequence, first.reason, first.joint, #first.targets }, { 1, "first", false, 3 })
    lu.assertEquals(first.source, { seat = a.seat, name = "qiao__slash", rank = "6", suit = "heart", points = 9 })
    lu.assertEquals({ first.targets[1].seat, first.targets[1].winner }, { b.seat, a.seat })
    lu.assertEquals({ first.targets[2].seat, first.targets[2].winner }, { c.seat, 0 })
    lu.assertEquals({ first.targets[3].seat, first.targets[3].winner }, { d.seat, d.seat })
    lu.assertEquals({ second.sequence, second.source.seat, second.reason, second.targets[1].winner },
      { 2, b.seat, "second", a.seat })
  end)
  local snapshot
  FkTest.runInRoom(function() snapshot = room:serialize(a) end)
  FkTest.runInClient(function()
    local before = Client.pindianHistory(ClientInstance)
    ClientInstance:setBanner("qiao_pindian_record_1", 0)
    ClientInstance:setBanner("qiao_pindian_record_2", 0)
    ClientInstance:deserialize(snapshot)
    lu.assertEquals(Client.pindianHistory(ClientInstance), before)

    local board = Fk:getBoardGame(snapshot.settings.gameMode)
    local otherClient = board.client_klass:new(FkTest.createFakeClient())
    local displayed = {}
    function otherClient:notifyUI(command, data)
      lu.assertEquals(command, "QiaoPindianResult")
      lu.assertEquals(self:getBanner("qiao_pindian_record_" .. data.sequence), data)
      table.insert(displayed, data)
    end
    for _, record in ipairs(before) do
      otherClient.callbacks.SetBanner(otherClient, { "qiao_pindian_record_" .. record.sequence, record })
    end
    lu.assertEquals(displayed, before)
  end)
end

function Testqiao_room_records:testJointPindianWinnerAndTiedLeaders()
  local room = FkTest.room
  local a, b, c = table.unpack(room.players, 1, 3)
  local U = require "packages.utility.utility"
  for _, lastNumber in ipairs({ 7, 12 }) do
    FkTest.runInRoom(function()
      local fromCard = giveCard(room, a, "qiao__slash", 4)
      local second = giveCard(room, b, "qiao__peach", 12)
      local third = giveCard(room, c, "qiao__jink", lastNumber)
      FkTest.setNextReplies(b, { FkTest.ReplyChooseCards({ second.id }) })
      FkTest.setNextReplies(c, { FkTest.ReplyChooseCards({ third.id }) })
      U.jointPindian(a, { b, c }, "joint", fromCard)
    end)
  end
  FkTest.runInClient(function()
    local records = Client.pindianHistory(ClientInstance)
    lu.assertEquals(#records, 2)
    lu.assertEquals({ records[1].joint, records[1].winner, #records[1].targets }, { true, b.seat, 2 })
    lu.assertEquals({ records[2].joint, records[2].winner, #records[2].targets }, { true, 0, 2 })
  end)
end

return { name = "qiao_room_records" }
