local support = __dofile("../../../tests/support/hegemony.lua")
local content = __dofile("../../../tests/support/ascension_content.lua")
local H = require "packages.hegemony.util"
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local Variants = require "packages.qiao.pkg.qiao_mode.rules.variants"

Testmode_rules = { setup = support.initQiaoRoom, tearDown = support.clearRoom }

function Testmode_rules:testOneGlobalWindowAfterAllHandsAreDealt()
  support.clearRoom()
  local focusCalls, waits = 0, 0
  support.createRoom {
    mode = "qiao_heg_mode",
    realSelection = true,
    configure = function(current)
      local focus, delay = current.notifyMoveFocus, current.delay
      function current:notifyMoveFocus(players, command, timeout)
        if command == "qiao_initial_prelight" then
          focusCalls = focusCalls + 1
          lu.assertTrue(players == self.players)
          lu.assertEquals(timeout, 3000)
          for _, player in ipairs(players) do
            lu.assertTrue(player:getHandcardNum() >= 4)
          end
        end
        return focus(self, players, command, timeout)
      end
      function current:delay(ms)
        if ms == 3000 then
          lu.assertEquals(focusCalls, 1)
          waits = waits + 1
        end
        return delay(self, ms)
      end
    end,
  }
  lu.assertEquals(focusCalls, 1)
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
  turnStart(p, { { "revealMain:::qiao_test__wei_1" } })
  lu.assertEquals(p.general, "qiao_test__wei_1")
  lu.assertEquals(p.deputyGeneral, "anjiang")
end

function Testmode_rules:testRevealPromptAtTurnStartCanRevealDeputy()
  local p = room().players[1]
  hidden(p, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
  turnStart(p, { { "revealDeputy:::qiao_test__wei_2" } })
  lu.assertEquals(p.general, "anjiang")
  lu.assertEquals(p.deputyGeneral, "qiao_test__wei_2")
end

function Testmode_rules:testRevealPromptAtTurnStartCanRevealBothOrCancel()
  local current, p = room(), room().players[1]
  hidden(p, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
  turnStart(p, { { "revealAll" } })
  lu.assertEquals(p.general, "qiao_test__wei_1")
  lu.assertEquals(p.deputyGeneral, "qiao_test__wei_2")

  local second = current.players[2]
  hidden(second, "qiao_test__wei_3", "qiao_test__wei_4", "wei")
  turnStart(second, { { "Cancel" } })
  lu.assertEquals(second.general, "anjiang")
  lu.assertEquals(second.deputyGeneral, "anjiang")
end

function Testmode_rules:testRevealProhibitionIsRespectedByTheRealPrompt()
  local current, p = room(), room().players[1]
  hidden(p, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
  FkTest.runInRoom(function()
    current:setPlayerMark(p, "RevealProhibited", { "m" })
  end)
  local captured
  local original = current.askToChoice
  current.askToChoice = function(self, target, params)
    if target == p and params.prompt == "#HegRevealGenerals" then captured = params end
    return original(self, target, params)
  end
  turnStart(p, { { "Cancel" } })
  current.askToChoice = original
  lu.assertNotNil(captured)
  lu.assertFalse(table.contains(captured.choices, "revealMain:::qiao_test__wei_1"))
  lu.assertTrue(table.contains(captured.choices, "revealDeputy:::qiao_test__wei_2"))
  lu.assertEquals(p.general, "anjiang")

  -- Both positions prohibited: the upstream prompt offers no reveal option.
  hidden(p, "qiao_test__wei_1", "qiao_test__wei_2", "wei")
  FkTest.runInRoom(function()
    current:setPlayerMark(p, "RevealProhibited", { "m", "d" })
  end)
  local prohibited
  current.askToChoice = function(self, target, params)
    if target == p and params.prompt == "#HegRevealGenerals" then prohibited = params end
    return original(self, target, params)
  end
  turnStart(p, nil)
  current.askToChoice = original
  lu.assertNotNil(prohibited)
  lu.assertEquals(prohibited.choices, { "Cancel" })
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
  local original = current.askToChoice
  current.askToChoice = function(self, target, params)
    if target == p then table.insert(prompts, params.prompt) end
    return original(self, target, params)
  end
  turnStart(p, { { "Cancel" }, { "Cancel" } })
  current.askToChoice = original
  lu.assertTrue(table.contains(prompts, "#QiaoSecondLordConvert"))
  lu.assertTrue(table.contains(prompts, "#HegRevealGenerals"))
  lu.assertFalse(table.contains(prompts, "#HegPrepareConvertLord"))
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
