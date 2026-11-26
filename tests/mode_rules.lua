local support = __dofile("../../../tests/support/hegemony.lua")
local content = __dofile("../../../tests/support/ascension_content.lua")
local H = require "packages.hegemony.util"
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local Variants = require "packages.qiao.pkg.qiao_mode.rules.variants"
local SkillPrelight = require "packages.qiao.pkg.qiao_mode.rules.skill_prelight"
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")

Testmode_rules = { setup = support.initQiaoRoom, tearDown = support.clearRoom }

function Testmode_rules:testSkillButtonLabelsKeepActionableAndProtectedSkills()
  local clientClass = Fk:getBoardGame("qiao_heg_mode").client_klass
  local cases = {
    { "qiao__skill_em_shu001_flag", "六师率义旗", "六师" },
    { "qiao__retinue_skill_bingzhou_langqi", "并州狼骑", "并州骑" },
    { "qiao__retinue_skill_qingzhou_jingrui", "青州精锐", "青州兵" },
    { "qiao__retinue_skill_lujiang_shangjia", "庐江上甲", "庐江兵" },
    { "qiao__luminous_pearl_skill", "定澜夜明珠", "夜明珠" },
    { "qiao__sihai_liuqian_skill", "四海流钱", "流钱" },
    { "qiao__five_elements_fan_skill", "五行鹤翎扇", "五行扇" },
    { "qiao__spear_skill", "丈八蛇矛", "丈八矛" },
    { "qiao__xuehai_mowangzun_skill", "血海魔王樽", "魔王樽" },
    { "qiao__halberd_skill", "方天画戟", "方天戟" },
    { "qiao__blade_skill", "青龙偃月刀", "青龙刀" },
    { "qiao__triblade_skill", "三尖两刃刀", "三尖刀" },
    { "qiao__black_chain_skill", "乌铁锁链", "乌铁链" },
    { "qiao__crossbow_skill", "诸葛连弩", "诸葛弩" },
    { "qiao__dragon_phoenix_skill", "飞龙夺凤", "龙凤剑" },
    { "qiao__shenshou_sizhao_skill", "神授思召", "思召剑" },
    { "qiao__xuwang_zhimian_skill", "虚妄之冕", "虚妄冕" },
    { "qiao__jinxiu_zhengpao_skill", "锦绣征袍", "锦绣袍" },
    { "qiao__zhoujun_lingbingyin_skill", "州郡领兵印", "领兵印" },
    { "qiao__retinue_skill_bingzhou_distance", "并州狼骑·距离", false },
    { "qiao__retinue_skill_baima_yicong", "白马义从", false },
    { "qiao__skill_em_wei001_banner", "霸者求贤状", false },
    { "qiao__retinue_skill_bazhenbing_viewas", "八阵兵", "八阵兵" },
    { "qiao__retinue_skill_baima_yicong", "白马·义", "白马·义" },
    { "qiao__skill_wu011_2", "红颜状态", "红颜状" },
    { "qiao__dark_armor_skill", "黑光铠防具", "黑光铠" },
  }
  for _, case in ipairs(cases) do
    local name, full, expected = table.unpack(case)
    lu.assertNotNil(Fk.skills[name], name)
    lu.assertEquals(clientClass.skillButtonLabel(nil, name, full, false), expected, name)
  end
  lu.assertEquals(clientClass.skillButtonLabel(nil, "qiao__retinue_skill_baima_yicong",
    "白马义从", true), "白马义")
end

