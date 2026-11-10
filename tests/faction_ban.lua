local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
Testhanjin_faction_ban = {}
local six = { "wei", "shu", "wu", "qun", "han", "jin" }
local function first(list, n) return table.slice(list, 1, n + 1) end

function Testhanjin_faction_ban:testSixKingdomsLeaveFour()
  local plan = Ban.plan(six, nil, first)
  lu.assertEquals(#plan.allowed, 4)
  lu.assertEquals(#plan.banned, 2)
end

function Testhanjin_faction_ban:testFiveKingdomsLeaveFour()
  lu.assertEquals(#Ban.plan(table.slice(six, 1, 6), nil, first).banned, 1)
end

function Testhanjin_faction_ban:testFourKingdomsDoNotBan()
  local four = table.slice(six, 1, 5)
  lu.assertEquals(Ban.plan(four, nil, first).allowed, four)
  lu.assertEquals(Ban.plan(four, { winners = { "wei" }, banned = {} }, first).banned, {})
end

function Testhanjin_faction_ban:testFormalContentDoesNotBorrowUpstreamCardsOrGenerals()
  lu.assertEquals(#Fk.packages.hanjin_generals.generals, 0)
  lu.assertEquals(#Fk.packages.hanjin_cards.cards, 0)
  lu.assertFalse(table.contains(Fk.game_modes.hanjin_heg_mode.whitelist, "hegemony_standard"))
  lu.assertFalse(table.contains(Fk.game_modes.hanjin_heg_mode.whitelist, "hegemony_cards"))
end

function Testhanjin_faction_ban:testPreviousWinnerBannedPreviousBansProtected()
  local plan = Ban.plan(six, { winners = { "wei" }, banned = { "han", "jin" } }, first)
  lu.assertTrue(table.contains(plan.banned, "wei"))
  lu.assertTrue(table.contains(plan.allowed, "han"))
  lu.assertTrue(table.contains(plan.allowed, "jin"))
end

function Testhanjin_faction_ban:testImpossibleHistoryDoesNotSilentlyBreakRules()
  lu.assertError(Ban.plan, six, { winners = { "wei" }, banned = { "wei" } }, first)
end

function Testhanjin_faction_ban:testDualKingdomRetainedIfEitherAllowed()
  lu.assertTrue(Ban.generalAllowed({ kingdom = "wei", subkingdom = "shu" }, { "shu" }))
  lu.assertFalse(Ban.generalAllowed({ kingdom = "wei", subkingdom = "shu" }, { "wu" }))
  lu.assertEquals(Ban.pairKingdoms({ kingdom = "wei", subkingdom = "shu" },
    { kingdom = "wei", subkingdom = "shu" }, { "shu" }), { "shu" })
end

function Testhanjin_faction_ban:testWildCapIsConfigurableAndAllowsZero()
  local generals = { a = { kingdom = "wei" }, b = { kingdom = "wild" },
    c = { kingdom = "wild" }, d = { kingdom = "wild" } }
  local get = function(name) return generals[name] end
  local kept = Ban.filterGenerals({ "a", "b", "c", "d" }, { "wei" }, 2, first, get)
  lu.assertEquals(kept, { "a", "b", "c" })
  lu.assertEquals(Ban.filterGenerals({ "a", "b", "c" }, { "wei" }, 0, first, get), { "a" })
end

function Testhanjin_faction_ban:testWildIsNotACountableKingdom()
  local get = function(name) return ({ a = { kingdom = "wei", subkingdom = "han" }, b = { kingdom = "wild" } })[name] end
  lu.assertEquals(Ban.collectKingdoms({ "a", "b" }, get), { "wei", "han" })
end

function Testhanjin_faction_ban:testMalformedSelectionIsRejectedBeforeGeneralLookup()
  local Selection = require "packages.hanjin.pkg.hanjin_mode.rules.selection"
  lu.assertEquals(Selection.decode(123), {})
  lu.assertEquals(Selection.decode({}), {})
  lu.assertEquals(Selection.decode({ "only_one" }), {})
  lu.assertEquals(Selection.decode({ "one,two,three" }), {})
end

return { name = "hanjin_faction_ban" }
