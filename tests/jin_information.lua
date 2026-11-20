-- JIN003 昭然 / JIN007 识人：信息与隐藏选牌入口。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local ZHAORAN = "qiao__skill_jin003_1"
local SHIREN = "qiao__skill_jin007_1"

Testqiao_jin_information = {}
Testqiao_jin_information.tearDown = support.clearRoom

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function prepare(main)
  local room = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "wei" })
    for _, q in ipairs(room.players) do
      local ids = q:getCardIds("he")
      if #ids > 0 then
        room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
      end
    end
    skill_test.installDualGenerals(room, room.players[1], {
      main = main,
      deputy = "qiao_test__jin_2",
      kingdom = "jin",
    })
    room.current = room.players[1]
    room.players[1].phase = Player.Play
  end)
  return room
end

local function give(room, player, specs)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room:obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

function Testqiao_jin_information:testZhaoranVisibilityAndLostLastSuit()
  local room = prepare("qiao_heg__jin003")
  local p, viewer = room.players[1], room.players[2]
  local heart = give(room, p, { { "jink", Card.Heart, 3 } })[1]

  FkTest.setNextReplies(p, { "1" })
  inRoom(function()
    room.logic:trigger(fk.EventPhaseStart, p, { phase = Player.Play })
  end)
  lu.assertTrue(p:getMark("qiao_jin003_1_open-phase") > 0)
  lu.assertTrue(viewer:cardVisible(heart))

  -- 真实弃置最后一张红桃：只识别一次，选择摸一张。
  FkTest.setNextReplies(p, { { "qiao__skill_jin003_1-draw" } })
  inRoom(function()
    room:throwCard({ heart }, "test", p, p)
  end)
  lu.assertTrue(table.contains(p:getTableMark("qiao_jin003_1_lost_suits-phase"), Card.Heart))
end

function Testqiao_jin_information:testShirenHiddenPickThenDeclareAndRevealOne()
  local room = prepare("qiao_heg__jin007")
  local p, p2, p3 = room.players[1], room.players[2], room.players[3]
  local c2 = give(room, p2, { { "jink", Card.Heart, 4 } })[1]
  local c3 = give(room, p3, { { "peach", Card.Heart, 5 } })[1]
  local declarations = {}
  local sendLog = room.sendLog
  room.sendLog = function(self, log)
    if log.type == "#qiao__skill_jin007_1-declared" then
      table.insert(declarations, log)
    end
    return sendLog(self, log)
  end

  -- 隐藏选两张，再依次声明；最后只展示并获得者一张。
  FkTest.setNextReplies(p, {
    "1",
    FkTest.ReplyChoosePlayer({ p2 }),
    FkTest.ReplyChoosePlayer({ p3 }),
    FkTest.ReplyChoosePlayer({ p2 }),
  })
  FkTest.setNextReplies(p2, { { "slash" } })
  FkTest.setNextReplies(p3, { { "peach" } })
  FkTest.setRoomBreakpoint(p, "AskForUseActiveSkill", function(data)
    return data[2] == "#qiao__skill_jin007_1-reveal"
  end)
  inRoom(function()
    p.phase = Player.Start
    room.current = p
    room.logic:trigger(fk.EventPhaseStart, p, { phase = Player.Start })
  end)

  lu.assertEquals(#declarations, 2)
  lu.assertEquals({ declarations[1].from, declarations[1].arg }, { p2.id, "slash" })
  lu.assertEquals({ declarations[2].from, declarations[2].arg }, { p3.id, "peach" })
  lu.assertNil(declarations[1].card)
  lu.assertNil(declarations[2].card)
  lu.assertFalse(p:cardVisible(c2))
  lu.assertFalse(p:cardVisible(c3))
  FkTest.runInClient(function()
    local handler = ClientInstance.current_request_handler
    lu.assertEquals(handler.skill_name, "choose_players_skill")
    local tips = require "ltk.client.util"
    lu.assertEquals(tips:getTargetTip(p2.id), { { content = Fk:translate("slash"), type = "normal" } })
    lu.assertEquals(tips:getTargetTip(p3.id), { { content = Fk:translate("peach"), type = "normal" } })
    lu.assertEquals(tips:getTargetTip(p.id), {})
  end)
  FkTest.resumeRoom()
  room.sendLog = sendLog

  -- p2 实际为闪、声明杀：不同，获得其余被选择的 p3 牌。
  lu.assertEquals(#p:getCardIds("h"), 2)
  lu.assertFalse(table.contains(p2:getCardIds("h"), c2))
  lu.assertFalse(table.contains(p3:getCardIds("h"), c3))
end

return { name = "qiao_jin_information" }
