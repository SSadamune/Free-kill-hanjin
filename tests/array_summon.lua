local H = require "packages.hegemony.util"
local A = require "packages.qiao.pkg.qiao_mode.rules.array_summon"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"
local support = __dofile("../../../tests/support/hegemony.lua")
local fixture = __dofile("../../../tests/support/skill_test.lua")
local clientRoom = __dofile("../../../tests/support/client_room.lua")

Testqiao_array_summon = { setup = support.initQiaoRoom, tearDown = support.clearRoom }

local function prepare(main, kingdom, deputy)
  local room = FkTest.room
  local owner = room.players[1]
  fixture.installBlankGenerals(room, "qun")
  fixture.installDualGenerals(room, owner, {
    main = "qiao_heg__" .. main, deputy = deputy or "qiao_test__" .. kingdom .. "_2", kingdom = kingdom,
  })
  owner:hideGeneral(false)
  owner:revealGeneral(false)
  room.current, owner.phase = owner, Player.Play
  return room, owner
end

local function hide(room, seat, kingdom, main, deputy)
  local player = room.players[seat]
  fixture.installDualGenerals(room, player, {
    main = main or "qiao_test__" .. kingdom .. "_1",
    deputy = deputy or "qiao_test__" .. kingdom .. "_2", kingdom = kingdom,
  })
  player:hideGeneral(false)
  player:hideGeneral(true)
  room:setPlayerProperty(player, "kingdom", "unknown")
  return player
end

local function play(room, owner, answer, reply)
  local asked = {}
  fixture.withSkillRequests(room, A.skill, {
    askToChoice = function(_, who, params)
      if who ~= owner then table.insert(asked, who.seat) end
      local choice = answer and answer(who, params) or "Cancel"
      lu.assertTrue(table.contains(params.choices, choice), "无法选择 " .. choice)
      return choice
    end,
  }, function()
    room:handleUseCardReply(owner, reply or FkTest.ReplyUseSkill(A.skill, {}, {}), nil)
  end)
  return asked
end

function Testqiao_array_summon:testClientConfirmAndFormationChainInBothDirections()
  FkTest.runInRoom(function()
    local room, owner = prepare("wei018", "wei")
    hide(room, 2, "wei")
    hide(room, 3, "wei")
    hide(room, 8, "wei")
    local reply
    clientRoom.run(room, function(players)
      local me = players[1]
      for _, p in ipairs(players) do
        p.mark.__heg_general, p.mark.__heg_deputy, p.mark.__heg_kingdom = nil, nil, nil
      end
      local board = Fk:getBoardGame("qiao_heg_mode")
      local client = board.client_klass:new(ClientInstance.client)
      local handler = client.request_handlers.PlayCard:new(me)
      handler:setup()
      lu.assertTrue(handler:skillButtonValidity(A.skill))
      handler:selectSkill(A.skill, {selected = true})
      lu.assertEquals(handler.skill_name, A.skill)
      lu.assertFalse(handler:targetValidity(players[2].id))
      for _, id in ipairs(me:getCardIds("h")) do lu.assertFalse(handler:cardValidity(id)) end
      lu.assertTrue(handler:feasible())
      local notify = ClientInstance.notifyUI
      ClientInstance.notifyUI = function(_, command, payload)
        if command == "ReplyToServer" then reply = payload end
      end
      local ok, err = pcall(function() handler:doOKButton() end)
      ClientInstance.notifyUI = notify
      handler:_finish()
      assert(ok, err)
    end)
    lu.assertEquals(reply.card.skill, A.skill)
    local asked = play(room, owner, function(who)
      if who.seat == 2 then return "revealAll" end
      if who.seat == 8 then return "revealDeputy:::qiao_test__wei_2" end
      return "Cancel"
    end, reply)
    lu.assertEquals(asked, {2, 3, 8})
    lu.assertTrue(H.inFormationRelation(owner, room.players[2]))
    lu.assertTrue(H.inFormationRelation(owner, room.players[8]))
    lu.assertEquals(room.players[3].kingdom, "unknown")
    lu.assertEquals(room.players[8].general, "anjiang")
    lu.assertEquals(owner:usedSkillTimes(A.skill, Player.HistoryPhase), 1)
    lu.assertEquals(play(room, owner), {})
    lu.assertEquals(owner:usedSkillTimes(A.skill, Player.HistoryPhase), 1)
  end)
end

