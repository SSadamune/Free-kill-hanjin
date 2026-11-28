local support = __dofile("../../../tests/support/hegemony.lua")
local content = __dofile("../../../tests/support/ascension_content.lua")
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local V = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.selection"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local H = require "packages.hegemony.util"

local G = content.generals

local function create(options)
  options = options or {}
  local backend = FkTest.createFakeRoom({ 1, 2, 3, 4, 5, 6, 7, 8 })
  -- Keep the deterministic ban plan away from Wei so succession candidates can
  -- legally join the dead monarch's faction.
  backend._session_data = json.encode {
    qiao_faction_ban_v1 = { version = 1, winners = { "wu", "qun" }, banned = {} },
  }
  local settings = { qiao_wild_count = 0 }
  for key, value in pairs(options.settings or {}) do settings[key] = value end
  return support.createRoom {
    mode = options.mode or Modes.collection, realSelection = true, backend = backend,
    settings = settings,
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
local function freshRoom(settings, mode)
  support.clearRoom()
  return preparePlayers(create { settings = settings, mode = mode })
end

Testsecond_lord = { setup = setup, tearDown = support.clearRoom }

local function room() return FkTest.room end
local function player(n) return room().players[n] end

local function hidden(p, main, deputy, kingdom)
  content.setupHidden(room(), p, main, deputy, kingdom)
end

local function revealed(p, main, deputy, kingdom)
  content.setupRevealed(room(), p, main, deputy, kingdom)
end

local function triggerTurnStart(p, firstChoice, secondReply)
  FkTest.cleanNextReplies(p)
  local replies = { { firstChoice or "Cancel" } }
  if secondReply then table.insert(replies, secondReply) end
  FkTest.setNextReplies(p, replies)
  FkTest.runInRoom(function() room().logic:trigger(fk.TurnStart, p, {}) end)
  FkTest.cleanNextReplies(p)
end

function Testsecond_lord:testOneHiddenPositionLeftSkipsFollowUp()
  local actor = player(1)
  local deputy = "qiao_turn_reveal_deputy:::" .. G.wei_deputy.name
  local main = "qiao_turn_reveal:::" .. G.wei_normal.name
  lu.assertEquals(Fk:translate("qiao_turn_reveal"), "明置%arg")
  lu.assertEquals(Fk:translate("qiao_turn_reveal_deputy"), "明置%arg")
  FkTest.runInRoom(function() hidden(actor, G.wei_normal.name, G.wei_deputy.name, "wei") end)
  local asks = {}
  FkTest.setRoomBreakpoint(actor, "AskForOptions", function(data)
    table.insert(asks, { prompt = data[6], choices = table.simpleClone(data[1]) })
    return false
  end)
  triggerTurnStart(actor, deputy, "__cancel")
  lu.assertEquals(asks, {
    { prompt = "#HegRevealGenerals", choices = { A.ASCEND_ACCEPT, main, deputy } },
    { prompt = "#QiaoTurnRevealAlso", choices = { "qiao_turn_reveal_also_main" } },
  })
  lu.assertEquals(actor.general, "anjiang")
  lu.assertEquals(actor.deputyGeneral, G.wei_deputy.name)
  triggerTurnStart(actor, main)
  lu.assertEquals(asks[3], {
    prompt = "#HegRevealGenerals", choices = { A.ASCEND_ACCEPT, main },
  })
  lu.assertEquals(#asks, 3)
  lu.assertEquals(actor.general, G.wei_normal.name)
end

function Testsecond_lord:testAscensionAndDeputyRevealWaitForBothReplies()
  local actor = player(1)
  FkTest.runInRoom(function() hidden(actor, G.wei_normal.name, G.wei_deputy.name, "wei") end)
  local duringFollowUp
  FkTest.setRoomBreakpoint(actor, "AskForOptions", function(data)
    if data[6] == "#QiaoTurnRevealAlso" then
      duringFollowUp = { actor.general, actor.deputyGeneral, actor.kingdom, data[5], data[1] }
    end
    return false
  end)
  triggerTurnStart(actor, A.ASCEND_ACCEPT, { "qiao_turn_reveal_also_deputy" })
  lu.assertEquals(duringFollowUp, {
    "anjiang", "anjiang", "unknown", "heg_rule", { "qiao_turn_reveal_also_deputy" },
  })
  lu.assertEquals(actor.general, V.lord_version(G.wei_normal.name))
  lu.assertEquals(actor.deputyGeneral, G.wei_deputy.name)
  lu.assertTrue(A.has_lord(room(), "wei"))
end

function Testsecond_lord:testHiddenMainDoesNotChangePublicTurnStartFocus()
  local r, actor, other = room(), player(1), player(2)
  local ordinaryMain = "qiao_test__wei_1"
  local public, private = {}, {}
  local broadcast = r.doBroadcastNotify
  local function observeTurn(main)
    FkTest.runInRoom(function() hidden(actor, main, G.wei_deputy.name, "wei") end)
    public, private = {}, {}
    r.doBroadcastNotify = function(self, command, data, recipients)
      if command == "MoveFocus" then
        lu.assertNil(recipients)
        table.insert(public, { table.simpleClone(data[1]), data[2], data[3] })
      end
      return broadcast(self, command, data, recipients)
    end
    triggerTurnStart(actor, "Cancel")
    r.doBroadcastNotify = broadcast
    lu.assertEquals(actor.general, "anjiang")
    lu.assertEquals(actor.deputyGeneral, "anjiang")
    lu.assertEquals(#private, 1)
    return public, private[1]
  end
  FkTest.setRoomBreakpoint(actor, "AskForOptions", function(data)
    table.insert(private, table.simpleClone(data[1]))
    return false
  end)
  local leaked = false
  FkTest.setRoomBreakpoint(other, "AskForOptions", function()
    leaked = true
    return false
  end)
  local eligibleFocus, eligibleChoices = observeTurn(G.wei_normal.name)
  local ordinaryFocus, ordinaryChoices = observeTurn(ordinaryMain)
  lu.assertTrue(table.contains(eligibleChoices, A.ASCEND_ACCEPT))
  lu.assertFalse(table.contains(ordinaryChoices, A.ASCEND_ACCEPT))
  lu.assertEquals(eligibleFocus, { { { actor.id }, "heg_rule", r.timeout * 1000 } })
  lu.assertEquals(eligibleFocus, ordinaryFocus)
  lu.assertFalse(leaked)
end

--- Record ascension prompts so a blocked target can be distinguished from a
--- rejected offer.
local function captureAscensionPrompts()
  local prompts = { convert = {}, succession = {} }
  FkTest.runInRoom(function()
    local r = room()
    local askOptions = r.askToOptions
    function r:askToOptions(target, params)
      if params.prompt == "#HegRevealGenerals" and table.find(params.options, function(option)
        return option == A.ASCEND_ACCEPT or option:startsWith(A.ASCEND_KINGDOM .. ":::")
      end) then
        table.insert(prompts.convert, target.seat)
      end
      return askOptions(self, target, params)
    end
    local original = r.askToChoice
    function r:askToChoice(target, params)
      local prompt = params and params.prompt
      if prompt == "#QiaoSecondLordSuccession" then
        table.insert(prompts.succession, target.seat)
      end
      return original(self, target, params)
    end
  end)
  return prompts
end

--- Capture the upstream wild-founding request. Return a predicate; the wrapper
--- answers it instead of blocking so the test can assert the request never ran.
local function captureWildFounding()
  local prompted = false
  FkTest.runInRoom(function()
    local r = room()
    local original = r.askToChoice
    function r:askToChoice(target, params)
      if params and params.prompt == "#wild-choose" then
        prompted = true
        return nil
      end
      return original(self, target, params)
    end
  end)
  return function() return prompted end
end

local function markDead(p, kingdom)
  -- Reveal directly instead of broadcasting: the victory helper only needs the
  -- final face-up state, and broadcasting property changes for already-dead
  -- fake clients can invalidate the test room's client state.
  local main = p:getMark("__heg_general")
  local deputy = p:getMark("__heg_deputy")
  if type(main) == "string" then p.general = main end
  if type(deputy) == "string" then p.deputyGeneral = deputy end
  p.dead = true
  table.removeOne(room().alive_players, p)
  room():setPlayerProperty(p, "kingdom", kingdom)
end

function Testsecond_lord:testFirstOrdinaryAscensionOccupiesFactionSlot()
  local first, second = player(1), player(2)
  FkTest.runInRoom(function()
    hidden(first, G.wei_normal.name, G.wei_deputy.name, "wei")
    hidden(second, G.wei_normal2.name, G.wei_deputy.name, "wei")
  end)
  FkTest.setNextReplies(first, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(first, A.ASCEND_ACCEPT)
  lu.assertEquals(first.general, G.wei_monarch.name)
  lu.assertEquals(first.kingdom, "wei")
  lu.assertEquals(first:getMark("__heg_general"), G.wei_monarch.name)
  lu.assertEquals(first:getMark("hasShownMainGeneral"), 1)
  lu.assertTrue(first:hasSkill(content.skills.monarch))
  lu.assertFalse(first:hasSkill(content.skills.normal))
  lu.assertTrue(A.has_lord(room(), "wei"))

  -- The second candidate of the same faction must not be offered a normal
  -- ascension once the slot is occupied.
  FkTest.setNextReplies(second, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(second, "Cancel")
  lu.assertEquals(second.general, "anjiang")
  lu.assertEquals(second.kingdom, "unknown")
  lu.assertEquals(first.general, G.wei_monarch.name)
end

function Testsecond_lord:testFormalHanLiuxieAscendsOnFirstTurn()
  local candidate = player(1)
  local animation
  local currentRoom = room()
  local doAnimate = currentRoom.doAnimate
  function currentRoom:doAnimate(kind, data)
    if kind == "InvokeUltSkill" and data.name == "qiao_lord_ascension" then animation = table.simpleClone(data) end
    return doAnimate(self, kind, data)
  end
  FkTest.runInRoom(function()
    room():setBanner("all_kingdoms", { "han", "wei", "shu", "qun" })
    hidden(candidate, "qiao_heg__han001", "qiao_test__han_2", "han")
  end)
  local prompts = captureAscensionPrompts()
  triggerTurnStart(candidate, A.ASCEND_ACCEPT)
  lu.assertEquals(prompts.convert, { candidate.seat })
  lu.assertEquals(candidate.general, "qiao_heg__em_han001")
  lu.assertEquals(candidate.kingdom, "han")
  lu.assertEquals(animation, { name = "qiao_lord_ascension", player = candidate.id, deputy = false })
end

function Testsecond_lord:testFormalWuSunquanAscendsOnFirstTurn()
  local candidate = player(1)
  FkTest.runInRoom(function()
    room():setBanner("all_kingdoms", { "han", "wei", "shu", "wu" })
    hidden(candidate, "qiao_heg__wu001", "qiao_test__wu_2", "wu")
  end)
  local prompts = captureAscensionPrompts()
  triggerTurnStart(candidate, A.ASCEND_ACCEPT)
  lu.assertEquals(prompts.convert, { candidate.seat })
  lu.assertEquals(candidate.general, "qiao_heg__em_wu001")
  lu.assertEquals(candidate.kingdom, "wu")
end

function Testsecond_lord:testOrdinaryAscensionNeedsHiddenMainAndFirstTurn()
  local p = player(1)
  FkTest.runInRoom(function()
    revealed(p, G.wei_normal.name, G.wei_deputy.name, "wei")
  end)
  triggerTurnStart(p, "Cancel")
  lu.assertEquals(p.general, G.wei_normal.name)

  FkTest.runInRoom(function()
    hidden(p, G.wei_normal.name, G.wei_deputy.name, "wei")
    room():setPlayerMark(p, A.TURNS_MARK, 1)
  end)
  triggerTurnStart(p, "Cancel")
  lu.assertEquals(p.general, "anjiang")
end

function Testsecond_lord:testAscensionAppliesHpGainOnlyWhenPairMaxIncreases()
  local high = player(1)
  FkTest.runInRoom(function()
    hidden(high, G.wei_normal.name, G.wei_deputy.name, "wei")
  end)
  lu.assertEquals(high.maxHp, 3)
  lu.assertEquals(high.hp, 3)
  FkTest.setNextReplies(high, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(high, A.ASCEND_ACCEPT)
  lu.assertEquals(high.maxHp, 4)
  lu.assertEquals(high.hp, 4)
end

function Testsecond_lord:testAscensionDoesNotChangeHpWhenPairMaxDoesNotIncrease()
  local equal = player(1)
  FkTest.runInRoom(function()
    hidden(equal, G.wei_normal2.name, G.wei_deputy.name, "wei")
  end)
  lu.assertEquals(equal.maxHp, 4)
  FkTest.setNextReplies(equal, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(equal, A.ASCEND_ACCEPT)
  lu.assertEquals(equal.maxHp, 4)
  lu.assertEquals(equal.hp, 4)
  lu.assertEquals(equal.general, G.wei_monarch2.name)
end

function Testsecond_lord:testAscensionKeepsHpWhenPairMaxIsEqual()
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, G.wei_normal3.name, G.wei_deputy.name, "wei")
  end)
  lu.assertEquals(p.maxHp, 4)
  lu.assertEquals(p.hp, 4)
  FkTest.setNextReplies(p, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(p, A.ASCEND_ACCEPT)
  lu.assertEquals(p.general, G.wei_monarch3.name)
  lu.assertEquals(p.maxHp, 4)
  lu.assertEquals(p.hp, 4)
end

function Testsecond_lord:testAscensionRevealsMainAndSyncsKingdomAndSkills()
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, G.wei_normal.name, G.wei_deputy.name, "wei")
  end)
  FkTest.setNextReplies(p, { { A.ASCEND_ACCEPT } })
  triggerTurnStart(p, A.ASCEND_ACCEPT)
  lu.assertNotEquals(p.general, "anjiang")
  lu.assertEquals(p.kingdom, "wei")
  lu.assertEquals(p.general, G.wei_monarch.name)
  lu.assertTrue(p:hasSkill(content.skills.monarch))
  lu.assertFalse(p:hasSkill(content.skills.normal))
  lu.assertEquals(p:getMark("__heg_kingdom"), "wei")
  -- The deputy stays hidden; only the main general was revealed by ascension.
  lu.assertEquals(p.deputyGeneral, "anjiang")
end

function Testsecond_lord:testRealZhangjiaoAscensionClearsOldfakesAndKeepsIndependentSource()
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, "qiao_heg__qun010", "qiao_heg__qun002", "qun")
    room():addFakeSkill(p, "qiao__skill_qun010_1")
    room():addFakeSkill(p, "qiao__skill_qun010_2")
    p:prelightSkill("qiao__skill_qun010_1", true)
    p:prelightSkill("qiao__skill_qun010_2", true)
    -- 鬼道另有独立实际来源：清理旧主将 fake 时不能删除它。
    p:addSkill(Fk.skills["qiao__skill_qun010_2"])
    room():setBanner("all_kingdoms", { "qun" })
    lu.assertTrue(p:hasSkill("qiao__skill_qun010_2"))
  end)
  triggerTurnStart(p, A.ASCEND_ACCEPT)

  lu.assertEquals(p.general, "qiao_heg__em_qun010")
  lu.assertEquals(p.deputyGeneral, "anjiang")
  lu.assertEquals(p.role, "qun")
  lu.assertTrue(p:hasSkill("qiao__skill_em_qun010_1"), "弘法应可获取")
  lu.assertTrue(p:hasSkill("qiao__em_qun010_banner"), "弘法应实际授予黄巾天兵符")
  lu.assertTrue(p:hasSkill("qiao__skill_em_qun010_2"), "悟心正常")
  lu.assertTrue(p:hasSkill("qiao__skill_em_qun010_3"), "问道正常")
  lu.assertFalse(p:hasSkill("qiao__skill_qun010_1"), "旧雷击 fake 应清理")
  lu.assertFalse(p:isFakeSkill("qiao__skill_qun010_1"))
  lu.assertTrue(p:hasSkill("qiao__skill_qun010_2"), "独立鬼道来源应保留")
  lu.assertFalse(p:isFakeSkill("qiao__skill_qun010_2"),
    "旧主将的鬼道 fake 可清，但独立实际来源不可误删")
end

function Testsecond_lord:testHiddenDeputySameSkillFakeIsPreserved()
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, "qiao_heg__qun010", G.qun_deputy.name, "qun")
    room():addFakeSkill(p, "qiao__skill_qun010_1")
    room():addFakeSkill(p, "qiao__skill_qun010_2")
    p:prelightSkill("qiao__skill_qun010_1", true)
    p:prelightSkill("qiao__skill_qun010_2", true)
    room():setBanner("all_kingdoms", { "qun" })
    lu.assertTrue(p:isFakeSkill("qiao__skill_qun010_1"))
  end)
  triggerTurnStart(p, A.ASCEND_ACCEPT)

  lu.assertEquals(p.general, "qiao_heg__em_qun010")
  lu.assertEquals(p.deputyGeneral, "anjiang")
  lu.assertTrue(p:isFakeSkill("qiao__skill_qun010_1"),
    "暗副将仍印刷同名雷击，fake 不应被旧主将清理")
  lu.assertTrue(p:isFakeSkill("qiao__skill_qun010_2"),
    "暗副将仍印刷同名鬼道，fake 不应被旧主将清理")
  lu.assertTrue(table.contains(p.prelighted_skills, Fk.skills["qiao__skill_qun010_1"]))
  lu.assertTrue(p:hasSkill("qiao__skill_qun010_1"))
  lu.assertTrue(p:hasSkill("qiao__skill_qun010_2"))
