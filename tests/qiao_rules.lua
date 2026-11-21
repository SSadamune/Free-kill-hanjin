local support = __dofile("../../../tests/support/hegemony.lua")
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Session = require "packages.qiao.pkg.qiao_mode.rules.session"
Testqiao_rules = { setup = support.initQiaoRoom, tearDown = support.clearRoom }

function Testqiao_rules:testModeAndRealSelection()
  local room = FkTest.room
  lu.assertEquals(room:getSettings("gameMode"), "qiao_heg_mode")
  lu.assertFalse(table.contains(Fk.game_mode_disabled.qiao_heg_mode, "qiao_generals"))
  lu.assertEquals(#room:getBanner("all_kingdoms"), 4)
  lu.assertEquals(#room:getBanner("qiao_banned_kingdoms"), 2) -- Six independent test factions.
  for _, p in ipairs(room.players) do
    local a, b = p:getMark("__heg_general"), p:getMark("__heg_deputy")
    lu.assertTrue(#Guest.pairKingdoms(room, a, b) > 0)
    lu.assertEquals(#p:getCardIds("h"), 4)
    lu.assertFalse(table.contains(room.general_pile, a))
    lu.assertFalse(table.contains(room.general_pile, b))
  end
end

function Testqiao_rules:testBannedGeneralsCannotReenterViaSameNameConversion()
  local room = FkTest.room
  local wild = 0
  FkTest.runInRoom(function()
    for _, name in ipairs(room.general_pile) do
      -- A pile entry may be a guest resolved to this game's allowed set even
      -- though its printed affiliation is banned.
      local entry = Guest.factionsOf(room, name)
      lu.assertNotNil(entry)
      if entry.wild then
        wild = wild + 1
      else
        lu.assertTrue(table.find(entry.kingdoms, function(k)
          return table.contains(room:getBanner("all_kingdoms"), k)
        end) ~= nil)
      end
    end
    for _, name in ipairs(room:getTag("qiao_excluded_generals")) do lu.assertFalse(Fk:canUseGeneral(name)) end
  end)
  for _, p in ipairs(room.players) do
    if Fk.generals[p:getMark("__heg_general")].kingdom == "wild" then wild = wild + 1 end
  end
  lu.assertTrue(wild <= 4)
end

function Testqiao_rules:testBannedEquipmentRestoresMatchingOrdinaryCard()
  local room = FkTest.room
  local original = table.find(Fk.cards, function(card) return card.name == "qiao_test__dragon_phoenix" end)
  local ordinary = table.find(Fk.cards, function(card)
    return card.name == "qiao_test__double_swords" and card.suit == original.suit and card.number == original.number
  end)
  local result, void
  FkTest.runInRoom(function()
    result, void = Cards.apply(room, { original.id }, { ordinary.id }, { "shu" })
  end)
  lu.assertEquals(result, { ordinary.id })
  lu.assertEquals(void, { original.id })
end

local function testCard(name)
  return assert(table.find(Fk.cards, function(card) return card.name == "qiao_test__" .. name end))
end

function Testqiao_rules:testHanSwordIsAddedWithoutReplacingAnOrdinaryCard()
  local sword, ordinary = testCard("chixiao_sword"), testCard("blank_basic")
  local kept = Cards.apply(FkTest.room, { sword.id, ordinary.id }, {}, {})
  lu.assertEquals(kept, { sword.id, ordinary.id })
  local banned, void = Cards.apply(FkTest.room, { sword.id, ordinary.id }, {}, { "han" })
  lu.assertEquals(banned, { ordinary.id })
  lu.assertEquals(void, { sword.id })
end

function Testqiao_rules:testJinMountReplacesJueyingAndRestoresItWhenBanned()
  local mount, ordinary = testCard("linxiao_yuyu"), testCard("jueying")
  local active, void = Cards.apply(FkTest.room, { mount.id, ordinary.id }, {}, {})
  lu.assertEquals(active, { mount.id })
  lu.assertEquals(void, { ordinary.id })
  local banned, excluded = Cards.apply(FkTest.room, { mount.id, ordinary.id }, {}, { "jin" })
  lu.assertEquals(banned, { ordinary.id })
  lu.assertEquals(excluded, { mount.id })
end

function Testqiao_rules:testFactionTricksStayOutsideTheDefaultDeckEvenWhenAllowed()
  local trick = testCard("faction_trick")
  local removed = Cards.apply(FkTest.room, { trick.id }, {}, { "wei" })
  lu.assertEquals(removed, {})
  local stillRemoved = Cards.apply(FkTest.room, { trick.id }, {}, { "shu" })
  lu.assertEquals(stillRemoved, {})
  -- Only a special effect explicitly adding the trick may put it back.
  local included = Cards.apply(FkTest.room, { trick.id }, {}, { "shu" },
    { include_tricks = { trick.name } })
  lu.assertEquals(included, { trick.id })
  local banned = Cards.apply(FkTest.room, { trick.id }, {}, { "wei" },
    { include_tricks = { trick.name } })
  lu.assertEquals(banned, {})
end

function Testqiao_rules:testMissingOrdinaryCopyIsPrintedWithTheOriginalSuitAndRank()
  local special = testCard("linxiao_yuyu")
  local result, void
  FkTest.runInRoom(function()
    result, void = Cards.apply(FkTest.room, { special.id }, {}, { "jin" })
  end)
  local replacement = Fk:getCardById(result[1])
  lu.assertEquals(replacement.name, "qiao_test__jueying")
  lu.assertEquals(replacement.suit, special.suit)
  lu.assertEquals(replacement.number, special.number)
  lu.assertEquals(replacement.package.extensionName, "qiao")
  lu.assertFalse(table.contains(void, replacement.id))
end

function Testqiao_rules:testWildCountUIHasDefaultFourAndPreservesZero()
  local W = require "ui_emu.preferences"
  local mode = Fk.game_modes.qiao_heg_mode
  local function value(settings)
    for _, group in ipairs(W.toQmlData(mode.ui_settings, { _mode = settings })) do
      for _, field in ipairs(group._children) do
        lu.assertNotEquals(field._settingsKey, "notBanToFourKingdoms")
        if field._settingsKey == "qiao_wild_count" then return field.value end
      end
    end
    error("Missing wild count setting")
  end
  lu.assertEquals(value({}), 4)
  lu.assertEquals(value({ qiao_wild_count = 0 }), 0)
end

function Testqiao_rules:testCandidateUIHasKingdomSwitchesAndDynamicLimit()
  local W = require "ui_emu.preferences"
  local mode = Fk.game_modes.qiao_free_mode
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
  local offers = default.qiao_offer_count
  lu.assertEquals({ offers.from, offers.to, offers.value }, { 5, 10, 7 })
  local raised = rows { qiao_kingdom_limit = 6, qiao_offer_count = 5 }
  lu.assertEquals(raised.qiao_offer_count.value, 7)
  local lowered = rows { qiao_kingdom_limit = 2, qiao_offer_count = 3 }
  lu.assertEquals(lowered.qiao_offer_count.from, 3)
  lu.assertEquals(lowered.qiao_offer_count.value, 3)
  lu.assertEquals(rows({ qiao_offer_count = 11 }).qiao_offer_count.value, 10)
  local group = default.qiao_candidate_summary
  lu.assertEquals(#group._children, #Ban.kingdoms)
  lu.assertEquals(group.value, "魏、蜀、吴、群、汉、晋")
  lu.assertEquals(default.generalTimeout.to, 300)
  lu.assertEquals(default.generalTimeout.value, 90)
  lu.assertEquals(default.qiao_wild_count.to, 12)
  lu.assertEquals(default[Ban.limitKey].value, 4)
  lu.assertEquals(default[Ban.limitKey].from, 1)
  lu.assertEquals(default[Ban.limitKey].to, #Ban.kingdoms)
  local custom = rows { qiao_candidate_wei = false, qiao_kingdom_limit = 3 }
  lu.assertEquals(custom.qiao_candidate_summary.value, "蜀、吴、群、汉、晋")
  lu.assertEquals(custom[Ban.limitKey].value, 3)
  lu.assertEquals(custom[Ban.limitKey].to, #Ban.kingdoms - 1)
end

function Testqiao_rules:testOnlyIndependentContentEntersGame()
  local room = FkTest.room
  for _, name in ipairs(room.general_pile) do lu.assertEquals(Fk.generals[name].package.extensionName, "qiao") end
  for _, p in ipairs(room.players) do
    for _, key in ipairs({ "__heg_general", "__heg_deputy" }) do
      lu.assertEquals(Fk.generals[p:getMark(key)].package.extensionName, "qiao")
    end
  end
  local ids = table.simpleClone(room.draw_pile)
  for _, p in ipairs(room.players) do table.insertTable(ids, p:getCardIds("h")) end
  local allowed = room:getBanner("all_kingdoms")
  for _, id in ipairs(ids) do
    local card = Fk:getCardById(id)
    lu.assertEquals(card.package.extensionName, "qiao")
    local spec = Cards.equipment[card.name]
    if spec then
      lu.assertTrue(table.find(spec.kingdoms, function(kingdom)
        return table.contains(allowed, kingdom)
      end) ~= nil)
    end
    local kingdom = Cards.tricks[card.name]
    if kingdom then lu.assertTrue(kingdom == "wild" or table.contains(allowed, kingdom)) end
  end
end

function Testqiao_rules:testCollectionAndFreeModeSettingsAreDistinct()
  local W = require "ui_emu.preferences"
  local modes = Fk.game_modes
  local function preferences(mode, seatCompensation)
    local groups, rows = {}, {}
    local config = { _mode = {
      qiao_faction_ban_enabled = false, qiao_guest_replacement = false,
      qiao_late_seat_compensation = seatCompensation,
    } }
    local data = W.toQmlData(mode.ui_settings, config)
    lu.assertEquals(data[1].title, "qiao_rule_settings")
    for _, group in ipairs(data) do
      if group.title then groups[group.title] = true end
      for _, item in ipairs(group._children) do rows[item._settingsKey] = item end
    end
    local candidates = rows.qiao_candidate_summary._children
    lu.assertEquals(table.find(candidates, function(row)
      return row._settingsKey == "qiao_candidate_han"
    end).title, "qiao_enable_han")
    lu.assertEquals(table.find(candidates, function(row)
      return row._settingsKey == "qiao_candidate_jin"
    end).title, "qiao_enable_jin")
    lu.assertFalse(rows.qiao_guest_replacement.value)
    lu.assertStrContains(rows.qiao_guest_replacement._qml.url, "CheckRow.qml")
    return groups, rows
  end
  local collectionGroups, collection = preferences(modes.qiao_heg_mode)
  local freeGroups, free = preferences(modes.qiao_free_mode)
  for _, group in ipairs({ "hegemony_additional_rule", "hegemony_special_rule" }) do
    lu.assertNil(collectionGroups[group])
    lu.assertTrue(freeGroups[group])
  end
  lu.assertEquals(table.map(collection.qiao_candidate_summary._children, function(item)
    return item._settingsKey
  end), { "qiao_candidate_han", "qiao_candidate_jin" })
  lu.assertNil(collection.qiao_wolves)
  lu.assertNil(collection.qiao_late_seat_compensation)
  lu.assertNil(collection.qiao_kingdom_limit)
  lu.assertFalse(collection.qiao_faction_ban_enabled.value)
  lu.assertStrContains(collection.qiao_faction_ban_enabled._qml.url, "CheckRow.qml")
  lu.assertNotNil(free.qiao_wolves)
  lu.assertNotNil(free.qiao_kingdom_limit)
  local compensation = free.qiao_late_seat_compensation
  lu.assertEquals(compensation._qml.name, "TranslatedComboRow")
  lu.assertEquals(compensation.model, { "qiao_late_seat_none", "qiao_late_seat_luck_card" })
  lu.assertEquals(compensation.value, "qiao_late_seat_none")
  local _, saved = preferences(modes.qiao_free_mode, "qiao_late_seat_luck_card")
  lu.assertEquals(saved.qiao_late_seat_compensation.value, "qiao_late_seat_luck_card")
  for name, pack in pairs(Fk.packages) do
    -- The ascension fixture is registered only for its collection-mode suites.
    if not pack._ascension_content then
      lu.assertEquals(table.contains(Fk.game_mode_disabled.qiao_heg_mode, name),
        table.contains(Fk.game_mode_disabled.qiao_free_mode, name), name)
    end
  end
end

function Testqiao_rules:testFinishedGameRecordsResultInItsNativeRoom()
  local room = FkTest.room
  local p = room.players[1]
  FkTest.runInRoom(function()
    p:revealGeneral(false)
    p:revealGeneral(true)
    room:gameOver({ p })
  end)
  local saved = json.decode(room.room:getSessionData()).qiao_faction_ban_v1
  lu.assertNotNil(saved)
  lu.assertEquals(saved.banned, room:getBanner("qiao_banned_kingdoms"))
  if table.contains(Ban.kingdoms, p.kingdom) then lu.assertEquals(saved.winners, {p.kingdom}) end
  local other = FkTest.createFakeRoom({1,2,3,4,5,6,7,8})
  lu.assertNil(other._session_data)
end

function Testqiao_rules:testHistoryConsumedSoAbortedGamesDoNotReuseOldResults()
  local room = FkTest.room
  Session.finish(room, {})
  local previous = Session.consume(room)
  lu.assertEquals(previous.banned, room:getBanner("qiao_banned_kingdoms"))
  lu.assertNil(Session.consume(room))
end

for _, skel in ipairs(Fk.packages.qiao_generals.skill_skels) do
  for index, callback in ipairs(skel.tests) do
    Testqiao_rules["testSkill_" .. skel.name .. "_" .. index] = function()
      callback(FkTest.room, FkTest.room.players[1])
    end
  end
end

return { name = "qiao_rules" }
