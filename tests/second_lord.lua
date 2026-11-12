local support = __dofile("../../../tests/support/hegemony.lua")
local content = __dofile("../../../tests/support/ascension_content.lua")
local A = require "packages.hanjin.pkg.hanjin_mode.rules.ascension"
local V = require "packages.hanjin.pkg.hanjin_mode.rules.general_versions"

local G = content.generals

local function create()
  local backend = FkTest.createFakeRoom({ 1, 2, 3, 4, 5, 6, 7, 8 })
  -- Keep the deterministic ban plan away from Wei so succession candidates can
  -- legally join the dead monarch's faction.
  backend._session_data = json.encode {
    hanjin_faction_ban_v1 = { version = 1, winners = { "wu", "qun" }, banned = {} },
  }
  return support.createRoom {
    mode = "hanjin_heg_mode", realSelection = true, backend = backend,
    settings = { hanjin_wild_count = 0 },
  }
end

local function setup()
  local room = create()
  FkTest.runInRoom(function()
    for index, player in ipairs(room.players) do
      local kingdom = index % 2 == 0 and "shu" or "qun"
      content.setupHidden(room, player, "hanjin_test__" .. kingdom .. "_1",
        "hanjin_test__" .. kingdom .. "_2", kingdom)
      room:setPlayerProperty(player, "kingdom", kingdom)
    end
  end)
  return room
end

Testsecond_lord = { setup = setup, tearDown = support.clearRoom }

local function room() return FkTest.room end
local function player(n) return room().players[n] end

local function hidden(p, main, deputy, kingdom)
  content.setupHidden(room(), p, main, deputy, kingdom)
end

local function revealed(p, main, deputy, kingdom)
  content.setupRevealed(room(), p, main, deputy, kingdom)
end

local function triggerTurnStart(p, firstChoice)
  FkTest.cleanNextReplies(p)
  -- The first reply belongs to the HanJin ascension prompt (when offered); the
  -- second cancels the upstream national-war reveal prompt that still follows.
  FkTest.setNextReplies(p, { { firstChoice or "Cancel" }, { "Cancel" } })
  FkTest.runInRoom(function() room().logic:trigger(fk.TurnStart, p, {}) end)
  FkTest.cleanNextReplies(p)
end

local function markDead(p, kingdom)
  -- Reveal directly instead of broadcasting: the victory helper only needs the
  -- final face-up state, and broadcasting property changes for already-dead
  -- fake clients can invalidate the test room's client state.
  local main = p:getMark("__heg_general")
  local deputy = p:getMark("__heg_deputy")
  if type(main) == "string" then p.general = main end
  if type(deputy) == "string" then p.deputyGeneral = deputy end
  p.dead = true
  table.removeOne(room().alive_players, p)
  room():setPlayerProperty(p, "kingdom", kingdom)
end

