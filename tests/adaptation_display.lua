local support = __dofile("../../../tests/support/hegemony.lua")
local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"

Testadaptation_display = { setup = support.initHanjinRoom, tearDown = support.clearRoom }

local function room() return FkTest.room end

local function mountedDisplay()
  for _, list in pairs(room().status_skills) do
    for _, skill in ipairs(list) do
      if skill.skeleton and skill.skeleton.name == "#hanjin_adaptation_display" then
        return skill
      end
    end
  end
  error("Mounted adaptation display skill not found")
end

local function bySlot(current, slot)
  return table.find(Fk.cards, function(card)
    return (card.extra_data or {}).hanjin_slot == slot
      and current:getCardArea(card.id) ~= Card.Unknown
  end)
end

local function use(entries)
  local current = room()
  local card = Fk:cloneCard("hanjin_test__blank_basic")
  if entries then A.setCardEntries(card, entries) end
  return UseCardData:new {
    from = current.players[1], tos = { current.players[2] }, card = card, extra_data = {},
  }
end

local function captureSpecific(fn)
  local current = room()
  local logs = {}
  local original = current.sendLog
  current.sendLog = function(self, log) table.insert(logs, log) end
  local ok, err = pcall(fn)
  current.sendLog = original
  assert(ok, err)
  return table.filter(logs, function(log) return log.type == "#InvokeSkillHanjinAdaptation" end), logs
end

local function clearHands(current, player)
  for _, other in ipairs(current.players) do
    if other == player then
      local ids = other:getCardIds("h")
      if #ids > 0 then current:throwCard(ids, "test", other, other) end
    elseif #other:getCardIds("h") > 0 then
      current:throwCard(other:getCardIds("h"), "test", other, other)
    end
  end
end

local function giveType(current, player, cardType)
  local id = assert(table.find(current.draw_pile, function(id) return Fk:getCardById(id).type == cardType end))
  current:obtainCard(player, id, true, fk.ReasonJustMove, player, "test")
  return id
end

function Testadaptation_display:testPhysicalCardsExposeTheirOwnSlotMarks()
  local current = room()
  local canqu = assert(bySlot(current, "standard1/S/10"))
  local gujun = assert(bySlot(current, "shibei/S/4"))
  lu.assertEquals(canqu.name, "hanjin__slash")
  lu.assertEquals(gujun.name, "hanjin__slash")
  -- Move both same-name cards into a hand; the hand move is what publishes the
  -- marks to their owner (draw-pile cards are intentionally not stamped).
  local canquMark, gujunMark, secondMark
  FkTest.runInRoom(function()
    current:obtainCard(current.players[1], canqu.id, true, fk.ReasonJustMove, current.players[1], "test")
    current:obtainCard(current.players[1], gujun.id, true, fk.ReasonJustMove, current.players[1], "test")
    canquMark = canqu:getMark("@hanjin_adaptation_1")
    gujunMark = gujun:getMark("@hanjin_adaptation_1")
    secondMark = canqu:getMark("@hanjin_adaptation_2")
  end)

  lu.assertEquals(canquMark, { "hanjin_condition_canqu", "·", "hanjin_adaptation_add_target" })
  lu.assertEquals(gujunMark, { "hanjin_condition_gujun", "·", "hanjin_adaptation_add_target" })
  -- Same card name at different physical positions must not share entries.
  lu.assertNotEquals(canquMark[1], gujunMark[1])
  lu.assertEquals(secondMark, 0)

  -- These are the raw values the client receives and translates into a row.
  lu.assertEquals(Fk:translate("@hanjin_adaptation_1"), "应变")
  lu.assertEquals(Fk:translate(canquMark[1]), "残躯")
  lu.assertEquals(Fk:translate(canquMark[2]), "·")
  lu.assertEquals(Fk:translate(canquMark[3]), "目标+1")
  -- Mirrors LtkLuaUtil.setMark's Array branch: translate each part, join with spaces.
  lu.assertEquals(table.concat({
    Fk:translate(canquMark[1]), Fk:translate(canquMark[2]), Fk:translate(canquMark[3]),
  }, " "), "残躯 · 目标+1")
  local roundtrip = cbor.decode(cbor.encode(canquMark))
  lu.assertEquals(roundtrip, canquMark)
end

