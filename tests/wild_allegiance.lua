local support = __dofile("../../../tests/support/hegemony.lua")
local content = __dofile("../../../tests/support/ascension_content.lua")
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local V = require "packages.qiao.pkg.qiao_mode.rules.general_versions"

local G = content.generals

local function create(options)
  options = options or {}
  local backend = FkTest.createFakeRoom({ 1, 2, 3, 4, 5, 6, 7, 8 })
  -- Allow Wei/Shu/Han/Jin so the wild and loyalty tests have stable factions.
  backend._session_data = json.encode {
    qiao_faction_ban_v1 = { version = 1, winners = { "wu", "qun" }, banned = {} },
  }
  local settings = { qiao_wild_count = 4 }
  for key, value in pairs(options.settings or {}) do settings[key] = value end
  return support.createRoom {
    mode = "qiao_heg_mode", realSelection = true, backend = backend,
    settings = settings,
    -- Keep the opening wild pool deterministic so the ascension wild originals
    -- are kept and their loyalty versions are derived-excluded from dealing;
    -- the in-game allegiance ascent must still offer them.
    configure = function(room)
      local original = room.makeGeneralPile
      local keep = {
        [G.wild_simple.name] = true,
        [G.wild_dual.name] = true,
        [G.wild_blocked.name] = true,
      }
      function room:makeGeneralPile()
        original(self)
        self.general_pile = table.filter(self.general_pile, function(name)
          local general = Fk.generals[name]
          return general == nil or general.kingdom ~= "wild" or keep[name]
        end)
      end
    end,
  }
end

local function preparePlayers(room)
  FkTest.runInRoom(function()
    for index, player in ipairs(room.players) do
      local kingdom = index % 2 == 0 and "shu" or "qun"
      content.setupHidden(room, player, "qiao_test__" .. kingdom .. "_1",
        "qiao_test__" .. kingdom .. "_2", kingdom)
      room:setPlayerProperty(player, "kingdom", kingdom)
    end
  end)
  return room
end

local function setup()
  return preparePlayers(create())
end

--- Replace the setup room with one whose host settings were passed to Room:new.
local function freshRoom(settings)
  support.clearRoom()
  return preparePlayers(create { settings = settings })
end

Testqiao_wild_allegiance = { setup = setup, tearDown = support.clearRoom }

local function room() return FkTest.room end
local function player(n) return room().players[n] end

local function hidden(p, main, deputy, kingdom)
  content.setupHidden(room(), p, main, deputy, kingdom)
end

local function revealed(p, main, deputy, kingdom)
  content.setupRevealed(room(), p, main, deputy, kingdom)
end

local function prepare(p)
  FkTest.runInRoom(function()
    room():setCurrent(p)
    room().logic:trigger(fk.EventPhaseStart, p, { phase = Player.Start })
  end)
end

local function makeWild(p, main, deputy, kingdom)
  hidden(p, main, deputy, kingdom or "wei")
  room():setPlayerProperty(p, "maxHp", 3)
  room():setPlayerProperty(p, "hp", 3)
end

function Testqiao_wild_allegiance:testFirstTurnConditionAndHpRevealSync()
  local p = player(1)
  FkTest.runInRoom(function() makeWild(p, G.wild_simple.name, G.wei_deputy.name, "wei") end)
  lu.assertEquals(#A.wild_candidates(room(), p), 1)
  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_simple.name } })
  prepare(p)

  lu.assertEquals(p.general, G.loyalty_simple.name)
  lu.assertEquals(p.kingdom, "wei")
  lu.assertEquals(p:getMark("__heg_wild"), 0)
  lu.assertEquals(p:getMark("__heg_general"), G.loyalty_simple.name)
  lu.assertEquals(p:getMark(A.WILD_ASCENDED_MARK), 1)
  lu.assertTrue(p:hasSkill(content.skills.loyalty))
  lu.assertEquals(p.maxHp, 4)
  lu.assertEquals(p.hp, 4)
  lu.assertEquals(p.deputyGeneral, "anjiang")
  lu.assertEquals(p:getMark("@!!yinyangfish"), 0)
  lu.assertEquals(p:getMark("HalfMaxHpLeft"), 1, "效忠也应重判新组合的阴阳鱼")
  FkTest.runInRoom(function() p:revealGeneral(true) end)
  lu.assertEquals(p:getMark("@!!yinyangfish"), 1)