function Testsecond_lord:testFirstOrdinaryAscensionOccupiesFactionSlot()
  local first, second = player(1), player(2)
  FkTest.runInRoom(function()
    hidden(first, G.wei_normal.name, G.wei_deputy.name, "wei")
    hidden(second, G.wei_normal2.name, G.wei_deputy.name, "wei")
  end)
  FkTest.setNextReplies(first, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(first, A.ASCEND_ACCEPT)
  lu.assertEquals(first.general, G.wei_monarch.name)
  lu.assertEquals(first.kingdom, "wei")
  lu.assertEquals(first:getMark("__heg_general"), G.wei_monarch.name)
  lu.assertEquals(first:getMark("hasShownMainGeneral"), 1)
  lu.assertTrue(first:hasSkill(content.skills.monarch))
  lu.assertFalse(first:hasSkill(content.skills.normal))
  lu.assertTrue(A.has_lord(room(), "wei"))

  -- The second candidate of the same faction must not be offered a normal
  -- ascension once the slot is occupied.
  FkTest.setNextReplies(second, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(second, "Cancel")
  lu.assertEquals(second.general, "anjiang")
  lu.assertEquals(second.kingdom, "unknown")
  lu.assertEquals(first.general, G.wei_monarch.name)
end

function Testsecond_lord:testOrdinaryAscensionNeedsHiddenMainAndFirstTurn()
  local p = player(1)
  FkTest.runInRoom(function()
    revealed(p, G.wei_normal.name, G.wei_deputy.name, "wei")
  end)
  triggerTurnStart(p, "Cancel")
  lu.assertEquals(p.general, G.wei_normal.name)

  FkTest.runInRoom(function()
    hidden(p, G.wei_normal.name, G.wei_deputy.name, "wei")
    room():setPlayerMark(p, A.TURNS_MARK, 1)
  end)
  triggerTurnStart(p, "Cancel")
  lu.assertEquals(p.general, "anjiang")
end

function Testsecond_lord:testAscensionAppliesHpGainOnlyWhenPairMaxIncreases()
  local high = player(1)
  FkTest.runInRoom(function()
    hidden(high, G.wei_normal.name, G.wei_deputy.name, "wei")
  end)
  lu.assertEquals(high.maxHp, 3)
  lu.assertEquals(high.hp, 3)
  FkTest.setNextReplies(high, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(high, A.ASCEND_ACCEPT)
  lu.assertEquals(high.maxHp, 4)
  lu.assertEquals(high.hp, 4)
end

function Testsecond_lord:testAscensionDoesNotChangeHpWhenPairMaxDoesNotIncrease()
  local equal = player(1)
  FkTest.runInRoom(function()
    hidden(equal, G.wei_normal2.name, G.wei_deputy.name, "wei")
  end)
  lu.assertEquals(equal.maxHp, 4)
  FkTest.setNextReplies(equal, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(equal, A.ASCEND_ACCEPT)
  lu.assertEquals(equal.maxHp, 4)
  lu.assertEquals(equal.hp, 4)
  lu.assertEquals(equal.general, G.wei_monarch2.name)
end

function Testsecond_lord:testAscensionKeepsHpWhenPairMaxIsEqual()
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, G.wei_normal3.name, G.wei_deputy.name, "wei")
  end)
  lu.assertEquals(p.maxHp, 4)
  lu.assertEquals(p.hp, 4)
  FkTest.setNextReplies(p, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(p, A.ASCEND_ACCEPT)
  lu.assertEquals(p.general, G.wei_monarch3.name)
  lu.assertEquals(p.maxHp, 4)
  lu.assertEquals(p.hp, 4)
end

function Testsecond_lord:testAscensionRevealsMainAndSyncsKingdomAndSkills()
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, G.wei_normal.name, G.wei_deputy.name, "wei")
  end)
  FkTest.setNextReplies(p, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(p, A.ASCEND_ACCEPT)
  lu.assertNotEquals(p.general, "anjiang")
  lu.assertEquals(p.kingdom, "wei")
  lu.assertEquals(p.general, G.wei_monarch.name)
  lu.assertTrue(p:hasSkill(content.skills.monarch))
  lu.assertFalse(p:hasSkill(content.skills.normal))
  lu.assertEquals(p:getMark("__heg_kingdom"), "wei")
  -- The deputy stays hidden; only the main general was revealed by ascension.
  lu.assertEquals(p.deputyGeneral, "anjiang")
end

function Testsecond_lord:testSuccessionOrderFirstAcceptorAndRevealSync()
  local lord, first, second, other = player(1), player(2), player(3), player(4)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    -- Keep the main general revealed while hiding only the deputy.
    lord:hideGeneral(true)
    room():setPlayerProperty(lord, "kingdom", "wei")

    hidden(first, G.wei_normal.name, "hanjin_test__qun_1", "qun")
    hidden(second, G.wei_normal2.name, "hanjin_test__qun_2", "qun")
    room():setCurrent(first)
  end)
  FkTest.setNextReplies(first, { { "Cancel" } })
  FkTest.setNextReplies(second, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)

  lu.assertEquals(first.general, "anjiang")
  lu.assertEquals(first.kingdom, "unknown")
  lu.assertEquals(second.general, G.wei_monarch2.name)
  lu.assertEquals(second.kingdom, "wei")
  lu.assertTrue(A.has_lord(room(), "wei"))
  lu.assertEquals(lord.deputyGeneral, G.wei_deputy.name)
  lu.assertEquals(other.kingdom, "shu")
  lu.assertNotEquals(first.kingdom, "wild")
end

function Testsecond_lord:testSuccessionStopsAtFirstAcceptor()
  local lord, first, second = player(1), player(2), player(3)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(first, G.wei_normal.name, "hanjin_test__qun_1", "qun")
    hidden(second, G.wei_normal2.name, "hanjin_test__qun_2", "qun")
    room():setCurrent(first)
  end)
  FkTest.setNextReplies(first, { { A.ASCEND_ACCEPT } })
  FkTest.setNextReplies(second, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertEquals(first.general, G.wei_monarch.name)
  lu.assertEquals(second.general, "anjiang")
end

function Testsecond_lord:testSuccessionAsksFromCurrentSeatInActionOrder()
  local lord, first, second, third = player(1), player(2), player(3), player(4)
  local asked = {}
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(first, G.wei_normal.name, "hanjin_test__qun_1", "qun")
    hidden(second, G.wei_normal2.name, "hanjin_test__qun_2", "qun")
    hidden(third, G.wei_normal3.name, "hanjin_test__qun_1", "qun")
    room():setCurrent(second)
    local currentRoom = room()
    local original = currentRoom.askToChoice
    function currentRoom:askToChoice(target, params)
      if params and params.prompt == "#HanjinSecondLordSuccession" then
        table.insert(asked, target.seat)
      end
      return original(self, target, params)
    end
  end)
  FkTest.setNextReplies(first, { { "Cancel" } })
  FkTest.setNextReplies(second, { { "Cancel" } })
  FkTest.setNextReplies(third, { { "Cancel" } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  -- Seats 3 -> 4 -> 2: action order starts at the current player and wraps.
  lu.assertEquals(asked, { 3, 4, 2 })
end

function Testsecond_lord:testSuccessionHpAndConsumableMarks()
  local lord, candidate = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    room():changeHero(candidate, G.wei_normal.name, false, false, false, false, false)
    room():setPlayerMark(candidate, "__heg_general", G.wei_normal.name)
    room():changeHero(candidate, G.wei_deputy.name, false, true, false, false, false)
    room():setPlayerMark(candidate, "__heg_deputy", G.wei_deputy.name)
    candidate:hideGeneral(false) -- main hidden, deputy stays revealed
    room():setPlayerProperty(candidate, "kingdom", "wei")
    room():setPlayerMark(candidate, "__heg_kingdom", "wei")
    room():setPlayerProperty(candidate, "maxHp", 3)
    room():setPlayerProperty(candidate, "hp", 3)
    room():setCurrent(candidate)
  end)
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)

  lu.assertEquals(candidate.general, G.wei_monarch.name)
  lu.assertEquals(candidate.maxHp, 4)
  lu.assertEquals(candidate.hp, 4)
  lu.assertEquals(candidate:getMark("@!!companion"), 1)
  lu.assertEquals(candidate:getMark("@!!yinyangfish"), 1)
