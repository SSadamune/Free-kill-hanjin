local support = __dofile("../../../tests/support/hegemony.lua")
local Session = require "packages.hanjin.pkg.hanjin_mode.rules.session"
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
Testhanjin_scenarios = {
  tearDown = function()
    Ban.resetKingdoms()
    support.clearRoom()
  end,
}

local function create(options)
  options = options or {}
  options.mode = "hanjin_heg_mode"
  options.realSelection = true
  return support.createRoom(options)
end

function Testhanjin_scenarios:testConsecutiveGamesRespectWinnerAndPreviousBan()
  local first = create { settings = { hanjin_wild_count = 0 } }
  local backend = first.room
  local winner = first.players[1]
  local oldBans = table.simpleClone(first:getBanner("hanjin_banned_kingdoms"))
  FkTest.runInRoom(function()
    winner:revealGeneral(false)
    winner:revealGeneral(true)
    first:gameOver({ winner })
  end)
  local kingdom = winner.kingdom
  lu.assertTrue(table.contains(Ban.kingdoms, kingdom))
  support.clearRoom()
  local second = create { backend = backend, settings = { hanjin_wild_count = 0 } }
  lu.assertTrue(table.contains(second:getBanner("hanjin_banned_kingdoms"), kingdom))
  for _, banned in ipairs(oldBans) do
    lu.assertTrue(table.contains(second:getBanner("all_kingdoms"), banned))
  end
end

function Testhanjin_scenarios:testPreviousWinnerOutsideCandidatesIsIgnored()
  local first = create { settings = { hanjin_wild_count = 0 } }
  local winner = first.players[1]
  FkTest.runInRoom(function()
    winner:revealGeneral(false)
    winner:revealGeneral(true)
    first:setPlayerProperty(winner, "kingdom", "wei")
    first:gameOver({ winner })
  end)
  local backend = first.room
  support.clearRoom()
  local second = create { backend = backend, settings = {
    hanjin_wild_count = 0,
    hanjin_candidate_kingdoms = { "shu", "wu", "qun", "han" },
    hanjin_kingdom_limit = 4,
  } }
  lu.assertEquals(second:getBanner("hanjin_banned_kingdoms"), {})
  lu.assertEquals(second:getBanner("all_kingdoms"), { "shu", "wu", "qun", "han" })
end

function Testhanjin_scenarios:testZeroWildGeneralsFromHostSetting()
  local room = create { settings = { hanjin_wild_count = 0 } }
  for _, name in ipairs(room.general_pile) do lu.assertNotEquals(Fk.generals[name].kingdom, "wild") end
  for _, p in ipairs(room.players) do
    lu.assertNotEquals(Fk.generals[p:getMark("__heg_general")].kingdom, "wild")
  end
end

function Testhanjin_scenarios:testFutureWinnerCanBeRecordedForNextCandidates()
  Ban.registerKingdom("hanjin_test_future_7")
  local room = create { settings = { hanjin_wild_count = 0 } }
  local winner = room.players[1]
  FkTest.runInRoom(function()
    room:setPlayerProperty(winner, "kingdom", "hanjin_test_future_7")
    room:gameOver({ winner })
  end)
  local saved = json.decode(room.room:getSessionData()).hanjin_faction_ban_v1
  lu.assertNotNil(saved)
  lu.assertTrue(table.contains(saved.winners, "hanjin_test_future_7"))
  Ban.resetKingdoms()
end

function Testhanjin_scenarios:testOtherModeClearsPreviousHanjinGame()
  local room = create()
  Session.finish(room, {})
  local backend = room.room
  support.clearRoom()
  local ordinary = support.createRoom { backend = backend }
  lu.assertNil(ordinary:getSessionData().hanjin_faction_ban_v1)
end

function Testhanjin_scenarios:testIllegalClientReplyFallsBackToOfferedLegalPair()
  -- All six factions are allowed here, so no guest candidate triggers a redraw
  -- dialog that would consume the deliberately invalid final-selection reply.
  local room = create {
    settings = {
      hanjin_wild_count = 0,
      hanjin_candidate_kingdoms = { "wei", "shu", "wu", "qun", "han", "jin" },
      hanjin_kingdom_limit = 6,
    },
    configure = function(room)
      room.room:getOwner()._fake_router._reply_list = { cbor.encode({ "caocao,caocao", "kingdom,not_a_kingdom" }) }
    end,
  }
  lu.assertTrue(table.contains(room:getTag("hanjin_selection_fallbacks"), room.room:getOwner():getId()))
  for _, p in ipairs(room.players) do
    local a, b = p:getMark("__heg_general"), p:getMark("__heg_deputy")
    lu.assertNotEquals(a, "caocao")
    lu.assertNotEquals(a, b)
    lu.assertTrue(table.contains(room:getBanner("all_kingdoms"), p:getMark("__heg_kingdom")))
  end
end

