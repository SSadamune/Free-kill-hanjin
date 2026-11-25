local support = __dofile("../../../tests/support/hegemony.lua")
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local H = require "packages.hegemony.util"
local Locked = require "packages.qiao.pkg.qiao_mode.rules.locked_factions"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local PairHp = require "packages.qiao.pkg.qiao_mode.rules.pair_hp"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.selection"
local LtkUI = require "packages.freekill-core.ltk.client.util"

Testlocked_factions = { tearDown = support.clearRoom }

local function startRoom(count, alternate, modeSettings, previous)
  local ids = {}
  for id = 1, count do table.insert(ids, id) end
  -- The engine test client starts in an eight-seat lobby.
  for id = count + 1, 8 do ClientInstance:removePlayer({ id }) end
  local propsById, defaults = {}, {}
  local ask = Request.ask
  Request.ask = function(self, ...)
    if self.room:getSettings("gameMode") == Modes.locked and self.focus_text == "AskForGeneral" then
      for _, player in ipairs(self.players) do
        propsById[player.id] = self.data[player.id].component.model.prop
        defaults[player.id] = self.default_reply[player.id]
      end
      local first = self.players[1]
      local faction = function(player)
        return propsById[player.id].prompt:match(":::([^:]+):seat#%d+$")
      end
      local otherFaction = table.find(self.players, function(player)
        return faction(player) ~= faction(first)
      end)
      -- A reply with two real cards from another faction must still be rejected.
      for _, player in ipairs(self.players) do
        local choice = player == first and defaults[otherFaction.id] or defaults[player.id]
        FkTest.setNextReplies(player, { choice })
      end
    end
    return ask(self, ...)
  end
  local ok, room = pcall(support.createRoom, {
    mode = Modes.locked,
    backend = FkTest.createFakeRoom(ids),
    realSelection = true,
    settings = {
      enableFreeAssign = true,
      luckTime = 5,
      _mode = modeSettings or { generalTimeout = 1 },
    },
    configure = function(current)
      if previous then current:setSessionData { qiao_faction_ban_v1 = previous } end
      local shuffle = current.shuffleTable
      function current:shuffleTable(list)
        if #list == 4 and Ban.isKnown(list[1]) and Ban.isKnown(list[4]) then
          if alternate then list[2], list[3] = list[3], list[2] end
        else
          return shuffle(self, list)
        end
      end
    end,
  })
  Request.ask = ask
  assert(ok, room)
  lu.assertFalse(room:getSettings("enableFreeAssign"))
  lu.assertEquals(#room:getBanner("all_kingdoms"), 2)
  local kingdoms = room:getBanner("qiao_candidate_kingdoms")
  lu.assertEquals(#room:getBanner("qiao_banned_kingdoms"), #kingdoms - 2)
  local dealt = {}
  local baseOffers = math.max(2, math.min(modeSettings and modeSettings.qiao_offer_count or 5, 5))
  for _, player in ipairs(room.players) do
    local props = assert(propsById[player.id])
    lu.assertEquals(props.choiceNum, 2)
    local landlord = count == 3 and player.seat == 1
    lu.assertEquals(#props.generals, baseOffers + (landlord and 2 or 0))
    local assigned = player:getMark("__heg_init_kingdom")
    local promptKey, faction, seat = props.prompt:match("^(.-):::([^:]+):(seat#%d+)$")
    lu.assertEquals(seat, "seat#" .. player.seat)
    lu.assertEquals(faction, Ban.kingdomLabel(assigned))
    local title = Fk:translate(promptKey, "zh_CN"):gsub("%%arg2", Fk:translate(seat, "zh_CN"))
      :gsub("%%arg", faction)
    local seatName = ({ "一号位", "二号位", "三号位", "四号位" })[player.seat]
    local identity = landlord and "地主" or "农民"
    local expectedTitle = count == 3 and (identity .. "（" .. seatName .. "）") or seatName
    lu.assertEquals(title, "你是" .. expectedTitle .. "，势力为" .. faction .. "，请选择主将与副将")
    lu.assertFalse(props.extraData.freeAssign)
    lu.assertEquals(props.extraData.guests, {})
    lu.assertEquals(props.extraData.guestIllustrations, Guest.replacementEnabled(room))
    lu.assertFalse(props.convertDisabled)
    local rule = Fk.choose_general_rule.qiao_heg_pair
    lu.assertTrue(rule.feasible(defaults[player.id], props.generals, props.extraData))
    lu.assertEquals(player.general, "anjiang")
    lu.assertEquals(player.deputyGeneral, "anjiang")
    lu.assertEquals(player.kingdom, "unknown")
    lu.assertEquals(ClientInstance:getPlayerById(player.id).kingdom, "unknown")
    for _, name in ipairs(props.generals) do
      lu.assertTrue(table.contains(Guest.factionsOf(room, name).kingdoms, assigned))
      lu.assertNil(dealt[name])
      dealt[name] = true
    end
    local main, deputy = PairHp.actual_main(player), PairHp.actual_deputy(player)
    lu.assertTrue(table.contains(props.generals, main))
    lu.assertTrue(table.contains(props.generals, deputy))
    lu.assertFalse(table.contains(room.general_pile, main))
    lu.assertFalse(table.contains(room.general_pile, deputy))
  end
  lu.assertEquals(room:getTag("qiao_selection_fallbacks"), { room.players[1].id })
  return room
end

function Testlocked_factions:testRoomRuleSelectsCapacity()
  local mode = Fk.game_modes[Modes.locked]
  local W = require "ui_emu.preferences"
  local function settings(count, rule)
    return { playerNum = count, _mode = { [Locked.ruleKey] = rule } }
  end

  local defaultRow = W.toQmlData(mode.ui_settings, settings(3))[1]._children[1]
  lu.assertEquals(defaultRow._settingsKey, Locked.ruleKey)
  lu.assertEquals(defaultRow.title, Locked.ruleKey)
  lu.assertEquals(defaultRow.model, Locked.rules)
  lu.assertEquals(defaultRow.roomSizes, { [Locked.rules[1]] = 3, [Locked.rules[2]] = 4 })
  lu.assertEquals(defaultRow.value, Locked.rules[1])
  lu.assertTrue(mode:feasible(settings(3, Locked.rules[1])))
  lu.assertFalse(mode:feasible(settings(4, Locked.rules[1])))
  lu.assertTrue(mode:feasible(settings(4, Locked.rules[2])))
  lu.assertFalse(mode:feasible(settings(3, Locked.rules[2])))
  lu.assertTrue(mode:feasible(settings(4)))
end

function Testlocked_factions:testThreePlayerSeatsAndLandlordSkills()
  local room = startRoom(3)
  local first, second, third = table.unpack(room.players)
  lu.assertEquals(second:getMark("__heg_kingdom"), third:getMark("__heg_kingdom"))
  lu.assertNotEquals(first:getMark("__heg_kingdom"), second:getMark("__heg_kingdom"))
  for _, player in ipairs(room.players) do
    local landlord = player == first
    lu.assertEquals(player:hasSkill("m_feiyang"), landlord)
    lu.assertEquals(player:hasSkill("m_bahu"), landlord)
    local maxHp = PairHp.max_hp(PairHp.actual_main(player), PairHp.actual_deputy(player), room)
    lu.assertEquals(player.maxHp, maxHp + (landlord and 1 or 0))
    lu.assertEquals(player.hp, player.maxHp)
    lu.assertEquals(player:getHandcardNum(), 4)
  end

  FkTest.runInRoom(function()
    second:revealGeneral(false)
    lu.assertTrue(H.compareExpectedKingdomWith(third, second))
    third:revealGeneral(true)
    lu.assertEquals(second.kingdom, third.kingdom)
    lu.assertTrue(H.compareKingdomWith(second, third))
    lu.assertNotEquals(second.kingdom, "wild")

    room:setCurrent(first)
    first.phase = Player.Start
    room.logic:trigger(fk.EventPhaseStart, first, PhaseData:new { who = first, phase = Player.Start })
    lu.assertEquals(first:getHandcardNum(), 5)

    local slash = Fk:cloneCard("qiao__slash")
    first.phase = Player.Play
    first:addCardUseHistory(slash.trueName)
    lu.assertTrue(slash.skill:withinTimesLimit(first, Player.HistoryPhase, slash))

    local judge = room:printCard("qiao__indulgence", Card.Heart, 6).id
    room:moveCardTo(judge, Card.PlayerJudge, first, fk.ReasonJustMove)
    local hand = first:getCardIds("h")
    FkTest.setNextReplies(first, { FkTest.ReplyUseSkill("discard_skill", {}, { hand[1], hand[2] }) })
    first.phase = Player.Judge
    room.logic:trigger(fk.EventPhaseStart, first, PhaseData:new { who = first, phase = Player.Judge })
    lu.assertEquals(first:getHandcardNum(), 3)
    lu.assertEquals(room:getCardArea(judge), Card.DiscardPile)
  end)
end

function Testlocked_factions:testFourPlayerFormationAndSiege()
  for _, alternate in ipairs({ false, true }) do
    local room = startRoom(4, alternate)
    local first, second, third, fourth = table.unpack(room.players)
    local teammate, opponent = alternate and third or second, alternate and second or third
    FkTest.runInRoom(function()
      for _, player in ipairs(room.players) do player:revealGeneral(false) end
    end)
    lu.assertTrue(H.compareKingdomWith(first, teammate))
    lu.assertTrue(H.compareKingdomWith(opponent, fourth))
    lu.assertTrue(H.compareKingdomWith(first, opponent, true))
    lu.assertEquals(H.inFormationRelation(first, teammate), not alternate)
    lu.assertEquals(H.inSiegeRelation(first, teammate, opponent), alternate)
    local counts = {}
    for _, player in ipairs(room.players) do
      table.insert(counts, player:getHandcardNum())
      lu.assertFalse(player:hasSkill("m_feiyang"))
      lu.assertFalse(player:hasSkill("m_bahu"))
    end
    lu.assertEquals(counts, { 3, 4, 4, 5 })
    support.clearRoom()
  end
end

function Testlocked_factions:testBattleRoyalRequiresOptIn()
  for _, enabled in ipairs({ false, true }) do
    local settings = { generalTimeout = 1, qiao_offer_count = 3 }
    if enabled then settings[BattleRoyal.settingKey] = true end
    local room = startRoom(3, nil, settings)
    local first = room.players[1]
    lu.assertFalse(BattleRoyal.entered(room))
    FkTest.runInRoom(function()
      room.logic:trigger(fk.BeforeTurnStart, first, TurnData:new(first, "game_rule"))
      lu.assertEquals(BattleRoyal.entered(room), enabled)
      if not enabled then H.enterBattleRoyalMode(room) end
    end)
    lu.assertEquals(BattleRoyal.entered(room), enabled)
    lu.assertEquals(first:hasSkill(BattleRoyal.SKILL), enabled)
    lu.assertFalse(first:hasSkill("battle_royal&"))
    support.clearRoom()
  end
end

function Testlocked_factions:testCollectionFactionSettingsAndRotation()
  local modeSettings = {
    generalTimeout = 1, qiao_candidate_jin = false, qiao_guest_replacement = false, qiao_offer_count = 9,
  }
  local room = startRoom(3, nil, modeSettings, {
    version = 1, winners = { "wei" }, banned = { "han" },
  })
  local W = require "ui_emu.preferences"
  local function configuredOffers(settings)
    for _, group in ipairs(W.toQmlData(Fk.game_modes[Modes.locked].ui_settings, { _mode = settings })) do
      for _, field in ipairs(group._children) do
        if field._settingsKey == "qiao_offer_count" then return { field.from, field.to, field.value } end
      end
    end
  end
  lu.assertEquals(configuredOffers(modeSettings), { 2, 5, 5 })
  lu.assertEquals(configuredOffers({ qiao_faction_ban_enabled = false, qiao_offer_count = 3 }), { 2, 5, 3 })
  lu.assertEquals(room:getBanner("qiao_candidate_kingdoms"), { "wei", "shu", "wu", "qun", "han" })
  lu.assertEquals(room:getTag("qiao_rotation_banned_kingdoms"), { "wei" })
  lu.assertFalse(table.contains(room:getBanner("all_kingdoms"), "wei"))
  lu.assertFalse(table.contains(room:getBanner("all_kingdoms"), "jin"))
  lu.assertFalse(Guest.replacementEnabled(room))
end

function Testlocked_factions:testGuestCandidateCanBeSelectedButCannotBeRedrawn()
  local room = startRoom(3)
  local player = room.players[1]
  local general, deputy, spare = "qiao_heg__shu002", "qiao_test__wei_1", "qiao_test__wei_2"
  local offers = { [player] = { general, deputy } }
  local props, hasRedrawState, picked, kingdoms, fallbacks, redrawn, replacement, reason
  FkTest.setRoomBreakpoint(player, "CustomDialog", function(data)
    props = data.component.model.prop
    hasRedrawState = player.mini_game_data ~= nil
    room:handleUpdateMini(player.id, { player.id, "updatemini", "redraw", "1", general })
    return false
  end)
  FkTest.setNextReplies(player, { { general, deputy } })
  FkTest.runInRoom(function()
    room:setBanner("all_kingdoms", { "wei", "jin" })
    room:setTag(Guest.key, {})
    for _, name in ipairs({ general, deputy, spare }) do table.removeOne(room.disabled_generals, name) end
    room.general_pile = { spare }
    picked, kingdoms, fallbacks = Selection.choose(room, { player }, offers, { [player] = "wei" })
    redrawn, replacement, reason = Selection.applyRedraw(room, player, offers, { general })
  end)
  lu.assertTrue(Guest.isGuest(room, general))
  lu.assertTrue(props.extraData.guestIllustrations)
  lu.assertEquals(props.extraData.guestFactions[general], Guest.guestKingdoms(general))
  lu.assertEquals(props.extraData.guests, {})
  lu.assertFalse(hasRedrawState)
  lu.assertFalse(redrawn)
  lu.assertNil(replacement)
  lu.assertEquals(reason, "redraw_disabled")
  lu.assertEquals(offers[player], { general, deputy })
  lu.assertEquals(room.general_pile, { spare })
  lu.assertEquals(picked[player], { general, deputy })
  lu.assertEquals(kingdoms[player], "wei")
  lu.assertEquals(fallbacks, {})
  lu.assertEquals(room:getTag("qiao_guest_redraws_v1"), {})
end

function Testlocked_factions:testClientConversionRespectsAssignment()
  startRoom(3)
  local client = Fk:getBoardGame(Modes.locked).client_klass:new({ notifyUI = function() end })
  client.settings = { gameMode = Modes.locked }
  client.disabled_packs, client.disabled_generals = {}, {}
  local prior = ClientInstance
  ClientInstance = client
  local ok, err = pcall(function()
    local general, alternative = "qiao_heg__wei002", "qiao_heg__jin009"
    lu.assertTrue(table.contains(LtkUI:getSameGenerals(general), alternative))
    client:notifyUI("CustomDialog", {
      component = { model = { prop = { extraData = { locked = true, pairing = { [general] = {} } } } } },
    })
    lu.assertFalse(table.contains(LtkUI:getSameGenerals(general), alternative))
    client:notifyUI("CustomDialog", { component = { model = { prop = {
      extraData = { locked = true, pairing = { [general] = {}, [alternative] = {} } },
    } } } })
    lu.assertTrue(table.contains(LtkUI:getSameGenerals(general), alternative))
  end)
  ClientInstance = prior
  assert(ok, err)
end

return { name = "locked_factions" }