end

function Testqiao_wild_allegiance:testOtherUnknownCondition()
  local p = player(1)
  FkTest.runInRoom(function()
    makeWild(p, G.wild_simple.name, G.wei_deputy.name, "wei")
    room():setPlayerMark(p, A.TURNS_MARK, 1)
    room():setPlayerProperty(player(2), "kingdom", "unknown")
  end)
  lu.assertEquals(#A.wild_candidates(room(), p), 1)
  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_simple.name } })
  prepare(p)
  lu.assertEquals(p.general, G.loyalty_simple.name)
end

function Testqiao_wild_allegiance:testTargetFactionLordCondition()
  local p = player(1)
  FkTest.runInRoom(function()
    makeWild(p, G.wild_simple.name, G.wei_deputy.name, "wei")
    room():setPlayerMark(p, A.TURNS_MARK, 1)
    revealed(player(2), G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(player(3), "qiao_test__shu_1", "qiao_test__shu_2", "shu")
  end)
  lu.assertEquals(#A.wild_candidates(room(), p), 1)
  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_simple.name } })
  prepare(p)
  lu.assertEquals(p.general, G.loyalty_simple.name)
end

function Testqiao_wild_allegiance:testNoTimingConditionMeansNoOffer()
  local p = player(1)
  FkTest.runInRoom(function()
    makeWild(p, G.wild_simple.name, G.wei_deputy.name, "wei")
    room():setPlayerMark(p, A.TURNS_MARK, 1)
  end)
  lu.assertEquals(#A.wild_candidates(room(), p), 0)
  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_simple.name } })
  prepare(p)
  lu.assertEquals(p.general, "anjiang")
  lu.assertEquals(p:getMark("__heg_general"), G.wild_simple.name)
  lu.assertEquals(p:getMark("__heg_kingdom"), "wei")
end

function Testqiao_wild_allegiance:testPopulationCheckAppliesEvenWithLord()
  local p = player(1)
  FkTest.runInRoom(function()
    makeWild(p, G.wild_simple.name, G.wei_deputy.name, "wei")
    room():setPlayerMark(p, A.TURNS_MARK, 0)
    revealed(player(2), G.wei_monarch.name, G.wei_deputy.name, "wei")
    for index = 3, 5 do
      revealed(player(index), "qiao_test__wei_3", "qiao_test__wei_4", "wei")
    end
  end)
  lu.assertEquals(#A.wild_candidates(room(), p), 0)
  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_simple.name } })
  prepare(p)
  lu.assertEquals(p.general, "anjiang")
end

function Testqiao_wild_allegiance:testMultiKingdomOnlyLegalKingdomIsOffered()
  local p = player(1)
  FkTest.runInRoom(function()
    makeWild(p, G.wild_dual.name, G.wei_deputy.name, "wei")
  end)
  local candidates = A.wild_candidates(room(), p)
  lu.assertEquals(#candidates, 1)
  lu.assertEquals(candidates[1].general, G.loyalty_dual.name)
  lu.assertEquals(candidates[1].kingdom, "wei")

  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_dual.name } })
  prepare(p)
  lu.assertEquals(p.general, G.loyalty_dual.name)
  lu.assertEquals(p.kingdom, "wei")
end

function Testqiao_wild_allegiance:testOnlyOneLoyaltyAscensionPerPlayer()
  local p = player(1)
  FkTest.runInRoom(function() makeWild(p, G.wild_simple.name, G.wei_deputy.name, "wei") end)
  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_simple.name } })
  prepare(p)
  lu.assertEquals(p.general, G.loyalty_simple.name)
  local maxHp, hp = p.maxHp, p.hp
  lu.assertEquals(#A.wild_candidates(room(), p), 0)
  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_simple.name } })
  prepare(p)
  lu.assertEquals(p.general, G.loyalty_simple.name)
  lu.assertEquals(p.maxHp, maxHp)
  lu.assertEquals(p.hp, hp)
  lu.assertEquals(p:getMark(A.WILD_ASCENDED_MARK), 1)