end

function Testsecond_lord:testRealLiubeiLordSkillIsInstalled()
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, "qiao_heg__shu001", "qiao_test__shu_2", "shu")
    room():setBanner("all_kingdoms", { "shu" })
    A.ascend(room(), p, "qiao_heg__em_shu001", "shu", { kind = "lord" })
  end)
  lu.assertEquals(p.general, "qiao_heg__em_shu001")
  lu.assertTrue(p:hasSkill("qiao__skill_em_shu001_1"),
    "章武应作为国战君主技能获取")
  lu.assertFalse(p:hasSkill("qiao__skill_shu001_1"), "旧仁德应移除")
end

function Testsecond_lord:testSuccessionOrderFirstAcceptorAndRevealSync()
  local lord, first, second, other = player(1), player(2), player(3), player(4)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    -- Keep the main general revealed while hiding only the deputy.
    lord:hideGeneral(true)
    room():setPlayerProperty(lord, "kingdom", "wei")

    hidden(first, G.wei_normal.name, "qiao_test__qun_1", "qun")
    hidden(second, G.wei_normal2.name, "qiao_test__qun_2", "qun")
    room():setCurrent(first)
  end)
  FkTest.setNextReplies(first, { { "Cancel" } })
  FkTest.setNextReplies(second, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)

  lu.assertEquals(first.general, "anjiang")
  lu.assertEquals(first.kingdom, "unknown")
  lu.assertEquals(second.general, G.wei_monarch2.name)
  lu.assertEquals(second.kingdom, "wei")
  lu.assertTrue(A.has_lord(room(), "wei"))
  lu.assertEquals(lord.deputyGeneral, G.wei_deputy.name)
  lu.assertEquals(other.kingdom, "shu")
  lu.assertNotEquals(first.kingdom, "wild")