function Testmode_rules:testStateSkillsCannotPrelightButMixedSkillsCan()
  local room = FkTest.room
  local player = room.players[1]
  local hongyan, mashu = "qiao__skill_wu011_2", "qiao__skill_shu006_1"
  local paoxiao = "qiao__skill_shu003_1"
  lu.assertFalse(SkillPrelight.canPrelight(hongyan))
  lu.assertFalse(SkillPrelight.canPrelight(mashu))
  lu.assertFalse(SkillPrelight.canPrelight("qiao__skill_wu017_2"))
  lu.assertFalse(SkillPrelight.canPrelight("qiao__skill_jin023_2"))
  lu.assertFalse(SkillPrelight.canPrelight("qiao__skill_wei002_3"))
  lu.assertTrue(SkillPrelight.canPrelight("qiao__skill_em_han001_1"))
  lu.assertTrue(SkillPrelight.canPrelight("qiao__skill_em_han001_3"))
  lu.assertTrue(SkillPrelight.canPrelight(paoxiao))

  FkTest.runInRoom(function()
    skill_test.installBlankGenerals(room, "shu")
    for _, name in ipairs({ hongyan, mashu, paoxiao }) do
      player:addFakeSkill(name)
      room.callbacks.prelight(room, player.id, { "", "prelight", name, "true" })
    end
    player:prelightSkill(Fk.skills[mashu], true)
  end)
  lu.assertFalse(table.contains(player.prelighted_skills, Fk.skills[hongyan]))
  lu.assertFalse(table.contains(player.prelighted_skills, Fk.skills[mashu]))
  lu.assertTrue(table.contains(player.prelighted_skills, Fk.skills[paoxiao]))

  local clientClass = Fk:getBoardGame("qiao_heg_mode").client_klass
  local notices = {}
  local client = clientClass:new({
    notifyUI = function(_, command, data) table.insert(notices, { command, data }) end,
  })
  FkTest.runInRoom(function()
    client:notifyUI("AddSkill", { player.id, hongyan, true })
    client:notifyUI("AddSkill", { player.id, paoxiao, true })
    client:notifyUI("LoseSkill", { player.id, hongyan, true })
    client:notifyUI("ChangeSelf", player.id)
  end)
  lu.assertEquals(notices[1], { "AddSkill", { player.id, hongyan } })
  lu.assertEquals(notices[3], { "AddSkill", { player.id, paoxiao, true } })
  lu.assertEquals(notices[5], { "LoseSkill", { player.id, hongyan } })
  lu.assertEquals(notices[8], { "QiaoRefreshPrelightButtons", {} })
end

function Testmode_rules:testActiveAndPrelightButtonsFromHiddenSkillNotifications()
  local room = FkTest.room
  local serverPlayer = room.players[1]
  local sanchen = "qiao__skill_jin006_1"
  local minsi = "qiao__skill_han007_1"
  local wusheng = "qiao__skill_shu002_1"
  local shangyi = "qiao__skill_wu017_1"
  local kanpo = "qiao__skill_shu011_3"
  FkTest.runInRoom(function()
    skill_test.installBlankGenerals(room, "jin")
    skill_test.installDualGenerals(room, serverPlayer, {
      main = "qiao_heg__jin006", deputy = "qiao_test__jin_2", kingdom = "jin",
    })
    serverPlayer:hideGeneral(false)
    room:setCurrent(serverPlayer)
    serverPlayer.phase = Player.Play
    lu.assertTrue(serverPlayer:isFakeSkill(sanchen))
    room.callbacks.prelight(room, serverPlayer.id, { "", "prelight", sanchen, "true" })
    lu.assertFalse(table.contains(serverPlayer.prelighted_skills, Fk.skills[sanchen]))
  end)

  client_room.run(room, function(clients)
    local player = clients[1]
    player._fake_skills = table.simpleClone(player._fake_skills)
    player._manually_fake_skills = table.simpleClone(player._manually_fake_skills)
    local buttons = {}
    local board = Fk:getBoardGame("qiao_heg_mode")
    local client = board.client_klass:new({
      notifyUI = function(_, command, data)
        if command ~= "AddSkill" or data[1] ~= player.id then return end
        local entry = buttons[data[2]] or {}
        entry[data[3] and "prelight" or "regular"] = true
        buttons[data[2]] = entry
      end,
    })
    client.players = clients
    for _, name in ipairs({
      sanchen, "qiao__skill_jin017_2", "qiao__skill_han005_1", "qiao__skill_han004_1",
      "qiao__skill_qun001_1", "qiao__skill_shu001_1", minsi, wusheng, shangyi, kanpo,
    }) do
      client:addSkill({ player.id, name, true })
      lu.assertTrue(buttons[name].regular, name)
      lu.assertEquals(buttons[name].prelight == true, name == wusheng or name == shangyi or name == kanpo, name)
    end

    -- A room summary restores dark skills separately from the request handler's
    -- skill list. Rebuild the same client-side state, then send the real snapshot.
    player.player_skills = {}
    player._manually_fake_skills = { Fk.skills[sanchen], Fk.skills[minsi], Fk.skills[wusheng] }
    player.prelighted_skills = {}
    buttons = {}
    local previousClient = ClientInstance
    ClientInstance = client
    local ok, err = pcall(player.sendDataToUI, player)
    ClientInstance = previousClient
    if not ok then error(err, 0) end
    lu.assertEquals(buttons[sanchen], { regular = true })
    lu.assertEquals(buttons[minsi], { regular = true })
    lu.assertTrue(buttons[wusheng].prelight)

    local handler = client.request_handlers.PlayCard:new(player)
    handler:setup()
    local button = handler.scene:getAllItems("SkillButton")[sanchen]
    lu.assertNotNil(button, "重连后技能对应的请求按钮须重新登记")
    lu.assertTrue(handler:skillButtonValidity(sanchen))
    handler:selectSkill(sanchen, { selected = true })
    lu.assertEquals(handler.skill_name, sanchen)
    lu.assertTrue(handler:targetValidity(clients[2].id))
    handler:_finish()
  end)