end

function Testqiao_wild_allegiance:testRejectKeepsOriginalAndHiddenInfo()
  local p = player(1)
  FkTest.runInRoom(function() makeWild(p, G.wild_simple.name, G.wei_deputy.name, "wei") end)
  local beforeMax, beforeHp = p.maxHp, p.hp
  FkTest.setNextReplies(p, { { "Cancel" } })
  prepare(p)
  lu.assertEquals(p.general, "anjiang")
  lu.assertEquals(p.kingdom, "unknown")
  lu.assertEquals(p:getMark("__heg_general"), G.wild_simple.name)
  lu.assertEquals(p:getMark("__heg_kingdom"), "wei")
  lu.assertEquals(p.maxHp, beforeMax)
  lu.assertEquals(p.hp, beforeHp)
  lu.assertEquals(p:getMark(A.WILD_ASCENDED_MARK), 0)
end

function Testqiao_wild_allegiance:testStartingAsLoyaltyVersionIsNotAnAscension()
  local p = player(1)
  FkTest.runInRoom(function()
    revealed(p, G.loyalty_simple.name, G.wei_deputy.name, "wei")
    room():setPlayerMark(p, A.TURNS_MARK, 0)
    room():setPlayerProperty(p, "maxHp", 4)
    room():setPlayerProperty(p, "hp", 4)
  end)
  lu.assertEquals(#A.wild_candidates(room(), p), 0)
  prepare(p)
  lu.assertEquals(p.maxHp, 4)
  lu.assertEquals(p.hp, 4)
  lu.assertEquals(p:getMark(A.WILD_ASCENDED_MARK), 0)
end

function Testqiao_wild_allegiance:testDerivedOpeningExclusionDoesNotBlockLoyaltyAscension()
  local p = player(1)
  local original
  FkTest.runInRoom(function()
    makeWild(p, G.wild_simple.name, G.wei_deputy.name, "wei")
    -- The opening plan keeps the wild original and appends its unkept loyalty
    -- version to the runtime disable list; this is not a host ban.
    lu.assertTrue(table.contains(room().disabled_generals, G.loyalty_simple.name))
    original = cbor.decode(room().room:settings())
    lu.assertFalse(table.contains(original.disabledGenerals or {}, G.loyalty_simple.name))
  end)
  lu.assertEquals(#A.wild_candidates(room(), p), 1)
  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_simple.name } })
  prepare(p)
  lu.assertEquals(p.general, G.loyalty_simple.name)
  lu.assertEquals(p.kingdom, "wei")
end

function Testqiao_wild_allegiance:testExplicitBanStillBlocksWhenAlsoDerivedExcluded()
  freshRoom { disabledGenerals = { G.loyalty_simple.name } }
  local p = player(1)
  FkTest.runInRoom(function()
    makeWild(p, G.wild_simple.name, G.wei_deputy.name, "wei")
    -- Overlap: the same version is both derived-excluded and explicitly banned.
    lu.assertTrue(table.contains(room().disabled_generals, G.loyalty_simple.name))
  end)
  lu.assertEquals(#A.wild_candidates(room(), p), 0)
  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_simple.name } })
  prepare(p)
  lu.assertEquals(p.general, "anjiang")
  lu.assertEquals(p:getMark("__heg_kingdom"), "wei")
end