function Testqiao_array_summon:testSiegeBothDirectionsAndIndependentHuyi()
  FkTest.runInRoom(function()
    local room, owner = prepare("han014", "han")
    hide(room, 3, "han")
    hide(room, 7, "han")
    local asked = {}
    for _, seat in ipairs({3, 7}) do
      local who = room.players[seat]
      FkTest.setRoomBreakpoint(who, "AskForChoices", function(data)
        if data[5] == A.skill then table.insert(asked, seat) end
        return false
      end)
      FkTest.setNextReplies(who, {{"revealMain:::qiao_test__han_1"}})
    end
    room:handleUseCardReply(owner, FkTest.ReplyUseSkill(A.skill, {}, {}), nil)
    lu.assertEquals(asked, {3, 7})
    lu.assertTrue(H.inSiegeRelation(owner, room.players[3], room.players[2]))
    lu.assertTrue(H.inSiegeRelation(owner, room.players[7], room.players[8]))
    lu.assertEquals(owner:usedSkillTimes("qiao__skill_han014_2", Player.HistoryTurn), 0)
  end)
end

function Testqiao_array_summon:testOnlyReverseRouteAndIneligibleResponse()
  FkTest.runInRoom(function()
    local room, owner = prepare("shu012", "shu")
    local unknown = hide(room, 8, "wu")
    lu.assertTrue(Fk.skills[A.skill]:canUse(owner))
    lu.assertEquals(play(room, owner, function(_, params)
      lu.assertEquals(params.choices, {"Cancel"})
      return "Cancel"
    end), {8})
    lu.assertEquals(unknown.kingdom, "unknown")
    lu.assertEquals(owner:usedSkillTimes(A.skill, Player.HistoryPhase), 1)
  end)
end

function Testqiao_array_summon:testSharedUseForTwoArraysAndNewPlayPhase()
  FkTest.runInRoom(function()
    local room, owner = prepare("jin023", "jin", "qiao_heg__qun024")
    hide(room, 3, "jin")
    hide(room, 8, "jin")
    local asked = play(room, owner, function(who)
      if who == owner then return "qiao_array_siege" end
      return "Cancel"
    end)
    lu.assertEquals(asked, {3})
    lu.assertEquals(play(room, owner), {})
    owner:setSkillUseHistory("", 0, Player.HistoryPhase)
    lu.assertEquals(play(room, owner, function(who)
      return who == owner and "qiao_array_formation" or "Cancel"
    end), {8})
  end)
end

function Testqiao_array_summon:testFourThenThreeSurvivorsAndSameResponderOnce()
  FkTest.runInRoom(function()
    local room, owner = prepare("wu017", "wu")
    local hidden = hide(room, 3, "wu")
    for i = 5, 8 do room.players[i].dead = true end
    room.alive_players = {owner, room.players[2], hidden, room.players[4]}
    lu.assertEquals(play(room, owner), {3})
    room.players[4].dead = true
    table.remove(room.alive_players)
    owner:setSkillUseHistory("", 0, Player.HistoryPhase)
    lu.assertEquals(play(room, owner, function() return "revealAll" end), {3})
    lu.assertTrue(H.inSiegeRelation(owner, hidden, room.players[2]))
  end)
end

function Testqiao_array_summon:testPublicEntryFollowsGeneralCardAndPhase()
  FkTest.runInRoom(function()
    local room, owner = prepare("wei018", "wei")
    hide(room, 2, "wei")
    owner:hideGeneral(false)
    lu.assertFalse(owner:hasShownSkill(A.skill))
    lu.assertEquals(play(room, owner), {})
    lu.assertEquals(owner:usedSkillTimes(A.skill), 0)
    local source = "qiao__skill_shu012_2"
    Cards.grant(room, owner.deputyGeneral, source)
    lu.assertFalse(owner:hasShownSkill(A.skill), "天覆仅在主将位生效")
    Cards.grant(room, owner.deputyGeneral, "qiao__skill_qun024_2")
    lu.assertTrue(Fk.skills[A.skill]:canUse(owner), "明置将牌后天取得龙飞")
    owner.phase = Player.Start
    lu.assertEquals(play(room, owner), {})
    lu.assertEquals(owner:usedSkillTimes(A.skill), 0)
    owner.phase = Player.Play
    Cards.revoke(room, owner.deputyGeneral, "qiao__skill_qun024_2")
    lu.assertFalse(owner:hasShownSkill(A.skill))
  end)
