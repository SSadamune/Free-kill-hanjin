local support = __dofile("../../../tests/support/hegemony.lua")
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local Cards = require "packages.hanjin.pkg.hanjin_mode.rules.cards"
local Session = require "packages.hanjin.pkg.hanjin_mode.rules.session"
Testhanjin_rules = { setup = support.initHanjinRoom, tearDown = support.clearRoom }

function Testhanjin_rules:testModeAndRealSelection()
  local room = FkTest.room
  lu.assertEquals(room:getSettings("gameMode"), "hanjin_heg_mode")
  lu.assertFalse(table.contains(Fk.game_mode_disabled.hanjin_heg_mode, "hanjin_generals"))
  lu.assertEquals(#room:getBanner("all_kingdoms"), 4)
  lu.assertEquals(#room:getBanner("hanjin_banned_kingdoms"), 2) -- Six independent test factions.
  for _, p in ipairs(room.players) do
    local a, b = p:getMark("__heg_general"), p:getMark("__heg_deputy")
    lu.assertTrue(#Ban.pairKingdoms(Fk.generals[a], Fk.generals[b], room:getBanner("all_kingdoms")) > 0)
    lu.assertEquals(#p:getCardIds("h"), 4)
    lu.assertFalse(table.contains(room.general_pile, a))
    lu.assertFalse(table.contains(room.general_pile, b))
  end
end

function Testhanjin_rules:testBannedGeneralsCannotReenterViaSameNameConversion()
  local room = FkTest.room
  local wild = 0
  FkTest.runInRoom(function()
    for _, name in ipairs(room.general_pile) do
      lu.assertTrue(Ban.generalAllowed(Fk.generals[name], room:getBanner("all_kingdoms")))
      if Fk.generals[name].kingdom == "wild" then wild = wild + 1 end
    end
    for _, name in ipairs(room:getTag("hanjin_excluded_generals")) do lu.assertFalse(Fk:canUseGeneral(name)) end
  end)
  for _, p in ipairs(room.players) do
    if Fk.generals[p:getMark("__heg_general")].kingdom == "wild" then wild = wild + 1 end
  end
  lu.assertTrue(wild <= 4)
end

function Testhanjin_rules:testBannedEquipmentRestoresMatchingOrdinaryCard()
  local room = FkTest.room
  local original = table.find(Fk.cards, function(card) return card.name == "hanjin_test__dragon_phoenix" end)
  local ordinary = table.find(Fk.cards, function(card)
    return card.name == "hanjin_test__double_swords" and card.suit == original.suit and card.number == original.number
  end)
  local result, void
  FkTest.runInRoom(function()
    result, void = Cards.apply(room, { original.id }, { ordinary.id }, { "shu" })
  end)
  lu.assertEquals(result, { ordinary.id })
  lu.assertEquals(void, { original.id })
end

local function testCard(name)
  return assert(table.find(Fk.cards, function(card) return card.name == "hanjin_test__" .. name end))
end

function Testhanjin_rules:testHanSwordIsAddedWithoutReplacingAnOrdinaryCard()
  local sword, ordinary = testCard("chixiao_sword"), testCard("blank_basic")
  local kept = Cards.apply(FkTest.room, { sword.id, ordinary.id }, {}, {})
  lu.assertEquals(kept, { sword.id, ordinary.id })
  local banned, void = Cards.apply(FkTest.room, { sword.id, ordinary.id }, {}, { "han" })
  lu.assertEquals(banned, { ordinary.id })
  lu.assertEquals(void, { sword.id })
end

function Testhanjin_rules:testJinMountReplacesJueyingAndRestoresItWhenBanned()
  local mount, ordinary = testCard("linxiao_yuyu"), testCard("jueying")
  local active, void = Cards.apply(FkTest.room, { mount.id, ordinary.id }, {}, {})
  lu.assertEquals(active, { mount.id })
  lu.assertEquals(void, { ordinary.id })
  local banned, excluded = Cards.apply(FkTest.room, { mount.id, ordinary.id }, {}, { "jin" })
  lu.assertEquals(banned, { ordinary.id })
  lu.assertEquals(excluded, { mount.id })
end

function Testhanjin_rules:testFactionTrickRemovedOnlyWhenItsFactionBanned()
  local trick = testCard("faction_trick")
  local banned = Cards.apply(FkTest.room, { trick.id }, {}, { "wei" })
  lu.assertEquals(banned, {})
  local active = Cards.apply(FkTest.room, { trick.id }, {}, { "shu" })
  lu.assertEquals(active, { trick.id })
end

function Testhanjin_rules:testMissingOrdinaryCopyIsPrintedWithTheOriginalSuitAndRank()
  local special = testCard("linxiao_yuyu")
  local result, void
  FkTest.runInRoom(function()
    result, void = Cards.apply(FkTest.room, { special.id }, {}, { "jin" })
  end)
  local replacement = Fk:getCardById(result[1])
  lu.assertEquals(replacement.name, "hanjin_test__jueying")
  lu.assertEquals(replacement.suit, special.suit)
  lu.assertEquals(replacement.number, special.number)
  lu.assertEquals(replacement.package.extensionName, "hanjin")
  lu.assertFalse(table.contains(void, replacement.id))
end

function Testhanjin_rules:testWildCountUIHasDefaultFourAndPreservesZero()
  local W = require "ui_emu.preferences"
  local mode = Fk.game_modes.hanjin_heg_mode
  local function value(settings)
    for _, group in ipairs(W.toQmlData(mode.ui_settings, { _mode = settings })) do
      for _, field in ipairs(group._children) do
        lu.assertNotEquals(field._settingsKey, "notBanToFourKingdoms")
        if field._settingsKey == "hanjin_wild_count" then return field.value end
      end
    end
    error("Missing wild count setting")
  end
  lu.assertEquals(value({}), 4)
  lu.assertEquals(value({ hanjin_wild_count = 0 }), 0)
end

function Testhanjin_rules:testCandidateUIHasKingdomSwitchesAndDynamicLimit()
  local W = require "ui_emu.preferences"
  local mode = Fk.game_modes.hanjin_heg_mode
  local function rows(settings)
    local result = {}
    for _, group in ipairs(W.toQmlData(mode.ui_settings, { _mode = settings })) do
      for _, field in ipairs(group._children) do
        if field._settingsKey then result[field._settingsKey] = field end
      end
    end
    return result
  end
  local default = rows({})
  local switches = 0
  for key in pairs(default) do
    if key:startsWith(Ban.candidatePrefix) then switches = switches + 1 end
  end
  lu.assertEquals(switches, #Ban.kingdoms)
  lu.assertEquals(default["hanjin_candidate_wei"].value, true)
  lu.assertEquals(default[Ban.limitKey].value, 4)
  lu.assertEquals(default[Ban.limitKey].from, 1)
  lu.assertEquals(default[Ban.limitKey].to, #Ban.kingdoms)
  local custom = rows { hanjin_candidate_wei = false, hanjin_kingdom_limit = 3 }
  lu.assertEquals(custom["hanjin_candidate_wei"].value, false)
  lu.assertEquals(custom[Ban.limitKey].value, 3)
  lu.assertEquals(custom[Ban.limitKey].to, #Ban.kingdoms - 1)
end

function Testhanjin_rules:testOnlyIndependentContentEntersGame()
  local room = FkTest.room
  for _, name in ipairs(room.general_pile) do lu.assertEquals(Fk.generals[name].package.extensionName, "hanjin") end
  for _, p in ipairs(room.players) do
    for _, key in ipairs({ "__heg_general", "__heg_deputy" }) do
      lu.assertEquals(Fk.generals[p:getMark(key)].package.extensionName, "hanjin")
    end
  end
  local ids = table.simpleClone(room.draw_pile)
  for _, p in ipairs(room.players) do table.insertTable(ids, p:getCardIds("h")) end
  for _, id in ipairs(ids) do
    local card = Fk:getCardById(id)
    lu.assertEquals(card.package.extensionName, "hanjin")
    local spec = Cards.equipment[card.name]
    local kingdom = spec and spec.kingdom or Cards.tricks[card.name]
    if kingdom then lu.assertTrue(table.contains(room:getBanner("all_kingdoms"), kingdom)) end
  end
end

function Testhanjin_rules:testFinishedGameRecordsResultInItsNativeRoom()
  local room = FkTest.room
  local p = room.players[1]
  FkTest.runInRoom(function()
    p:revealGeneral(false)
    p:revealGeneral(true)
    room:gameOver({ p })
  end)
  local saved = json.decode(room.room:getSessionData()).hanjin_faction_ban_v1
  lu.assertNotNil(saved)
  lu.assertEquals(saved.banned, room:getBanner("hanjin_banned_kingdoms"))
  if table.contains(Ban.kingdoms, p.kingdom) then lu.assertEquals(saved.winners, {p.kingdom}) end
  local other = FkTest.createFakeRoom({1,2,3,4,5,6,7,8})
  lu.assertNil(other._session_data)
end

function Testhanjin_rules:testHistoryConsumedSoAbortedGamesDoNotReuseOldResults()
  local room = FkTest.room
  Session.finish(room, {})
  local previous = Session.consume(room)
  lu.assertEquals(previous.banned, room:getBanner("hanjin_banned_kingdoms"))
  lu.assertNil(Session.consume(room))
end

for _, skel in ipairs(Fk.packages.hanjin_generals.skill_skels) do
  for index, callback in ipairs(skel.tests) do
    Testhanjin_rules["testSkill_" .. skel.name .. "_" .. index] = function()
      callback(FkTest.room, FkTest.room.players[1])
    end
  end
end

return { name = "hanjin_rules" }