end

function Testsecond_lord:testSpentMarksAreNotGrantedAgainWhenAlreadyRevealed()
  local lord, candidate = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    room():setPlayerProperty(candidate, "maxHp", 3)
    room():setPlayerProperty(candidate, "hp", 3)
    room():setCurrent(candidate)
  end)
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  -- Both cards were already revealed before the ascension, so the ascension is
  -- not the first full reveal and must not grant/spend a new mark.
  lu.assertEquals(candidate:getMark("@!!companion"), 0)
  lu.assertEquals(candidate:getMark("@!!yinyangfish"), 0)
end

function Testsecond_lord:testNoSuccessorConvertsFactionAndKeepsExistingWild()
  local lord, hiddenAlly, revealedAlly, wildAlly = player(1), player(2), player(3), player(4)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(hiddenAlly, G.wei_normal.name, "hanjin_test__qun_1", "wei")
    revealed(revealedAlly, G.wei_normal2.name, G.wei_deputy.name, "wei")
    revealed(wildAlly, "hanjin_test__wild_1", "hanjin_test__qun_2", "wild")
    room():setPlayerMark(wildAlly, "__heg_wild", 1)
    room():setCurrent(revealedAlly)
  end)
  FkTest.setNextReplies(hiddenAlly, { { "Cancel" } })
  FkTest.setNextReplies(revealedAlly, { { "Cancel" } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)

  lu.assertFalse(A.has_lord(room(), "wei"))
  lu.assertEquals(hiddenAlly:getMark("__heg_kingdom"), "wild")
  lu.assertEquals(hiddenAlly.kingdom, "unknown")
  lu.assertEquals(hiddenAlly.role, "wild")
  lu.assertEquals(revealedAlly.kingdom, "wild")
  -- An already-wild character must not be restored by a successor or by the
  -- lord's death conversion.
  lu.assertEquals(wildAlly.kingdom, "wild")
  lu.assertEquals(wildAlly:getMark("__heg_wild"), 1)
end

function Testsecond_lord:testOverpopulatedCandidateIsNotAsked()
  local lord, candidate = player(1), player(2)
  local allies = { player(3), player(4), player(5) }
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, "hanjin_test__qun_1", "wei")
    for _, ally in ipairs(allies) do
      revealed(ally, G.wei_normal2.name, G.wei_deputy.name, "wei")
    end
    room():setCurrent(candidate)
  end)
  -- Four other Wei characters (the dead monarch and three allies) reach the
  -- 8-player half threshold, so the candidate cannot legally join.
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  for _, ally in ipairs(allies) do FkTest.setNextReplies(ally, { { "Cancel" } }) end
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertNotEquals(candidate.general, G.wei_monarch.name)
  lu.assertEquals(candidate:getMark("__heg_kingdom"), "wild")
