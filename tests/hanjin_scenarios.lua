local support = __dofile("../../../tests/support/hegemony.lua")
local Session = require "packages.hanjin.pkg.hanjin_mode.rules.session"
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
Testhanjin_scenarios = { tearDown = support.clearRoom }

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

function Testhanjin_scenarios:testZeroWildGeneralsFromHostSetting()
  local room = create { settings = { hanjin_wild_count = 0 } }
  for _, name in ipairs(room.general_pile) do lu.assertNotEquals(Fk.generals[name].kingdom, "wild") end
  for _, p in ipairs(room.players) do
    lu.assertNotEquals(Fk.generals[p:getMark("__heg_general")].kingdom, "wild")
  end
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
  local room = create { configure = function(room)
    room.room:getOwner()._fake_router._reply_list = { cbor.encode({ "caocao,caocao", "kingdom,not_a_kingdom" }) }
  end }
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
  lu.assertEquals(#room:getBanner("hanjin_banned_kingdoms"), 2)
  lu.assertEquals(#room:getBanner("all_kingdoms"), 4)
end

return { name = "hanjin_scenarios" }
