local support = __dofile("../../../tests/support/hegemony.lua")
local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
local Pool = require "packages.hanjin.pkg.hanjin_mode.rules.general_pool"
local Versions = require "packages.hanjin.pkg.hanjin_mode.rules.general_versions"
local Discard = require "packages.hanjin.pkg.hanjin_mode.rules.general_discard"
local Selection = require "packages.hanjin.pkg.hanjin_mode.rules.selection"

Testhanjin_guest_allegiance = {
  setup = function()
    -- Load the independent content only when this suite runs so its global
    -- registrations do not leak into earlier suites of the combined file.
    __dofile("../../../tests/support/guest_allegiance_content.lua")
  end,
  tearDown = support.clearRoom,
}

local function forcedBackend()
  -- The test client is created for eight seats; keep rooms at that size and
  -- exercise the four-player path through the pure version plan instead.
  local backend = FkTest.createFakeRoom({ 1, 2, 3, 4, 5, 6, 7, 8 })
  -- Force the ban plan to leave wu/qun/han/jin: the two previous winners are
  -- banned and no other kingdom is protected from the random choice.
  backend._session_data = json.encode {
    hanjin_faction_ban_v1 = { version = 1, winners = { "wei", "shu" }, banned = {} },
  }
  return backend
end

local function create(options)
  options = options or {}
  options.mode = "hanjin_heg_mode"
  options.realSelection = true
  options.backend = options.backend or forcedBackend()
  options.settings = options.settings or {}
  options.settings.hanjin_wild_count = options.settings.hanjin_wild_count or 0
  return support.createRoom(options)
end

local function purePlan(playerCount, names, wildCount, previous, opts)
  return Versions.planPool(playerCount, names, previous, wildCount, function(list, n)
    return table.slice(list, 1, n + 1)
  end, function(name) return Fk.generals[name] end, opts)
end

local function contentNames()
  local names = {}
  for _, pack in ipairs({ Fk.packages.hanjin_test_content, Fk.packages.hanjin_test_guest_content }) do
    for _, general in ipairs(pack.generals) do table.insert(names, general.name) end
  end
  return names
end

local function wildNamesOf(names)
  return table.filter(names, function(name) return Fk.generals[name].kingdom == "wild" end)
end

function Testhanjin_guest_allegiance:testGuestResolutionOrder()
  local allowed = { "wu", "qun", "han", "jin" }
  local original = Guest.resolve("hanjin_test__guest_partial", allowed)
  lu.assertEquals(original.source, "original")
  lu.assertEquals(original.kingdoms, { "wu" })
  local guest = Guest.resolve("hanjin_test__guest_dual_1", allowed)
  lu.assertEquals(guest.source, "guest")
  lu.assertEquals(guest.kingdoms, { "han" })
  lu.assertNil(Guest.resolve("hanjin_test__guest_banned", allowed))
  lu.assertNil(Guest.resolve("hanjin_test__wei_1", { "wu", "qun" }))
end

