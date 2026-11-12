local support = __dofile("../../../tests/support/hegemony.lua")
local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
local CardData = require "packages.hanjin.pkg.hanjin_cards.data.cards"
Testhanjin_card_reuse = { setup = support.initHanjinRoom, tearDown = support.clearRoom }

local function card(name, suit, number)
  return assert(table.find(Fk.cards, function(c)
    return c.name == name and (suit == nil or c.suit == suit)
      and (number == nil or c.number == number)
  end), "missing " .. name)
end

local function give(room, player, c)
  if not table.contains(player:getCardIds("h"), c.id) then
    room:obtainCard(player, c.id, true, fk.ReasonJustMove, player, "test")
  end
  return c
end

local function use(room, from, tos, c, extra)
  local data = UseCardData:new { from = from, tos = tos or {}, card = c, extra_data = extra or {} }
  room:useCard(data)
  return data
end

local function clearAllAreas(room)
  for _, player in ipairs(room.players) do
    local ids = player:getCardIds("he")
    if #ids > 0 then room:throwCard(ids, "test", player, player) end
  end
end

local function setSingleKingdom(room, player)
  for _, other in ipairs(room.players) do
    other.kingdom = other == player and "han" or "wei"
    other.role = other.kingdom
  end
end

local function observeAdaptationUse(room, cardName, skillName)
  local seen = {}
  local skel = fk.CreateSkill { name = skillName }
  skel:addEffect(A.Triggered, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == player and data.use.card.name == cardName
    end,
    on_refresh = function(self, event, target, player, data)
      table.insert(seen, data)
    end,
  })
  room:addSkill(skel:createSkill())
  return seen
end

function Testhanjin_card_reuse:testSlashDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__slash")
  local hp = t.hp
  FkTest.runInRoom(function()
    give(room, p, c)
    FkTest.setNextReplies(t, { "" })
    use(room, p, { t }, c)
  end)
  lu.assertEquals(t.hp, hp - 1)
end

function Testhanjin_card_reuse:testJinkResponse()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local slash, jink = card("hanjin__slash"), card("hanjin__jink")
  local hp = t.hp
  lu.assertEquals(jink.skill.name, "jink_skill")
  FkTest.runInRoom(function()
    give(room, p, slash)
    give(room, t, jink)
    FkTest.setNextReplies(t, { { card = jink.id } })
    room:useVirtualCard("hanjin__slash", nil, p, t)
  end)
  lu.assertEquals(t.hp, hp)
end

function Testhanjin_card_reuse:testPeachHeal()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__peach")
  FkTest.runInRoom(function()
    p.hp = p.maxHp - 1
    give(room, p, c)
    use(room, p, { p }, c)
  end)
  lu.assertEquals(p.hp, p.maxHp)
end

function Testhanjin_card_reuse:testDismantlement()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__dismantlement")
  local targetCard = card("hanjin__slash", Card.Heart, 10)
  FkTest.runInRoom(function()
    give(room, p, c)
    give(room, t, targetCard)
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    local original = room.askToChooseCard
    room.askToChooseCard = function() return targetCard.id end
    use(room, p, { t }, c)
    room.askToChooseCard = original
  end)
  lu.assertFalse(table.contains(t:getCardIds("h"), targetCard.id))
end

function Testhanjin_card_reuse:testAxeEquipSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__axe")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
  end)
  lu.assertTrue(table.contains(p:getEquipments(), c.id))
  lu.assertTrue(p:hasSkill("hanjin__axe_skill"))
end

function Testhanjin_card_reuse:testIceSlashDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__ice__slash")
  local hp = t.hp
  local dtype
  local skel = fk.CreateSkill { name = "#hanjin_probe_ice_damage" }
  skel:addEffect(fk.DamageInflicted, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == player and data.card and data.card.name == "hanjin__ice__slash"
    end,
    on_refresh = function(self, event, target, player, data) dtype = data.damageType end,
  })
  FkTest.runInRoom(function() room:addSkill(skel:createSkill()) end)
  FkTest.runInRoom(function()
    give(room, p, c)
    FkTest.setNextReplies(t, { "" })
    use(room, p, { t }, c)
  end)
  lu.assertEquals(t.hp, hp - 1)
  lu.assertEquals(dtype, fk.IceDamage)
end

function Testhanjin_card_reuse:testChasingNearExecuteBoth()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local physical = card("hanjin__chasing_near")
  local c = Fk:cloneCard("hanjin__chasing_near")
  c:addSubcard(physical.id)
  local first = card("hanjin__slash", Card.Club, 2)
  local second = card("hanjin__slash", Card.Club, 3)
  A.setCardEntries(c, { { id = "probe_both", condition = "kongchao", effect = "execute_both" } })
  local data
  FkTest.runInRoom(function()
    for _, id in ipairs(p:getCardIds("h")) do room:throwCard(id, "test", p, p) end
    give(room, p, physical)
    give(room, t, first)
    give(room, t, second)
    local answers = { first.id, second.id }
    local original = room.askToChooseCard
    room.askToChooseCard = function(self, player, params)
      return table.remove(answers, 1)
    end
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    data = UseCardData:new { from = p, tos = { t }, card = c, extra_data = {} }
    room:useCard(data)
    room.askToChooseCard = original
  end)
  lu.assertFalse(table.contains(t:getCardIds("hej"), first.id))
  lu.assertTrue(table.contains(p:getCardIds("h"), second.id))
  lu.assertTrue(A.hasEffect(data, "execute_both"))
