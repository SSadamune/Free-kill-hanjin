local support = __dofile("../../../tests/support/hegemony.lua")
local skillTest = __dofile("../../../tests/support/skill_test.lua")
local Client = require "packages.qiao.pkg.qiao_mode.client"
local Ltk = require "packages.freekill-core.ltk.client.util"

Fk:loadTranslationTable { ["@qiao_test_discard_public"] = "测试标记" }

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
    lu.assertEquals(cards[1], {
      id = peach.id, markFallbacks = {}, name = Fk:translate(peach.name),
      lord = false, thisTurn = false,
    })
    lu.assertEquals(cards[2], {
      id = sword.id, markFallbacks = {}, name = Fk:translate(sword.name),
      lord = true, thisTurn = false,
    })
  end)
  FkTest.runInRoom(function() room:obtainCard(room.players[1], sword, true, fk.ReasonPrey) end)
  FkTest.runInClient(function()
    lu.assertFalse(table.contains(ClientInstance.discard_pile, sword.id))
    lu.assertEquals(Client.discardCardsForDisplay(ClientInstance)[1].name, Fk:translate(peach.name))
  end)
  FkTest.runInRoom(function() room:shuffleDrawPile() end)
  FkTest.runInClient(function() lu.assertEquals(Client.discardCardsForDisplay(ClientInstance), {}) end)
end

function Testqiao_room_records:testDiscardDistinguishesBothClubFourSlashes()
  local room = FkTest.room
  local ids = {}
  FkTest.runInRoom(function()
    for _, card in ipairs(Fk.packages.qiao_cards.cards) do
      if card.name == "qiao__slash" and card.suit == Card.Club and card.number == 4 then
        table.insert(ids, card.id)
      end
    end
    room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonPut, "test", nil, true)
    room:setCardMark(Fk:getCardById(ids[1]), "@qiao_test_discard_public", 1)
  end)
  FkTest.runInClient(function()
    local marks = {}
    for _, row in ipairs(Client.discardCardsForDisplay(ClientInstance)) do
      if table.contains(ids, row.id) then
        for _, mark in ipairs(row.markFallbacks) do marks[mark.k] = mark.v end
      end
    end
    lu.assertNotNil(marks["@qiao_adaptation_1_kongchao"])
    lu.assertNotNil(marks["@qiao_adaptation_1_gujun"])
    lu.assertNotNil(table.find(Ltk:getCardData(ids[1]).mark, function(mark)
      return mark.k == "@qiao_test_discard_public" and mark.v == 1
    end))
  end)
end

function Testqiao_room_records:testDiscardGroupsByLastArrivalInTheCurrentTurn()
  local room = FkTest.room
  local player = room.players[1]
  local old, reused, fresh, snapshot
  FkTest.runInRoom(function()
    old = room:printCard("qiao__chixiao_sword", Card.Heart, 9)
    reused = room:printCard("qiao__slash", Card.Club, 4)
    fresh = room:printCard("qiao__jink", Card.Heart, 2)
    room:moveCardTo({ old.id, reused.id }, Card.DiscardPile, nil, fk.ReasonPut, "test", nil, true)

    local move = fk.CreateSkill { name = "#qiao_test_discard_turn" }
    move:addEffect(fk.EventPhaseStart, {
      can_refresh = function(self, event, target, actor)
        return target == player and actor == player and player.phase == Player.Finish
          and room:getCardArea(fresh.id) == Card.Void
      end,
      on_refresh = function()
        room:obtainCard(player, reused, true, fk.ReasonPrey)
        room:moveCardTo({ reused.id, fresh.id }, Card.DiscardPile, nil, fk.ReasonPut, "test", nil, true)
      end,
    })
    room:addSkill(move:createSkill())
    GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Finish })):exec()
    snapshot = room:serialize(player)
  end)

  lu.assertEquals(cbor.decode(snapshot.banners).qiao_discard_before_turn, { old.id })
  FkTest.runInClient(function()
    local cards = Client.discardCardsForDisplay(ClientInstance)
    lu.assertEquals(table.map(cards, function(card) return { card.id, card.thisTurn } end),
      { { fresh.id, true }, { reused.id, true }, { old.id, false } })
  end)

  FkTest.runInRoom(function()
    GameEvent.Turn:create(TurnData:new(player, "discard_test_extra_turn", { Player.Finish })):exec()
  end)
  FkTest.runInClient(function()
    local cards = Client.discardCardsForDisplay(ClientInstance)
    lu.assertEquals(table.map(cards, function(card) return card.thisTurn end), { false, false, false })
  end)
end

local function watchPindian(room)
  local trace = { commands = {}, results = {}, logs = {} }
  local broadcast = room.doBroadcastNotify
  function room:doBroadcastNotify(command, data, ...)
    if command == "QiaoPindianStart" or command == "QiaoPindianResult" then
      table.insert(trace.commands, command)
      if command == "QiaoPindianResult" then table.insert(trace.results, data) end
    elseif command == "GameLog" then
      table.insert(trace.logs, data)
    end
    return broadcast(self, command, data, ...)
  end
  return trace
end

local function giveCard(room, player, name, number)
  local card = room:printCard(name, Card.Heart, number)
  room:obtainCard(player, card, false, fk.ReasonJustMove)
  return card
end

function Testqiao_room_records:testMultiTargetThenConsecutivePindian()
  local room = FkTest.room
  local trace = watchPindian(room)
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
  lu.assertEquals(trace.commands, { "QiaoPindianStart", "QiaoPindianResult", "QiaoPindianStart", "QiaoPindianResult" })
  local first, second = trace.results[1], trace.results[2]
  lu.assertEquals(first.cards[1], { seat = a.seat, name = "qiao__slash", rank = "6", number = 6, suit = "heart", points = 9 })
  lu.assertEquals({ first.cards[2].winner, first.cards[3].winner, first.cards[4].winner }, { a.seat, 0, d.seat })
  lu.assertEquals({ second.cards[1].seat, second.cards[2].winner }, { b.seat, a.seat })
  lu.assertNotNil(table.find(trace.logs, function(log) return log.type == "#QiaoPindianTie" and log.to[1] == c.id end))
  lu.assertNotNil(table.find(trace.logs, function(log) return log.type == "#QiaoPindianWinner" and log.arg == d.seat end))
end

function Testqiao_room_records:testJointPindianWinnerAndTiedLeaders()
  local room = FkTest.room
  local trace = watchPindian(room)
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
  lu.assertEquals(#trace.results, 2)
  for i, record in ipairs(trace.results) do
    lu.assertEquals({ record.joint, record.winner, #record.cards }, { true, i == 1 and b.seat or 0, 3 })
  end
  lu.assertNotNil(table.find(trace.logs, function(log) return log.type == "#ShowJointPindianWinner" end))
  lu.assertNotNil(table.find(trace.logs, function(log) return log.type == "#JointPindianNoWinner" end))
  lu.assertNil(table.find(trace.logs, function(log) return log.type == "#QiaoPindianTie" end))
end

return { name = "qiao_room_records" }