end

function Testsecond_lord:testSuccessionStopsAtFirstAcceptor()
  local lord, first, second = player(1), player(2), player(3)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(first, G.wei_normal.name, "qiao_test__qun_1", "qun")
    hidden(second, G.wei_normal2.name, "qiao_test__qun_2", "qun")
    room():setCurrent(first)
  end)
  FkTest.setNextReplies(first, { { A.ASCEND_ACCEPT } })
  FkTest.setNextReplies(second, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertEquals(first.general, G.wei_monarch.name)
  lu.assertEquals(second.general, "anjiang")
end

function Testsecond_lord:testSuccessionAsksFromCurrentSeatInActionOrder()
  local lord, first, second, third = player(1), player(2), player(3), player(4)
  local asked = {}
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(first, G.wei_normal.name, "qiao_test__qun_1", "qun")
    hidden(second, G.wei_normal2.name, "qiao_test__qun_2", "qun")
    hidden(third, G.wei_normal3.name, "qiao_test__qun_1", "qun")
    room():setCurrent(second)
    local currentRoom = room()
    local original = currentRoom.askToChoice
    function currentRoom:askToChoice(target, params)
      if params and params.prompt == "#QiaoSecondLordSuccession" then
        table.insert(asked, target.seat)
      end
      return original(self, target, params)
    end
  end)
  FkTest.setNextReplies(first, { { "Cancel" } })
  FkTest.setNextReplies(second, { { "Cancel" } })
  FkTest.setNextReplies(third, { { "Cancel" } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  -- Seats 3 -> 4 -> 2: action order starts at the current player and wraps.
  lu.assertEquals(asked, { 3, 4, 2 })
end

function Testsecond_lord:testSuccessionHpAndConsumableMarks()
  local lord, candidate = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    candidate.deputyGeneral = G.wei_deputy.name
    room():setPlayerMark(candidate, "hasShownDeputyGeneral", 1)
    room():setPlayerProperty(candidate, "kingdom", "wei")
    room():setPlayerMark(candidate, "__heg_kingdom", "wei")
    room():setPlayerProperty(candidate, "maxHp", 3)
    room():setPlayerProperty(candidate, "hp", 3)
    H.judegHegMark(candidate)
    room():setCurrent(candidate)
  end)
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)

  lu.assertEquals(candidate.general, G.wei_monarch.name)
  lu.assertEquals(candidate.maxHp, 4)
  lu.assertEquals(candidate.hp, 4)
  lu.assertEquals(candidate:getMark("@!!companion"), 1)
  lu.assertEquals(candidate:getMark("@!!yinyangfish"), 1)
  lu.assertEquals(candidate:getMark(A.COMPANION_MARK), 1)
  lu.assertEquals(candidate:getMark(A.YINYANG_MARK), 1)
