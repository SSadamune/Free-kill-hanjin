local support = __dofile("../../../tests/support/hegemony.lua")
local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
Testhanjin_adaptation = { setup = support.initHanjinRoom, tearDown = support.clearRoom }

local function use(entries)
  local room = FkTest.room
  local card = Fk:cloneCard("hanjin_test__blank_basic")
  A.setCardEntries(card, entries)
  return UseCardData:new { from = room.players[1], tos = { room.players[2] }, card = card, extra_data = {} }
end

function Testhanjin_adaptation:testVirtualCardWithExplicitConditionsIsAnAdaptationCard()
  local data = use({ { condition = "zhuzhan", effect = "execute_both" } })
  lu.assertTrue(data.card:isVirtual())
  lu.assertTrue(A.isAdaptationCard(data.card, data))
  lu.assertFalse(A.isAdaptationCard(Fk:cloneCard("hanjin_test__blank_basic")))
end

function Testhanjin_adaptation:testRichIncludesTiesAndCanquRequiresExactlyOneHp()
  local data = use({})
  lu.assertTrue(A.snapshot(FkTest.room, data).fujia)
  data.from.hp = 1
  lu.assertTrue(A.snapshot(FkTest.room, data).canqu)
  data.from.hp = 2
  lu.assertFalse(A.snapshot(FkTest.room, data).canqu)
end

function Testhanjin_adaptation:testGujunRequiresKnownKingdomAndNoOtherLivingMember()
  local data = use({})
  lu.assertFalse(A.snapshot(FkTest.room, data).gujun)
  data.from.kingdom = "han"
  lu.assertTrue(A.snapshot(FkTest.room, data).gujun)
  FkTest.room.players[3].kingdom = "han"
  lu.assertFalse(A.snapshot(FkTest.room, data).gujun)
end

function Testhanjin_adaptation:testSatisfiedNonTargetEffectsAreForcedAndIndependent()
  local data = use({ {condition="fujia",effect="damage"}, {condition="canqu",effect="damage"} })
  data.from.hp = 1
  FkTest.runInRoom(function() A.prepare(FkTest.room, data); A.resolve(FkTest.room, data) end)
  lu.assertEquals(data.additionalDamage, 2)
  lu.assertEquals(A.getResult(data).triggered_count, 2)
end

function Testhanjin_adaptation:testSingleIgnoreCannotEnableTwoFailedConditions()
  local data = use({ {id="one",condition="canqu",effect="damage"}, {id="two",condition="kongchao",effect="damage"} })
  A.grantIgnore(data, "test_source", "one")
  FkTest.runInRoom(function() A.prepare(FkTest.room, data); A.resolve(FkTest.room, data) end)
  lu.assertEquals(data.additionalDamage, 1)
  lu.assertEquals(A.getResult(data).triggered_count, 1)
end

function Testhanjin_adaptation:testTwoIgnoreSourcesCanEnableTwoEntries()
  local data = use({ {id="one",condition="canqu",effect="damage"}, {id="two",condition="kongchao",effect="damage"} })
  A.grantIgnore(data, "first_source", "one")
  A.grantIgnore(data, "second_source", "two")
  FkTest.runInRoom(function() A.prepare(FkTest.room, data); A.resolve(FkTest.room, data) end)
  lu.assertEquals(data.additionalDamage, 2)
end

