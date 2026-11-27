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

local function startRoom(count, alternate, modeSettings, previous, blankDraft)
  local ids = {}
  for id = 1, count do table.insert(ids, id) end
  -- The engine test client starts in an eight-seat lobby.
  for id = count + 1, 8 do ClientInstance:removePlayer({ id }) end
  local propsById, defaults = {}, {}
  local function replyToDraft(request)
    for _, player in ipairs(request.players) do
      propsById[player.id] = request.data[player.id].component.model.prop
      defaults[player.id] = request.default_reply[player.id]
    end
    local first = request.players[1]
    local function faction(player)
      return propsById[player.id].prompt:match(":::([^:]+):seat#%d+$")
    end
    local otherFaction = table.find(request.players, function(player)
      return faction(player) ~= faction(first)
    end)
    -- A reply with two real cards from another faction must still be rejected.
    for _, player in ipairs(request.players) do
      local choice = player == first and defaults[otherFaction.id] or defaults[player.id]
      FkTest.setNextReplies(player, { choice })
    end
  end
  local room = support.createRoom {
    mode = Modes.locked,
    backend = FkTest.createFakeRoom(ids),
    realSelection = true,
    settings = {
      enableFreeAssign = true,
      luckTime = 5,
      _mode = modeSettings or { generalTimeout = 1 },
    },
    configure = function(current)
      -- Queue replies before the opening draft sends packets, within this room only.
      local notify = current.notifyMoveFocus
      function current:notifyMoveFocus(players, command, timeout)
        local request = self.current_request
        if command == "AskForGeneral" and request and request.command == "CustomDialog" then
          self.notifyMoveFocus = notify
          replyToDraft(request)
        end
        return notify(self, players, command, timeout)
      end
      if previous then current:setSessionData { qiao_faction_ban_v1 = previous } end
      if blankDraft then
        local makePile = current.makeGeneralPile
        function current:makeGeneralPile()
          makePile(self)
          -- Opening-hand assertions measure the mode's base draw, with no skill altering it.
          self.general_pile = table.filter(self.general_pile, function(name)
            return name:match("^qiao_test__[a-z]+_%d+$") ~= nil
          end)
        end
      end
      local shuffle = current.shuffleTable
      function current:shuffleTable(list)
        if #list == 4 and Ban.isKnown(list[1]) and Ban.isKnown(list[4]) then
          if alternate then list[2], list[3] = list[3], list[2] end
        else
          return shuffle(self, list)
        end
      end
    end,
  }
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

function Testlocked_factions:testFinishedLockedGamesWriteNativeWinAndLoss()
  for _, count in ipairs({ 3, 4 }) do
    local room = startRoom(count, nil, { [Locked.ruleKey] = Locked.rules[count - 2] })
    local records = {}
    function room.room:updatePlayerWinRate(id, mode, _, result)
      lu.assertEquals(mode, Modes.locked)
      lu.assertNil(records[id], "The same player was counted twice")
      records[id] = result
    end

    FkTest.runInRoom(function()
      room.start_time = os.time()
      lu.assertFalse(room:shouldUpdateWinRate())
      room.start_time = os.time() - 60
      room:setTag("qiao_locked_start_rejected", true)
      lu.assertFalse(room:shouldUpdateWinRate())
      room:setTag("qiao_locked_start_rejected", nil)
      room:gameOver({ room.players[1] })
    end)

    for seat, player in ipairs(room.players) do
      lu.assertEquals(records[player.id], seat == 1 and 1 or 2)
    end
    support.clearRoom()
  end
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
  local humanVsAI = W.toQmlData(mode.ui_settings, settings(6, Locked.humanVsAI))[1]._children[1]
  lu.assertEquals(humanVsAI.value, Locked.humanVsAI)
  lu.assertTrue(mode:feasible(settings(2, Locked.humanVsAI)))
  lu.assertTrue(mode:feasible(settings(10, Locked.humanVsAI)))
  lu.assertFalse(mode:feasible(settings(11, Locked.humanVsAI)))
end