function Testhanjin_scenarios:testSixKingdomPoolUsesExactlyTwoBans()
  local room = create()
  lu.assertEquals(#room:getBanner("hanjin_candidate_kingdoms"), 6)
  lu.assertEquals(room:getBanner("hanjin_kingdom_limit"), 4)
  lu.assertEquals(#room:getBanner("hanjin_banned_kingdoms"), 2)
  lu.assertEquals(#room:getBanner("all_kingdoms"), 4)
end

function Testhanjin_scenarios:testCustomCandidateSetBelowLimitHasNoBan()
  local room = create { settings = {
    hanjin_wild_count = 0,
    hanjin_candidate_kingdoms = { "wei", "shu", "wu" },
    hanjin_kingdom_limit = 3,
  } }
  lu.assertEquals(room:getBanner("hanjin_candidate_kingdoms"), { "wei", "shu", "wu" })
  lu.assertEquals(room:getBanner("hanjin_kingdom_limit"), 3)
  lu.assertEquals(room:getBanner("hanjin_banned_kingdoms"), {})
  lu.assertEquals(room:getBanner("all_kingdoms"), { "wei", "shu", "wu" })
  for _, player in ipairs(room.players) do
    for _, key in ipairs({ "__heg_general", "__heg_deputy" }) do
      local name = player:getMark(key)
      local entry = Guest.factionsOf(room, name)
      lu.assertNotNil(entry)
      lu.assertTrue(entry.wild or table.find(entry.kingdoms, function(k)
        return table.contains({ "wei", "shu", "wu" }, k)
      end) ~= nil)
    end
  end
  lu.assertTrue(table.contains(room.disabled_generals, "hanjin_test__qun_1"))
end

function Testhanjin_scenarios:testPerKingdomSwitchSettingsReachTheServer()
  local room = create { settings = {
    hanjin_wild_count = 0,
    hanjin_candidate_wei = false,
    hanjin_candidate_jin = false,
  } }
  lu.assertEquals(room:getBanner("hanjin_candidate_kingdoms"), { "shu", "wu", "qun", "han" })
  lu.assertEquals(room:getBanner("hanjin_kingdom_limit"), 4)
  lu.assertEquals(room:getBanner("all_kingdoms"), { "shu", "wu", "qun", "han" })
  lu.assertEquals(room:getBanner("hanjin_banned_kingdoms"), {})
end

function Testhanjin_scenarios:testCustomCandidateSetUsesExplicitLimit()
  local room = create { settings = {
    hanjin_wild_count = 0,
    hanjin_candidate_kingdoms = { "wei", "shu", "wu", "qun", "han" },
    hanjin_kingdom_limit = 3,
  } }
  lu.assertEquals(#room:getBanner("all_kingdoms"), 3)
  lu.assertEquals(#room:getBanner("hanjin_banned_kingdoms"), 2)
  for _, kingdom in ipairs(room:getBanner("all_kingdoms")) do
    lu.assertTrue(table.contains({ "wei", "shu", "wu", "qun", "han" }, kingdom))
  end
end

function Testhanjin_scenarios:testInvalidCandidateSettingsFailFeasibility()
  local mode = assert(Fk.game_modes.hanjin_heg_mode)
  local settings = { playerNum = 8, gameMode = mode.name }
  settings._mode = { hanjin_candidate_kingdoms = {}, hanjin_kingdom_limit = 1 }
  lu.assertFalse(mode:feasible(settings))
  settings._mode = { hanjin_candidate_kingdoms = { "wei", "shu" }, hanjin_kingdom_limit = 3 }
  lu.assertFalse(mode:feasible(settings))
  settings._mode = { hanjin_candidate_kingdoms = { "wei", "shu" }, hanjin_kingdom_limit = 2 }
  lu.assertTrue(mode:feasible(settings))
end

function Testhanjin_scenarios:testCandidateExcludedFactionCardsLeaveTheDeck()
  local Cards = require "packages.hanjin.pkg.hanjin_mode.rules.cards"
  local room = create { settings = {
    hanjin_wild_count = 0,
    hanjin_candidate_kingdoms = { "wei", "shu" },
    hanjin_kingdom_limit = 2,
  } }
  local ids = table.simpleClone(room.draw_pile)
  for _, player in ipairs(room.players) do table.insertTable(ids, player:getCardIds("h")) end
  for _, id in ipairs(ids) do
    local card = Fk:getCardById(id)
    local spec = Cards.equipment[card.name]
    if spec then
      lu.assertTrue(table.find(spec.kingdoms, function(kingdom)
        return table.contains({ "wei", "shu" }, kingdom)
      end) ~= nil)
    end
    local kingdom = Cards.tricks[card.name]
    if kingdom then lu.assertTrue(kingdom == "wild" or table.contains({ "wei", "shu" }, kingdom)) end
  end
end

function Testhanjin_scenarios:testPreviousRecordOnlyAppliesToCurrentCandidates()
  local backend = FkTest.createFakeRoom({ 1, 2, 3, 4, 5, 6, 7, 8 })
  backend._session_data = json.encode {
    hanjin_faction_ban_v1 = {
      version = 1, winners = { "wei" }, banned = { "jin" },
    },
  }
  local room = create { backend = backend, settings = {
    hanjin_wild_count = 0,
    hanjin_candidate_kingdoms = { "shu", "wu", "qun", "han" },
    hanjin_kingdom_limit = 4,
  } }
  lu.assertEquals(room:getBanner("hanjin_banned_kingdoms"), {})
  lu.assertEquals(room:getBanner("all_kingdoms"), { "shu", "wu", "qun", "han" })
end

return { name = "hanjin_scenarios" }