end

function Testsecond_lord:testAscensionRechecksUnprintedCompanionAndFishWithHiddenDeputy()
  local candidate = player(1)
  FkTest.runInRoom(function()
    hidden(candidate, G.wei_normal2.name, G.wei_deputy.name, "wei")
    H.judegHegMark(candidate)
    lu.assertEquals(candidate:getMark("CompanionEffect"), 0)
    lu.assertEquals(candidate:getMark("HalfMaxHpLeft"), 0)
    lu.assertTrue(A.ascend(room(), candidate, G.wei_monarch2.name, "wei", { kind = "lord" }))
    lu.assertEquals(candidate.deputyGeneral, "anjiang")
    lu.assertEquals(candidate:getMark("CompanionEffect"), 1)
    lu.assertEquals(candidate:getMark("HalfMaxHpLeft"), 1)
    lu.assertEquals(candidate:getMark("@!!companion"), 0)
    lu.assertEquals(candidate:getMark("@!!yinyangfish"), 0)
    candidate:revealGeneral(true)
    lu.assertEquals(candidate:getMark("@!!companion"), 1)
    lu.assertEquals(candidate:getMark("@!!yinyangfish"), 1)
  end)
end
function Testsecond_lord:testSpentMarksAreNotGrantedAgainWhenAlreadyRevealed()
  local lord, candidate = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    H.judegHegMark(candidate)
    candidate:revealGeneral(false)
    candidate:revealGeneral(true)
  end)
  lu.assertEquals(candidate:getMark("@!!companion"), 1, "真实双亮应先领到珠联")
  lu.assertEquals(candidate:getMark("@!!yinyangfish"), 1, "真实双亮应先领到阴阳鱼")
  lu.assertEquals(candidate:getMark(A.COMPANION_MARK), 1)
  lu.assertEquals(candidate:getMark(A.YINYANG_MARK), 1)
  FkTest.runInRoom(function()
    H.removeHegMark(room(), candidate, "companion")
    H.removeHegMark(room(), candidate, "yinyangfish")
    candidate:hideGeneral(false)
    room():setPlayerProperty(candidate, "kingdom", "wei")
    room():setPlayerMark(candidate, "__heg_kingdom", "wei")
    room():setPlayerProperty(candidate, "maxHp", 3)
    room():setPlayerProperty(candidate, "hp", 3)
    room():setCurrent(candidate)
  end)
  lu.assertEquals(candidate:getMark("@!!companion"), 0, "先实际花掉珠联")
  lu.assertEquals(candidate:getMark("@!!yinyangfish"), 0, "先实际花掉阴阳鱼")
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertEquals(candidate:getMark("@!!companion"), 0, "已领过后花掉，升变不得重发珠联")
  lu.assertEquals(candidate:getMark("@!!yinyangfish"), 0, "已领过后花掉，升变不得重发阴阳鱼")
  lu.assertEquals(candidate:getMark(A.COMPANION_MARK), 1)
  lu.assertEquals(candidate:getMark(A.YINYANG_MARK), 1)
end
function Testsecond_lord:testNoSuccessorConvertsFactionAndKeepsExistingWild()
  local lord, hiddenAlly, revealedAlly, wildAlly = player(1), player(2), player(3), player(4)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(hiddenAlly, G.wei_normal.name, "qiao_test__qun_1", "wei")
    revealed(revealedAlly, G.wei_normal2.name, G.wei_deputy.name, "wei")
    revealed(wildAlly, "qiao_test__wild_1", "qiao_test__qun_2", "wild")
    room():setPlayerMark(wildAlly, "__heg_wild", 1)
    room():setCurrent(revealedAlly)
  end)
  FkTest.setNextReplies(hiddenAlly, { { "Cancel" } })
  FkTest.setNextReplies(revealedAlly, { { "Cancel" } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)

  lu.assertFalse(A.has_lord(room(), "wei"))
  lu.assertEquals(hiddenAlly:getMark("__heg_kingdom"), "wild")
  lu.assertEquals(hiddenAlly.kingdom, "unknown")
  lu.assertEquals(hiddenAlly.role, "wild")
  lu.assertEquals(revealedAlly.kingdom, "wild")
  -- An already-wild character must not be restored by a successor or by the
  -- lord's death conversion.
  lu.assertEquals(wildAlly.kingdom, "wild")
  lu.assertEquals(wildAlly:getMark("__heg_wild"), 1)
end

function Testsecond_lord:testOverpopulatedCandidateIsNotAsked()
  local lord, candidate = player(1), player(2)
  local allies = { player(3), player(4), player(5) }
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, "qiao_test__qun_1", "wei")
    for _, ally in ipairs(allies) do
      revealed(ally, G.wei_normal2.name, G.wei_deputy.name, "wei")
    end
    room():setCurrent(candidate)
  end)
  -- Four other Wei characters (the dead monarch and three allies) reach the
  -- 8-player half threshold, so the candidate cannot legally join.
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  for _, ally in ipairs(allies) do FkTest.setNextReplies(ally, { { "Cancel" } }) end
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertNotEquals(candidate.general, G.wei_monarch.name)
  lu.assertEquals(candidate:getMark("__heg_kingdom"), "wild")