end

function Testmode_rules:testOneGlobalWindowAfterAllHandsAreDealt()
  support.clearRoom()
  local countdownCalls, waits = 0, 0
  support.createRoom {
    mode = "qiao_heg_mode",
    realSelection = true,
    configure = function(current)
      local notify, delay = current.doBroadcastNotify, current.delay
      function current:doBroadcastNotify(command, data, players)
        if command == "QiaoInitialPrelight" then
          countdownCalls = countdownCalls + 1
          lu.assertNil(players)
          lu.assertEquals(data, { 3000 })
          for _, player in ipairs(self.players) do
            lu.assertTrue(player:getHandcardNum() >= 4)
          end
        end
        return notify(self, command, data, players)
      end
      function current:delay(ms)
        if ms == 3000 then
          lu.assertEquals(countdownCalls, 1)
          waits = waits + 1
        end
        return delay(self, ms)
      end
    end,
  }
  lu.assertEquals(countdownCalls, 1)
  lu.assertEquals(waits, 1)
  for _, trigger in ipairs(Fk.global_trigger) do
    lu.assertNotEquals(trigger.name, "#qiao_initial_prelight")
  end
end

local G = content.generals

local function room() return FkTest.room end

local function hidden(player, main, deputy, kingdom)
  FkTest.runInRoom(function()
    content.setupHidden(room(), player, main, deputy, kingdom)
  end)
end

local function turnStart(player, replies)
  FkTest.cleanNextReplies(player)
  if replies ~= nil then FkTest.setNextReplies(player, replies) end
  FkTest.runInRoom(function() room().logic:trigger(fk.TurnStart, player, {}) end)
  FkTest.cleanNextReplies(player)
end

function Testmode_rules:testModeRuleLoadsNationalWarRuleAndExchangeHistory()
  local current = room()
  lu.assertTrue(current:hasSkill("heg_rule"))
  lu.assertTrue(current:hasSkill("#qiao_exchange_history"))
  lu.assertTrue(current:hasSkill("#qiao_ascension_rule"))
  lu.assertTrue(current:hasSkill("#qiao_adaptation_display"))

  local counts = {}
  for _, name in ipairs(current.logic.skills) do counts[name] = (counts[name] or 0) + 1 end
  lu.assertEquals(counts["heg_rule"], 1)
  lu.assertEquals(counts["#qiao_exchange_history"], 1)
  lu.assertEquals(counts["#qiao_ascension_rule"], 1)
  lu.assertEquals(counts["#qiao_adaptation_display"], 1)

  -- Dependencies are attached to the real mode-rule Skill object, not left in
  -- the skeleton's display-only related_skills name list.
  local related = {}
  for _, skill in ipairs(Fk.skills["#qiao_commander_rule"].related_skills) do
    related[skill.name] = true
  end
  lu.assertTrue(related["heg_rule"])
  lu.assertTrue(related["#qiao_exchange_history"])
  lu.assertTrue(related["#qiao_ascension_rule"])
  lu.assertTrue(related["#qiao_adaptation_display"])

  -- The display effects and status skill are room-scoped, not global.
  for _, skill in ipairs(Fk.global_trigger) do
    lu.assertFalse(skill.name:startsWith("#qiao_adaptation_display"))
    if skill.skeleton then
      lu.assertNotEquals(skill.skeleton.name, "qiao__qun_control_rule")
      lu.assertNotEquals(skill.skeleton.name, "qiao__qun_damage_history")
    end
  end
  for _, name in ipairs({ "qiao__qun_dying_rule", "qiao__qun_cards_rule",
    "qiao__qun_control_rule", "qiao__qun_damage_history", "qiao__qun_duanchang_rule" }) do
    lu.assertTrue(current:hasSkill(name), "Missing room rule: " .. name)
  end
  for _, list in pairs(Fk.global_status_skill) do
    for _, skill in ipairs(list) do
      lu.assertFalse(skill.skeleton and skill.skeleton.name == "#qiao_adaptation_display")
    end
  end
  local statusCount = 0
  for _, list in pairs(current.status_skills) do
    for _, skill in ipairs(list) do
      if skill.skeleton and skill.skeleton.name == "#qiao_adaptation_display" then
        statusCount = statusCount + 1
      end
    end
  end
  lu.assertEquals(statusCount, 1)