function Testlocked_factions:testCreationChecksTheActiveBanSchemeAndHidesWildCount()
  __dofile("../../../tests/support/qiao_content.lua")
  local mode = Fk.game_modes[Modes.locked]
  local W = require "ui_emu.preferences"
  local scheme = { banPkg = {} }
  for name in pairs(Fk.packages) do scheme.banPkg[name] = {} end
  local options = { playerNum = 4, qiaoLockedBanScheme = scheme,
    _mode = { [Locked.ruleKey] = Locked.rules[2], [Guest.settingKey] = false } }

  local shortlist = {}
  scheme.banPkg.qiao_test_content = shortlist
  for _, kingdom in ipairs({ "wei", "shu" }) do
    for i = 1, 3 do table.insert(shortlist, ("qiao_test__%s_%d"):format(kingdom, i)) end
  end
  lu.assertFalse(mode:feasible(options))
  table.insert(shortlist, "qiao_test__wei_4")
  table.insert(shortlist, "qiao_test__shu_4")
  lu.assertTrue(mode:feasible(options))
  scheme.normalPkg = { qiao_test_content = { "qiao_test__shu_4" } }
  lu.assertFalse(mode:feasible(options))

  for _, group in ipairs(W.toQmlData(mode.ui_settings, options)) do
    for _, row in ipairs(group._children) do
      lu.assertNotEquals(row._settingsKey, "qiao_wild_count")
    end
  end
end