function Testadaptation_display:testMultipleEntriesAndVirtualCardsUseExplicitMetadata()
  local current = room()
  local card
  FkTest.runInRoom(function()
    card = current:printCard("hanjin_test__blank_basic", Card.Heart, 5)
    A.setCardEntries(card, {
      { condition = "gujun", effect = "ignore_times" },
      { condition = "kongchao", effect = "draw" },
    })
    A.stampCard(current, card)
  end)
  lu.assertEquals(card:getMark("@hanjin_adaptation_1"),
    { "hanjin_condition_gujun", "·", "hanjin_adaptation_ignore_times" })
  lu.assertEquals(card:getMark("@hanjin_adaptation_2"),
    { "hanjin_condition_kongchao", "·", "hanjin_adaptation_draw" })

  local tips = assert(A.cardTips(card))
  lu.assertEquals(#tips, 2)
  lu.assertEquals(tips[1], { content = "孤军·无视次数", type = "normal" })
  lu.assertEquals(tips[2], { content = "空巢·摸一张牌", type = "normal" })

  local virtual = Fk:cloneCard("hanjin__slash")
  lu.assertNil(A.cardTips(virtual))
  A.setCardEntries(virtual, { { condition = "fujia", effect = "damage" } })
  lu.assertEquals(A.cardTips(virtual)[1].content, "富甲·伤害+1")

  local material = Fk:cloneCard("hanjin__slash")
  material:addSubcard(card.id)
  lu.assertNil(A.cardTips(material))
end

function Testadaptation_display:testStampSyncClearsReducedAndLostMarks()
  local current = room()
  local card
  local initialStamped, initialSecond
  FkTest.runInRoom(function()
    card = current:printCard("hanjin_test__blank_basic", Card.Heart, 4)
    A.setCardEntries(card, {
      { condition = "gujun", effect = "ignore_times" },
      { condition = "kongchao", effect = "draw" },
    })
    A.stampCard(current, card)
    initialStamped = A.cardStamped(card)
    initialSecond = card:getMark("@hanjin_adaptation_2")
  end)
  lu.assertTrue(initialStamped)
  lu.assertNotEquals(initialSecond, 0)

  -- Two entries reduced to one: the old second mark must not survive.
  local reducedStamped
  FkTest.runInRoom(function()
    A.setCardEntries(card, { { condition = "gujun", effect = "ignore_times" } })
    reducedStamped = A.cardStamped(card)
  end)
  lu.assertFalse(reducedStamped)
  local afterFirst, afterSecond, afterStamped
  FkTest.runInRoom(function()
    A.stampMoved(current, { { toArea = Player.Hand, to = current.players[1],
      moveInfo = { { cardId = card.id } } } })
    afterFirst = card:getMark("@hanjin_adaptation_1")
    afterSecond = card:getMark("@hanjin_adaptation_2")
    afterStamped = A.cardStamped(card)
  end)
  lu.assertEquals(afterSecond, 0)
  lu.assertEquals(afterFirst, { "hanjin_condition_gujun", "·", "hanjin_adaptation_ignore_times" })
  lu.assertTrue(afterStamped)

  -- Entries removed entirely: old marks must be cleared rather than skipped.
  local hasMarksAfterClear, clearedStamped
  FkTest.runInRoom(function()
    A.setCardEntries(card, {})
    A.stampMoved(current, { { toArea = Player.Hand, to = current.players[1],
      moveInfo = { { cardId = card.id } } } })
    hasMarksAfterClear = A.hasDisplayMarks(card)
    clearedStamped = A.cardStamped(card)
  end)
  lu.assertFalse(hasMarksAfterClear)
  lu.assertTrue(clearedStamped)

  -- Moving a card with neither adaptation data nor old marks must broadcast nothing.
  local broadcasts = 0
  local original = current.doBroadcastNotify
  FkTest.runInRoom(function()
    local plain = current:printCard("hanjin_test__blank_basic", Card.Heart, 3)
    current.doBroadcastNotify = function(self, command, data, players)
      if command == "SetCardMark" then broadcasts = broadcasts + 1 end
      return original(self, command, data, players)
    end
    A.stampMoved(current, { { toArea = Player.Hand, to = current.players[1],
      moveInfo = { { cardId = plain.id } } } })
    current.doBroadcastNotify = original
  end)
  lu.assertEquals(broadcasts, 0)
end

function Testadaptation_display:testDrawPileCardsAreNotStampedAndHandAudienceIsOwnerOnly()
  local current = room()
  local card
  for _, candidate in ipairs(Fk.cards) do
    if (candidate.extra_data or {}).hanjin_slot and A.isAdaptationCard(candidate)
      and current:getCardArea(candidate.id) == Card.DrawPile then
      card = candidate
      break
    end
  end
  lu.assertNotNil(card)
  -- GamePrepared must not publish marks for face-down draw-pile cards.
  local unmarked
  FkTest.runInRoom(function() unmarked = A.hasDisplayMarks(card) end)
  lu.assertFalse(unmarked)

  local recipients, hasMarks
  local original = current.doBroadcastNotify
  FkTest.runInRoom(function()
    current.doBroadcastNotify = function(self, command, data, players)
      if command == "SetCardMark" then recipients = players end
      return original(self, command, data, players)
    end
    A.stampMoved(current, { { toArea = Player.Hand, to = current.players[1],
      moveInfo = { { cardId = card.id } } } })
    current.doBroadcastNotify = original
    hasMarks = A.hasDisplayMarks(card)
  end)
  lu.assertNotNil(recipients)
  lu.assertEquals(#recipients, 1)
  lu.assertEquals(recipients[1].id, current.players[1].id)
  lu.assertTrue(hasMarks)
end

function Testadaptation_display:testInitialHandHookStampsOnlyTheOwner()
  local current = room()
  local player = current.players[1]
  local card
  for _, candidate in ipairs(Fk.cards) do
    if (candidate.extra_data or {}).hanjin_slot and A.isAdaptationCard(candidate)
      and current:getCardArea(candidate.id) == Card.DrawPile then
      card = candidate
      break
    end
  end
  lu.assertNotNil(card)
  local recipients, hasMarks
  local original = current.doBroadcastNotify
  FkTest.runInRoom(function()
    current.doBroadcastNotify = function(self, command, data, players)
      if command == "SetCardMark" then recipients = players end
      return original(self, command, data, players)
    end
    current.logic:trigger(fk.AfterDrawInitialCards, player,
      DrawInitialData:new { cards = { card.id } })
    current.doBroadcastNotify = original
    hasMarks = A.hasDisplayMarks(card)
  end)
  lu.assertNotNil(recipients)
  lu.assertEquals(#recipients, 1)
  lu.assertEquals(recipients[1].id, player.id)
  lu.assertTrue(hasMarks)
end

function Testadaptation_display:testPublicMoveNotifiesAllPlayers()
  local current = room()
  local player = current.players[1]
  local card
  FkTest.runInRoom(function()
    card = current:printCard("hanjin_test__blank_basic", Card.Heart, 6)
    A.setCardEntries(card, { { condition = "gujun", effect = "damage" } })
  end)
  local seen, broadcastToAll, hasMarks
  local original = current.doBroadcastNotify
  FkTest.runInRoom(function()
    current.doBroadcastNotify = function(self, command, data, players)
      if command == "SetCardMark" then
        seen = true
        broadcastToAll = players == nil
      end
      return original(self, command, data, players)
    end
    A.stampMoved(current, { { toArea = Card.Processing, to = player,
      moveInfo = { { cardId = card.id } } } })
    current.doBroadcastNotify = original
    hasMarks = A.hasDisplayMarks(card)
  end)
  lu.assertTrue(seen)
  lu.assertTrue(broadcastToAll)
  lu.assertTrue(hasMarks)
end

function Testadaptation_display:testMountedCardTipUsesTheCurrentViewAsResult()
  local current = room()
  local display = mountedDisplay()
  local material = assert(bySlot(current, "standard1/S/10"))
  local materialTips = assert(A.cardTips(material))
  lu.assertEquals(materialTips[1].content, "残躯·目标+1")

  local virtual = Fk:cloneCard("hanjin_test__blank_basic")
  A.setCardEntries(virtual, { { condition = "gujun", effect = "damage" } })
  local resultTips = display:getCardTip(current.players[1], material.id, {}, {}, virtual, true, {})
  lu.assertEquals(#resultTips, 1)
  lu.assertEquals(resultTips[1].content, "孤军·伤害+1")

  -- The result card is authoritative even when it has no adaptation entry:
  -- the material's entries must not leak onto it.
  local bare = Fk:cloneCard("hanjin_test__blank_basic")
  lu.assertNil(display:getCardTip(current.players[1], material.id, {}, {}, bare, true, {}))

  -- With no result card, an ordinary physical card keeps its own tips.
  local ownTips = display:getCardTip(current.players[1], material.id, {}, {}, nil, true, {})
  lu.assertEquals(#ownTips, 1)
  lu.assertEquals(ownTips[1].content, "残躯·目标+1")
end

function Testadaptation_display:testRealClientCardTipPathUsesTheResultCard()
  local current = room()
  local material = assert(bySlot(current, "standard1/S/10"))
  local virtual = Fk:cloneCard("hanjin_test__blank_basic")
  A.setCardEntries(virtual, { { condition = "gujun", effect = "damage" } })
  local bare = Fk:cloneCard("hanjin_test__blank_basic")
  local ClientUtil = require "ltk.client.util"
  local handlerClass = ClientInstance.request_handlers["AskForUseActiveSkill"]
  local oldHandler = ClientInstance.current_request_handler

  local function request(selectedCard)
    local handler = {
      pendings = {}, selected_targets = {}, selected_card = selectedCard,
      skill_name = nil, extra_data = {},
      scene = { items = { CardItem = { [material.id] = { enabled = true } } } },
    }
    function handler:isInstanceOf(class) return class == handlerClass end
    ClientInstance.current_request_handler = handler
    local ok, tips = pcall(function() return ClientUtil:getCardTip(material.id) end)
    ClientInstance.current_request_handler = oldHandler
    assert(ok, tips)
    return tips
  end

  local virtualTips = request(virtual)
  lu.assertEquals(#table.filter(virtualTips, function(tip) return tip.content == "孤军·伤害+1" end), 1)

  local bareTips = request(bare)
  lu.assertEquals(#table.filter(bareTips, function(tip) return tip.content == "残躯·目标+1" end), 0)

  local physicalTips = request(material)
  lu.assertEquals(#table.filter(physicalTips, function(tip) return tip.content == "残躯·目标+1" end), 1)
end

function Testadaptation_display:testEveryConditionNamesItsOwnTrigger()
  local current = room()
  local from, helper = current.players[1], current.players[3]
  local function run(condition, prepare)
    local data = use { { condition = condition, effect = "damage" } }
    local specific
    FkTest.runInRoom(function()
      if prepare then prepare(data) end
      specific = captureSpecific(function()
        A.prepare(current, data)
        A.resolve(current, data)
      end)
    end)
    lu.assertEquals(#specific, 1, condition)
    lu.assertEquals(specific[1].arg, "hanjin_condition_" .. condition)
    return data
  end

  run("fujia", function() clearHands(current, from) end)
  run("canqu", function() from.hp = 1 end)
  run("kongchao", function()
    local ids = from:getCardIds("h")
    if #ids > 0 then current:throwCard(ids, "test", from, from) end
  end)
  run("gujun", function()
    from.kingdom = "han"
    from.role = "han"
    for index = 2, #current.players do
      current.players[index].kingdom = "shu"
      current.players[index].role = "shu"
    end
  end)
  run("zhuzhan", function()
    local id = giveType(current, helper, Card.TypeBasic)
    FkTest.setNextReplies(helper, { FkTest.ReplyDiscard({ id }) })
  end)
end

function Testadaptation_display:testMultipleEntriesShowInResolutionOrder()
  local current = room()
  local from = current.players[1]
  from.hp = 1
  local data = use {
    { condition = "canqu", effect = "damage" },
    { condition = "kongchao", effect = "damage" },
  }
  local specific
  FkTest.runInRoom(function()
    local ids = from:getCardIds("h")
    if #ids > 0 then current:throwCard(ids, "test", from, from) end
    specific = captureSpecific(function()
      A.prepare(current, data)
      A.resolve(current, data)
    end)
  end)
  lu.assertEquals(table.map(specific, function(log) return log.arg end), {
    "hanjin_condition_canqu", "hanjin_condition_kongchao",
  })
end

function Testadaptation_display:testReentrantResolutionShowsEachSuccessfulEntryOnce()
  local current = room()
  local from = current.players[1]
  from.hp = 1
  local data = use {
    { condition = "canqu", effect = "damage" },
    { condition = "canqu", effect = "damage" },
  }
  local skel = fk.CreateSkill { name = "#hanjin_test_adaptation_display_reentrant" }
  skel:addEffect(A.Triggered, {
    global = true,
    can_refresh = function(self, event, target, player) return target == player end,
    on_refresh = function(self, event, target, player, result)
      A.resolve(current, result.use)
    end,
  })
  local specific
  FkTest.runInRoom(function()
    current:addSkill(skel:createSkill())
    specific = captureSpecific(function()
      A.prepare(current, data)
      A.resolve(current, data)
    end)
  end)
  lu.assertEquals(#specific, 2)
  lu.assertEquals(A.getResult(data).triggered_count, 2)
end

function Testadaptation_display:testFailedOrCancelledEntriesShowNoTrigger()
  local current = room()
  local from = current.players[1]
  local declined = use { { condition = "fujia", effect = "remove_target" } }
  local original = current.askToChoosePlayers
  local specific
  FkTest.runInRoom(function()
    clearHands(current, from)
    current.askToChoosePlayers = function() return {} end
    specific = captureSpecific(function()
      A.prepare(current, declined)
      A.resolve(current, declined)
    end)
  end)
  current.askToChoosePlayers = original
  lu.assertEquals(#specific, 0)
  lu.assertFalse(A.getResult(declined).triggered)

  local impossible = use { { condition = "canqu", effect = "damage" } }
  from.hp = 4
  FkTest.runInRoom(function()
    specific = captureSpecific(function()
      A.prepare(current, impossible)
      A.resolve(current, impossible)
    end)
  end)
  lu.assertEquals(#specific, 0)
  lu.assertFalse(A.getResult(impossible).triggered)

  local unsupported = use { { condition = "zhuzhan", effect = "damage" } }
  FkTest.runInRoom(function()
    specific = captureSpecific(function()
      A.prepare(current, unsupported)
      A.resolve(current, unsupported)
    end)
  end)
  lu.assertEquals(#specific, 0)
  lu.assertFalse(A.getResult(unsupported).triggered)
end

function Testadaptation_display:testIgnoreTokenKeepsTheOriginalConditionName()
  local current = room()
  local from = current.players[1]
  from.hp = 4
  local data = use { { condition = "canqu", effect = "damage" } }
  A.grantIgnore(data, "test_source")
  local specific
  FkTest.runInRoom(function()
    specific = captureSpecific(function()
      A.prepare(current, data)
      A.resolve(current, data)
    end)
  end)
  lu.assertEquals(#specific, 1)
  lu.assertEquals(specific[1].arg, "hanjin_condition_canqu")
  lu.assertEquals(A.getResult(data).entries[1].ignored_by, "test_source")
end

function Testadaptation_display:testUseOnlyAddedEntryNamesItsCondition()
  local current = room()
  local from = current.players[1]
  from.hp = 1
  local data = use(nil)
  A.addEntry(data, { condition = "canqu", effect = "damage" })
  local specific
  FkTest.runInRoom(function()
    specific = captureSpecific(function()
      A.prepare(current, data)
      A.resolve(current, data)
    end)
  end)
  lu.assertEquals(#specific, 1)
  lu.assertEquals(specific[1].arg, "hanjin_condition_canqu")
  lu.assertTrue(A.getResult(data).triggered)
end

local function physical(suit, number)
  return assert(table.find(Fk.cards, function(card)
    return card.name == "hanjin__thunder__slash" and card.suit == suit and card.number == number
  end))
end

local function give(current, player, card)
  if not table.contains(player:getCardIds("h"), card.id) then
    current:obtainCard(player, card.id, true, fk.ReasonJustMove, player, "test")
  end
  return card
end

local function realUse(kingdom)
  local current = room()
  local from, target = current.players[1], current.players[2]
  local card = physical(Card.Spade, 9)
  from.phase = Player.Play
  from.kingdom = kingdom
  from.role = kingdom
  from.hp = 4
  from.cardUsedHistory["slash"] = { 0, 0, 0, 0 }
  for index = 2, #current.players do
    current.players[index].kingdom = "wei"
    current.players[index].role = "wei"
  end
  local data = UseCardData:new { from = from, tos = { target }, card = card, extra_data = {} }
  FkTest.setNextReplies(target, { "" })
  local specific, logs
  FkTest.runInRoom(function()
    give(current, from, card)
    specific, logs = captureSpecific(function() current:useCard(data) end)
  end)
  return data, specific, logs
end

function Testadaptation_display:testRealUseShowsOneConcreteConditionAndNoGenericText()
  local data, specific, logs = realUse("han")
  lu.assertEquals(#specific, 1)
  lu.assertEquals(specific[1].arg, "hanjin_condition_gujun")
  lu.assertEquals(#table.filter(logs, function(log)
    return log.type:startsWith("#InvokeSkill")
  end), 1)
  lu.assertTrue(A.getResult(data).triggered)
end

function Testadaptation_display:testPreparedUseWithoutSuccessShowsNoTriggerText()
  local data, specific, logs = realUse("unknown")
  lu.assertEquals(#specific, 0)
  lu.assertEquals(#table.filter(logs, function(log)
    return log.type:startsWith("#InvokeSkill")
  end), 0)
  lu.assertFalse(A.getResult(data).triggered)
end

return { name = "adaptation_display" }