end

function Testsecond_lord:testAlreadyWildCandidateCannotSucceed()
  local lord, candidate = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(candidate, G.wei_normal.name, G.wei_deputy.name, "wild")
    room():setPlayerMark(candidate, "__heg_kingdom", "wei")
    room():setCurrent(candidate)
  end)
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertEquals(candidate.kingdom, "wild")
  lu.assertEquals(candidate.general, G.wei_normal.name)
  lu.assertNotEquals(candidate.general, G.wei_monarch.name)
end

function Testsecond_lord:testLordPresenceDoesNotPreventOverpopulationWild()
  local lord, candidate = player(1), player(2)
  local allies = { player(3), player(4), player(5) }
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    for _, ally in ipairs(allies) do
      revealed(ally, G.wei_normal2.name, G.wei_deputy.name, "wei")
    end
  end)
  -- Four other Wei characters meet the 8-player half threshold. Even though a
  -- monarch is present, the revealing candidate must still become a wild
  -- character; the upstream "a lord prevents wild conversion" shortcut is not
  -- used in this mode.
  FkTest.runInRoom(function() candidate:revealGeneral(false) end)
  lu.assertEquals(candidate.kingdom, "wild")
  lu.assertEquals(candidate.general, G.wei_normal.name)
end

function Testsecond_lord:testSuccessorDoesNotRestoreExistingWild()
  local lord, candidate, wildAlly = player(1), player(2), player(3)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(wildAlly, "hanjin_test__wild_1", G.wei_deputy.name, "wild")
    room():setPlayerMark(wildAlly, "__heg_kingdom", "wei")
    room():setCurrent(candidate)
  end)
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertEquals(candidate.general, G.wei_monarch.name)
  lu.assertEquals(wildAlly.kingdom, "wild")
  lu.assertEquals(wildAlly:getMark("__heg_kingdom"), "wei")