end

function Testsecond_lord:testAlreadyWildCandidateCannotSucceed()
  local lord, candidate = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(candidate, G.wei_normal.name, G.wei_deputy.name, "wild")
    room():setPlayerMark(candidate, "__heg_kingdom", "wei")
    room():setCurrent(candidate)
  end)
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertEquals(candidate.kingdom, "wild")
  lu.assertEquals(candidate.general, G.wei_normal.name)
  lu.assertNotEquals(candidate.general, G.wei_monarch.name)
end

function Testsecond_lord:testLordPresenceDoesNotPreventOverpopulationWild()
  local lord, candidate = player(1), player(2)
  local allies = { player(3), player(4), player(5) }
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    for _, ally in ipairs(allies) do
      revealed(ally, G.wei_normal2.name, G.wei_deputy.name, "wei")
    end
  end)
  -- Four other Wei characters meet the 8-player half threshold. Even though a
  -- monarch is present, the revealing candidate must still become a wild
  -- character; the upstream "a lord prevents wild conversion" shortcut is not
  -- used in this mode.
  FkTest.runInRoom(function() candidate:revealGeneral(false) end)
  lu.assertEquals(candidate.kingdom, "wild")
  lu.assertEquals(candidate.general, G.wei_normal.name)
end

function Testsecond_lord:testOverflowWildRevealDoesNotEnterUpstreamFounding()
  local lord, candidate = player(1), player(2)
  local allies = { player(3), player(4), player(5) }
  local allowedBefore
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    for _, ally in ipairs(allies) do
      revealed(ally, G.wei_normal2.name, G.wei_deputy.name, "wei")
    end
    room():setBanner("all_kingdoms", { "wei", "shu", "wu", "qun" })
    -- broadcastGeneral leaves the private role at the initial kingdom; the
    -- overflow itself only changes kingdom to wild.
    candidate.role = "wei"
    allowedBefore = room():getBanner("all_kingdoms")
  end)
  local prompted = captureWildFounding()
  FkTest.runInRoom(function() candidate:revealGeneral(false) end)
  lu.assertFalse(prompted(), "溢出转野不得进入上游建国询问")
  lu.assertEquals(candidate.kingdom, "wild")
  lu.assertEquals(candidate.role, "wild")
  lu.assertEquals(candidate:getMark("hasShownMainGeneral"), 1,
    "上游其余明置流程仍须执行")
  -- getBanner 对普通表返回副本，上游临时插入的 unknown/hidden 不得回写到
  -- 房间或广播给客户端。
  lu.assertEquals(room():getBanner("all_kingdoms"), allowedBefore)
end

function Testsecond_lord:testExclusiveWildFoundingExcludesHanAndJin()
  local room, candidate = room(), player(1)
  local request
  FkTest.runInRoom(function()
    hidden(candidate, G.wild_simple.name, "qiao_test__shu_1", "shu")
    candidate.role = "shu"
    player(2).role = "heg_qin"
    room:setBanner("all_kingdoms", { "wei", "shu", "wu", "qun", "han", "jin" })
    local ask = room.askToChoice
    function room:askToChoice(target, params)
      if params.prompt == "#wild-choose" then
        lu.assertIs(target, candidate)
        request = params
        return "heg_hanr"
      end
      return ask(self, target, params)
    end
    candidate:revealGeneral(false)
  end)
  lu.assertNotNil(request, "野心家专属武将仍应进入建国询问")
  for _, options in ipairs({ request.choices, request.all_choices }) do
    lu.assertFalse(table.contains(options, "heg_han"))
    lu.assertFalse(table.contains(options, "heg_jin"))
    lu.assertTrue(table.contains(options, "heg_hanr"), "韩和汉是不同国号")
  end
  lu.assertFalse(table.contains(request.choices, "heg_qin"), "已占用的国号仍不可选")
  lu.assertEquals(candidate.role, "heg_hanr")
  lu.assertTrue(table.contains(H.wildKingdoms, "heg_han"))
  lu.assertTrue(table.contains(H.wildKingdoms, "heg_jin"))
end

function Testsecond_lord:testOverflowWildDeathDoesNotEnterUpstreamFounding()
  local lord, candidate = player(1), player(2)
  local allies = { player(3), player(4), player(5) }
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    for _, ally in ipairs(allies) do
      revealed(ally, G.wei_normal2.name, G.wei_deputy.name, "wei")
    end
    room():setBanner("all_kingdoms", { "wei", "shu", "wu", "qun" })
    candidate.role = "wei"
  end)
  FkTest.runInRoom(function() candidate:revealGeneral(false) end)
  lu.assertEquals(candidate.role, "wild")
  -- No winner yet: the HanJin GameOverJudge guard falls through to the
  -- upstream handler, which must not offer founding for an overflow wild.
  local prompted = captureWildFounding()
  FkTest.runInRoom(function() room():killPlayer { who = candidate } end)
  lu.assertFalse(prompted(), "溢出转野死亡时不得进入上游建国询问")
  lu.assertEquals(candidate.role, "wild")
end

function Testsecond_lord:testRegularRevealKeepsItsIdentity()
  local normal = player(6)
  FkTest.runInRoom(function()
    hidden(normal, "qiao_test__shu_1", "qiao_test__shu_2", "shu")
    room():setBanner("all_kingdoms", { "wei", "shu", "wu", "qun" })
    normal.role = "shu"
  end)
  local prompted = captureWildFounding()
  FkTest.runInRoom(function() normal:revealGeneral(false) end)
  lu.assertFalse(prompted())
  lu.assertEquals(normal.kingdom, "shu")
  lu.assertEquals(normal.role, "shu")
  lu.assertEquals(normal:getMark("hasShownMainGeneral"), 1)
end

function Testsecond_lord:testSuccessorDoesNotRestoreExistingWild()
  local lord, candidate, wildAlly = player(1), player(2), player(3)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(wildAlly, "qiao_test__wild_1", G.wei_deputy.name, "wild")
    room():setPlayerMark(wildAlly, "__heg_kingdom", "wei")
    room():setCurrent(candidate)
  end)
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertEquals(candidate.general, G.wei_monarch.name)
  lu.assertEquals(wildAlly.kingdom, "wild")
  lu.assertEquals(wildAlly:getMark("__heg_kingdom"), "wei")
end

function Testsecond_lord:testProhibitRevealBlocksSuccession()
  local lord, candidate = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, G.wei_deputy.name, "wei")
    room():setPlayerMark(candidate, "RevealProhibited", { "m" })
    room():setCurrent(candidate)
  end)
  lu.assertNil(A.lord_candidate(room(), candidate, "wei"))
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertEquals(candidate.general, "anjiang")
  lu.assertEquals(candidate:getMark("__heg_kingdom"), "wild")
end