function Testqiao_wild_allegiance:testBannedPackBlocksLoyaltyAscension()
  freshRoom { disabledPack = { content.pack.name } }
  local p = player(1)
  FkTest.runInRoom(function()
    makeWild(p, G.wild_simple.name, G.wei_deputy.name, "wei")
  end)
  lu.assertEquals(#A.wild_candidates(room(), p), 0)
  FkTest.setNextReplies(p, { { A.WILD_ASCEND .. "::wei::" .. G.loyalty_simple.name } })
  prepare(p)
  lu.assertEquals(p.general, "anjiang")
end

local function poolPick(list, n)
  return table.slice(list, 1, n + 1)
end

local function poolNames()
  return {
    "qiao_test__wei_1", "qiao_test__shu_1", "qiao_test__wu_1",
    "qiao_test__qun_1", "qiao_test__han_1", "qiao_test__jin_1",
    G.wild_simple.name, G.wild_dual.name, G.wild_blocked.name,
    G.loyalty_simple.name, G.loyalty_dual.name, G.loyalty_blocked.name,
  }
end

function Testqiao_wild_allegiance:testFourPlayerPlanReplacesAllOriginalsAndDeduplicates()
  local get = function(name) return assert(Fk.generals[name]) end
  V.register { normal = G.wild_simple.name, loyalty = G.loyalty_simple.name }
  V.register { normal = G.wild_dual.name, loyalty = G.loyalty_dual.name }
  V.register { normal = G.wild_blocked.name, loyalty = G.loyalty_blocked.name }
  local plan = V.planPool(4, poolNames(),
    { winners = { "wei", "shu" }, banned = {} }, 4, poolPick, get)
  lu.assertEquals(plan.wild_kept, {})
  for _, name in ipairs({ G.wild_simple.name, G.wild_dual.name, G.wild_blocked.name }) do
    lu.assertFalse(table.contains(plan.kept, name))
    lu.assertTrue(table.contains(plan.excluded, name))
  end
  -- Ban plan bans the first two kingdoms (wei/shu); dual Wei/Jin loyalty is
  -- still kept through Jin, while Wei-only and Shu-only versions are excluded.
  lu.assertTrue(table.contains(plan.kept, G.loyalty_dual.name))
  lu.assertFalse(table.contains(plan.kept, G.loyalty_simple.name))
  lu.assertFalse(table.contains(plan.kept, G.loyalty_blocked.name))
  local seen = {}
  for _, name in ipairs(plan.kept) do
    lu.assertNil(seen[name], "Pool plan must deduplicate versions")
    seen[name] = true
  end
end

function Testqiao_wild_allegiance:testFivePlayerCapZeroReplacesOriginals()
  local get = function(name) return assert(Fk.generals[name]) end
  local plan = V.planPool(5, poolNames(),
    { winners = { "wei", "shu" }, banned = {} }, 0, poolPick, get)
  lu.assertEquals(plan.wild_kept, {})
  for _, name in ipairs({ G.wild_simple.name, G.wild_dual.name, G.wild_blocked.name }) do
    lu.assertFalse(table.contains(plan.kept, name))
  end
  lu.assertTrue(table.contains(plan.kept, G.loyalty_dual.name))
end

function Testqiao_wild_allegiance:testFivePlayerCapKeepsOriginalsWithoutVersions()
  local get = function(name) return assert(Fk.generals[name]) end
  local plan = V.planPool(5, poolNames(),
    { winners = { "wei", "shu" }, banned = {} }, 8, poolPick, get)
  lu.assertEquals(#plan.wild_kept, 3)
  for _, name in ipairs(plan.wild_kept) do lu.assertTrue(table.contains(plan.kept, name)) end
  for _, name in ipairs({ G.loyalty_simple.name, G.loyalty_dual.name, G.loyalty_blocked.name }) do
    lu.assertFalse(table.contains(plan.kept, name))
  end
end

function Testqiao_wild_allegiance:testAllegianceRegistrationIsShared()
  V.register { normal = G.wild_simple.name, loyalty = G.loyalty_simple.name }
  lu.assertTrue(V.is_loyalty(G.loyalty_simple.name))
  lu.assertEquals(V.loyalty_versions(G.wild_simple.name), { G.loyalty_simple.name })
  lu.assertEquals(V.original_of(G.loyalty_simple.name), G.wild_simple.name)
  lu.assertTrue(V.loyalties[G.loyalty_simple.name] ~= nil)
end

return { name = "qiao_wild_allegiance" }