end

function Testqiao_array_summon:testGuestAllegianceAndWildMainMayOnlyRevealDeputy()
  FkTest.runInRoom(function()
    local room, owner = prepare("wei018", "wei")
    -- 首次明置按选将时登记的本局势力。将牌的印刷势力可以不同。
    hide(room, 2, "wei", "qiao_test__wu_1", "qiao_test__wu_2")
    local wild = hide(room, 8, "wei")
    room:setPlayerMark(wild, "__heg_wild", 1)
    local asked = play(room, owner, function(who, params)
      if who == wild then
        lu.assertEquals(params.choices, {"revealDeputy:::qiao_test__wei_2", "Cancel"})
        return params.choices[1]
      end
      return "revealMain:::qiao_test__wu_1"
    end)
    lu.assertEquals(asked, {2, 8})
    lu.assertEquals(room.players[2].kingdom, "wei")
    lu.assertEquals(wild.general, "anjiang")
    lu.assertEquals(wild.kingdom, "wei")
  end)
end

function Testqiao_array_summon:testCancelledRevealRequestsLeaveBothGeneralsHidden()
  FkTest.runInRoom(function()
    local room, owner = prepare("wei018", "wei")
    local second = hide(room, 2, "wei")
    local last = hide(room, 8, "wei")
    room:setPlayerMark(second, MarkEnum.RevealProhibited, {"m", "d"})
    room:setPlayerMark(last, MarkEnum.RevealProhibited, {"m"})
    local observed = {}
    for _, who in ipairs({second, last}) do
      FkTest.setRoomBreakpoint(who, "AskForChoices", function(data)
        if data[5] == A.skill then
          table.insert(observed, who.seat)
          lu.assertTrue(data[4], "响应询问须可取消")
          lu.assertEquals(data[1], who == second and {"Cancel"} or {"revealDeputy:::qiao_test__wei_2", "Cancel"})
        end
        return false
      end)
      -- 先点可见的取消选项，再走原生请求未收到有效选择的取消分支。
      FkTest.setNextReplies(who, who == second and {{"Cancel"}} or {{}})
    end
    room:handleUseCardReply(owner, FkTest.ReplyUseSkill(A.skill, {}, {}), nil)
    lu.assertEquals(observed, {2, 8})
    lu.assertEquals(last.kingdom, "unknown")
    lu.assertEquals(second.general, "anjiang")
    lu.assertEquals(owner:usedSkillTimes(A.skill, Player.HistoryPhase), 1)
  end)
end

function Testqiao_array_summon:testTenPlayerRoomStopsAsSoonAsFourthAllyReveals()
  support.clearRoom()
  local backend = FkTest.createFakeRoom({1, 2, 3, 4, 5, 6, 7, 8, 9, 10})
  -- 引擎默认测试客户端只登记前八座，再同步本房其余两位。
  for seat = 9, 10 do
    local who = backend:getPlayers():at(seat - 1)
    ClientInstance:addPlayer({who:getId(), who:getScreenName(), who:getAvatar(), true, 0})
  end
  support.createRoom {mode = "qiao_heg_mode", backend = backend, realSelection = true}
  FkTest.runInRoom(function()
    local room, owner = prepare("wei018", "wei")
    lu.assertEquals(#room.players, 10)
    local first = hide(room, 2, "wei")
    local other = hide(room, 10, "wei")
    for _, seat in ipairs({4, 5}) do room:setPlayerProperty(room.players[seat], "kingdom", "wei") end
    room.players[4].dead = true
    table.removeOne(room.alive_players, room.players[4])
    room:setPlayerMark(room.players[5], MarkEnum.PlayerRemoved .. "-turn", 1)
    local asked = {}
    for _, who in ipairs({first, other}) do
      FkTest.setRoomBreakpoint(who, "AskForChoices", function(data)
        if data[5] == A.skill then table.insert(asked, who.seat) end
        return false
      end)
      FkTest.setNextReplies(who, {{"revealAll"}})
    end
    room:handleUseCardReply(owner, FkTest.ReplyUseSkill(A.skill, {}, {}), nil)
    lu.assertEquals(asked, {2})
    lu.assertEquals(first.kingdom, "wei")
    lu.assertEquals(other.kingdom, "unknown", "第四人亮将后，另一侧不再询问")
    lu.assertEquals(A.choices(room, owner), {})
  end)
end

return { name = "qiao_array_summon" }
