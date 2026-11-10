local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
Testhanjin_faction_ban = { tearDown = function() Ban.resetKingdoms() end }
local six = { "wei", "shu", "wu", "qun", "han", "jin" }
local function first(list, n) return table.slice(list, 1, n + 1) end
local function getter(settings)
  return function(key) return settings[key] end
end

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

function Testhanjin_faction_ban:testFormalContentIsIndependentAndDoesNotBorrowUpstream()
  lu.assertEquals(#Fk.packages.hanjin_generals.generals, 0)
  -- Formal HanJin content currently has exactly the two independent Thunder Slash cards.
  lu.assertEquals(#Fk.packages.hanjin_cards.cards, 2)
  for _, card in ipairs(Fk.packages.hanjin_cards.cards) do
    lu.assertEquals(card.package, Fk.packages.hanjin_cards)
    lu.assertEquals(card.package.extensionName, "hanjin")
    lu.assertEquals(card.name, "hanjin__thunder__slash")
  end
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

function Testhanjin_faction_ban:testDefaultSettingsAreSixCandidatesAndLimitFour()
  local config = Ban.resolveSettings(getter({}))
  lu.assertEquals(config.candidates, six)
  lu.assertEquals(config.limit, 4)
  local plan = Ban.plan(config.candidates, nil, first, config.limit)
  lu.assertEquals(#plan.allowed, 4)
  lu.assertEquals(#plan.banned, 2)
end

function Testhanjin_faction_ban:testCustomCandidateSetBelowLimitHasNoBan()
  local config = Ban.resolveSettings(getter {
    hanjin_candidate_kingdoms = { "wei", "shu", "wu" },
  })
  lu.assertEquals(config.candidates, { "wei", "shu", "wu" })
  lu.assertEquals(config.limit, 3)
  local plan = Ban.plan(config.candidates, { winners = { "wei" } }, first, config.limit)
  lu.assertEquals(plan.banned, {})
  lu.assertEquals(plan.allowed, config.candidates)
end

function Testhanjin_faction_ban:testCustomCandidateSetAndExplicitLimit()
  local config = Ban.resolveSettings(getter {
    hanjin_candidate_kingdoms = { "wei", "shu", "wu", "qun", "han" },
    hanjin_kingdom_limit = 3,
  })
  lu.assertEquals(config.candidates, { "wei", "shu", "wu", "qun", "han" })
  lu.assertEquals(config.limit, 3)
  local plan = Ban.plan(config.candidates, nil, first, config.limit)
  lu.assertEquals(#plan.allowed, 3)
  lu.assertEquals(#plan.banned, 2)
end

function Testhanjin_faction_ban:testLegacySwitchKeysStillBuildCandidates()
  local config = Ban.resolveSettings(getter {
    hanjin_candidate_wei = false,
    hanjin_candidate_jin = false,
  })
  lu.assertEquals(config.candidates, { "shu", "wu", "qun", "han" })
  lu.assertEquals(config.limit, 4)
end

function Testhanjin_faction_ban:testInvalidSettingsAreRejected()
  lu.assertError(Ban.resolveSettings, getter { hanjin_candidate_kingdoms = {} })
  lu.assertError(Ban.resolveSettings, getter { hanjin_candidate_kingdoms = { "wei", "wei" } })
  lu.assertError(Ban.resolveSettings, getter { hanjin_candidate_kingdoms = { "unknown" } })
  lu.assertError(Ban.resolveSettings, getter {
    hanjin_candidate_kingdoms = { "wei", "shu" }, hanjin_kingdom_limit = 0,
  })
  lu.assertError(Ban.resolveSettings, getter {
    hanjin_candidate_kingdoms = { "wei", "shu" }, hanjin_kingdom_limit = 3,
  })
  lu.assertError(Ban.resolveSettings, getter {
    hanjin_candidate_kingdoms = { "wei", "shu" }, hanjin_kingdom_limit = "4",
  })
  lu.assertError(Ban.resolveSettings, getter {
    hanjin_candidate_kingdoms = { "wei", "shu" }, hanjin_kingdom_limit = 1.5,
  })
  lu.assertError(Ban.resolveSettings, getter {
    hanjin_candidate_wei = "yes",
  })
  local allOff = {}
  for _, kingdom in ipairs(six) do allOff["hanjin_candidate_" .. kingdom] = false end
  lu.assertError(Ban.resolveSettings, getter(allOff))
end

function Testhanjin_faction_ban:testPreviousRecordOnlyConstrainsCurrentCandidates()
  -- Winner/protected kingdoms outside this game's candidates are irrelevant.
  local plan = Ban.plan({ "shu", "wu", "qun", "han" },
    { winners = { "wei" }, banned = { "jin" } }, first, 3)
  lu.assertEquals(#plan.allowed, 3)
  lu.assertEquals(#plan.banned, 1)
  for _, kingdom in ipairs(plan.banned) do
    lu.assertTrue(table.contains({ "shu", "wu", "qun", "han" }, kingdom))
  end
  -- At or below the limit, no extra ban is applied even for a previous winner.
  local noBan = Ban.plan({ "shu", "wu", "qun", "han" },
    { winners = { "shu" } }, first, 4)
  lu.assertEquals(noBan.banned, {})
  -- A current winner is banned first; the protected current kingdom survives.
  local constrained = Ban.plan(six,
    { winners = { "wei" }, banned = { "han", "jin" } }, first, 4)
  lu.assertTrue(table.contains(constrained.banned, "wei"))
  lu.assertTrue(table.contains(constrained.allowed, "han"))
  lu.assertTrue(table.contains(constrained.allowed, "jin"))
end

function Testhanjin_faction_ban:testTooManyMandatoryBansIsRejected()
  lu.assertError(Ban.plan, { "wei", "shu", "wu", "qun" },
    { winners = { "wei", "shu" }, banned = {} }, first, 3)
  lu.assertError(Ban.plan, six,
    { winners = { "wei" }, banned = { "wei" } }, first, 4)
end

function Testhanjin_faction_ban:testFutureKingdomsCanBeRegisteredWithoutChangingDefaults()
  -- Test-only ids; these do not create formal kingdoms, generals or cards.
  Ban.registerKingdom("hanjin_test_future_7")
  Ban.registerKingdom("hanjin_test_future_8")
  local eight = table.connect(six, { "hanjin_test_future_7", "hanjin_test_future_8" })
  local config = Ban.resolveSettings(getter {})
  -- Future kingdoms are selectable but are not part of the default candidate set.
  lu.assertEquals(config.candidates, six)
  local enabled = Ban.resolveSettings(getter { hanjin_candidate_hanjin_test_future_7 = true })
  lu.assertTrue(table.contains(enabled.candidates, "hanjin_test_future_7"))
  lu.assertFalse(table.contains(enabled.candidates, "hanjin_test_future_8"))
  local plan = Ban.plan(eight, nil, first, 4)
  lu.assertEquals(#plan.allowed, 4)
  lu.assertEquals(#plan.banned, 4)
end

function Testhanjin_faction_ban:testMalformedSelectionIsRejectedBeforeGeneralLookup()
  local Selection = require "packages.hanjin.pkg.hanjin_mode.rules.selection"
  lu.assertEquals(Selection.decode(123), {})
  lu.assertEquals(Selection.decode({}), {})
  lu.assertEquals(Selection.decode({ "only_one" }), {})
  lu.assertEquals(Selection.decode({ "one,two,three" }), {})
end

return { name = "hanjin_faction_ban" }