function Testlocked_factions:testDraftKeepsEqualFarmerOffersAndTwoExtraLandlordOffers()
  __dofile("../../../tests/support/qiao_content.lua")
  local players = { {}, {}, {} }
  local room = {
    players = players,
    getSettings = function(_, key)
      if key == Locked.ruleKey then return Locked.rules[1] end
      if key == Guest.settingKey then return false end
    end,
    shuffleTable = function() end,
  }
  local function plan(cardsPerFaction)
    local kept = {}
    for _, kingdom in ipairs({ "wei", "shu" }) do
      for i = 1, cardsPerFaction do
        table.insert(kept, ("qiao_test__%s_%d"):format(kingdom, i))
      end
    end
    return { kept = kept, allowed = { "wei", "shu" }, candidates = { "wei", "shu" },
      banned = {}, excluded = {} }
  end

  local offers, assigned, count = Locked.deal(room, plan(5), 5)
  lu.assertEquals(count, 2)
  lu.assertEquals({ #offers[players[1]], #offers[players[2]], #offers[players[3]] }, { 4, 2, 2 })
  lu.assertEquals(assigned[players[2]], assigned[players[3]])
  lu.assertNotEquals(assigned[players[1]], assigned[players[2]])
  lu.assertNil(Locked.deal(room, plan(3), 5))
end

function Testlocked_factions:testServerRejectsRuleThatDoesNotMatchActualSeats()
  for id = 4, 8 do ClientInstance:removePlayer({ id }) end
  local room, message
  local ok, errorMessage = pcall(support.createRoom, {
    mode = Modes.locked,
    backend = FkTest.createFakeRoom({ 1, 2, 3 }),
    realSelection = true,
    settings = { _mode = { [Locked.ruleKey] = Locked.rules[2] } },
    configure = function(current)
      room = current
      local original = room.sendLog
      function current:sendLog(log, ...)
        if log.type == "#QiaoLockedWrongPlayerCount" then message = log end
        return original(self, log, ...)
      end
    end,
  })
  lu.assertFalse(ok)
  lu.assertStrContains(errorMessage, "National-war setup did not reach the test loop")
  lu.assertNotNil(message)
  lu.assertTrue(room.game_finished)
  lu.assertNil(room:getTag("qiao_test_ready"))
end

function Testlocked_factions:testThreePlayerSeatsAndLandlordSkills()
  local room = startRoom(3, nil, nil, nil, true)
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
    local room = startRoom(4, alternate, nil, nil, true)
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

local function startHumanVsAI(humanCount, robotCount)
  local count = humanCount + robotCount
  local ids = {}
  for id = 1, count do table.insert(ids, id) end
  local backend = FkTest.createFakeRoom(ids)
  for id = count + 1, 8 do ClientInstance:removePlayer({ id }) end
  for id = 1, count do
    local player = backend:getPlayers():at(id - 1)
    if id > 8 then ClientInstance:addPlayer({ player:getId(), player:getScreenName(), player:getAvatar(), true, 0 }) end
    if id > humanCount then player:setState(fk.Player_Robot) end
  end

  local room = support.createRoom {
    mode = Modes.locked, backend = backend, realSelection = true,
    settings = { _mode = { [Locked.ruleKey] = Locked.humanVsAI, qiao_offer_count = 2, generalTimeout = 1 } },
    configure = function(current)
      local notify = current.notifyMoveFocus
      function current:notifyMoveFocus(players, command, timeout)
        local req = self.current_request
        if command == "AskForGeneral" and req and req.command == "CustomDialog" then
          self.notifyMoveFocus = notify
          for _, player in ipairs(req.players) do
            local prop = req.data[player.id].component.model.prop
            lu.assertStrContains(prop.prompt, "#QiaoChooseLockedKingdom")
            lu.assertEquals(#prop.generals, 2)
            if player.serverplayer:getState() ~= fk.Player_Robot then
              FkTest.setNextReplies(player, { req.default_reply[player.id] })
            end
          end
        end
        return notify(self, players, command, timeout)
      end
    end,
  }
  local clans = {}
  for _, player in ipairs(room.players) do
    local assigned = player:getMark("__heg_init_kingdom")
    lu.assertTrue(Ban.isKnown(assigned))
    lu.assertEquals(player.kingdom, "unknown")
    lu.assertFalse(player:hasSkill("m_feiyang", true))
    lu.assertFalse(player:hasSkill("m_bahu", true))
    lu.assertEquals(player:getHandcardNum(), 4)
    local clan = clans[assigned] or { humans = 0, robots = 0 }
    local kind = player.serverplayer:getState() == fk.Player_Robot and "robots" or "humans"
    clan[kind] = clan[kind] + 1
    clans[assigned] = clan
  end
  local humans, robots = {}, {}
  for _, clan in pairs(clans) do
    lu.assertTrue(clan.humans == 0 or clan.robots == 0)
    if clan.humans > 0 then table.insert(humans, clan.humans) end
    if clan.robots > 0 then table.insert(robots, clan.robots) end
  end
  table.sort(humans)
  table.sort(robots)
  lu.assertEquals(#room:getBanner("all_kingdoms"), #humans + #robots)
  return room, humans, robots
end

function Testlocked_factions:testHumanVsAIEqualFactionsExceedNormalCapWithoutTurningWild()
  local room, humans, robots = startHumanVsAI(5, 5)
  lu.assertEquals(humans, { 5 })
  lu.assertEquals(robots, { 5 })
  FkTest.runInRoom(function()
    local hidden = room.players[#room.players]
    for i = 1, #room.players - 1 do
      local p = room.players[i]
      p:revealGeneral(true, true)
      lu.assertEquals(p.kingdom, p:getMark("__heg_init_kingdom"))
    end
    local ally = table.find(room.players, function(p) return p ~= hidden and p.kingdom == hidden:getMark("__heg_init_kingdom") end)
    lu.assertTrue(H.compareExpectedKingdomWith(hidden, ally))
    hidden:revealGeneral(false, true)
    lu.assertEquals(hidden.kingdom, hidden:getMark("__heg_init_kingdom"))
  end)
end

function Testlocked_factions:testHumanVsAIKeepsSingleExtraRobotTogether()
  local _, humans, robots = startHumanVsAI(2, 3)
  lu.assertEquals(humans, { 2 })
  lu.assertEquals(robots, { 3 })
end

function Testlocked_factions:testHumanVsAISplitsMoreNumerousHumans()
  local _, humans, robots = startHumanVsAI(2, 1)
  lu.assertEquals(humans, { 1, 1 })
  lu.assertEquals(robots, { 1 })
end

function Testlocked_factions:testHumanVsAISplitsMoreNumerousRobots()
  local _, humans, robots = startHumanVsAI(2, 5)
  lu.assertEquals(humans, { 2 })
  lu.assertEquals(robots, { 2, 3 })
end

function Testlocked_factions:testHumanVsAIRejectsMissingRobotSide()
  for id = 3, 8 do ClientInstance:removePlayer({ id }) end
  local room, message
  local ok = pcall(support.createRoom, {
    mode = Modes.locked, backend = FkTest.createFakeRoom({ 1, 2 }), realSelection = true,
    settings = { _mode = { [Locked.ruleKey] = Locked.humanVsAI } },
    configure = function(current)
      room = current
      local original = room.sendLog
      function current:sendLog(log, ...)
        if log.type == "#QiaoLockedMissingHumanOrRobot" then message = log end
        return original(self, log, ...)
      end
    end,
  })
  lu.assertFalse(ok)
  lu.assertNotNil(message)
  lu.assertTrue(room.game_finished)
end

return { name = "locked_factions" }
