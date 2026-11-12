local support = __dofile("../../../tests/support/hegemony.lua")
local content = __dofile("../../../tests/support/only_as_content.lua")
local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"
local BattleRoyal = require "packages.hanjin.pkg.hanjin_mode.rules.battle_royal"
local H = require "packages.hegemony.util"

local function setup()
  Fk.currentResponsePattern = nil
  return support.initHanjinRoom()
end

local function teardown()
  Fk.currentResponsePattern = nil
  support.clearRoom()
end

Testhanjin_only_as = { setup = setup, tearDown = teardown }

local function room() return FkTest.room end
local function run(fn) FkTest.runInRoom(fn) end

local function enterBattleRoyal()
  run(function() BattleRoyal.enter(room()) end)
end

local function give(player, name, suit, number)
  local card
  run(function()
    card = room():printCard(name, suit, number)
    room():obtainCard(player, card, true)
  end)
  return card
end

local function hasTarget(t, target)
  return table.contains(t, target)
end

local function markSources(player)
  return player:getMark(O.SOURCE_MARK)
end

function Testhanjin_only_as:testSourceUnionIndependentRemovalAndSync()
  local player = room().players[1]
  enterBattleRoyal()
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  local heartUid = nil
  run(function()
    heartUid = O.addSource(room(), {
      def = "hanjin_test_heart_dismantlement",
      holder = player,
      duration = "game",
    })
  end)

  local useTargets = O.availableTargets(room(), player, peach.id, "use")
  lu.assertTrue(hasTarget(useTargets, "hanjin__slash"))
  lu.assertTrue(hasTarget(useTargets, "hanjin__jink"))
  lu.assertTrue(hasTarget(useTargets, "hanjin__dismantlement"))
  local responseTargets = O.availableTargets(room(), player, peach.id, "response")
  lu.assertTrue(hasTarget(responseTargets, "hanjin__slash"))
  lu.assertTrue(hasTarget(responseTargets, "hanjin__jink"))
  lu.assertFalse(hasTarget(responseTargets, "hanjin__dismantlement"))
  -- 红桃来源只允许“使用”，不授予打出拆的权限。
  lu.assertTrue(O.isForbidden(player, peach))

  local mark = markSources(player)
  lu.assertTrue(type(mark) == "table")
  local defs = {}
  for _, rec in ipairs(mark) do defs[rec.def] = true end
  lu.assertTrue(defs["battle_royal"])
  lu.assertTrue(defs["hanjin_test_heart_dismantlement"])

  run(function() O.removeSource(room(), heartUid) end)
  lu.assertFalse(hasTarget(O.availableTargets(room(), player, peach.id, "use"), "hanjin__dismantlement"))
  lu.assertTrue(O.isForbidden(player, peach))
  mark = markSources(player)
  for _, rec in ipairs(mark) do
    lu.assertNotEquals(rec.def, "hanjin_test_heart_dismantlement")
  end

  -- 二次 GameStart 初始化不得清除已登记来源。
  run(function()
    O.addSource(room(), {
      def = "hanjin_test_heart_dismantlement", holder = player, duration = "game",
    })
    room().logic:trigger(fk.GameStart, player, {})
  end)
  lu.assertTrue(hasTarget(O.availableTargets(room(), player, peach.id, "use"), "hanjin__dismantlement"))

  run(function() O.clearSources(room(), player) end)
  lu.assertFalse(O.isForbidden(player, peach))
  lu.assertEquals(markSources(player), 0)
end

function Testhanjin_only_as:testTurnExpiryAndIndependentSources()
  local player = room().players[1]
  enterBattleRoyal()
  local material = give(player, "hanjin__jink", Card.Spade, 4)
  local uid
  run(function()
    uid = O.addSource(room(), {
      def = "tuxi",
      holder = player,
      duration = "turn",
      cards = { material.id },
    })
  end)
  lu.assertTrue(hasTarget(O.availableTargets(room(), player, material.id, "use"), "hanjin__slash"))
  local other = give(player, "hanjin__jink", Card.Spade, 5)
  lu.assertFalse(hasTarget(O.availableTargets(room(), player, other.id, "use"), "hanjin__slash"))
  run(function()
    local event = fk.TurnEnd:new(room(), player, {})
    for _, s in ipairs(room().logic.skill_table[fk.TurnEnd] or {}) do
      if s:getSkeleton() ~= nil and s:getSkeleton().name == O.RULE_SKILL then
        s:trigger(event, player, player, {})
      end
    end
  end)
  lu.assertFalse(hasTarget(O.availableTargets(room(), player, material.id, "use"), "hanjin__slash"))
  lu.assertFalse(O.isForbidden(player, material))
  local mark = markSources(player)
  for _, rec in ipairs(mark) do lu.assertNotEquals(rec.def, "tuxi") end