end

function Testmode_rules:testBoardGameRegistrationUsesOneSharedEngine()
  local base = Fk:getBoardGame("new_heg_mode")
  local qiao = Fk:getBoardGame("qiao_heg_mode")
  -- The extension must not add a second boardgame that reuses the same Engine:
  -- Fk:loadPackages() postLoads every board entry, which would run the Engine's
  -- postLoad twice and duplicate game modes/card types.
  lu.assertEquals(base.page.name, "Room")
  lu.assertEquals(qiao.page.url, "packages/qiao/pkg/qiao_mode/qml/QiaoRoom.qml")
  lu.assertEquals(Fk:getBoardGame("qiao_free_mode").page, qiao.page)
  lu.assertIs(qiao.room_klass, base.room_klass)
  lu.assertIs(qiao.engine, Fk)
  lu.assertNil(Fk.boardgames.qiao)
  lu.assertIs(qiao.client_klass, require "packages.qiao.pkg.qiao_mode.client")
  lu.assertEquals(Fk.game_modes.qiao_heg_mode.game_name,
    Fk.game_modes.new_heg_mode.game_name)
  local shared = 0
  for _, board in pairs(Fk.boardgames) do
    if board.engine == Fk then shared = shared + 1 end
  end
  lu.assertEquals(shared, 1)
end

