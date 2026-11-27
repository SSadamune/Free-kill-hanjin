local rooms = __dofile("../../../tests/support/hegemony.lua")
local fixture = __dofile("../../../tests/support/skill_test.lua")
local generals = require "packages.qiao.pkg.qiao_bingqing.data.shi_vector"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local E = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local function id(key) return "qiao__skill_" .. key end
local function give(room, p, name, suit)
  local card = room:printCard(name, suit or Card.Club, 7)
  room:obtainCard(p, card, false, fk.ReasonJustMove)
  return card
end
local function asGeneral(room, p, key, deputy)
  fixture.installDualGenerals(room, p, {
    main = deputy and "qiao_test__han_1" or "qiao_heg__" .. key,
    deputy = deputy and "qiao_heg__" .. key or "qiao_test__han_2",
    kingdom = "han",
  })
end
local function run(fn)
  local finished = false
  FkTest.runInRoom(function()
    local room = FkTest.room
    fn(room, table.unpack(room.players))
    finished = true
  end)
  lu.assertTrue(finished, "场景必须运行到最后一个断言")
end

Testqiao_shi_vector = {
  setup = function()
    rooms.initQiaoRoom()
    run(function(room, first)
      fixture.installBlankGenerals(room, "han")
      room.current = first
      first.phase = Player.Play
    end)
  end,
  tearDown = rooms.clearRoom,
}
local T = Testqiao_shi_vector

function T:testJingchuRemovesUntilTwoRemainAndOnlyThenDrawsAndGives()
  run(function(room, tian, remaining, a, b)
    asGeneral(room, tian, "han047")
    local before, others = tian:getHandcardNum(), remaining:getHandcardNum()
    local queue = table.filter(room:getPresentPlayers(), function(to) return to ~= tian and to ~= remaining end)
    local count = #queue
    fixture.withSkillRequests(room, id("han047_2"), {
      askToChoosePlayers = function(_, _, params)
        lu.assertFalse(table.contains(params.targets, tian))
        return { table.remove(queue, 1) }
      end,
      askToCards = function() return { tian:getCardIds("h")[1] } end,
      askToChoice = function() return "Cancel" end,
    }, function()
      for i = 1, count do
        room.logic:trigger(fk.CardUseFinished, tian, { from = tian, card = Fk:cloneCard("qiao__slash"), tos = {} })
        if i < count then lu.assertEquals(tian:getHandcardNum(), before) end
      end
    end)
    lu.assertTrue(a:isRemoved() and b:isRemoved())
    lu.assertEquals(tian:getHandcardNum(), before + 1)
    lu.assertEquals(remaining:getHandcardNum(), others + 1)
  end)
end

local function checkSuolingFocus(suit)
  run(function(room, yuan, receiver, target)
    asGeneral(room, yuan, "han051")
    room:throwCard(receiver:getCardIds("h"), "test", receiver, receiver)
    give(room, receiver, "qiao__jink", suit)
    local gift = give(room, yuan, "qiao__jink", Card.Spade)
    local choosing, focus = false, 0
    local notify = room.doBroadcastNotify
    room.doBroadcastNotify = function(self, command, data, ...)
      if choosing and command == "MoveFocus" and table.contains(data[1], receiver.id) then focus = focus + 1 end
      return notify(self, command, data, ...)
    end
    fixture.withSkillRequests(room, id("han051_1"), {
      askToCards = function(self, who, params, original)
        choosing = true
        local reply = original(self, who, params)
        choosing = false
        return reply
      end,
      askToUseCard = function() return nil end,
    }, function()
      room:handleUseCardReply(yuan, FkTest.ReplyUseSkill(id("han051_1"), { receiver, target }, { gift.id }))
    end)
    room.doBroadcastNotify = notify
    lu.assertEquals(focus, 1)
    lu.assertIs(room:getCardOwner(gift.id), receiver)
  end)
end
return { name = "qiao_shi_vector" }