end

function Testhanjin_only_as:testRealUseRequestRejectsDirectPeachAndAllowsConversion()
  local player, target = room().players[1], room().players[2]
  enterBattleRoyal()
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  local hp = target.hp
  lu.assertTrue(player:prohibitUse(peach))
  lu.assertTrue(player:prohibitResponse(peach))

  -- 服务端复核：即使伪造直接使用实体桃的回复，PreCardUse 也会中止。
  local directUse
  FkTest.setNextReplies(player, { { card = peach.id, targets = { target.id } } })
  run(function()
    directUse = room():askToUseCard(player, {
      pattern = "slash", skill_name = "hanjin_test_direct", cancelable = true,
    })
  end)
  lu.assertNotNil(directUse)
  run(function() room():useCard(directUse) end)
  lu.assertEquals(target.hp, hp)
  lu.assertTrue(table.contains(player:getCardIds("h"), peach.id))
  lu.assertEquals(Fk:getCardById(peach.id).trueName, "peach")

  -- 真实 AskForUseCard → handleUseCardReply → before_use → PreCardUse。
  local use
  FkTest.setNextReplies(player, { {
    card = { skill = BattleRoyal.SKILL, subcards = { peach.id } },
    targets = { target.id },
    interaction_data = "hanjin__slash",
  } })
  run(function()
    use = room():askToUseCard(player, {
      pattern = "slash", skill_name = "hanjin_test_converted", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.trueName, "slash")
  lu.assertTrue(table.contains(use.card.skillNames, BattleRoyal.SKILL))
  lu.assertFalse(table.contains(use.card.skillNames, "hanjin_only_as"))
  lu.assertEquals(use.card.subcards, { peach.id })
  -- 实体牌本身牌名不变。
  lu.assertEquals(Fk:getCardById(peach.id).trueName, "peach")
  run(function() room():useCard(use) end)
  lu.assertEquals(target.hp, hp - 1)
  lu.assertFalse(table.contains(player:getCardIds("h"), peach.id))
end

function Testhanjin_only_as:testRealResponseRequestAndDirectResponseRejection()
  local player = room().players[1]
  enterBattleRoyal()
  local peach = give(player, "hanjin__peach", Card.Heart, 4)

  -- 伪造直接打出实体桃：PreCardRespond 中止，桃仍在手。
  local direct
  FkTest.setNextReplies(player, { { card = peach.id } })
  run(function()
    direct = room():askToResponse(player, {
      pattern = "jink", skill_name = "hanjin_test_response", cancelable = true,
    })
  end)
  lu.assertNotNil(direct)
  run(function() room():responseCard(direct) end)
  lu.assertTrue(table.contains(player:getCardIds("h"), peach.id))

  -- 真实响应请求，选择鏖战提供的桃当闪。
  local respond
  FkTest.setNextReplies(player, { {
    card = { skill = BattleRoyal.SKILL, subcards = { peach.id } },
    targets = {},
    interaction_data = "hanjin__jink",
  } })
  run(function()
    respond = room():askToResponse(player, {
      pattern = "jink", skill_name = "hanjin_test_response", cancelable = true,
    })
  end)
  lu.assertNotNil(respond)
  lu.assertEquals(respond.card.trueName, "jink")
  lu.assertEquals(respond.card.subcards, { peach.id })
  run(function() room():responseCard(respond) end)
  lu.assertFalse(table.contains(player:getCardIds("h"), peach.id))
  lu.assertEquals(Fk:getCardById(peach.id).trueName, "peach")
end

function Testhanjin_only_as:testWoodenOxPileIsHandlyAndConverted()
  local player, target = room().players[1], room().players[2]
  enterBattleRoyal()
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  run(function()
    room():handleAddLoseSkills(player, "hanjin__wooden_ox_skill", nil, false, true)
    player:addToPile("$sa_carriage", peach.id, false, "hanjin__wooden_ox_skill")
  end)
  lu.assertTrue(table.contains(player:getHandlyIds(true), peach.id))
  lu.assertTrue(O.isForbidden(player, peach))
  lu.assertTrue(hasTarget(O.availableTargets(room(), player, peach.id, "response"), "hanjin__jink"))

  local use
  FkTest.setNextReplies(player, { {
    card = { skill = BattleRoyal.SKILL, subcards = { peach.id } },
    targets = {},
    interaction_data = "hanjin__jink",
  } })
  run(function()
    use = room():askToResponse(player, {
      pattern = "jink", skill_name = "hanjin_test_wooden_ox", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.trueName, "jink")
  run(function() room():responseCard(use) end)
  lu.assertFalse(table.contains(player:getHandlyIds(true), peach.id))
end

function Testhanjin_only_as:testAocaiRestrictedTopCardsOfferConversion()
  local player = room().players[1]
  enterBattleRoyal()
  run(function() room():handleAddLoseSkills(player, content.jijiu, nil, false, true) end)
  run(function() room():handleAddLoseSkills(player, "hanjin__aocai", nil, false, true) end)
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  -- 将傲才要看的顶牌放到牌堆顶。
  run(function()
    table.removeOne(player.player_cards[Player.Hand], peach.id)
    table.insert(room().draw_pile, 1, peach.id)
    room().card_place[peach.id] = Card.DrawPile
  end)
  lu.assertTrue(O.isForbidden(player, peach))

  local respond
  FkTest.setNextReplies(player, {
    { card = { skill = "hanjin__aocai", subcards = {} }, targets = {} },
    { O.restrictedLabel(peach) .. "：将【桃】当【闪】打出" },
    { "" },
  })
  run(function()
    respond = room():askToResponse(player, {
      pattern = "jink", skill_name = "hanjin_test_aocai", cancelable = true,
    })
  end)
  lu.assertNotNil(respond)
  lu.assertEquals(respond.card.trueName, "jink")
  lu.assertEquals(respond.card.subcards, { peach.id })
  run(function() room():responseCard(respond) end)
  lu.assertEquals(Fk:getCardById(peach.id).trueName, "peach")
end

function Testhanjin_only_as:testUseOnlyDismantlementThroughRealUseRequest()
  local player, target = room().players[1], room().players[2]
  enterBattleRoyal()
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  run(function()
    room():handleAddLoseSkills(player, content.heart, nil, false, true)
    O.addSource(room(), {
      def = "hanjin_test_heart_dismantlement", holder = player, duration = "game",
    })
  end)
  local handCount = #target:getCardIds("h")
  -- use 询问必须按 pattern 过滤：当前请求是拆，杀不在候选内。
  lu.assertFalse(O.targetAllowedInRequest(player, "hanjin__slash", peach.id, "use", "dismantlement"))
  -- 使用窗口不能因为 pattern 非空就把被动【闪】当成可用转换。
  local legalActions = O.actionsForCard(room(), player, peach.id, "use", { check_legal = true })
  local hasJink, hasSlash = false, false
  for _, action in ipairs(legalActions) do
    if action.target == "hanjin__jink" then hasJink = true end
    if action.target == "hanjin__slash" then hasSlash = true end
  end
  lu.assertFalse(hasJink)
  lu.assertTrue(hasSlash)
  local use
  FkTest.setNextReplies(player, { {
    card = { skill = content.heart, subcards = { peach.id } },
    targets = { target.id },
    interaction_data = "hanjin__dismantlement",
  } })
  run(function()
    use = room():askToUseCard(player, {
      pattern = "dismantlement", skill_name = "hanjin_test_dismantlement", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.trueName, "dismantlement")
  lu.assertTrue(table.contains(use.card.skillNames, content.heart))
  lu.assertFalse(table.contains(use.card.skillNames, BattleRoyal.SKILL))
  run(function() room():useCard(use) end)
  lu.assertEquals(#target:getCardIds("h"), handCount - 1)

  -- 仅 use 权限的来源：use 窗口可用，纯 response 窗口不可用。
  give(player, "hanjin__jink", Card.Heart, 8)
  run(function()
    O.clearSources(room(), player)
    O.addSource(room(), {
      def = "hanjin_test_heart_dismantlement", holder = player, duration = "game",
    })
  end)
  lu.assertTrue(O.hasAvailable(player, "use"))
  lu.assertFalse(O.hasAvailable(player, "response"))
end

function Testhanjin_only_as:testSyntaxDoesNotGrantSkillAndEntriesStayWithSource()
  local player = room().players[1]
  lu.assertNil(Fk.skills["hanjin_only_as"])
  lu.assertFalse(player:hasSkill(BattleRoyal.SKILL, true, true))
  enterBattleRoyal()
  lu.assertTrue(player:hasSkill(BattleRoyal.SKILL, true, true))
  lu.assertEquals(Fk:translate(BattleRoyal.SKILL), "鏖战")
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  run(function()
    room():handleAddLoseSkills(player, content.heart, nil, false, true)
    O.addSource(room(), {
      def = "hanjin_test_heart_dismantlement", holder = player, duration = "game",
    })
  end)
  -- 用途并存，但各自的转换入口仅能执行自己的效果。
  lu.assertTrue(O.cardSelectable(player, peach.id, "hanjin__slash", "battle_royal"))
  lu.assertFalse(O.cardSelectable(player, peach.id, "hanjin__dismantlement", "battle_royal"))
  lu.assertTrue(O.cardSelectable(player, peach.id, "hanjin__dismantlement",
    "hanjin_test_heart_dismantlement"))
  local use
  FkTest.setNextReplies(player, { {
    card = { skill = BattleRoyal.SKILL, subcards = { peach.id } },
    targets = { room().players[2].id }, interaction_data = "hanjin__dismantlement",
  }, "" })
  run(function()
    use = room():askToUseCard(player, { pattern = "dismantlement", cancelable = true })
  end)
  lu.assertNil(use)
  lu.assertTrue(table.contains(player:getCardIds("h"), peach.id))
end

function Testhanjin_only_as:testJijiuAndLongdanConversionsAreNotBlocked()
  local player, target = room().players[1], room().players[2]
  enterBattleRoyal()
  run(function() room():handleAddLoseSkills(player, content.jijiu, nil, false, true) end)
  run(function() room():handleAddLoseSkills(player, content.longdan, nil, false, true) end)
  local peach = give(player, "hanjin__peach", Card.Heart, 4)

  -- 急救同名桃转桃：只允许“使用”求桃；走真实 askToUseCard/使用流程并回复体力。
  run(function()
    room():setCurrent(room().players[2])
    room():setPlayerProperty(player, "hp", player.maxHp - 1)
  end)
  lu.assertFalse(Fk.skills[content.jijiu]:enabledAtResponse(player, true))
  lu.assertTrue(Fk.skills[content.jijiu]:enabledAtResponse(player, false))
  local hp = player.hp
  local jijiuUse
  FkTest.setNextReplies(player, { {
    card = { skill = content.jijiu, subcards = { peach.id } },
    targets = { player.id },
  } })
  run(function()
    jijiuUse = room():askToUseCard(player, {
      pattern = "peach", skill_name = "hanjin_test_jijiu", cancelable = true,
    })
  end)
  lu.assertNotNil(jijiuUse)
  lu.assertEquals(jijiuUse.card.trueName, "peach")
  lu.assertTrue(jijiuUse.card:isConverted())
  run(function() room():useCard(jijiuUse) end)
  lu.assertEquals(player.hp, hp + 1)
  lu.assertFalse(table.contains(player:getCardIds("h"), peach.id))

  -- 龙胆桃转酒：真实使用请求。
  local peach2 = give(player, "hanjin__peach", Card.Heart, 5)
  local wineUse
  FkTest.setNextReplies(player, { {
    card = { skill = content.longdan, subcards = { peach2.id } },
    targets = { player.id },
  } })
  run(function()
    wineUse = room():askToUseCard(player, {
      pattern = "analeptic", skill_name = "hanjin_test_longdan", cancelable = true,
    })
  end)
  lu.assertNotNil(wineUse)
  lu.assertEquals(wineUse.card.trueName, "analeptic")
  run(function() room():useCard(wineUse) end)
  lu.assertTrue(player.drank > 0)
end

function Testhanjin_only_as:testClientViewAsBuildsConvertedCardWithoutServerTag()
  local player = room().players[1]
  enterBattleRoyal()
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  local clientCard
  FkTest.runInClient(function()
    local skill = Fk.skills[BattleRoyal.SKILL]
    skill.interaction.data = "hanjin__slash"
    clientCard = skill:viewAs(Self, { peach.id })
    skill.interaction.data = nil
  end)
  lu.assertNotNil(clientCard)
  lu.assertEquals(clientCard.name, "hanjin__slash")
  lu.assertEquals(clientCard.trueName, "slash")
  lu.assertEquals(clientCard.subcards, { peach.id })
  lu.assertNotNil(clientCard:getMark(O.CARD_MARK))
end

function Testhanjin_only_as:testClientRequestHandlerDistinguishesUseAndResponse()
  local player = room().players[1]
  enterBattleRoyal()
  local useMode, responseMode, useHandler, responseHandler
  FkTest.runInClient(function()
    local useClass = ClientInstance.request_handlers["AskForUseCard"]
    local responseClass = ClientInstance.request_handlers["AskForResponseCard"]
    useHandler = setmetatable({ class = useClass, extra_data = {} }, { __index = useClass })
    ClientInstance.current_request_handler = useHandler
    Fk.currentResponsePattern = "dismantlement"
    useMode = O.currentMode(Self)
    responseHandler = setmetatable({ class = responseClass, extra_data = {} },
      { __index = responseClass })
    ClientInstance.current_request_handler = responseHandler
    Fk.currentResponsePattern = "jink"
    responseMode = O.currentMode(Self)
    ClientInstance.current_request_handler = nil
    Fk.currentResponsePattern = nil
  end)
  lu.assertEquals(useHandler.class.name, "ReqUseCard")
  lu.assertEquals(responseHandler.class.name, "ReqResponseCard")
  lu.assertEquals(useMode, "use")
  lu.assertEquals(responseMode, "response")
end

function Testhanjin_only_as:testForgedTargetsPatternsAndExpiredSourcesAreRejected()
  local player = room().players[1]
  enterBattleRoyal()
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  local skill = Fk.skills[BattleRoyal.SKILL]

  -- 合法目标会在服务端复核后写入 verified。
  local ok = false
  run(function()
    ok = O.validateUse(room(), player, {
      from = player, tos = {}, card = O.buildCard(player, peach.id, "hanjin__jink", BattleRoyal.SKILL),
    }, { mode = "response", pattern = "jink" })
  end)
  lu.assertTrue(ok)

  -- 伪造目标：鏖战不提供桃当桃。
  local badTarget = false
  run(function()
    local card = O.buildCard(player, peach.id, "hanjin__peach", BattleRoyal.SKILL)
    badTarget = O.validateUse(room(), player, { from = player, tos = {}, card = card },
      { mode = "use", pattern = "peach" })
  end)
  lu.assertFalse(badTarget)

  -- 伪造请求模式：拆只有使用权限，在响应窗口不得成立。
  local heartUid
  run(function()
    heartUid = O.addSource(room(), {
      def = "hanjin_test_heart_dismantlement", holder = player, duration = "game",
    })
  end)
  local badMode = false
  run(function()
    local card = O.buildCard(player, peach.id, "hanjin__dismantlement", BattleRoyal.SKILL)
    badMode = O.validateUse(room(), player, { from = player, tos = {}, card = card },
      { mode = "response", pattern = "dismantlement" })
  end)
  lu.assertFalse(badMode)
  run(function() O.removeSource(room(), heartUid) end)

  -- 伪造底牌：即使人为写入 verified 记录，底牌不匹配鏖战来源也必须失败。
  local blank = give(player, "hanjin__jink", Card.Spade, 9)
  local forgedSubcard = false
  run(function()
    local card = O.buildCard(player, blank.id, "hanjin__slash", BattleRoyal.SKILL)
    card:setMark(O.VERIFIED_MARK, { mode = "use", pattern = "slash" })
    forgedSubcard = O.validateUse(room(), player,
      { from = player, tos = {}, card = card }, { mode = "use", pattern = "slash" })
  end)
  lu.assertFalse(forgedSubcard)

  -- 过期来源：移除鏖战来源后，回合来源新增再推进回合，应完全失效。
  run(function() O.clearSources(room(), player) end)
  local uid
  run(function()
    uid = O.addSource(room(), {
      def = "tuxi", holder = player, duration = "turn", cards = { peach.id },
    })
  end)
  run(function() O.advanceTurn(room()) end)
  local expired = false
  run(function()
    local card = O.buildCard(player, peach.id, "hanjin__slash", BattleRoyal.SKILL)
    expired = O.validateUse(room(), player, { from = player, tos = {}, card = card },
      { mode = "use", pattern = "slash" })
  end)
  lu.assertFalse(expired)
end

function Testhanjin_only_as:testRoundDurationExpiresOnRoundStart()
  local player = room().players[1]
  enterBattleRoyal()
  run(function() O.clearSources(room(), player) end)
  local material = give(player, "hanjin__jink", Card.Spade, 8)
  run(function()
    O.addSource(room(), {
      def = "tuxi", holder = player, duration = "round", cards = { material.id },
    })
  end)
  lu.assertTrue(hasTarget(O.availableTargets(room(), player, material.id, "use"), "hanjin__slash"))
  run(function()
    room():setBanner("RoundCount", (room():getBanner("RoundCount") or 0) + 1)
    -- 直接调用真实注册在 fk.RoundStart 上的汉晋 refresh effect，避免 testmode
    -- 的其它 RoundStart 流程产生新的回合请求。
    for _, s in ipairs(room().logic.skill_table[fk.RoundStart] or {}) do
      if s:getSkeleton() ~= nil and s:getSkeleton().name == O.RULE_SKILL then
        s:refresh(fk.RoundStart:new(room(), player, {}), player, player, {})
      end
    end
  end)
  lu.assertFalse(hasTarget(O.availableTargets(room(), player, material.id, "use"), "hanjin__slash"))
end

function Testhanjin_only_as:testRestrictedAuthorizationIsBoundAndCleared()
  local player = room().players[1]
  enterBattleRoyal()
  local first, second = give(player, "hanjin__jink", Card.Spade, 6),
    give(player, "hanjin__jink", Card.Spade, 7)
  run(function()
    O.authorizeCard(room(), player, first.id, "test")
  end)
  lu.assertTrue(O.isAuthorized(room(), player, first.id))
  lu.assertFalse(O.isAuthorized(room(), player, second.id))
  run(function()
    room():moveCardTo(first.id, Card.DiscardPile, nil, fk.ReasonPut, nil, nil, true)
  end)
  lu.assertFalse(O.isAuthorized(room(), player, first.id))
  run(function() O.clearAuthorization(room(), player) end)
  lu.assertFalse(O.isAuthorized(room(), player, first.id))
end

function Testhanjin_only_as:testSkillSourceFollowsGeneralVisibilityAndLoss()
  local player = room().players[1]
  enterBattleRoyal()
  local slash = give(player, "hanjin__slash", Card.Spade, 4)
  run(function()
    room():changeHero(player, "hanjin_test__only_as_source_holder", false, false, false, false, false)
    room():setPlayerMark(player, "__heg_general", "hanjin_test__only_as_source_holder")
    player:revealGeneral(false)
  end)
  local uid
  run(function()
    uid = O.addSource(room(), {
      def = "shuangren",
      holder = player,
      duration = "game",
      skill = "hanjin_test__only_as_source_skill",
    })
  end)
  lu.assertTrue(hasTarget(O.availableTargets(room(), player, slash.id, "use"), "hanjin__collateral"))

  -- 暗置时技能暂时失效，但来源保留，重新明置后恢复。
  run(function() player:hideGeneral(false) end)
  lu.assertFalse(hasTarget(O.availableTargets(room(), player, slash.id, "use"), "hanjin__collateral"))
  local mark = markSources(player)
  for _, rec in ipairs(type(mark) == "table" and mark or {}) do
    lu.assertNotEquals(rec.def, "shuangren")
  end
  run(function() player:revealGeneral(false) end)
  lu.assertTrue(hasTarget(O.availableTargets(room(), player, slash.id, "use"), "hanjin__collateral"))

  -- 技能被临时无效化时 hasShownSkill 为 false，来源应暂时失效并可恢复。
  run(function()
    room():invalidateSkill(player, "hanjin_test__only_as_source_skill", "", "test")
    O.refresh(room())
  end)
  lu.assertFalse(hasTarget(O.availableTargets(room(), player, slash.id, "use"), "hanjin__collateral"))
  run(function()
    room():validateSkill(player, "hanjin_test__only_as_source_skill", "", "test")
    O.refresh(room())
  end)
  lu.assertTrue(hasTarget(O.availableTargets(room(), player, slash.id, "use"), "hanjin__collateral"))

  -- 更换武将后来源所属技能不存在，来源应被永久移除。
  run(function()
    room():changeHero(player, "hanjin_test__wei_1", false, false, false, false, false)
    room():setPlayerMark(player, "__heg_general", "hanjin_test__wei_1")
    O.refresh(room())
  end)
  lu.assertFalse(hasTarget(O.availableTargets(room(), player, slash.id, "use"), "hanjin__collateral"))
end

function Testhanjin_only_as:testForgedConvertedCardAndIllegalTargetAreRejected()
  local player, target = room().players[1], room().players[2]
  enterBattleRoyal()
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  local hp = target.hp

  -- 未经过服务端请求验证的伪造转化牌不能进入 PreCardUse 之后。
  local forged = O.buildCard(player, peach.id, "hanjin__slash", BattleRoyal.SKILL)
  run(function()
    room():useCard { from = player, tos = { target.id }, card = forged }
  end)
  lu.assertEquals(target.hp, hp)
  lu.assertTrue(table.contains(player:getCardIds("h"), peach.id))

  -- 目标复核：距离外的角色不能成为转化杀的目标。
  local far = room().players[5]
  local outOfRange = false
  run(function()
    O.clearSources(room(), player)
    O.addSource(room(), { def = "battle_royal", holder = player, duration = "game" })
    local card = O.buildCard(player, peach.id, "hanjin__slash", BattleRoyal.SKILL)
    outOfRange = O.validateUse(room(), player, { from = player, tos = { far.id }, card = card },
      { mode = "use", pattern = "slash" })
  end)
  lu.assertFalse(outOfRange)

  -- 多目标组合复核：单目标【杀】不能借提交多个各自合法的目标来生效多次。
  local multi = false
  run(function()
    local card = O.buildCard(player, peach.id, "hanjin__slash", BattleRoyal.SKILL)
    multi = O.validateUse(room(), player, {
      from = player, tos = { room().players[2].id, room().players[3].id }, card = card,
    }, { mode = "use", pattern = "slash" })
  end)
  lu.assertFalse(multi)
end

function Testhanjin_only_as:testAocaiUsePathOffersConversionToSlash()
  local player, target = room().players[1], room().players[2]
  enterBattleRoyal()
  run(function() room():handleAddLoseSkills(player, "hanjin__aocai", nil, false, true) end)
  local peaches = {
    give(player, "hanjin__peach", Card.Heart, 4),
    give(player, "hanjin__peach", Card.Heart, 5),
  }
  run(function()
    for i, card in ipairs(peaches) do
      table.removeOne(player.player_cards[Player.Hand], card.id)
      table.insert(room().draw_pile, i, card.id)
      room().card_place[card.id] = Card.DrawPile
    end
  end)
  local hp = target.hp
  local use
  local top = Fk:getCardById(room().draw_pile[1])
  FkTest.setNextReplies(player, {
    { card = { skill = "hanjin__aocai", subcards = {} }, targets = { target.id } },
    { O.restrictedLabel(top) .. "：将【桃】当【杀】使用" },
    { card = { skill = "virtual_viewas", subcards = {} }, targets = { target.id },
      interaction_data = "hanjin__slash" },
    { "" },
  })
  run(function()
    use = room():askToUseCard(player, {
      pattern = "slash", skill_name = "hanjin_test_aocai_use", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.trueName, "slash")
  run(function() room():useCard(use) end)
  lu.assertEquals(target.hp, hp - 1)
end

function Testhanjin_only_as:testClientMarkSyncAndAocaiKeepsRestrictedCardSet()
  local player = room().players[1]
  enterBattleRoyal()
  local clientMark
  FkTest.runInClient(function()
    clientMark = Self:getMark(O.SOURCE_MARK)
  end)
  lu.assertTrue(type(clientMark) == "table")

  -- 傲才只允许牌堆顶两张牌；玩家手里的桃不能通过该入口使用。
  local handPeach = give(player, "hanjin__peach", Card.Heart, 4)
  local topJink = give(player, "hanjin__jink", Card.Spade, 5)
  local topSlash = give(player, "hanjin__slash", Card.Spade, 6)
  run(function()
    for _, card in ipairs({ topJink, topSlash }) do
      table.removeOne(player.player_cards[Player.Hand], card.id)
      table.insert(room().draw_pile, 1, card.id)
      room().card_place[card.id] = Card.DrawPile
    end
  end)
  local result
  FkTest.setNextReplies(player, { { "将【桃】当【闪】打出" } })
  run(function()
    result = O.askRestricted(room(), player, {
      cards = { topJink.id, topSlash.id },
      pattern = "jink",
      is_response = true,
      skill_name = "hanjin__aocai",
      cancelable = true,
    })
  end)
  lu.assertNil(result)
  lu.assertTrue(table.contains(player:getCardIds("h"), handPeach.id))
end

function Testhanjin_only_as:testAocaiDirectResponseConsumesAuthorization()
  local player = room().players[1]
  enterBattleRoyal()
  local jink = give(player, "hanjin__jink", Card.Spade, 8)
  run(function()
    room():handleAddLoseSkills(player, "hanjin__aocai", nil, false, true)
    room():moveCardTo(jink.id, Card.DrawPile, nil, fk.ReasonJustMove, "test", nil, false)
    table.removeOne(room().draw_pile, jink.id)
    table.insert(room().draw_pile, 1, jink.id)
  end)
  FkTest.setNextReplies(player, {
    { card = { skill = "hanjin__aocai", subcards = {} }, targets = {} },
    { O.restrictedLabel(jink) .. "：打出【闪】" },
  })
  local response
  run(function()
    response = room():askToResponse(player, {
      pattern = "jink", skill_name = "test", cancelable = true,
    })
  end)
  lu.assertNotNil(response)
  lu.assertEquals(response.card.id, jink.id)
  run(function() room():responseCard(response) end)
  lu.assertEquals(room():getCardArea(jink.id), Card.DiscardPile)
  lu.assertNil(O.authorizationEntry(room(), player))
end

function Testhanjin_only_as:testAocaiDirectUseConsumesAuthorization()
  local player, target = room().players[1], room().players[2]
  enterBattleRoyal()
  local slash = give(player, "hanjin__slash", Card.Spade, 8)
  run(function()
    room():handleAddLoseSkills(player, "hanjin__aocai", nil, false, true)
    room():moveCardTo(slash.id, Card.DrawPile, nil, fk.ReasonJustMove, "test", nil, false)
    table.removeOne(room().draw_pile, slash.id)
    table.insert(room().draw_pile, 1, slash.id)
  end)
  FkTest.setNextReplies(player, {
    { card = { skill = "hanjin__aocai", subcards = {} }, targets = { target.id } },
    { O.restrictedLabel(slash) .. "：使用【杀】" },
    { card = { skill = "userealcard_skill", subcards = { slash.id } }, targets = { target.id } },
  })
  local use, hp = nil, target.hp
  run(function()
    use = room():askToUseCard(player, {
      pattern = "slash", skill_name = "test", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.id, slash.id)
  run(function() room():useCard(use) end)
  lu.assertEquals(target.hp, hp - 1)
  lu.assertNil(O.authorizationEntry(room(), player))
end

function Testhanjin_only_as:testMovedCardCannotReviveRestrictedAuthorization()
  local player = room().players[1]
  enterBattleRoyal()
  local peach = give(player, "hanjin__peach", Card.Heart, 8)
  run(function()
    O.authorizeCard(room(), player, peach.id, "test", { mode = "response", pattern = "jink" })
    room():moveCardTo(peach.id, Card.DiscardPile, nil, fk.ReasonJustMove, "test")
    room():obtainCard(player, peach.id, true)
  end)
  lu.assertFalse(O.isAuthorized(room(), player, peach.id))
  lu.assertNil(O.authorizationEntry(room(), player))
end

return { name = "hanjin_only_as" }