end

function Testsecond_lord:testProhibitRevealBlocksSuccession()
  local lord, candidate = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    room():setPlayerMark(candidate, "RevealProhibited", { "m" })
    room():setCurrent(candidate)
  end)
  lu.assertNil(A.lord_candidate(room(), candidate, "wei"))
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertEquals(candidate.general, "anjiang")
  lu.assertEquals(candidate:getMark("__heg_kingdom"), "wild")
end

function Testsecond_lord:testUnifiedVersionRegistryQueries()
  lu.assertTrue(V.is_lord(G.wei_monarch.name))
  lu.assertFalse(V.is_lord(G.wei_normal.name))
  lu.assertEquals(V.lord_version(G.wei_normal.name), G.wei_monarch.name)
  lu.assertEquals(V.lord_kingdoms(G.wei_monarch.name), { "wei" })
  lu.assertTrue(V.is_loyalty(G.loyalty_simple.name))
  lu.assertEquals(V.loyalty_versions(G.wild_simple.name), { G.loyalty_simple.name })
  lu.assertEquals(V.original_of(G.loyalty_simple.name), G.wild_simple.name)
  FkTest.runInRoom(function()
    lu.assertFalse(V.selectable(G.wei_monarch.name, room()))
    lu.assertTrue(V.selectable(G.wei_normal.name, room()))
  end)
end