function Testmode_rules:testRevealPromptAtTurnStartCanRevealMain()
  local p = room().players[1]
  hidden(p, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
  turnStart(p, { { "revealMain:::qiao_test__wei_1" }, "__cancel" })
  lu.assertEquals(p.general, "qiao_test__wei_1")
  lu.assertEquals(p.deputyGeneral, "anjiang")
end

function Testmode_rules:testRevealPromptAtTurnStartCanRevealDeputy()
  local p = room().players[1]
  hidden(p, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
  turnStart(p, { { "revealDeputy:::qiao_test__wei_2" }, "__cancel" })
  lu.assertEquals(p.general, "anjiang")
  lu.assertEquals(p.deputyGeneral, "qiao_test__wei_2")
end

function Testmode_rules:testRevealPromptAtTurnStartCanRevealBothOrCancel()
  local current, p = room(), room().players[1]
  hidden(p, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
  turnStart(p, { { "revealMain:::qiao_test__wei_1" }, { "qiao_turn_reveal_also_deputy" } })
  lu.assertEquals(p.general, "qiao_test__wei_1")
  lu.assertEquals(p.deputyGeneral, "qiao_test__wei_2")

  local second = current.players[2]
  hidden(second, "qiao_test__wei_3", "qiao_test__wei_4", "wei")
  turnStart(second, { { "Cancel" } })
  lu.assertEquals(second.general, "anjiang")
  lu.assertEquals(second.deputyGeneral, "anjiang")
end

function Testmode_rules:testRobotTurnStartUsesRevealFallback()
  local current, robot = room(), room().players[2]
  hidden(robot, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
  robot.serverplayer:setState(fk.Player_Robot)

  -- Let the engine receive the bot's real reply. Fix only the random fallback
  -- so the regression consistently exercises a legal reveal rather than Cancel.
  local fallbacks = {}
  local main = "revealMain:::qiao_test__wei_1"
  local deputy = "revealDeputy:::qiao_test__wei_2"
  local alsoDeputy = "qiao_turn_reveal_also_deputy"
  local pick = current.tableRandomPick
  current.tableRandomPick = function(self, candidates, count)
    if table.contains(candidates, main) or table.contains(candidates, alsoDeputy) then
      table.insert(fallbacks, table.simpleClone(candidates))
      return { candidates[1] }
    end
    return pick(self, candidates, count)
  end
  turnStart(robot)
  lu.assertEquals(fallbacks, { { main, deputy, "Cancel" }, { alsoDeputy, "Cancel" } })
  lu.assertEquals(robot.general, "qiao_test__wei_1")
  lu.assertEquals(robot.deputyGeneral, "qiao_test__wei_2")
end

function Testmode_rules:testRevealProhibitionIsRespectedByTheRealPrompt()
  local current, p = room(), room().players[1]
  hidden(p, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
  FkTest.runInRoom(function()
    current:setPlayerMark(p, "RevealProhibited", { "m" })
  end)
  local captured
  local original = current.askToOptions
  current.askToOptions = function(self, target, params)
    if target == p and params.prompt == "#HegRevealGenerals" then captured = params end
    return original(self, target, params)
  end
  local attemptedReveal = false
  local reveal = p.revealGeneral
  p.revealGeneral = function(self, deputy)
    attemptedReveal = true
    return reveal(self, deputy)
  end
  turnStart(p, { "__cancel" })
  p.revealGeneral = reveal
  current.askToOptions = original
  lu.assertNotNil(captured)
  lu.assertEquals(captured.options, { "revealDeputy:::qiao_test__wei_2" })
  lu.assertFalse(attemptedReveal)
  lu.assertEquals(p.general, "anjiang")
  lu.assertEquals(p.deputyGeneral, "anjiang")

  -- Both positions prohibited: there is no actionable reveal request.
  hidden(p, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
  FkTest.runInRoom(function()
    current:setPlayerMark(p, "RevealProhibited", { "m", "d" })
  end)
  local prohibited
  current.askToOptions = function(self, target, params)
    if target == p and params.prompt == "#HegRevealGenerals" then prohibited = params end
    return original(self, target, params)
  end
  turnStart(p, nil)
  current.askToOptions = original
  lu.assertNil(prohibited)
  lu.assertEquals(p.general, "anjiang")
  lu.assertEquals(p.deputyGeneral, "anjiang")
end

function Testmode_rules:testNativeLordConversionDoesNotPreemptQiaoAscension()
  local current, p = room(), room().players[1]
  -- The test general has a HanJin lord version but no upstream HegUtil mapping.
  lu.assertNil(H.lordGenerals[G.wei_normal.name])
  hidden(p, G.wei_normal.name, G.wei_deputy.name, "wei")
  FkTest.runInRoom(function()
    current:setBanner("all_kingdoms", { "wei", "shu", "wu", "qun" })
    for index = 2, #current.players do
      current:setPlayerProperty(current.players[index], "kingdom", "shu")
    end
  end)
  local prompts = {}
  local original = current.askToOptions
  current.askToOptions = function(self, target, params)
    if target == p and params.prompt == "#HegRevealGenerals" then
      table.insert(prompts, table.simpleClone(params.options))
    end
    return original(self, target, params)
  end
  turnStart(p, { { "Cancel" } })
  current.askToOptions = original
  lu.assertEquals(prompts, { {
    A.ASCEND_ACCEPT, "qiao_turn_reveal:::" .. G.wei_normal.name, "qiao_turn_reveal_deputy:::" .. G.wei_deputy.name,
  } })
  lu.assertEquals(p.general, "anjiang")
  lu.assertFalse(A.has_lord(current, "wei"))
end

function Testmode_rules:testWolvesAreDisabledByDefault()
  local current = room()
  lu.assertFalse(Variants.enabled(current))
  lu.assertTrue(current:getSettings("old_battle_royal"))
  lu.assertFalse(table.find(current.logic.skill_table[fk.Damaged] or {}, function(skill)
    return skill:getSkeleton().name == "heg_rule"
  end) ~= nil)
  FkTest.runInRoom(function() H.enterBattleRoyalMode(current) end)
  lu.assertEquals(current:getBanner("@[:]BattleRoyalDummy"), "BattleRoyalMode")
  lu.assertFalse(current:hasSkill("#new_battle_royal_event&"))
  lu.assertNil(current:getBanner("@[:]new_battle_royal_event"))
end

function Testmode_rules:testWolvesCanBeEnabledExplicitly()
  support.clearRoom()
  local current = support.createRoom { mode = "qiao_free_mode", settings = { qiao_wolves = true } }
  lu.assertTrue(Variants.enabled(current))
  lu.assertFalse(current:getSettings("old_battle_royal"))
  lu.assertNotNil(table.find(current.logic.skill_table[fk.Damaged] or {}, function(skill)
    return skill:getSkeleton().name == "heg_rule"
  end))
  FkTest.runInRoom(function() H.enterBattleRoyalMode(current) end)
  lu.assertEquals(current:getBanner("@[:]BattleRoyalDummy"), "BattleRoyalMode")
  lu.assertTrue(current:hasSkill("#new_battle_royal_event&"))
end

function Testmode_rules:testDefaultOverridesLegacyNewBattleSetting()
  local current = room()
  current.settings._mode.old_battle_royal = false
  Variants.apply(current)
  lu.assertTrue(current:getSettings("old_battle_royal"))
end

return { name = "mode_rules" }