function Testsecond_lord:testUnifiedVersionRegistryQueries()
  lu.assertTrue(V.is_lord(G.wei_monarch.name))
  lu.assertFalse(V.is_lord(G.wei_normal.name))
  lu.assertEquals(V.lord_version(G.wei_normal.name), G.wei_monarch.name)
  lu.assertEquals(V.lord_kingdoms(G.wei_monarch.name), { "wei" })
  lu.assertTrue(V.is_loyalty(G.loyalty_simple.name))
  lu.assertEquals(V.loyalty_versions(G.wild_simple.name), { G.loyalty_simple.name })
  lu.assertEquals(V.original_of(G.loyalty_simple.name), G.wild_simple.name)
  FkTest.runInRoom(function()
    lu.assertFalse(V.selectable(G.wei_monarch.name, room()))
    lu.assertTrue(V.selectable(G.wei_normal.name, room()))
  end)
end

function Testsecond_lord:testWinnerWithLordEndsForUniqueFactionAboveHalf()
  local mode = Fk.game_modes.qiao_heg_mode
  local p1, p2, dead = player(1), player(2), player(6)
  local winner
  FkTest.runInRoom(function()
    revealed(p1, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(p2, G.wei_normal.name, G.wei_deputy.name, "wei")
    for index = 3, 5 do markDead(player(index), "wei") end
    for index = 6, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(dead)
  end)
  -- Five of eight players are Wei, but the remaining faction is unique. A lord
  -- must not be required for this board to end.
  lu.assertEquals(#winner, 5)
  lu.assertTrue(winner[1] == p1)
  lu.assertTrue(winner[2] == p2)
end

function Testsecond_lord:testWinnerWithoutLordEndsForUniqueFactionAboveHalf()
  local mode = Fk.game_modes.qiao_heg_mode
  local p1, p2, dead = player(1), player(2), player(6)
  local winner
  FkTest.runInRoom(function()
    revealed(p1, G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(p2, G.wei_normal2.name, G.wei_deputy.name, "wei")
    for index = 3, 5 do markDead(player(index), "wei") end
    for index = 6, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(dead)
  end)
  -- Same five-of-eight board as above, without a lord: the result is unchanged.
  lu.assertEquals(#winner, 5)
  lu.assertTrue(winner[1] == p1)
  lu.assertTrue(winner[2] == p2)
end

function Testsecond_lord:testWinnerWithAndWithoutLordSameUniqueFaction()
  local mode = Fk.game_modes.qiao_heg_mode
  local p1, p2, dead = player(1), player(2), player(6)
  local withoutLord, withLord
  FkTest.runInRoom(function()
    revealed(p1, G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(p2, G.wei_normal2.name, G.wei_deputy.name, "wei")
    for index = 3, 5 do markDead(player(index), "wei") end
    for index = 6, 8 do markDead(player(index), "shu") end
    withoutLord = mode:getWinner(dead)

    revealed(p1, G.wei_monarch.name, G.wei_deputy.name, "wei")
    withLord = mode:getWinner(dead)
  end)
  lu.assertEquals(#withoutLord, 5)
  lu.assertEquals(#withLord, 5)
  lu.assertEquals(withoutLord[1].id, withLord[1].id)
  lu.assertEquals(withoutLord[2].id, withLord[2].id)
end

function Testsecond_lord:testWinnerMultipleFactionsDoNotEndDespiteLordAndMajority()
  local mode = Fk.game_modes.qiao_heg_mode
  local winner
  FkTest.runInRoom(function()
    revealed(player(1), G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(player(2), G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(player(3), G.wei_normal2.name, G.wei_deputy.name, "wei")
    revealed(player(4), G.wei_normal3.name, G.wei_deputy.name, "wei")
    revealed(player(5), "qiao_test__wei_4", "qiao_test__qun_1", "wei")
    revealed(player(6), G.shu_plain.name, "qiao_test__shu_2", "shu")
    markDead(player(7), "shu")
    markDead(player(8), "shu")
    winner = mode:getWinner(player(8))
  end)
  -- Five Wei (with a lord) still coexist with a living Shu character.
  lu.assertEquals(winner, "")
end

function Testsecond_lord:testWinnerRejectsRegularAndOverpopulationWild()
  local mode = Fk.game_modes.qiao_heg_mode
  local p1, p2, dead = player(1), player(2), player(6)
  local winner
  FkTest.runInRoom(function()
    revealed(p1, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(p2, "qiao_test__wild_1", G.wei_deputy.name, "wild")
    room():setPlayerMark(p2, "__heg_kingdom", "wei")
    for index = 3, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(dead)
  end)
  lu.assertEquals(winner, "")
  -- A wild character is still independent and must not be merged back into Wei.
  lu.assertEquals(p2.kingdom, "wild")
  lu.assertEquals(p2:getMark("__heg_kingdom"), "wei")
end

function Testsecond_lord:testWinnerTreatsEachWildAsSeparateFaction()
  local mode = Fk.game_modes.qiao_heg_mode
  local winner
  FkTest.runInRoom(function()
    revealed(player(1), "qiao_test__wild_1", "qiao_test__qun_1", "wild")
    revealed(player(2), "qiao_test__wild_2", "qiao_test__qun_2", "wild")
    for index = 3, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(player(6))
  end)
  -- Two living wild characters are two factions, even when both are wild.
  lu.assertEquals(winner, "")
end

function Testsecond_lord:testWinnerSingleWildWins()
  local mode = Fk.game_modes.qiao_heg_mode
  local p1 = player(1)
  local winner
  FkTest.runInRoom(function()
    revealed(p1, "qiao_test__wild_1", "qiao_test__qun_1", "wild")
    for index = 2, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(player(6))
  end)
  lu.assertEquals(#winner, 1)
  lu.assertTrue(winner[1] == p1)
end

function Testsecond_lord:testLastSurvivorSharesFactionWinWithDeadAllies()
  local mode, survivor, ally = Fk.game_modes.qiao_heg_mode, player(1), player(2)
  local winner
  FkTest.runInRoom(function()
    revealed(survivor, G.wei_normal.name, G.wei_deputy.name, "wei")
    markDead(ally, "wei")
    markDead(player(3), "wei")
    player(3).surrendered = true
    for index = 4, 8 do markDead(player(index), "shu") end
    winner = mode:getWinner(player(8))
  end)
  lu.assertEquals(table.map(winner, Util.IdMapper), { survivor.id, ally.id })
end

function Testsecond_lord:testWinnerHiddenGeneralsFollowExpectedFactionSemantics()
  local mode = Fk.game_modes.qiao_heg_mode
  local p1, p2 = player(1), player(2)
  local allHidden, matchingHidden, differentHidden
  FkTest.runInRoom(function()
    hidden(p1, G.wei_normal.name, G.wei_deputy.name, "wei")
    hidden(p2, G.wei_normal2.name, G.wei_deputy.name, "wei")
    for index = 3, 8 do markDead(player(index), "shu") end
    allHidden = mode:getWinner(player(6))

    revealed(p1, G.wei_normal.name, G.wei_deputy.name, "wei")
    hidden(p2, G.wei_normal2.name, G.wei_deputy.name, "wei")
    matchingHidden = mode:getWinner(player(6))

    hidden(p2, G.wei_normal2.name, G.wei_deputy.name, "shu")
    differentHidden = mode:getWinner(player(6))
  end)
  -- unknown is not a shared faction: two hidden characters cannot win together.
  lu.assertEquals(allHidden, "")
  -- An expected Wei hidden character joins the known Wei anchor, as in national war.
  lu.assertEquals(#matchingHidden, 2)
  -- A hidden character expected to be Shu does not join the Wei anchor.
  lu.assertEquals(differentHidden, "")
end

function Testsecond_lord:testRealDeathEndsGameForUniqueRegularFactionAboveHalf()
  FkTest.runInRoom(function()
    for index = 1, 5 do
      revealed(player(index), "qiao_test__wei_" .. index, "qiao_test__qun_" .. index, "wei")
    end
    for index = 6, 8 do
      revealed(player(index), "qiao_test__shu_" .. index, "qiao_test__qun_" .. index, "shu")
    end
  end)
  for index = 8, 6, -1 do
    FkTest.runInRoom(function() room():killPlayer { who = player(index) } end)
  end
  -- The last Shu death happens through the real death + GameOverJudge flow.
  lu.assertTrue(room().game_finished)
  local summary = room():getBanner("GameSummary")
  for index = 1, 5 do
    lu.assertEquals(summary[player(index).seat].win, "Game Win")
  end
  lu.assertEquals(summary[player(6).seat].win, "Game Lose")
  local saved = json.decode(room().room:getSessionData()).qiao_faction_ban_v1
  lu.assertEquals(saved.winners, { "wei" })
end

function Testsecond_lord:testRealDeathSuccessionThenGameOver()
  local lord, successor, ally = player(1), player(2), player(3)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(successor, G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(ally, "qiao_test__wei_3", "qiao_test__qun_3", "wei")
    for index = 4, 8 do markDead(player(index), "shu") end
    room():setCurrent(successor)
  end)
  FkTest.setNextReplies(successor, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  -- Succession runs in BeforeGameOverJudge, then the real GameOverJudge sees the
  -- unique Wei faction and awards the win to all three members.
  lu.assertEquals(successor.general, G.wei_monarch.name)
  lu.assertTrue(room().game_finished)
  local summary = room():getBanner("GameSummary")
  lu.assertEquals(summary[successor.seat].win, "Game Win")
  lu.assertEquals(summary[ally.seat].win, "Game Win")
  lu.assertEquals(summary[lord.seat].win, "Game Win")
  local saved = json.decode(room().room:getSessionData()).qiao_faction_ban_v1
  lu.assertEquals(saved.winners, { "wei" })
end

function Testsecond_lord:testRealNoSuccessorConvertsLastAllyToWildAndWins()
  local lord, ally = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(ally, G.wei_normal.name, G.wei_deputy.name, "wei")
    for index = 3, 8 do markDead(player(index), "shu") end
    room():setCurrent(ally)
  end)
  FkTest.setNextReplies(ally, { { "Cancel" } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  -- No successor: the last ally becomes a wild character and is the sole survivor.
  lu.assertEquals(ally.kingdom, "wild")
  lu.assertTrue(room().game_finished)
  local summary = room():getBanner("GameSummary")
  lu.assertEquals(summary[ally.seat].win, "Game Win")
  -- A wild victory must not be recorded as a regular kingdom win.
  local saved = json.decode(room().room:getSessionData()).qiao_faction_ban_v1
  lu.assertEquals(saved.winners, {})
end

function Testsecond_lord:testRealNoSuccessorMultipleWildsKeepGameRunning()
  local lord, first, second = player(1), player(2), player(3)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    revealed(first, G.wei_normal.name, G.wei_deputy.name, "wei")
    revealed(second, G.wei_normal2.name, G.wei_deputy.name, "wei")
    for index = 4, 8 do markDead(player(index), "shu") end
    room():setCurrent(first)
  end)
  FkTest.setNextReplies(first, { { "Cancel" } })
  FkTest.setNextReplies(second, { { "Cancel" } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  -- Both surviving Wei characters become independent wild factions; no unique
  -- faction remains, so the real game-over flow must not finish the game.
  lu.assertEquals(first.kingdom, "wild")
  lu.assertEquals(second.kingdom, "wild")
  lu.assertFalse(room().game_finished)
end

function Testsecond_lord:testAscensionGrantsYinyangWhenOldPairWasEven()
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, "qiao_heg__qun010", "qiao_heg__qun007", "qun")
    for i = 2, 8 do
      room():setPlayerProperty(player(i), "kingdom", "shu")
      room():setPlayerMark(player(i), "__heg_kingdom", "shu")
    end
    room():setBanner("all_kingdoms", { "wei", "shu", "wu", "qun", "han", "jin" })
    p.deputyGeneral = "qiao_heg__qun007"
    room():setPlayerMark(p, "hasShownDeputyGeneral", 1)
    room():setCurrent(p)
  end)
  triggerTurnStart(p, A.ASCEND_ACCEPT)
  lu.assertEquals(p.general, "qiao_heg__em_qun010")
  lu.assertEquals(p.maxHp, 3, "君张角+贾诩体力上限仍为3，不因升变额外+1")
  lu.assertEquals(p:getMark("@!!yinyangfish"), 1, "旧组合偶数、新组合奇数，升变应补发阴阳鱼")
end
function Testsecond_lord:testFirstTurnBannedLordTargetIsNotOffered()
  freshRoom({ disabledGenerals = { G.wei_monarch.name } }, Modes.free)
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, G.wei_normal.name, G.wei_deputy.name, "wei")
  end)
  local prompts = captureAscensionPrompts()
  triggerTurnStart(p, "Cancel")
  lu.assertEquals(#prompts.convert, 0, "A banned target version must not be offered")
  lu.assertEquals(p.general, "anjiang")
  lu.assertEquals(p.kingdom, "unknown")
end

function Testsecond_lord:testBanningNormalVersionDoesNotBlockLordAscension()
  freshRoom { disabledGenerals = { G.wei_normal.name } }
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, G.wei_normal.name, G.wei_deputy.name, "wei")
  end)
  -- Only the normal version is banned; the lord target stays a separate version.
  triggerTurnStart(p, A.ASCEND_ACCEPT)
  lu.assertEquals(p.general, G.wei_monarch.name)
  lu.assertEquals(p.kingdom, "wei")
end

function Testsecond_lord:testBannedPackBlocksLordAscension()
  freshRoom({ disabledPack = { content.pack.name } }, Modes.free)
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, G.wei_normal.name, G.wei_deputy.name, "wei")
  end)
  local prompts = captureAscensionPrompts()
  triggerTurnStart(p, "Cancel")
  lu.assertEquals(#prompts.convert, 0)
  lu.assertEquals(p.general, "anjiang")
end

function Testsecond_lord:testWhitelistedTargetInBannedPackStillAscends()
  -- Equivalent to the create-room whitelist expansion: the pack is not in
  -- disabledPack, and every non-whitelisted general is in disabledGenerals.
  local keep = { [G.wei_normal.name] = true, [G.wei_monarch.name] = true }
  local disabled = {}
  for _, general in pairs(G) do
    if not keep[general.name] then table.insert(disabled, general.name) end
  end
  freshRoom({ disabledGenerals = disabled }, Modes.free)
  local p = player(1)
  FkTest.runInRoom(function()
    hidden(p, G.wei_normal.name, G.wei_deputy.name, "wei")
  end)
  triggerTurnStart(p, A.ASCEND_ACCEPT)
  lu.assertEquals(p.general, G.wei_monarch.name)
  lu.assertEquals(p.kingdom, "wei")
end

function Testsecond_lord:testModeDisabledPackAllowsAscensionButHostBanBlocksIt()
  local function setupJin(targetRoom)
    FkTest.runInRoom(function()
      local p = targetRoom.players[1]
      content.place(targetRoom, p, false, "qiao_heg__jin001")
      content.place(targetRoom, p, true, "qiao_test__jin_2")
      targetRoom:setPlayerProperty(p, "kingdom", "jin")
      targetRoom:setPlayerMark(p, "__heg_kingdom", "jin")
    end)
  end

  local room = freshRoom(nil, Modes.free)
  -- 模拟仅由模式禁用的包，兵情篇现已进入汉晋正式选将池。
  table.insertIfNeed(room.disabled_packs, "qiao_bingqing")
  setupJin(room)
  local ok
  FkTest.runInRoom(function()
    ok = A.ascend(room, room.players[1], "qiao_heg__em_jin001", "jin", { kind = "lord" })
  end)
  lu.assertTrue(ok, "A mode-disabled pack must not block in-game ascension")
  lu.assertEquals(room.players[1].general, "qiao_heg__em_jin001")
  lu.assertTrue(table.contains(room.disabled_packs, "qiao_bingqing"),
    "Fixture must use a pack disabled by the mode whitelist")
  local raw = cbor.decode(room.room:settings())
  lu.assertFalse(table.contains(raw.disabledPack or {}, "qiao_bingqing"),
    "The mode-level disable must not be present in the host settings")

  room = freshRoom({ disabledPack = { "qiao_bingqing" } }, Modes.free)
  setupJin(room)
  FkTest.runInRoom(function()
    ok = A.ascend(room, room.players[1], "qiao_heg__em_jin001", "jin", { kind = "lord" })
  end)
  lu.assertFalse(ok, "A host-banned pack must still block ascension")
  lu.assertEquals(room.players[1].general, "qiao_heg__jin001")
end

function Testsecond_lord:testSuccessionSkipsBannedTargetAndAsksNextCandidate()
  freshRoom({ disabledGenerals = { G.wei_monarch.name } }, Modes.free)
  local lord, first, second = player(1), player(2), player(3)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(first, G.wei_normal.name, "qiao_test__qun_1", "qun")
    hidden(second, G.wei_normal2.name, "qiao_test__qun_2", "qun")
    room():setCurrent(first)
  end)
  local prompts = captureAscensionPrompts()
  FkTest.setNextReplies(first, { { A.ASCEND_ACCEPT } })
  FkTest.setNextReplies(second, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)

  lu.assertEquals(prompts.succession, { second.seat }, "Banned target must be skipped, not asked")
  lu.assertEquals(first.general, "anjiang")
  lu.assertEquals(second.general, G.wei_monarch2.name)
  lu.assertEquals(second.kingdom, "wei")
end

function Testsecond_lord:testSuccessionWithoutAllowedTargetKeepsWildFallback()
  freshRoom({ disabledGenerals = { G.wei_monarch.name } }, Modes.free)
  local lord, candidate = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal.name, "qiao_test__qun_1", "wei")
    room():setCurrent(candidate)
  end)
  local prompts = captureAscensionPrompts()
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)

  lu.assertEquals(#prompts.succession, 0)
  lu.assertEquals(candidate.general, "anjiang")
  lu.assertEquals(candidate:getMark("__heg_kingdom"), "wild")
  lu.assertFalse(A.has_lord(room(), "wei"))
end

function Testsecond_lord:testLordPolicyControlsHintsAndActualFirstTurnAscension()
  local normal, deputy, lord = "qiao_heg__wu001", "qiao_heg__wu002", "qiao_heg__em_wu001"
  for _, case in ipairs {
    { Modes.collection, true, true, true },
    { Modes.collection, false, false, false },
    { Modes.free, A.lordEnabled, true, true },
    { Modes.free, A.lordDisabled, false, false },
    { Modes.free, A.lordByBanScheme, true, false },
  } do
    local mode, setting, banned, allowed = table.unpack(case)
    freshRoom({ _mode = { [A.lordSetting] = setting }, disabledGenerals = banned and { lord } or {} }, mode)
    local p = player(1)
    FkTest.runInRoom(function()
      room():setBanner("all_kingdoms", { "wei", "shu", "wu", "qun" })
      hidden(p, normal, deputy, "wu")
      local data = Selection.askData(room(), { normal, deputy }).component.model.prop.extraData
      lu.assertEquals(data.ascensions[normal] == true, allowed)
      if not allowed then lu.assertFalse(A.ascend(room(), p, lord, "wu", { kind = "lord" })) end
    end)
    local prompts = captureAscensionPrompts()
    triggerTurnStart(p, allowed and A.ASCEND_ACCEPT or "Cancel")
    lu.assertEquals(#prompts.convert, allowed and 1 or 0)
    lu.assertEquals(p.general, allowed and lord or "anjiang")
  end
end

function Testsecond_lord:testEnabledLordPolicyAllowsBannedTargetToInherit()
  freshRoom({ disabledGenerals = { G.wei_monarch2.name }, _mode = { [A.lordSetting] = true } }, Modes.collection)
  local lord, candidate = player(1), player(2)
  FkTest.runInRoom(function()
    revealed(lord, G.wei_monarch.name, G.wei_deputy.name, "wei")
    hidden(candidate, G.wei_normal2.name, "qiao_test__qun_1", "wei")
    room():setCurrent(candidate)
  end)
  local prompts = captureAscensionPrompts()
  FkTest.setNextReplies(candidate, { { A.ASCEND_ACCEPT } })
  FkTest.runInRoom(function() room():killPlayer { who = lord } end)
  lu.assertEquals(prompts.succession, { candidate.seat })
  lu.assertEquals(candidate.general, G.wei_monarch2.name)
end

return { name = "second_lord" }