function Testsecond_lord:testWinnerWithLordEndsForUniqueFactionAboveHalf()
  local mode = Fk.game_modes.hanjin_heg_mode
  local p1, p2, dead = player(1), player(2), player(6)
  local winner
  FkTest.runInRoom(function()
    revealed(p1, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(p2, G.wei_normal.name, G.wei_deputy.name, "wei")
    for index = 3, 5 do markDead(player(index), "wei") end
    for index = 6, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(dead)
  end)
  -- Five of eight players are Wei, but the remaining faction is unique. A lord
  -- must not be required for this board to end.
  lu.assertEquals(#winner, 2)
  lu.assertTrue(winner[1] == p1)
  lu.assertTrue(winner[2] == p2)
end

function Testsecond_lord:testWinnerWithoutLordEndsForUniqueFactionAboveHalf()
  local mode = Fk.game_modes.hanjin_heg_mode
  local p1, p2, dead = player(1), player(2), player(6)
  local winner
  FkTest.runInRoom(function()
    revealed(p1, G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(p2, G.wei_normal2.name, G.wei_deputy.name, "wei")
    for index = 3, 5 do markDead(player(index), "wei") end
    for index = 6, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(dead)
  end)
  -- Same five-of-eight board as above, without a lord: the result is unchanged.
  lu.assertEquals(#winner, 2)
  lu.assertTrue(winner[1] == p1)
  lu.assertTrue(winner[2] == p2)
end

function Testsecond_lord:testWinnerWithAndWithoutLordSameUniqueFaction()
  local mode = Fk.game_modes.hanjin_heg_mode
  local p1, p2, dead = player(1), player(2), player(6)
  local withoutLord, withLord
  FkTest.runInRoom(function()
    revealed(p1, G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(p2, G.wei_normal2.name, G.wei_deputy.name, "wei")
    for index = 3, 5 do markDead(player(index), "wei") end
    for index = 6, 8 do markDead(player(index), "shu") end
    withoutLord = mode:getWinner(dead)

    revealed(p1, G.wei_monarch.name, G.wei_deputy.name, "wei")
    withLord = mode:getWinner(dead)
  end)
  lu.assertEquals(#withoutLord, 2)
  lu.assertEquals(#withLord, 2)
  lu.assertEquals(withoutLord[1].id, withLord[1].id)
  lu.assertEquals(withoutLord[2].id, withLord[2].id)
end

function Testsecond_lord:testWinnerMultipleFactionsDoNotEndDespiteLordAndMajority()
  local mode = Fk.game_modes.hanjin_heg_mode
  local winner
  FkTest.runInRoom(function()
    revealed(player(1), G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(player(2), G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(player(3), G.wei_normal2.name, G.wei_deputy.name, "wei")
    revealed(player(4), G.wei_normal3.name, G.wei_deputy.name, "wei")
    revealed(player(5), "hanjin_test__wei_4", "hanjin_test__qun_1", "wei")
    revealed(player(6), G.shu_plain.name, "hanjin_test__shu_2", "shu")
    markDead(player(7), "shu")
    markDead(player(8), "shu")
    winner = mode:getWinner(player(8))
  end)
  -- Five Wei (with a lord) still coexist with a living Shu character.
  lu.assertEquals(winner, "")
end

function Testsecond_lord:testWinnerRejectsRegularAndOverpopulationWild()
  local mode = Fk.game_modes.hanjin_heg_mode
  local p1, p2, dead = player(1), player(2), player(6)
  local winner
  FkTest.runInRoom(function()
    revealed(p1, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(p2, "hanjin_test__wild_1", G.wei_deputy.name, "wild")
    room():setPlayerMark(p2, "__heg_kingdom", "wei")
    for index = 3, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(dead)
  end)
  lu.assertEquals(winner, "")
  -- A wild character is still independent and must not be merged back into Wei.
  lu.assertEquals(p2.kingdom, "wild")
  lu.assertEquals(p2:getMark("__heg_kingdom"), "wei")
end

function Testsecond_lord:testWinnerTreatsEachWildAsSeparateFaction()
  local mode = Fk.game_modes.hanjin_heg_mode
  local winner
  FkTest.runInRoom(function()
    revealed(player(1), "hanjin_test__wild_1", "hanjin_test__qun_1", "wild")
    revealed(player(2), "hanjin_test__wild_2", "hanjin_test__qun_2", "wild")
    for index = 3, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(player(6))
  end)
  -- Two living wild characters are two factions, even when both are wild.
  lu.assertEquals(winner, "")
end

function Testsecond_lord:testWinnerSingleWildWins()
  local mode = Fk.game_modes.hanjin_heg_mode
  local p1 = player(1)
  local winner
  FkTest.runInRoom(function()
    revealed(p1, "hanjin_test__wild_1", "hanjin_test__qun_1", "wild")
    for index = 2, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(player(6))
  end)
  lu.assertEquals(#winner, 1)
  lu.assertTrue(winner[1] == p1)
end

function Testsecond_lord:testWinnerHiddenGeneralsFollowExpectedFactionSemantics()
  local mode = Fk.game_modes.hanjin_heg_mode
  local p1, p2 = player(1), player(2)
  local allHidden, matchingHidden, differentHidden
  FkTest.runInRoom(function()
    hidden(p1, G.wei_normal.name, G.wei_deputy.name, "wei")
    hidden(p2, G.wei_normal2.name, G.wei_deputy.name, "wei")
    for index = 3, 8 do markDead(player(index), "shu") end
    allHidden = mode:getWinner(player(6))

    revealed(p1, G.wei_normal.name, G.wei_deputy.name, "wei")
    hidden(p2, G.wei_normal2.name, G.wei_deputy.name, "wei")
    matchingHidden = mode:getWinner(player(6))

    hidden(p2, G.wei_normal2.name, G.wei_deputy.name, "shu")
    differentHidden = mode:getWinner(player(6))
  end)
  -- unknown is not a shared faction: two hidden characters cannot win together.
  lu.assertEquals(allHidden, "")
  -- An expected Wei hidden character joins the known Wei anchor, as in national war.
  lu.assertEquals(#matchingHidden, 2)
  -- A hidden character expected to be Shu does not join the Wei anchor.
  lu.assertEquals(differentHidden, "")
end

function Testsecond_lord:testRealDeathEndsGameForUniqueRegularFactionAboveHalf()
  FkTest.runInRoom(function()
    for index = 1, 5 do
      revealed(player(index), "hanjin_test__wei_" .. index, "hanjin_test__qun_" .. index, "wei")
    end
    for index = 6, 8 do
      revealed(player(index), "hanjin_test__shu_" .. index, "hanjin_test__qun_" .. index, "shu")
    end
  end)
  for index = 8, 6, -1 do
    FkTest.runInRoom(function() room():killPlayer { who = player(index) } end)
  end
  -- The last Shu death happens through the real death + GameOverJudge flow.
  lu.assertTrue(room().game_finished)
  local summary = room():getBanner("GameSummary")
  for index = 1, 5 do
    lu.assertEquals(summary[player(index).seat].win, "Game Win")
  end
  lu.assertEquals(summary[player(6).seat].win, "Game Lose")
  local saved = json.decode(room().room:getSessionData()).hanjin_faction_ban_v1
  lu.assertEquals(saved.winners, { "wei" })
end

function Testsecond_lord:testRealDeathSuccessionThenGameOver()
  local lord, successor, ally = player(1), player(2), player(3)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(successor, G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(ally, "hanjin_test__wei_3", "hanjin_test__qun_3", "wei")
    for index = 4, 8 do markDead(player(index), "shu") end
    room():setCurrent(successor)
  end)
  FkTest.setNextReplies(successor, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  -- Succession runs in BeforeGameOverJudge, then the real GameOverJudge sees the
  -- unique Wei faction and ends the game with the successor as a winner.
  lu.assertEquals(successor.general, G.wei_monarch.name)
  lu.assertTrue(room().game_finished)
  local summary = room():getBanner("GameSummary")
  lu.assertEquals(summary[successor.seat].win, "Game Win")
  lu.assertEquals(summary[ally.seat].win, "Game Win")
  lu.assertEquals(summary[lord.seat].win, "Game Lose")
  local saved = json.decode(room().room:getSessionData()).hanjin_faction_ban_v1
  lu.assertEquals(saved.winners, { "wei" })
end

function Testsecond_lord:testRealNoSuccessorConvertsLastAllyToWildAndWins()
  local lord, ally = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(ally, G.wei_normal.name, G.wei_deputy.name, "wei")
    for index = 3, 8 do markDead(player(index), "shu") end
    room():setCurrent(ally)
  end)
  FkTest.setNextReplies(ally, { { "Cancel" } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  -- No successor: the last ally becomes a wild character and is the sole survivor.
  lu.assertEquals(ally.kingdom, "wild")
  lu.assertTrue(room().game_finished)
  local summary = room():getBanner("GameSummary")
  lu.assertEquals(summary[ally.seat].win, "Game Win")
  -- A wild victory must not be recorded as a regular kingdom win.
  local saved = json.decode(room().room:getSessionData()).hanjin_faction_ban_v1
  lu.assertEquals(saved.winners, {})
end

function Testsecond_lord:testRealNoSuccessorMultipleWildsKeepGameRunning()
  local lord, first, second = player(1), player(2), player(3)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(first, G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(second, G.wei_normal2.name, G.wei_deputy.name, "wei")
    for index = 4, 8 do markDead(player(index), "shu") end
    room():setCurrent(first)
  end)
  FkTest.setNextReplies(first, { { "Cancel" } })
  FkTest.setNextReplies(second, { { "Cancel" } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  -- Both surviving Wei characters become independent wild factions; no unique
  -- faction remains, so the real game-over flow must not finish the game.
  lu.assertEquals(first.kingdom, "wild")
  lu.assertEquals(second.kingdom, "wild")
  lu.assertFalse(room().game_finished)
end

return { name = "second_lord" }