end

function Testhanjin_card_reuse:testForesightViewsAndRearrangesBeforeDrawingBothCards()
  local room = FkTest.room
  local player = room.players[1]
  local c = card("hanjin__foresight")
  local top1, top2, top3
  local order = {}
  local handAfter, bottom
  FkTest.runInRoom(function()
    clearAllAreas(room)
    give(room, player, c)
    top1, top2, top3 = room.draw_pile[1], room.draw_pile[2], room.draw_pile[3]
    lu.assertNotNil(top1)
    lu.assertNotNil(top2)
    lu.assertNotNil(top3)
    local originalGuanxing, originalDraw = room.askToGuanxing, room.drawCards
    room.askToGuanxing = function(self, who, params)
      table.insert(order, "guanxing")
      lu.assertEquals(who.id, player.id)
      lu.assertEquals(params.cards, { top1, top2 })
      local result = originalGuanxing(self, who, params)
      table.insert(order, "arranged")
      return result
    end
    room.drawCards = function(self, who, num, ...)
      table.insert(order, "draw")
      lu.assertEquals(who.id, player.id)
      lu.assertEquals(num, 2)
      return originalDraw(self, who, num, ...)
    end
    -- One real guanxing request: put the first card back on top and the second
    -- on the bottom, then let the card's own draw take the next two cards.
    FkTest.setNextReplies(player, { { { top1 }, { top2 } } })
    room:useCard(UseCardData:new { from = player, tos = { player }, card = c, extra_data = {} })
    room.askToGuanxing = originalGuanxing
    room.drawCards = originalDraw
    handAfter = player:getCardIds("h")
    bottom = room.draw_pile[#room.draw_pile]
  end)
  lu.assertEquals(order, { "guanxing", "arranged", "draw" })
  lu.assertEquals(#handAfter, 2)
  lu.assertTrue(table.contains(handAfter, top1))
  lu.assertTrue(table.contains(handAfter, top3))
  lu.assertFalse(table.contains(handAfter, top2))
  lu.assertEquals(bottom, top2)
  lu.assertFalse(A.isAdaptationCard(c))
end

function Testhanjin_card_reuse:testChasingNearRealSupportAtDistanceOneDiscardsThenHasNothingToObtain()
  local room = FkTest.room
  local p, t, helper = room.players[1], room.players[2], room.players[3]
  local c = card("hanjin__chasing_near")
  local targetCard = card("hanjin__peach", Card.Heart, 4)
  local supportCard = card("hanjin__dismantlement")
  lu.assertEquals(A.getEntries(c)[1].condition, "zhuzhan")
  local data, chooseCalls
  local targetThrows, targetObtains = {}, {}
  FkTest.runInRoom(function()
    clearAllAreas(room)
    give(room, p, c)
    give(room, helper, supportCard)
    give(room, t, targetCard)
    lu.assertEquals(#t:getCardIds("hej"), 1)
    lu.assertEquals(p:distanceTo(t), 1)
    FkTest.setNextReplies(helper, { FkTest.ReplyDiscard({ supportCard.id }) })
    local originalChoose = room.askToChooseCard
    chooseCalls = 0
    room.askToChooseCard = function(self, player, params)
      chooseCalls = chooseCalls + 1
      lu.assertIsTrue(player == p)
      lu.assertIsTrue(params.target == t)
      return targetCard.id
    end
    local originalThrow, originalObtain = room.throwCard, room.obtainCard
    room.throwCard = function(self, ids, ...)
      local list = type(ids) == "table" and ids or { ids }
      if table.contains(list, targetCard.id) then table.insert(targetThrows, table.clone(list)) end
      return originalThrow(self, ids, ...)
    end
    room.obtainCard = function(self, receiver, ids, ...)
      local list = type(ids) == "table" and ids or { ids }
      if table.contains(list, targetCard.id) then table.insert(targetObtains, table.clone(list)) end
      return originalObtain(self, receiver, ids, ...)
    end
    data = UseCardData:new { from = p, tos = { t }, card = c, extra_data = {} }
    room:useCard(data)
    room.askToChooseCard = originalChoose
    room.throwCard = originalThrow
    room.obtainCard = originalObtain
  end)
  lu.assertEquals(chooseCalls, 1)
  lu.assertEquals(#targetThrows, 1)
  lu.assertEquals(#targetObtains, 0)
  lu.assertEquals(#t:getCardIds("hej"), 0)
  lu.assertFalse(table.contains(p:getCardIds("h"), targetCard.id))
  lu.assertEquals(room:getCardArea(targetCard.id), Card.DiscardPile)
  lu.assertTrue(A.getResult(data).triggered)
  lu.assertEquals(A.getResult(data).effects.execute_both, 1)
  local record = A.getResult(data).entries[1]
  lu.assertEquals(record.condition, "zhuzhan")
  lu.assertTrue(record.satisfied)
  lu.assertNotNil(record.support)
  lu.assertEquals(record.support.player, helper.id)
  lu.assertEquals(record.support.card, supportCard.id)
end

function Testhanjin_card_reuse:testChasingNearRealSupportWithOnlyOneEquipmentDiscardsItToo()
  local room = FkTest.room
  local p, t, helper = room.players[1], room.players[2], room.players[3]
  local c = card("hanjin__chasing_near")
  local targetCard = card("hanjin__axe")
  local supportCard = card("hanjin__dismantlement")
  local data, chooseCalls
  local targetThrows, targetObtains = {}, {}
  FkTest.runInRoom(function()
    clearAllAreas(room)
    give(room, p, c)
    give(room, helper, supportCard)
    give(room, t, targetCard)
    room:moveCardTo({ targetCard.id }, Card.PlayerEquip, t, fk.ReasonPut, "test", nil, true, t)
    lu.assertEquals(#t:getCardIds("hej"), 1)
    lu.assertEquals(p:distanceTo(t), 1)
    FkTest.setNextReplies(helper, { FkTest.ReplyDiscard({ supportCard.id }) })
    local originalChoose = room.askToChooseCard
    chooseCalls = 0
    room.askToChooseCard = function(self, player, params)
      chooseCalls = chooseCalls + 1
      lu.assertIsTrue(player == p)
      lu.assertIsTrue(params.target == t)
      return targetCard.id
    end
    local originalThrow, originalObtain = room.throwCard, room.obtainCard
    room.throwCard = function(self, ids, ...)
      local list = type(ids) == "table" and ids or { ids }
      if table.contains(list, targetCard.id) then table.insert(targetThrows, table.clone(list)) end
      return originalThrow(self, ids, ...)
    end
    room.obtainCard = function(self, receiver, ids, ...)
      local list = type(ids) == "table" and ids or { ids }
      if table.contains(list, targetCard.id) then table.insert(targetObtains, table.clone(list)) end
      return originalObtain(self, receiver, ids, ...)
    end
    data = UseCardData:new { from = p, tos = { t }, card = c, extra_data = {} }
    room:useCard(data)
    room.askToChooseCard = originalChoose
    room.throwCard = originalThrow
    room.obtainCard = originalObtain
  end)
  lu.assertEquals(chooseCalls, 1)
  lu.assertEquals(#targetThrows, 1)
  lu.assertEquals(#targetObtains, 0)
  lu.assertEquals(#t:getCardIds("hej"), 0)
  lu.assertEquals(room:getCardArea(targetCard.id), Card.DiscardPile)
  lu.assertTrue(A.getResult(data).triggered)
  lu.assertEquals(A.getResult(data).effects.execute_both, 1)
  lu.assertEquals(A.getResult(data).entries[1].support.player, helper.id)
end

function Testhanjin_card_reuse:testJinkActualUseObtainsTheRespondedCardNotItself()
  local room = FkTest.room
  local attacker, target, jink, slash, seen
  FkTest.runInRoom(function()
    clearAllAreas(room)
    attacker, target = room.players[1], room.players[2]
    setSingleKingdom(room, target)
    jink = give(room, target, card("hanjin__jink", Card.Heart, 7))
    slash = give(room, attacker, card("hanjin__slash"))
    lu.assertTrue(A.isAdaptationCard(jink))
    seen = observeAdaptationUse(room, "hanjin__jink", "#hanjin_test_jink_actual_use")
    FkTest.setNextReplies(target, { { card = jink.id } })
    for _, q in ipairs(room.players) do
      if q ~= target then FkTest.setNextReplies(q, { "" }) end
    end
    room:useCard(UseCardData:new { from = attacker, tos = { target }, card = slash, extra_data = {} })
  end)
  lu.assertEquals(#seen, 1)
  local use = seen[1].use
  lu.assertEquals(seen[1].entry.condition, "gujun")
  lu.assertEquals(seen[1].entry.effect, "obtain_response_card")
  lu.assertNotNil(use.responseToEvent)
  lu.assertIsTrue(use.toCard == slash)
  lu.assertTrue(table.contains(target:getCardIds("h"), slash.id))
  lu.assertFalse(table.contains(target:getCardIds("h"), jink.id))
  lu.assertEquals(room:getCardOwner(slash.id).id, target.id)
  lu.assertEquals(room:getCardArea(slash.id), Card.PlayerHand)
  lu.assertEquals(room:getCardArea(jink.id), Card.DiscardPile)
  lu.assertEquals(target.hp, target.maxHp)
  local result = A.getResult(use)
  lu.assertEquals(result.triggered_count, 1)
  lu.assertEquals(result.effects.obtain_response_card, 1)
  lu.assertTrue(A.isAdaptationCard(jink))
end

function Testhanjin_card_reuse:testJinkPlayedAsResponseDoesNotTriggerAdaptation()
  local room = FkTest.room
  local target, jink, seen
  FkTest.runInRoom(function()
    clearAllAreas(room)
    local attacker = room.players[1]
    target = room.players[2]
    setSingleKingdom(room, target)
    jink = give(room, target, card("hanjin__jink", Card.Heart, 7))
    local archery = give(room, attacker, card("hanjin__archery_attack"))
    lu.assertTrue(A.isAdaptationCard(jink))
    seen = observeAdaptationUse(room, "hanjin__jink", "#hanjin_test_jink_pure_response")
    FkTest.setNextReplies(target, { { card = jink.id } })
    for index = 3, #room.players do FkTest.setNextReplies(room.players[index], { "" }) end
    local tos = table.slice(room.players, 2)
    room:useCard(UseCardData:new { from = attacker, tos = tos, card = archery, extra_data = {} })
  end)
  lu.assertEquals(#seen, 0)
  lu.assertEquals(room:getCardArea(jink.id), Card.DiscardPile)
  lu.assertEquals(#target:getCardIds("h"), 0)
  lu.assertEquals(target.hp, target.maxHp)
  lu.assertTrue(A.isAdaptationCard(jink))
end

function Testhanjin_card_reuse:testJinkObtainsAllMaterialsOfAVirtualRespondedCard()
  local room = FkTest.room
  local target, jink, first, second, seen
  FkTest.runInRoom(function()
    clearAllAreas(room)
    local attacker = room.players[1]
    target = room.players[2]
    setSingleKingdom(room, target)
    first = give(room, attacker, card("hanjin__slash"))
    second = give(room, attacker, card("hanjin__peach"))
    jink = give(room, target, card("hanjin__jink", Card.Heart, 7))
    seen = observeAdaptationUse(room, "hanjin__jink", "#hanjin_test_jink_virtual_materials")
    FkTest.setNextReplies(target, { { card = jink.id } })
    for _, q in ipairs(room.players) do
      if q ~= target then FkTest.setNextReplies(q, { "" }) end
    end
    room:useVirtualCard("hanjin__slash", { first.id, second.id }, attacker, target)
  end)
  lu.assertEquals(#seen, 1)
  local use = seen[1].use
  local responded = Card:getIdList(use.toCard)
  lu.assertTrue(table.contains(responded, first.id))
  lu.assertTrue(table.contains(responded, second.id))
  for _, id in ipairs({ first.id, second.id }) do
    lu.assertTrue(table.contains(target:getCardIds("h"), id))
    lu.assertEquals(room:getCardOwner(id).id, target.id)
  end
  lu.assertFalse(table.contains(target:getCardIds("h"), jink.id))
  lu.assertEquals(A.getResult(use).effects.obtain_response_card, 1)
end

function Testhanjin_card_reuse:testJinkDoesNotObtainAResponseCardThatLeftTheProcessingArea()
  local room = FkTest.room
  local target, jink, slash, seen
  FkTest.runInRoom(function()
    clearAllAreas(room)
    local attacker = room.players[1]
    target = room.players[2]
    setSingleKingdom(room, target)
    jink = give(room, target, card("hanjin__jink", Card.Heart, 7))
    slash = give(room, attacker, card("hanjin__slash"))
    local skel = fk.CreateSkill { name = "#hanjin_test_move_responded_card" }
    skel:addEffect(fk.AfterCardUseDeclared, {
      global = true, priority = 200,
      can_refresh = function(self, event, target, player, data)
        return target == player and data.card ~= nil and data.card.name == "hanjin__jink"
          and data.toCard ~= nil
      end,
      on_refresh = function(self, event, target, player, data)
        if room:getCardArea(data.toCard) == Card.Processing then
          room:moveCardTo(data.toCard, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
            "test", nil, true)
        end
      end,
    })
    room:addSkill(skel:createSkill())
    seen = observeAdaptationUse(room, "hanjin__jink", "#hanjin_test_jink_left_processing")
    FkTest.setNextReplies(target, { { card = jink.id } })
    for _, q in ipairs(room.players) do
      if q ~= target then FkTest.setNextReplies(q, { "" }) end
    end
    room:useCard(UseCardData:new { from = attacker, tos = { target }, card = slash, extra_data = {} })
  end)
  lu.assertEquals(#seen, 1)
  lu.assertEquals(room:getCardArea(slash.id), Card.DiscardPile)
  lu.assertFalse(table.contains(target:getCardIds("h"), slash.id))
  lu.assertEquals(#target:getCardIds("h"), 0)
  lu.assertEquals(A.getResult(seen[1].use).triggered_count, 1)
end

function Testhanjin_card_reuse:testJinkDoesNotFabricateACardForAnEmptyVirtualResponseCard()
  local room = FkTest.room
  local target, jink, seen
  FkTest.runInRoom(function()
    clearAllAreas(room)
    local attacker = room.players[1]
    target = room.players[2]
    setSingleKingdom(room, target)
    jink = give(room, target, card("hanjin__jink", Card.Heart, 7))
    seen = observeAdaptationUse(room, "hanjin__jink", "#hanjin_test_jink_no_material")
    FkTest.setNextReplies(target, { { card = jink.id } })
    for _, q in ipairs(room.players) do
      if q ~= target then FkTest.setNextReplies(q, { "" }) end
    end
    room:useVirtualCard("hanjin__slash", nil, attacker, target)
  end)
  lu.assertEquals(#seen, 1)
  lu.assertEquals(card("hanjin__jink", Card.Heart, 7).id, jink.id)
  lu.assertEquals(#target:getCardIds("h"), 0)
  lu.assertEquals(room:getCardArea(jink.id), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(seen[1].use.toCard), Card.Unknown)
  lu.assertEquals(A.getResult(seen[1].use).effects.obtain_response_card, 1)
  lu.assertTrue(seen[1].entry.triggered)
end

function Testhanjin_card_reuse:testCollateralFujiaDisresponsiveBlocksBothRealResponseWindows()
  local room = FkTest.room
  local user, main, sub, nullifier
  local collateral, weapon, slash, nullification
  local data, nullCalls, slashCalls
  FkTest.runInRoom(function()
    clearAllAreas(room)
    user, main, sub, nullifier = room.players[1], room.players[2], room.players[3], room.players[4]
    collateral = card("hanjin__collateral")
    weapon = card("hanjin__axe")
    slash = card("hanjin__slash")
    nullification = card("hanjin__nullification")
    give(room, user, collateral)
    give(room, user, card("hanjin__peach", Card.Heart, 4))
    give(room, main, slash)
    room:moveCardTo({ weapon.id }, Card.PlayerEquip, main, fk.ReasonPut, "test", nil, true, main)
    give(room, nullifier, nullification)
    lu.assertTrue(A.isAdaptationCard(collateral))
    lu.assertEquals(A.getEntries(collateral)[1].condition, "fujia")
    local originalNull = room.askToNullification
    nullCalls = {}
    room.askToNullification = function(self, players, params)
      local count = #players
      local result = originalNull(self, players, params)
      table.insert(nullCalls, { count = count, result = result })
      return result
    end
    local originalAsk = room.askToUseCard
    slashCalls = {}
    room.askToUseCard = function(self, player, params)
      local result = originalAsk(self, player, params)
      if params.pattern == "slash" then
        table.insert(slashCalls, {
          player = player.id,
          result = result,
          disresponsive = params.event_data ~= nil and params.event_data:isDisresponsive(player),
        })
      end
      return result
    end
    FkTest.setNextReplies(nullifier, { { card = nullification.id } })
    FkTest.setNextReplies(main, { FkTest.ReplyCard(slash, { sub }) })
    data = UseCardData:new { from = user, tos = { main, sub }, card = collateral, extra_data = {} }
    room:useCard(data)
    room.askToNullification = originalNull
    room.askToUseCard = originalAsk
  end)
  lu.assertEquals(#nullCalls, 1)
  lu.assertEquals(nullCalls[1].count, 0)
  lu.assertNil(nullCalls[1].result)
  lu.assertEquals(#slashCalls, 1)
  lu.assertEquals(slashCalls[1].player, main.id)
  lu.assertNil(slashCalls[1].result)
  lu.assertTrue(slashCalls[1].disresponsive)
  lu.assertTrue(table.contains(main:getCardIds("h"), slash.id))
  lu.assertTrue(table.contains(nullifier:getCardIds("h"), nullification.id))
  lu.assertTrue(table.contains(user:getCardIds("h"), weapon.id))
  lu.assertFalse(table.contains(user:getCardIds("h"), collateral.id))
  local result = A.getResult(data)
  lu.assertTrue(result.triggered)
  lu.assertEquals(result.triggered_count, 1)
  lu.assertEquals(result.effects.disresponsive, 1)
  lu.assertEquals(result.entries[1].condition, "fujia")
  lu.assertTrue(result.entries[1].triggered)
end

function Testhanjin_card_reuse:testBronzeSparrowGrantsAdaptationIgnore()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local bronze = card("hanjin__bronze_sparrow")
  local physical = card("hanjin__slash", Card.Club, 4)
  local slash = Fk:cloneCard("hanjin__slash")
  slash:addSubcard(physical.id)
  local extra = card("hanjin__peach", Card.Heart, 4)
  A.setCardEntries(slash, { { id = "probe_draw", condition = "kongchao", effect = "draw" } })
  local data
  FkTest.runInRoom(function()
    give(room, p, bronze)
    use(room, p, { p }, bronze)
    lu.assertTrue(p:hasSkill("hanjin__bronze_sparrow_skill"))
    give(room, p, physical)
    give(room, p, extra) -- ensure 空巢 is false
    FkTest.setNextReplies(t, { "" })
    data = UseCardData:new { from = p, tos = { t }, card = slash, extra_data = {} }
    room:useCard(data)
  end)
  lu.assertTrue(A.hasEffect(data, "draw"))
  lu.assertEquals(A.getResult(data).entries[1].ignored_by, "hanjin__bronze_sparrow_skill")
end

function Testhanjin_card_reuse:testAxeUnequipRemovesSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__axe")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("hanjin__axe_skill"))
    room:moveCardTo({ c.id }, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      "test", nil, true, p)
  end)
  lu.assertFalse(p:hasSkill("hanjin__axe_skill"))
end

function Testhanjin_card_reuse:testAdaptedEquipmentSkillsAttachAndDetach()
  local room = FkTest.room
  local p = room.players[1]
  local cases = {
    { "hanjin__spear", "hanjin__spear_skill" },
    { "hanjin__crossbow", "hanjin__crossbow_skill" },
    { "hanjin__six_swords", "hanjin__six_swords_skill" },
    { "hanjin__wooden_ox", "hanjin__wooden_ox_skill" },
    { "hanjin__jade_seal", "hanjin__jade_seal_skill" },
    { "hanjin__five_elements_fan", "hanjin__five_elements_fan_skill" },
    { "hanjin__black_chain", "hanjin__black_chain_skill" },
    { "hanjin__dark_armor", "hanjin__dark_armor_skill" },
    { "hanjin__eight_diagram", "hanjin__eight_diagram_skill" },
    { "hanjin__breastplate", "hanjin__breastplate_skill" },
    { "hanjin__peace_spell", "hanjin__peace_spell_skill" },
    { "hanjin__luminous_pearl", "hanjin__luminous_pearl_skill" },
    { "hanjin__dragon_phoenix", "#dragon_phoenix_skill" },
    { "hanjin__halberd", "hanjin__halberd_skill" },
    { "hanjin__blade", "#sa__blade_skill" },
    { "hanjin__liulongcanjia", "#liulongcanjia_skill" },
    { "hanjin__taigong_tactics", "hanjin__taigong_tactics_skill" },
    { "hanjin__wonder_map", "hanjin__wonder_map_skill" },
  }
  for _, case in ipairs(cases) do
    local c = card(case[1])
    local attached, detached
    FkTest.runInRoom(function()
      give(room, p, c)
      use(room, p, { p }, c)
      attached = p:hasSkill(case[2])
      room:moveCardTo({ c.id }, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
        "test", nil, true, p)
      detached = not p:hasSkill(case[2])
    end)
    lu.assertTrue(attached, "Missing equip skill " .. case[2])
    lu.assertTrue(detached, "Equip skill did not detach " .. case[2])
  end
end

function Testhanjin_card_reuse:testPassiveEquipmentSkillsAreHiddenButStayAttached()
  local passive, active = 0, 0
  for _, cardType in ipairs(CardData.types) do
    if cardType.type == "equip" and cardType.equip_skill then
      local skill = Fk.skills[cardType.equip_skill]
      lu.assertNotNil(skill, "Missing equip skill " .. tostring(cardType.equip_skill))
      local skeleton = skill:getSkeleton()
      if skeleton.attached_equip ~= nil then
        lu.assertEquals(skeleton.attached_equip, cardType.id)
        lu.assertTrue(skill:isEquipmentSkill(), cardType.id)
        local clickable = skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill)
        lu.assertEquals(skill.visible, clickable, cardType.id)
        if clickable then active = active + 1 else passive = passive + 1 end
      else
        lu.assertEquals(cardType.equip_skill, "hanjin__inert_equip")
        lu.assertFalse(skill.visible)
      end
    end
  end
  lu.assertTrue(passive > 0)
  lu.assertTrue(active > 0)
  lu.assertFalse(Fk.skills["hanjin__five_elements_fan_skill"].visible)
  lu.assertTrue(Fk.skills["hanjin__spear_skill"].visible)
  lu.assertTrue(Fk.skills["hanjin__luminous_pearl_skill"].visible)
  lu.assertTrue(Fk.skills["hanjin__wooden_ox_skill"].visible)
  lu.assertEquals(Fk:translate("hanjin__five_elements_fan"), "五行鹤翎扇")
end

function Testhanjin_card_reuse:testFiveElementsFanStaysHiddenAfterEquip()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__five_elements_fan")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("hanjin__five_elements_fan_skill"))
    lu.assertFalse(Fk.skills["hanjin__five_elements_fan_skill"].visible)
    lu.assertFalse(table.contains(p:getSkillNameList(), "hanjin__five_elements_fan_skill"))
    lu.assertEquals(Fk:translate("hanjin__five_elements_fan"), "五行鹤翎扇")
  end)
end

function Testhanjin_card_reuse:testBreastplateBPreventsNonLethalTwoDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__breastplate")
  local hp = p.hp
  local attached, equipped
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    attached = p:hasSkill("hanjin__breastplate_skill")
    equipped = table.contains(p:getEquipments(), c.id)
    FkTest.setNextReplies(p, { "1" })
    room:damage { from = t, to = p, damage = 2, damageType = fk.NormalDamage }
  end)
  lu.assertTrue(attached)
  lu.assertTrue(equipped)
  lu.assertEquals(p.hp, hp)
  lu.assertFalse(table.contains(p:getEquipments(), c.id))
end

function Testhanjin_card_reuse:testDrowningARequiresEquipmentAndBothOnZhuzhan()
  local room = FkTest.room
  local p, t, bare = room.players[1], room.players[2], room.players[3]
  local c = card("hanjin__drowning")
  local weapon = card("hanjin__axe")
  local treasure = card("hanjin__jade_seal")
  local hp = t.hp
  local data
  local order = {}
  FkTest.runInRoom(function()
    local entry = A.getEntries(c)[1]
    lu.assertEquals(entry.condition, "zhuzhan")
    lu.assertEquals(entry.effect, "execute_both")
    for _, id in ipairs(t:getCardIds("he")) do room:throwCard(id, "test", t, t) end
    room:moveCardTo({ weapon.id }, Card.PlayerEquip, t, fk.ReasonPut, "test", nil, true, t)
    room:moveCardTo({ treasure.id }, Card.PlayerEquip, t, fk.ReasonPut, "test", nil, true, t)
    lu.assertEquals(#t:getCardIds("e"), 2)
    local originalThrow = t.throwAllCards
    t.throwAllCards = function(self, area)
      if area == "e" then table.insert(order, "discard") end
      return originalThrow(self, area)
    end
    local skel = fk.CreateSkill { name = "#hanjin_probe_drowning_order" }
    skel:addEffect(fk.DamageInflicted, {
      global = true,
      can_refresh = function(self, event, target, player, damage)
        return target == t and damage.card and damage.card.name == "hanjin__drowning"
      end,
      on_refresh = function()
        table.insert(order, "damage")
      end,
    })
    room:addSkill(skel:createSkill())
    give(room, p, c)
    lu.assertNotIsTrue(p:canUseTo(c, bare))
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    data = UseCardData:new { from = p, tos = { t }, card = c, extra_data = {} }
    A.grantIgnore(data, "probe_zhuzhan")
    room:useCard(data)
    t.throwAllCards = originalThrow
  end)
  lu.assertEquals(order[1], "discard")
  lu.assertEquals(order[2], "damage")
  lu.assertEquals(#t:getCardIds("e"), 0)
  lu.assertEquals(t.hp, hp - 1)
  lu.assertTrue(A.hasEffect(data, "execute_both"))
  lu.assertEquals(A.getResult(data).entries[1].effect, "execute_both")
end

function Testhanjin_card_reuse:testBreastplateBAllowsRejection()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__breastplate")
  local hp = p.hp
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    FkTest.setNextReplies(p, { "" })
    room:damage { from = t, to = p, damage = 2, damageType = fk.NormalDamage }
  end)
  lu.assertEquals(p.hp, hp - 2)
  lu.assertTrue(table.contains(p:getEquipments(), c.id))
end

function Testhanjin_card_reuse:testBreastplateBShieldCountsForLethalThreshold()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__breastplate")
  FkTest.runInRoom(function()
    p.hp = 1
    room:changeShield(p, 1)
    give(room, p, c)
    use(room, p, { p }, c)
    -- 1 damage is not lethal while shield is counted (hp+shield = 2), and is
    -- not >1, so 护心镜 must not ask or trigger.
    room:damage { from = t, to = p, damage = 1, damageType = fk.NormalDamage }
  end)
  lu.assertTrue(table.contains(p:getEquipments(), c.id))
  lu.assertEquals(p.hp, 1)
  lu.assertEquals(p.shield, 0)
end

function Testhanjin_card_reuse:testDragonPhoenixADiscardsOnSlashTarget()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local equip = card("hanjin__dragon_phoenix")
  local slash = card("hanjin__slash")
  local victimCard = card("hanjin__peach", Card.Heart, 4)
  FkTest.runInRoom(function()
    give(room, p, equip)
    use(room, p, { p }, equip)
    lu.assertTrue(p:hasSkill("#dragon_phoenix_skill"))
    give(room, p, slash)
    give(room, t, victimCard)
    FkTest.setNextReplies(p, { "1" })
    FkTest.setNextReplies(t, { FkTest.ReplyDiscard({ victimCard }), "" })
    local data = UseCardData:new { from = p, tos = { t }, card = slash, extra_data = {} }
    room:useCard(data)
  end)
  lu.assertFalse(table.contains(t:getCardIds("he"), victimCard.id))
end

function Testhanjin_card_reuse:testHalberdUsesHanjinEquipSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__halberd")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("hanjin__halberd_skill"))
    lu.assertFalse(p:hasSkill("#sa__halberd_skill"))
  end)
end

function Testhanjin_card_reuse:testHalberdExpansionFilterReusesFactionRule()
  local room = FkTest.room
  local p1, p2, p3, p4, p5, p6, p7 =
    room.players[1], room.players[2], room.players[3], room.players[4],
    room.players[5], room.players[6], room.players[7]
  local slash = card("hanjin__slash")
  FkTest.runInRoom(function()
    local skill = Fk.skills["#hanjin__halberd_active"]
    lu.assertNotNil(skill)
    p2.kingdom, p3.kingdom, p4.kingdom = "wei", "shu", "wei"
    p5.kingdom, p6.kingdom = "unknown", "shu"
    local extra = {
      orig_tos = { p2.id },
      targets = { p2.id, p3.id, p4.id, p5.id, p6.id },
    }
    local function allowed(to, selected)
      return skill:targetFilter(p1, to, selected or {}, {}, slash, extra)
    end
    lu.assertTrue(allowed(p3))               -- 与原有目标势力不同
    lu.assertFalse(allowed(p4))              -- 与原有目标同为魏
    lu.assertTrue(allowed(p5))               -- 没有势力
    lu.assertFalse(allowed(p6, { p3 }))      -- 与已选额外目标同为蜀
    lu.assertFalse(allowed(p7))              -- 不在候选列表
  end)
end

function Testhanjin_card_reuse:testHalberdExpandedSlashNullifiesRemainingTargetsAfterJink()
  local room = FkTest.room
  local p1, p2, p3 = room.players[1], room.players[2], room.players[3]
  local halberd, slash = card("hanjin__halberd"), card("hanjin__slash")
  local p2Jink = card("hanjin__jink", Card.Heart, 2)
  local p3Jink = card("hanjin__jink", Card.Diamond, 3)
  local used
  FkTest.runInRoom(function()
    p1.kingdom, p2.kingdom, p3.kingdom = "han", "wei", "shu"
    give(room, p1, halberd)
    use(room, p1, { p1 }, halberd)
    give(room, p1, slash)
    give(room, p2, p2Jink)
    give(room, p3, p3Jink)
    local hp2, hp3 = p2.hp, p3.hp
    FkTest.setNextReplies(p1, {
      FkTest.ReplyUseSkill("#hanjin__halberd_active", { p3 }),
    })
    FkTest.setNextReplies(p2, { { card = p2Jink.id } })
    FkTest.setNextReplies(p3, { { card = p3Jink.id } })
    used = use(room, p1, { p2 }, slash)
    lu.assertEquals(p2.hp, hp2)
    lu.assertEquals(p3.hp, hp3)
    lu.assertTrue(table.contains(p3:getCardIds("h"), p3Jink.id))
    lu.assertFalse(table.contains(p2:getCardIds("h"), p2Jink.id))
  end)
  lu.assertTrue(table.contains(used.tos, p3))
end

function Testhanjin_card_reuse:testHalberdExpandedSlashWithoutJinkDamagesAllTargets()
  local room = FkTest.room
  local p1, p2, p3 = room.players[1], room.players[2], room.players[3]
  local halberd, slash = card("hanjin__halberd"), card("hanjin__slash")
  FkTest.runInRoom(function()
    p1.kingdom, p2.kingdom, p3.kingdom = "han", "wei", "shu"
    give(room, p1, halberd)
    use(room, p1, { p1 }, halberd)
    give(room, p1, slash)
    local hp2, hp3 = p2.hp, p3.hp
    FkTest.setNextReplies(p1, {
      FkTest.ReplyUseSkill("#hanjin__halberd_active", { p3 }),
    })
    FkTest.setNextReplies(p2, { "" })
    FkTest.setNextReplies(p3, { "" })
    use(room, p1, { p2 }, slash)
    lu.assertEquals(p2.hp, hp2 - 1)
    lu.assertEquals(p3.hp, hp3 - 1)
  end)
end

function Testhanjin_card_reuse:testHalberdWithoutExpansionKeepsOtherTargets()
  local room = FkTest.room
  local p1, p2, p3 = room.players[1], room.players[2], room.players[3]
  local halberd, slash = card("hanjin__halberd"), card("hanjin__slash")
  local jink = card("hanjin__jink", Card.Heart, 2)
  FkTest.runInRoom(function()
    p1.kingdom, p2.kingdom, p3.kingdom = "han", "wei", "shu"
    give(room, p1, halberd)
    use(room, p1, { p1 }, halberd)
    give(room, p1, slash)
    give(room, p2, jink)
    local hp3 = p3.hp
    FkTest.setNextReplies(p1, { "" }) -- 不发动扩目标
    FkTest.setNextReplies(p2, { { card = jink.id } })
    FkTest.setNextReplies(p3, { "" })
    use(room, p1, { p2, p3 }, slash)
    lu.assertEquals(p3.hp, hp3 - 1)
  end)
end

function Testhanjin_card_reuse:testBladeAUsesStrategicSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__blade")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("#sa__blade_skill"))
    lu.assertFalse(p:hasSkill("#blade_skill"))
  end)
end

function Testhanjin_card_reuse:testLiulongAInstallsNationalMountLock()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__liulongcanjia")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("#liulongcanjia_skill"))
    lu.assertEquals(p:getMark("@@liulongcanjia"), 1)
  end)
end

function Testhanjin_card_reuse:testLuminousAInstallsZhiheng()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("hanjin__luminous_pearl")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("hanjin__luminous_pearl_skill"))
  end)
end

function Testhanjin_card_reuse:testPeaceAPreventsAttributeDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("hanjin__peace_spell")
  local hp = p.hp
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("hanjin__peace_spell_skill"))
    room:damage { from = t, to = p, damage = 2, damageType = fk.FireDamage }
  end)
  lu.assertEquals(p.hp, hp)
end


return { name = "hanjin_card_reuse" }