function Testhanjin_adaptation:testUnspecifiedIgnoreMakesExactlyOneSelection()
  local room = FkTest.room
  local data = use({ {condition="canqu",effect="damage"}, {condition="kongchao",effect="damage"} })
  A.grantIgnore(data, "test_source")
  local asked = 0
  local original = room.askToChoice
  room.askToChoice = function(self, player, params)
    asked = asked + 1
    lu.assertEquals(#params.choices, 2)
    lu.assertFalse(params.cancelable)
    return params.choices[2]
  end
  FkTest.runInRoom(function() A.prepare(room, data); A.resolve(room, data) end)
  room.askToChoice = original
  lu.assertEquals(asked, 1)
  lu.assertEquals(data.additionalDamage, 1)
  lu.assertFalse(A.getResult(data).entries[1].triggered)
  lu.assertTrue(A.getResult(data).entries[2].triggered)
end

function Testhanjin_adaptation:testIgnoresDoNotLeakToAnotherUseOfTheSameCard()
  local room = FkTest.room
  local first = use({ {condition="canqu",effect="damage"} })
  A.grantIgnore(first, "only_this_use")
  local second = UseCardData:new { from = first.from, tos = first.tos, card = first.card, extra_data = {} }
  FkTest.runInRoom(function()
    A.prepare(room, first); A.resolve(room, first)
    A.prepare(room, second); A.resolve(room, second)
  end)
  lu.assertEquals(first.additionalDamage, 1)
  lu.assertNil(second.additionalDamage)
  lu.assertFalse(A.getResult(second).triggered)
end

function Testhanjin_adaptation:testDeclinedTargetChangeIsNotTriggered()
  local room = FkTest.room
  local data = use({ {condition="fujia",effect="remove_target"} })
  local events = 0
  local skel = fk.CreateSkill { name = "#hanjin_test_adaptation_observer" }
  skel:addEffect(A.Triggered, {
    global = true, can_refresh = function(self, event, target, player) return target == player end,
    on_refresh = function() events = events + 1 end,
  })
  local original = room.askToChoosePlayers
  room.askToChoosePlayers = function() return {} end
  FkTest.runInRoom(function() room:addSkill(skel:createSkill()); A.prepare(room, data); A.resolve(room, data) end)
  room.askToChoosePlayers = original
  lu.assertFalse(A.getResult(data).triggered)
  lu.assertEquals(events, 0)
  lu.assertEquals(#data.tos, 1)
end

function Testhanjin_adaptation:testAcceptedTargetChangeTriggersExactlyOnce()
  local room = FkTest.room
  local data = use({ {condition="fujia",effect="remove_target"} })
  local events = 0
  local skel = fk.CreateSkill { name = "#hanjin_test_adaptation_accepted_observer" }
  skel:addEffect(A.Triggered, {
    global = true, can_refresh = function(self, event, target, player) return target == player end,
    on_refresh = function() events = events + 1 end,
  })
  local original = room.askToChoosePlayers
  room.askToChoosePlayers = function() return {data.tos[1]} end
  FkTest.runInRoom(function()
    room:addSkill(skel:createSkill())
    A.prepare(room, data); A.resolve(room, data); A.resolve(room, data)
  end)
  room.askToChoosePlayers = original
  lu.assertEquals(A.getResult(data).triggered_count, 1)
  lu.assertEquals(events, 1)
  lu.assertEquals(#data.tos, 0)
end

function Testhanjin_adaptation:testMultipleConditionsUseTheSameUsageSnapshot()
  local room = FkTest.room
  local data = use({ {condition="kongchao",effect="draw"}, {condition="kongchao",effect="damage"} })
  FkTest.runInRoom(function()
    room:throwCard(data.from:getCardIds("h"), "test", data.from, data.from)
    A.prepare(room, data); A.resolve(room, data)
  end)
  lu.assertEquals(data.from:getHandcardNum(), 1)
  lu.assertEquals(data.additionalDamage, 1)
  lu.assertEquals(A.getResult(data).triggered_count, 2)
end

local function giveType(room, player, cardType)
  local id = assert(table.find(room.draw_pile, function(id) return Fk:getCardById(id).type == cardType end))
  room:obtainCard(player, id, true, fk.ReasonJustMove, player, "test")
  return id
end

function Testhanjin_adaptation:testSupportAsksSimultaneouslyAndOnlyOneHelperDiscards()
  local room = FkTest.room
  local data = use({ {condition="zhuzhan",effect="execute_both"} })
  local first, second = room.players[3], room.players[4]
  local a, b
  FkTest.runInRoom(function()
    a = giveType(room, first, Card.TypeBasic)
    b = giveType(room, second, Card.TypeBasic)
    FkTest.setNextReplies(first, { FkTest.ReplyDiscard({a}) })
    FkTest.setNextReplies(second, { FkTest.ReplyDiscard({b}) })
    A.prepare(room, data); A.resolve(room, data)
  end)
  local request = room.last_request
  lu.assertEquals(request.n, 1)
  lu.assertEquals(#request.winners, 1)
  lu.assertFalse(table.contains(request.players, data.from))
  lu.assertFalse(table.contains(request.players, data.tos[1]))
  local discarded = (not table.contains(first:getCardIds("h"), a) and 1 or 0)
    + (not table.contains(second:getCardIds("h"), b) and 1 or 0)
  lu.assertEquals(discarded, 1)
  lu.assertTrue(A.hasEffect(data, "execute_both"))
  lu.assertNil(data.additionalEffect) -- Both options does not mean repeat the card.
end

function Testhanjin_adaptation:testInvalidSupportReplyCannotWinTheRace()
  local room = FkTest.room
  local data = use({ {condition="zhuzhan",effect="damage"} })
  local helper, invalid = room.players[3], room.players[8]
  local id
  FkTest.runInRoom(function()
    id = giveType(room, helper, Card.TypeBasic)
    giveType(room, invalid, Card.TypeBasic)
    FkTest.setNextReplies(helper, { FkTest.ReplyDiscard({id}) })
    FkTest.setNextReplies(invalid, { FkTest.ReplyDiscard({9999999}) })
    A.prepare(room, data); A.resolve(room, data)
  end)
  lu.assertEquals(room.last_request.winners[1].id, helper.id)
  lu.assertEquals(data.additionalDamage, 1)
end

function Testhanjin_adaptation:testNoSupportMeansNoEffect()
  local data = use({ {condition="zhuzhan",effect="damage"} })
  FkTest.runInRoom(function() A.prepare(FkTest.room, data); A.resolve(FkTest.room, data) end)
  lu.assertNil(data.additionalDamage)
  lu.assertFalse(A.getResult(data).triggered)
end

function Testhanjin_adaptation:testEachSupportEntryRequiresItsOwnDiscard()
  local room = FkTest.room
  local data = use({ {condition="zhuzhan",effect="damage"}, {condition="zhuzhan",effect="damage"} })
  local helper = room.players[3]
  local a, b
  FkTest.runInRoom(function()
    a = giveType(room, helper, Card.TypeBasic)
    b = giveType(room, helper, Card.TypeBasic)
    FkTest.setNextReplies(helper, { FkTest.ReplyDiscard({a}), FkTest.ReplyDiscard({b}) })
    A.prepare(room, data); A.resolve(room, data)
  end)
  lu.assertEquals(data.additionalDamage, 2)
  lu.assertFalse(table.contains(helper:getCardIds("h"), a))
  lu.assertFalse(table.contains(helper:getCardIds("h"), b))
end

function Testhanjin_adaptation:testIgnoringSupportDoesNotAskOrChargeAHelper()
  local room = FkTest.room
  local data = use({ {id="support",condition="zhuzhan",effect="damage"} })
  A.grantIgnore(data, "test_source", "support")
  local previousRequest = room.last_request
  FkTest.runInRoom(function() A.prepare(room, data); A.resolve(room, data) end)
  lu.assertTrue(room.last_request == previousRequest)
  lu.assertEquals(data.additionalDamage, 1)
end

function Testhanjin_adaptation:testDecliningTargetDoesNotSuppressAnotherMandatoryEntry()
  local room = FkTest.room
  local data = use({ {condition="fujia",effect="remove_target"}, {condition="fujia",effect="damage"} })
  local original = room.askToChoosePlayers
  room.askToChoosePlayers = function() return {} end
  FkTest.runInRoom(function() A.prepare(room, data); A.resolve(room, data) end)
  room.askToChoosePlayers = original
  lu.assertEquals(data.additionalDamage, 1)
  lu.assertEquals(A.getResult(data).triggered_count, 1)
end

function Testhanjin_adaptation:testAConditionOnMaterialDoesNotImplicitlyTransferToAViewAsCard()
  local room = FkTest.room
  local material, virtual
  FkTest.runInRoom(function()
    material = room:printCard("hanjin_test__blank_basic", Card.Heart, 5)
    A.setCardEntries(material, {{condition="fujia",effect="damage"}})
    virtual = Fk:cloneCard("hanjin_test__blank_basic")
    virtual:addSubcard(material.id)
  end)
  lu.assertTrue(A.isAdaptationCard(material))
  lu.assertFalse(A.isAdaptationCard(virtual))
end

function Testhanjin_adaptation:testUseOnlyEntriesAreRecognizedWithoutChangingTheCard()
  local data = use({})
  A.addEntry(data, {condition="fujia",effect="damage"})
  lu.assertTrue(A.isAdaptationCard(data.card, data))
  lu.assertFalse(A.isAdaptationCard(data.card))
  FkTest.runInRoom(function() A.prepare(FkTest.room, data); A.resolve(FkTest.room, data) end)
  lu.assertEquals(data.additionalDamage, 1)
end

function Testhanjin_adaptation:testActualCardUseDetectsLastHandcardAfterItLeavesHand()
  local room = FkTest.room
  local data = use({ {condition="kongchao",effect="draw"} })
  FkTest.runInRoom(function()
    local ids = data.from:getCardIds("h")
    local material = table.remove(ids, 1)
    room:throwCard(ids, "test", data.from, data.from)
    data.card:addSubcard(material)
    room:useCard(data)
  end)
  lu.assertEquals(A.getResult(data).triggered_count, 1)
  lu.assertEquals(data.from:getHandcardNum(), 1)
end

function Testhanjin_adaptation:testRespondingWithoutUsingDoesNotTriggerAdaptation()
  local room = FkTest.room
  local data = use({ {condition="fujia",effect="draw"} })
  local count = data.from:getHandcardNum()
  FkTest.runInRoom(function() room:responseCard({ from = data.from, card = data.card }) end)
  lu.assertEquals(data.from:getHandcardNum(), count)
  lu.assertNil(A.getResult(data))
end

return { name = "hanjin_adaptation" }