function Testhanjin_guest_allegiance:testPairingUsesResolvedGuestFactions()
  local room = create {}
  local entry = Guest.factionsOf(room, "hanjin_test__guest_dual_1")
  lu.assertEquals(entry.source, "guest")
  lu.assertEquals(entry.kingdoms, { "han" })
  lu.assertTrue(#Guest.pairKingdoms(room, "hanjin_test__guest_dual_1", "hanjin_test__han_1") > 0)
  lu.assertEquals(#Guest.pairKingdoms(room, "hanjin_test__guest_dual_1", "hanjin_test__wu_1"), 0)
  -- A wild main general may pair with any allowed deputy; a wild deputy may not.
  local wild = room:getTag("hanjin_wild_kept_originals_v1")
  if #wild > 0 then
    lu.assertTrue(#Guest.pairKingdoms(room, wild[1], "hanjin_test__han_1") > 0)
    lu.assertEquals(#Guest.pairKingdoms(room, "hanjin_test__han_1", wild[1]), 0)
  end
end

function Testhanjin_guest_allegiance:testGuestOnlyFactionDoesNotEnterPreBanSet()
  -- Four printed kingdoms; the guest-only Han/Jin factions must not create the
  -- fifth/sixth pre-ban kingdom and trigger bans while the question is pending.
  local names = {
    "hanjin_test__wei_1", "hanjin_test__shu_1", "hanjin_test__wu_1",
    "hanjin_test__qun_1", "hanjin_test__guest_dual_1",
  }
  local plan = purePlan(8, names, 0, nil, {
    candidates = { "wei", "shu", "wu", "qun" }, limit = 4,
  })
  lu.assertEquals(plan.banned, {})
  lu.assertEquals(#plan.allowed, 4)
  lu.assertTrue(table.contains(plan.kept, "hanjin_test__guest_dual_1"))
end

function Testhanjin_guest_allegiance:testCandidateSetDoesNotDependOnPoolAndCanBeGuestOnly()
  local names = { "hanjin_test__guest_dual_1" }
  local guestPlan = purePlan(5, names, 0, nil, { candidates = { "han" }, limit = 1 })
  lu.assertEquals(guestPlan.allowed, { "han" })
  lu.assertTrue(table.contains(guestPlan.kept, "hanjin_test__guest_dual_1"))
  -- A candidate kingdom with no general at all is still a valid candidate set;
  -- it simply contributes no general to the pool.
  local emptyPlan = purePlan(5, names, 0, nil, { candidates = { "jin" }, limit = 1 })
  lu.assertEquals(emptyPlan.allowed, { "jin" })
  lu.assertEquals(emptyPlan.kept, {})
  lu.assertFalse(table.contains(emptyPlan.kept, "hanjin_test__guest_dual_1"))
end

function Testhanjin_guest_allegiance:testAllegianceVersionOutsideCandidatesIsExcluded()
  create {}
  local plan = purePlan(5, { "hanjin_test__wild_1" }, 0, nil, {
    candidates = { "han" }, limit = 1,
  })
  lu.assertFalse(table.contains(plan.kept, "hanjin_test__loyal_1"))
  lu.assertTrue(table.contains(plan.excluded, "hanjin_test__loyal_1"))
end

function Testhanjin_guest_allegiance:testFourPlayersReplaceEveryWildOriginal()
  local names = contentNames()
  local previous = { winners = { "wei", "shu" }, banned = {} }
  local plan = purePlan(4, names, 0, previous)
  lu.assertEquals(plan.wild_kept, {})
  local kept = {}
  for _, name in ipairs(plan.kept) do
    kept[name] = true
    lu.assertNotEquals(Fk.generals[name].kingdom, "wild", "Four players must not keep a wild original")
  end
  -- Registered loyalty versions replace the originals even when the cap is 0.
  lu.assertTrue(kept["hanjin_test__loyal_2"])
  lu.assertNil(kept["hanjin_test__loyal_1"]) -- wei banned
  lu.assertNil(kept["hanjin_test__loyal_5"]) -- wei/shu banned
  lu.assertNil(kept["hanjin_test__wild_1"])
  local stub = {
    getTag = function() return nil end,
    getBanner = function() return plan.allowed end,
    getSettings = function() return nil end,
  }
  local built = Pool.resolve(stub, plan, { wildNames = wildNamesOf(names) })
  for _, name in ipairs(built.names) do
    lu.assertNotEquals(Fk.generals[name].kingdom, "wild")
  end
  lu.assertTrue(table.contains(built.names, "hanjin_test__loyal_2"))
end

function Testhanjin_guest_allegiance:testFivePlayersCapKeepsOnlySelectedOriginals()
  local names = contentNames()
  local previous = { winners = { "wei", "shu" }, banned = {} }
  local plan = purePlan(5, names, 1, previous)
  lu.assertEquals(#plan.wild_kept, 1)
  lu.assertEquals(Fk.generals[plan.wild_kept[1]].kingdom, "wild")
  local kept = {}
  for _, name in ipairs(plan.kept) do kept[name] = true end
  -- Every non-kept original is replaced by its registered loyalty version, and
  -- every loyalty version entering the pool is unique.
  local seen = {}
  for _, name in ipairs(plan.kept) do
    if Versions.is_loyalty(name) then
      lu.assertNil(seen[name], "Duplicate allegiance version")
      seen[name] = true
    end
  end
  lu.assertNil(kept["hanjin_test__loyal_5"]) -- both factions banned
  lu.assertNil(kept["hanjin_test__loyal_1"]) -- wei banned
  lu.assertTrue(kept["hanjin_test__loyal_2"])
end

function Testhanjin_guest_allegiance:testBannedOriginalCannotReturnBySameName()
  local room = create { settings = { hanjin_wild_count = 0, disableSameConvert = true } }
  local original = "hanjin_test__wild__same"
  local version = "hanjin_test__loyal__same"
  local function inGame(name)
    if table.contains(room.general_pile, name) then return true end
    for _, player in ipairs(room.players) do
      for _, key in ipairs({ "__heg_general", "__heg_deputy" }) do
        if player:getMark(key) == name then return true end
      end
    end
    return false
  end
  lu.assertTrue(inGame(version))
  lu.assertFalse(inGame(original))
  lu.assertFalse(table.contains(room.disabled_generals, version))
  -- The banned original is hidden from same-name conversion even though the
  -- version shares its true name; the allowed version itself remains usable.
  FkTest.runInRoom(function()
    lu.assertFalse(Fk:canUseGeneral(original))
    lu.assertFalse(table.contains(Fk:getSameGenerals(version), original))
    lu.assertFalse(Fk:canUseGeneral("hanjin_test__wild_1"))
    lu.assertFalse(Fk:canUseGeneral("hanjin_test__loyal_5"))
  end)
end

function Testhanjin_guest_allegiance:testChainedGuestRedrawGoesToDiscardAndNeverReturns()
  local room = create {}
  local player = room.players[1]
  local changes, offers, discarded
  FkTest.setNextReplies(player, {
    { indices = { 1 } },
    { indices = { 3 } },
    { indices = {} },
  })
  FkTest.runInRoom(function()
    room.general_pile = {
      "hanjin_test__guest_dual_3", "hanjin_test__guest_dual_4", "hanjin_test__wei_2",
    }
    offers = {
      [player] = { "hanjin_test__guest_dual_1", "hanjin_test__guest_dual_2", "hanjin_test__wu_1" },
    }
    changes = Selection.redraw(room, { player }, offers)
    discarded = Discard.list(room)
  end)
  lu.assertEquals(#changes, 2, "The replacement guest candidate must be offered again")
  lu.assertEquals(#discarded, 2)
  lu.assertEquals(#offers[player], 3)
  lu.assertFalse(table.contains(offers[player], discarded[1]))
  lu.assertFalse(table.contains(offers[player], discarded[2]))
  if not Selection.firstLegalPair(room, offers[player]) then
    for _, name in ipairs(offers[player]) do
      local entry = Guest.factionsOf(room, name)
      print("  " .. name .. " -> " .. (entry and (entry.source .. ":" .. table.concat(entry.kingdoms, "/")) or "nil"))
    end
  end
  lu.assertNotNil(Selection.firstLegalPair(room, offers[player]))
  for _, name in ipairs(discarded) do
    lu.assertFalse(table.contains(room.general_pile, name))
    lu.assertTrue(table.contains(room.disabled_generals, name))
    lu.assertFalse(table.contains(offers[player], name))
  end
  -- Nothing in the discard pile can be returned or drawn later in this room.
  local returned
  FkTest.runInRoom(function()
    room:returnToGeneralPile({ "hanjin_test__guest_dual_1" })
    table.insert(room.general_pile, "hanjin_test__guest_dual_1")
    local drawn = room:getNGenerals(1)
    local many = room:findGenerals(function() return true end, 2)
    returned = {
      pile = table.contains(room.general_pile, "hanjin_test__guest_dual_1"),
      draw = table.contains(drawn, "hanjin_test__guest_dual_1"),
      find = room:findGeneral("hanjin_test__guest_dual_1"),
      findMany = table.contains(many, "hanjin_test__guest_dual_1"),
    }
  end)
  lu.assertFalse(returned.pile)
  lu.assertFalse(returned.draw)
  lu.assertNil(returned.find)
  lu.assertFalse(returned.findMany)
  lu.assertTrue(Discard.contains(room, "hanjin_test__guest_dual_1"))
end

function Testhanjin_guest_allegiance:testServerIgnoresNonGuestRedraw()
  local room = create {}
  local player = room.players[1]
  local offers = { [player] = { "hanjin_test__han_1", "hanjin_test__wu_1" } }
  local ok, reason
  FkTest.runInRoom(function()
    ok, _, reason = Selection.applyRedraw(room, player, offers, { "hanjin_test__han_1" })
  end)
  lu.assertFalse(ok)
  lu.assertEquals(reason, "no_guest_candidate")
  lu.assertEquals(offers[player], { "hanjin_test__han_1", "hanjin_test__wu_1" })
end

function Testhanjin_guest_allegiance:testFailedReplacementKeepsOriginalCandidate()
  local room = create {}
  local player = room.players[1]
  local offers, failures
  FkTest.setNextReplies(player, { { indices = { 1 } } })
  FkTest.runInRoom(function()
    room.general_pile = { "hanjin_test__qun_1" }
    offers = {
      [player] = { "hanjin_test__guest_dual_1", "hanjin_test__guest_dual_2" },
    }
    Selection.redraw(room, { player }, offers)
    failures = room:getTag("hanjin_guest_redraw_failures_v1")
  end)
  lu.assertEquals(offers[player], { "hanjin_test__guest_dual_1", "hanjin_test__guest_dual_2" })
  lu.assertEquals(#Discard.list(room), 0)
  lu.assertEquals(failures[1].reason, "no_legal_replacement")
end

function Testhanjin_guest_allegiance:testTwoPlayersRedrawInOneRound()
  local room = create {}
  local first, second = room.players[1], room.players[2]
  local offers, changes
  FkTest.setNextReplies(first, { { indices = { 1 } }, { indices = {} } })
  FkTest.setNextReplies(second, { { indices = { 1 } }, { indices = {} } })
  FkTest.runInRoom(function()
    room.general_pile = {
      "hanjin_test__wei_2", "hanjin_test__qun_1",
      "hanjin_test__han_1", "hanjin_test__wu_2",
    }
    offers = {
      [first] = { "hanjin_test__guest_dual_1", "hanjin_test__guest_dual_2", "hanjin_test__wu_1" },
      [second] = { "hanjin_test__guest_dual_3", "hanjin_test__guest_dual_4", "hanjin_test__han_2" },
    }
    changes = Selection.redraw(room, { first, second }, offers)
  end)
  lu.assertEquals(#changes, 2)
  lu.assertEquals(#Discard.list(room), 2)
  local seen = {}
  for _, p in ipairs({ first, second }) do
    for _, name in ipairs(offers[p]) do
      lu.assertNil(seen[name], "Offers must stay unique")
      seen[name] = true
    end
    lu.assertNotNil(Selection.firstLegalPair(room, offers[p]))
  end
end

function Testhanjin_guest_allegiance:testSelectionAcceptsGuestPairAndKingdom()
  local room = create {}
  local player = room.players[1]
  local offers = {
    [player] = { "hanjin_test__guest_dual_1", "hanjin_test__guest_dual_2", "hanjin_test__wu_1" },
  }
  FkTest.setNextReplies(player, {
    { "hanjin_test__guest_dual_1", "hanjin_test__guest_dual_2" },
    { "han" },
  })
  local pairs, kingdoms, fallbacks
  FkTest.runInRoom(function()
    pairs, kingdoms, fallbacks = Selection.choose(room, { player }, offers)
  end)
  lu.assertEquals(pairs[player], { "hanjin_test__guest_dual_1", "hanjin_test__guest_dual_2" })
  lu.assertEquals(kingdoms[player], "han")
  lu.assertEquals(#fallbacks, 0)
end

function Testhanjin_guest_allegiance:testInitialKingdomFallsBackWhenReplyIsIllegal()
  local room = create {}
  local player = room.players[1]
  local offers = {
    [player] = { "hanjin_test__guest_multi_1", "hanjin_test__guest_multi_2" },
  }
  FkTest.setNextReplies(player, {
    { "hanjin_test__guest_multi_1", "hanjin_test__guest_multi_2" },
    { "wei" },
  })
  local pairs, kingdoms
  FkTest.runInRoom(function()
    pairs, kingdoms = Selection.choose(room, { player }, offers)
  end)
  lu.assertEquals(pairs[player], { "hanjin_test__guest_multi_1", "hanjin_test__guest_multi_2" })
  lu.assertEquals(kingdoms[player], "han")
end

function Testhanjin_guest_allegiance:testIllegalSelectionFallsBackAndRejectsBadKingdom()
  local room = create {}
  local player = room.players[1]
  local offers = {
    [player] = { "hanjin_test__guest_dual_1", "hanjin_test__guest_dual_2", "hanjin_test__wu_1" },
  }
  FkTest.setNextReplies(player, {
    { "hanjin_test__guest_dual_1", "hanjin_test__wu_1" }, -- no common kingdom
    { "wei" }, -- also not legal for the fallback pair
  })
  local pairs, kingdoms, fallbacks
  FkTest.runInRoom(function()
    pairs, kingdoms, fallbacks = Selection.choose(room, { player }, offers)
  end)
  lu.assertEquals(#fallbacks, 1)
  lu.assertNotNil(Selection.firstLegalPair(room, offers[player]))
  lu.assertTrue(table.contains({ "han" }, kingdoms[player]))
end

function Testhanjin_guest_allegiance:testClientDialogContract()
  local room = create {}
  local offers = { "hanjin_test__guest_dual_1", "hanjin_test__guest_dual_2", "hanjin_test__wu_1" }
  local data, redraw, allowed, blocked
  FkTest.runInRoom(function()
    data = Selection.askData(room, offers)
    redraw = Selection.redrawData(room, offers, { "hanjin_test__guest_dual_1" })
    local rule = Fk.choose_general_rule.hanjin_heg_pair
    local extra = data.component.model.prop.extraData
    allowed = rule.card_filter("hanjin_test__guest_dual_2",
      { "hanjin_test__guest_dual_1" }, offers, extra)
    blocked = rule.card_filter("hanjin_test__wu_1",
      { "hanjin_test__guest_dual_1" }, offers, extra)
  end)
  lu.assertEquals(data.component.name, "ChooseGeneralBox")
  lu.assertEquals(data.component.model.name, "ChooseGeneralModel")
  local prop = data.component.model.prop
  lu.assertEquals(prop.ruleType, "hanjin_heg_pair")
  lu.assertTrue(prop.extraData.pairing["hanjin_test__guest_dual_1"] ~= nil)
  lu.assertTrue(table.contains(prop.extraData.pairing["hanjin_test__guest_dual_1"], "hanjin_test__guest_dual_2"))
  lu.assertEquals(redraw.component.url, "packages/hanjin/qml/GuestRedrawBox.qml")
  lu.assertEquals(redraw.component.prop.guests, { "hanjin_test__guest_dual_1" })
  lu.assertEquals(redraw.component.prop.factions["hanjin_test__guest_dual_1"].kingdoms, { "han" })
  lu.assertTrue(allowed)
  lu.assertFalse(blocked)
end

function Testhanjin_guest_allegiance:testDecodeAcceptsLegacyAndArrayShapes()
  lu.assertEquals(Selection.decode(123), {})
  lu.assertEquals(Selection.decode({}), {})
  lu.assertEquals(Selection.decode({ "only_one" }), {})
  local names, extra = Selection.decode({ "a,b", "kingdom,wei" })
  lu.assertEquals(names, { "a", "b" })
  lu.assertEquals(extra.kingdom, "wei")
  local array = Selection.decode({ "a", "b" })
  lu.assertEquals(array, { "a", "b" })
  lu.assertEquals(Selection.decode({ generals = { "a", "b" } }), { "a", "b" })
  lu.assertEquals(Selection.decodeRedraw(
    { indices = { "a", "missing", "b", "a" } }, { "a", "b" }), { "a", "b" })
end

return { name = "hanjin_guest_allegiance" }
