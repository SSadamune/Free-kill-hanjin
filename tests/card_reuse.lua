local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local CardData = require "packages.qiao.pkg.qiao_cards.data.cards"
local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wu", "wu" }

-- 固定全体白板双将：卡牌复用/应变用例只依赖卡牌与请求顺序，不能因随机双将
-- 引入额外技能询问；需要特定武将的交互用例在本用例内自行装入。
Testqiao_card_reuse = {
  setup = function()
    local room = support.initQiaoRoom()
    FkTest.runInRoom(function() skill_test.installBlankGenerals(room, DEFAULT_KINGDOMS) end)
  end,
  tearDown = support.clearRoom,
}

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

function Testqiao_card_reuse:testSlashDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("qiao__slash")
  local hp = t.hp
  FkTest.runInRoom(function()
    give(room, p, c)
    FkTest.setNextReplies(t, { "" })
    use(room, p, { t }, c)
  end)
  lu.assertEquals(t.hp, hp - 1)
end

function Testqiao_card_reuse:testJinkResponse()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local slash, jink = card("qiao__slash"), card("qiao__jink")
  local hp = t.hp
  lu.assertEquals(jink.skill.name, "jink_skill")
  FkTest.runInRoom(function()
    give(room, p, slash)
    give(room, t, jink)
    FkTest.setNextReplies(t, { { card = jink.id } })
    room:useVirtualCard("qiao__slash", nil, p, t)
  end)
  lu.assertEquals(t.hp, hp)
end

function Testqiao_card_reuse:testPeachHeal()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("qiao__peach")
  FkTest.runInRoom(function()
    p.hp = p.maxHp - 1
    give(room, p, c)
    use(room, p, { p }, c)
  end)
  lu.assertEquals(p.hp, p.maxHp)
end

function Testqiao_card_reuse:testDismantlement()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("qiao__dismantlement")
  local targetCard = card("qiao__slash", Card.Heart, 10)
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

function Testqiao_card_reuse:testAxeEquipSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("qiao__axe")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
  end)
  lu.assertTrue(table.contains(p:getEquipments(), c.id))
  lu.assertTrue(p:hasSkill("qiao__axe_skill"))
end

function Testqiao_card_reuse:testIceSlashDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("qiao__ice__slash")
  local hp = t.hp
  local dtype
  local skel = fk.CreateSkill { name = "#qiao_probe_ice_damage" }
  skel:addEffect(fk.DamageInflicted, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == player and data.card and data.card.name == "qiao__ice__slash"
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

function Testqiao_card_reuse:testChasingNearExecuteBoth()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local physical = card("qiao__chasing_near")
  local c = Fk:cloneCard("qiao__chasing_near")
  c:addSubcard(physical.id)
  local first = card("qiao__slash", Card.Club, 2)
  local second = card("qiao__slash", Card.Club, 3)
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

function Testqiao_card_reuse:testForesightViewsAndRearrangesBeforeDrawingBothCards()
  local room = FkTest.room
  local client, other = ClientInstance, nil
  FkTest.runInClient(function() other = room:getPlayerById(Self.id) end)
  local player = other:getNextAlive()
  local c = card("qiao__foresight")
  local top1, top2, top3
  local order = {}
  local privateMoves = {}
  local received = {}
  local handAfter, bottom
  FkTest.runInRoom(function()
    clearAllAreas(room)
    give(room, player, c)
    local nullification = room:printCard("qiao__nullification", Card.Spade, 11)
    room:moveCards { ids = { nullification.id }, toArea = Card.DrawPile,
      moveReason = fk.ReasonPut, moveVisible = false }
    top1, top2, top3 = room.draw_pile[1], room.draw_pile[2], room.draw_pile[3]
    lu.assertEquals(top1, nullification.id)
    lu.assertNotNil(top2)
    lu.assertNotNil(top3)
    local originalGuanxing, originalDraw = room.askToGuanxing, room.drawCards
    local originalNotify = room.notifyMoveCards
    room.notifyMoveCards = function(self, viewers, moves, eventId)
      for _, move in ipairs(moves) do
        if move.toArea == Card.Processing or move.toArea == Card.DrawPile then
          for _, info in ipairs(move.moveInfo) do
            local id = info.cardId
            if id == top1 or id == top2 then
              table.insert(privateMoves, { player:cardVisible(id, move), other:cardVisible(id, move) })
            end
          end
        end
      end
      return originalNotify(self, viewers, moves, eventId)
    end
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
    local mode = room:getSettings("gameMode")
    local qiaoClient = Fk:getBoardGame(mode).client_klass:new {
      notifyUI = function(_, command, data)
        if command ~= "QiaoMoveCards" then return end
        for _, move in ipairs(data.merged) do
          for _, id in ipairs(move.ids) do
            if id == top1 or id == top2 or id == top3 then
              table.insert(received, { id, move.fromArea, move.toArea, data[tostring(id)] })
            end
          end
        end
      end,
    }
    qiaoClient.settings = { gameMode = mode }
    -- FkTest's console client remains in testmode. Forward the engine's
    -- actual third-seat MoveCards payload through the registered Han-Jin client.
    local notify = client.notifyUI
    client.notifyUI = function(self, command, data)
      if command == "MoveCards" then qiaoClient:notifyUI(command, data) end
      return notify(self, command, data)
    end
    local ok, err = pcall(room.useCard, room,
      UseCardData:new { from = player, tos = { player }, card = c, extra_data = {} })
    client.notifyUI = notify
    room.askToGuanxing = originalGuanxing
    room.drawCards = originalDraw
    room.notifyMoveCards = originalNotify
    if not ok then error(err, 0) end
    handAfter = player:getCardIds("h")
    bottom = room.draw_pile[#room.draw_pile]
  end)
  lu.assertEquals(order, { "guanxing", "arranged", "draw" })
  lu.assertEquals(privateMoves, { { true, false }, { true, false }, { true, false }, { true, false } })
  lu.assertEquals(received, {
    { top1, Card.DrawPile, Card.Processing, false },
    { top2, Card.DrawPile, Card.Processing, false },
    { top1, Card.Processing, Card.DrawPile, false },
    { top2, Card.Processing, Card.DrawPile, false },
    { top1, Card.DrawPile, Card.PlayerHand, false },
    { top3, Card.DrawPile, Card.PlayerHand, false },
  })
  lu.assertEquals(#handAfter, 2)
  lu.assertTrue(table.contains(handAfter, top1))
  lu.assertTrue(table.contains(handAfter, top3))
  lu.assertFalse(table.contains(handAfter, top2))
  lu.assertEquals(bottom, top2)
  lu.assertFalse(A.isAdaptationCard(c))
end

function Testqiao_card_reuse:testUnexpectationExcludesItsSupporterFromTheClientRequest()
  local room = FkTest.room
  local user, target, helper, other = table.unpack(room.players, 1, 4)
  local useCard = card("qiao__unexpectation", Card.Heart, 3)
  local cost = card("qiao__dismantlement")
  local revealed = {}
  local useData
  local asked = false
  FkTest.runInRoom(function()
    clearAllAreas(room)
    give(room, user, useCard)
    give(room, helper, cost)
    -- 助战者弃牌后仍有手牌，本来符合出其不意的牌面目标条件。
    give(room, helper, room:printCard("qiao__jink", Card.Heart, 8))
    for _, who in ipairs({ target, other }) do
      give(room, who, room:printCard("qiao__jink", Card.Heart, 9))
    end
  end)
  FkTest.setNextReplies(helper, { FkTest.ReplyDiscard({ cost.id }) })
  skill_test.withSkillRequests(room, "choose_players_skill", {
    askToUseActiveSkill = function(self, who, params, ask)
      if params.prompt == "#qiao_adaptation_add_target" then
        asked = true
        lu.assertEquals(#helper:getCardIds("h"), 1)
        lu.assertEquals(room:getCardArea(cost.id), Card.DiscardPile)
        lu.assertEquals(params.extra_data.targets, { other.id })
        local reply = client_room.confirmSelection(room, who, params, {}, { other }, function(handler)
          lu.assertFalse(handler:targetValidity(helper.id))
        end)
        FkTest.setNextReplies(who, { reply })
      end
      return ask(self, who, params)
    end,
  }, function()
    skill_test.withSkillRequests(room, "qiao__unexpectation_skill", {
      askToChooseCard = function(self, who, params)
        table.insert(revealed, params.target.id)
        return params.target:getCardIds("h")[1]
      end,
    }, function()
      FkTest.runInRoom(function() useData = use(room, user, { target }, useCard) end)
    end)
  end)
  lu.assertTrue(asked)
  lu.assertEquals(A.getResult(useData).entries[1].support.player, helper.id)
  lu.assertEquals(table.map(useData.tos, Util.IdMapper), { target.id, other.id })
  lu.assertEquals(revealed, { target.id, other.id })
end

function Testqiao_card_reuse:testChasingNearRealSupportAtDistanceOneDiscardsThenHasNothingToObtain()
  local room = FkTest.room
  local p, t, helper = room.players[1], room.players[2], room.players[3]
  local c = card("qiao__chasing_near")
  local targetCard = card("qiao__peach", Card.Heart, 4)
  local supportCard = card("qiao__dismantlement")
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

function Testqiao_card_reuse:testChasingNearRealSupportWithOnlyOneEquipmentDiscardsItToo()
  local room = FkTest.room
  local p, t, helper = room.players[1], room.players[2], room.players[3]
  local c = card("qiao__chasing_near")
  local targetCard = card("qiao__axe")
  local supportCard = card("qiao__dismantlement")
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

function Testqiao_card_reuse:testJinkActualUseObtainsTheRespondedCardNotItself()
  local room = FkTest.room
  local attacker, target, jink, slash, seen
  FkTest.runInRoom(function()
    clearAllAreas(room)
    attacker, target = room.players[1], room.players[2]
    setSingleKingdom(room, target)
    jink = give(room, target, card("qiao__jink", Card.Heart, 7))
    slash = give(room, attacker, card("qiao__slash"))
    lu.assertTrue(A.isAdaptationCard(jink))
    seen = observeAdaptationUse(room, "qiao__jink", "#qiao_test_jink_actual_use")
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

function Testqiao_card_reuse:testJinkPlayedAsResponseDoesNotTriggerAdaptation()
  local room = FkTest.room
  local target, jink, seen
  local initial = {}
  local nullify_asks, nullify_targeted = 0, false
  local jink_responses, jink_uses = 0, 0
  FkTest.runInRoom(function()
    -- 本用例需要「目标可把任意牌当无懈」的隐将张让：万箭齐发结算时先有真实
    -- 无懈请求，再有为万箭准备的【闪】响应；两次回复分别对应这两次请求。
    target = room.players[2]
    skill_test.installDualGenerals(room, target, {
      main = "qiao_heg__han004", deputy = "qiao_test__han_2", kingdom = "han",
    })
    target:hideGeneral(false)
    clearAllAreas(room)
    local attacker = room.players[1]
    setSingleKingdom(room, target)
    for _, player in ipairs(room.players) do
      table.insert(initial, { player.id, player.general, player.deputyGeneral,
        player:getMark("__heg_general"), player:getMark("__heg_deputy") })
    end
    jink = give(room, target, card("qiao__jink", Card.Heart, 7))
    local archery = give(room, attacker, card("qiao__archery_attack"))
    lu.assertTrue(A.isAdaptationCard(jink))
    seen = observeAdaptationUse(room, "qiao__jink", "#qiao_test_jink_pure_response")
    -- 必达探针：本用例的【闪】只能以「打出」进入 RespondCard，不能出现
    -- CardUsing；A.Triggered 为 0 是结果，探针负责区分路径。
    local use_probe = fk.CreateSkill { name = "#qiao_test_jink_use_probe" }
    use_probe:addEffect(fk.CardUsing, {
      can_refresh = function(self, event, target, player, data)
        return target == player and data.card ~= nil and data.card.name == "qiao__jink"
      end,
      on_refresh = function() jink_uses = jink_uses + 1 end,
    })
    use_probe:addEffect(fk.CardResponding, {
      can_refresh = function(self, event, target, player, data)
        return target == player and data.card ~= nil and data.card.name == "qiao__jink"
      end,
      on_refresh = function() jink_responses = jink_responses + 1 end,
    })
    room:addSkill(use_probe:createSkill())
    -- 第一条取消先来的无懈请求，第二条才是万箭的【闪】响应。
    FkTest.setNextReplies(target, { "", { card = jink.id } })
    for index = 3, #room.players do FkTest.setNextReplies(room.players[index], { "" }) end

    local original_nullify = room.askToNullification
    room.askToNullification = function(self, players, params)
      nullify_asks = nullify_asks + 1
      if table.contains(players, target) then nullify_targeted = true end
      return original_nullify(self, players, params)
    end
    local ok, err = pcall(function()
      local tos = table.slice(room.players, 2)
      room:useCard(UseCardData:new { from = attacker, tos = tos, card = archery, extra_data = {} })
    end)
    room.askToNullification = original_nullify
    if not ok then error(err) end
  end)
  local observed = table.map(seen, function(data)
    return { from = data.use.from.id, card = data.use.card.name,
      skills = data.use.card.skillNames, condition = data.entry.condition,
      effect = data.entry.effect, against = data.use.toCard and data.use.toCard.name }
  end)
  lu.assertTrue(nullify_asks >= 1, json.encode { initial = initial, nullify_asks = nullify_asks })
  lu.assertTrue(nullify_targeted, json.encode { initial = initial, nullify_asks = nullify_asks })
  lu.assertEquals(#seen, 0, json.encode { initial = initial, observed = observed,
    nullify_asks = nullify_asks, jink_responses = jink_responses })
  lu.assertEquals(jink_responses, 1, "【闪】必须经 RespondCard 打出一次")
  lu.assertEquals(jink_uses, 0, "万箭的【闪】不能走 CardUsing（只能是打出）")
  lu.assertEquals(room:getCardArea(jink.id), Card.DiscardPile)
  lu.assertEquals(#target:getCardIds("h"), 0)
  lu.assertEquals(target.hp, target.maxHp)
  lu.assertTrue(A.isAdaptationCard(jink))
end

function Testqiao_card_reuse:testJinkObtainsAllMaterialsOfAVirtualRespondedCard()
  local room = FkTest.room
  local target, jink, first, second, seen
  FkTest.runInRoom(function()
    clearAllAreas(room)
    local attacker = room.players[1]
    target = room.players[2]
    setSingleKingdom(room, target)
    first = give(room, attacker, card("qiao__slash"))
    second = give(room, attacker, card("qiao__peach"))
    jink = give(room, target, card("qiao__jink", Card.Heart, 7))
    seen = observeAdaptationUse(room, "qiao__jink", "#qiao_test_jink_virtual_materials")
    FkTest.setNextReplies(target, { { card = jink.id } })
    for _, q in ipairs(room.players) do
      if q ~= target then FkTest.setNextReplies(q, { "" }) end
    end
    room:useVirtualCard("qiao__slash", { first.id, second.id }, attacker, target)
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

function Testqiao_card_reuse:testJinkDoesNotObtainAResponseCardThatLeftTheProcessingArea()
  local room = FkTest.room
  local target, jink, slash, seen
  FkTest.runInRoom(function()
    clearAllAreas(room)
    local attacker = room.players[1]
    target = room.players[2]
    setSingleKingdom(room, target)
    jink = give(room, target, card("qiao__jink", Card.Heart, 7))
    slash = give(room, attacker, card("qiao__slash"))
    local skel = fk.CreateSkill { name = "#qiao_test_move_responded_card" }
    skel:addEffect(fk.AfterCardUseDeclared, {
      global = true, priority = 200,
      can_refresh = function(self, event, target, player, data)
        return target == player and data.card ~= nil and data.card.name == "qiao__jink"
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
    seen = observeAdaptationUse(room, "qiao__jink", "#qiao_test_jink_left_processing")
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

function Testqiao_card_reuse:testJinkDoesNotFabricateACardForAnEmptyVirtualResponseCard()
  local room = FkTest.room
  local target, jink, seen
  FkTest.runInRoom(function()
    clearAllAreas(room)
    local attacker = room.players[1]
    target = room.players[2]
    setSingleKingdom(room, target)
    jink = give(room, target, card("qiao__jink", Card.Heart, 7))
    seen = observeAdaptationUse(room, "qiao__jink", "#qiao_test_jink_no_material")
    FkTest.setNextReplies(target, { { card = jink.id } })
    for _, q in ipairs(room.players) do
      if q ~= target then FkTest.setNextReplies(q, { "" }) end
    end
    room:useVirtualCard("qiao__slash", nil, attacker, target)
  end)
  lu.assertEquals(#seen, 1)
  lu.assertEquals(card("qiao__jink", Card.Heart, 7).id, jink.id)
  lu.assertEquals(#target:getCardIds("h"), 0)
  lu.assertEquals(room:getCardArea(jink.id), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(seen[1].use.toCard), Card.Unknown)
  lu.assertEquals(A.getResult(seen[1].use).effects.obtain_response_card, 1)
  lu.assertTrue(seen[1].entry.triggered)
end

function Testqiao_card_reuse:testCollateralFujiaDisresponsiveBlocksBothRealResponseWindows()
  local room = FkTest.room
  local user, main, sub, nullifier
  local collateral, weapon, slash, nullification
  local data, nullCalls, slashCalls
  FkTest.runInRoom(function()
    clearAllAreas(room)
    user, main, sub, nullifier = room.players[1], room.players[2], room.players[3], room.players[4]
    collateral = card("qiao__collateral")
    weapon = card("qiao__axe")
    slash = card("qiao__slash")
    nullification = card("qiao__nullification")
    give(room, user, collateral)
    give(room, user, card("qiao__peach", Card.Heart, 4))
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

function Testqiao_card_reuse:testBronzeSparrowGrantsAdaptationIgnore()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local bronze = card("qiao__bronze_sparrow")
  local physical = card("qiao__slash", Card.Club, 4)
  local slash = Fk:cloneCard("qiao__slash")
  slash:addSubcard(physical.id)
  local extra = card("qiao__peach", Card.Heart, 4)
  A.setCardEntries(slash, { { id = "probe_draw", condition = "kongchao", effect = "draw" } })
  local data
  FkTest.runInRoom(function()
    give(room, p, bronze)
    use(room, p, { p }, bronze)
    lu.assertTrue(p:hasSkill("qiao__bronze_sparrow_skill"))
    give(room, p, physical)
    give(room, p, extra) -- ensure 空巢 is false
    FkTest.setNextReplies(t, { "" })
    data = UseCardData:new { from = p, tos = { t }, card = slash, extra_data = {} }
    local askChoice = room.askToChoice
    local asked = 0
    skill_test.withSkillRequests(room, "qiao__bronze_sparrow_skill", {
      askToChoice = function(self, who, params)
        asked = asked + 1
        lu.assertEquals(params.choices, {
          "qiao_ignore_option:1::qiao_condition_kongchao:qiao_adaptation_draw",
        })
        FkTest.setNextReplies(p, { { params.choices[1] } })
        return askChoice(self, who, params)
      end,
    }, function() room:useCard(data) end)
    lu.assertEquals(asked, 1)
    -- 同一回合第二次使用应变牌时不再提供铜雀。
    lu.assertEquals(p:usedSkillTimes("qiao__bronze_sparrow_skill", Player.HistoryTurn), 1)
  end)
  lu.assertTrue(A.hasEffect(data, "draw"))
  lu.assertEquals(A.getResult(data).entries[1].ignored_by, "qiao__bronze_sparrow_skill")
end

-- 铜雀取消发动不消耗本回合次数，次数保留给之后的牌。
function Testqiao_card_reuse:testBronzeSparrowCancelKeepsTheTurnUse()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local bronze = card("qiao__bronze_sparrow")
  local firstCard = card("qiao__slash", Card.Club, 4)
  local secondPhysical = card("qiao__slash", Card.Club, 5)
  local first = Fk:cloneCard("qiao__slash")
  first:addSubcard(firstCard.id)
  local second = Fk:cloneCard("qiao__slash")
  second:addSubcard(secondPhysical.id)
  A.setCardEntries(first, { { id = "cancel_probe", condition = "canqu", effect = "draw" } })
  A.setCardEntries(second, { { id = "later_probe", condition = "kongchao", effect = "draw" } })
  local laterData
  FkTest.runInRoom(function()
    give(room, p, bronze)
    use(room, p, { p }, bronze)
    give(room, p, firstCard)
    give(room, p, secondPhysical)
    give(room, p, card("qiao__peach", Card.Heart, 4))
    room:setPlayerProperty(p, "hp", 1)
    FkTest.setNextReplies(p, { { "Cancel" } })
    FkTest.setNextReplies(t, { "" })
    local firstData = UseCardData:new { from = p, tos = { t }, card = first, extra_data = {} }
    local askChoice = room.askToChoice
    local asked = 0
    skill_test.withSkillRequests(room, "qiao__bronze_sparrow_skill", {
      askToChoice = function(self, who, params)
        asked = asked + 1
        lu.assertEquals(params.choices, {
          "qiao_ignore_option_satisfied:1::qiao_condition_canqu:qiao_adaptation_draw",
        })
        return askChoice(self, who, params)
      end,
    }, function() room:useCard(firstData) end)
    lu.assertEquals(asked, 1)
    lu.assertNil(A.getResult(firstData).entries[1].ignored_by)
    lu.assertTrue(A.hasEffect(firstData, "draw"))
    -- 之后的应变牌仍可发动铜雀，说明次数没有被取消消耗。
    FkTest.setNextReplies(p, {
      { "qiao_ignore_option:1::qiao_condition_kongchao:qiao_adaptation_draw" },
    })
    FkTest.setNextReplies(t, { "" })
    laterData = UseCardData:new { from = p, tos = { t }, card = second, extra_data = {} }
    room:useCard(laterData)
  end)
  lu.assertEquals(A.getResult(laterData).entries[1].ignored_by, "qiao__bronze_sparrow_skill")
end

function Testqiao_card_reuse:testBronzeSparrowShowsSatisfactionWhenAsked()
  local room = FkTest.room
  local source, keep, remove = room.players[1], room.players[2], room.players[3]
  local bronze = card("qiao__bronze_sparrow")
  local savage = Fk:cloneCard("qiao__savage_assault")
  A.setCardEntries(savage, {
    { id = "draw_first", condition = "canqu", effect = "draw" },
    { id = "then_remove", condition = "fujia", effect = "remove_target" },
  })
  FkTest.runInRoom(function()
    clearAllAreas(room)
    give(room, source, bronze)
    use(room, source, { source }, bronze)
    give(room, keep, room:printCard("qiao__jink", Card.Club, 2))
    room:setPlayerProperty(source, "hp", 1)
    local used = UseCardData:new {
      from = source, tos = { keep, remove }, card = savage, nullifiedTargets = { keep, remove },
    }
    local askChoice = room.askToChoice
    local asked = 0
    skill_test.withSkillRequests(room, "qiao__bronze_sparrow_skill", {
      askToChoice = function(self, who, params)
        asked = asked + 1
        lu.assertEquals(params.choices, {
          "qiao_ignore_option_satisfied:1::qiao_condition_canqu:qiao_adaptation_draw",
          "qiao_ignore_option:2::qiao_condition_fujia:qiao_adaptation_remove_target",
        })
        FkTest.setNextReplies(source, { { "Cancel" }, FkTest.ReplyChoosePlayer({ remove }) })
        return askChoice(self, who, params)
      end,
    }, function() room:useCard(used) end)
    local entries = A.getResult(used).entries
    lu.assertEquals(asked, 1)
    lu.assertTrue(entries[1].triggered)
    lu.assertTrue(entries[2].triggered)
    lu.assertNil(entries[2].ignored_by)
    lu.assertEquals(table.map(used.tos, Util.IdMapper), { keep.id })
    lu.assertEquals(source:usedSkillTimes("qiao__bronze_sparrow_skill", Player.HistoryTurn), 0)
  end)
end

function Testqiao_card_reuse:testAxeUnequipRemovesSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("qiao__axe")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("qiao__axe_skill"))
    room:moveCardTo({ c.id }, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      "test", nil, true, p)
  end)
  lu.assertFalse(p:hasSkill("qiao__axe_skill"))
end

function Testqiao_card_reuse:testAdaptedEquipmentSkillsAttachAndDetach()
  local room = FkTest.room
  local p = room.players[1]
  local cases = {
    { "qiao__spear", "qiao__spear_skill" },
    { "qiao__crossbow", "qiao__crossbow_skill" },
    { "qiao__six_swords", "qiao__six_swords_skill" },
    { "qiao__wooden_ox", "qiao__wooden_ox_skill" },
    { "qiao__jade_seal", "qiao__jade_seal_skill" },
    { "qiao__five_elements_fan", "qiao__five_elements_fan_skill" },
    { "qiao__black_chain", "qiao__black_chain_skill" },
    { "qiao__dark_armor", "qiao__dark_armor_skill" },
    { "qiao__eight_diagram", "qiao__eight_diagram_skill" },
    { "qiao__breastplate", "qiao__breastplate_skill" },
    { "qiao__peace_spell", "qiao__peace_spell_skill" },
    { "qiao__luminous_pearl", "qiao__luminous_pearl_skill" },
    { "qiao__dragon_phoenix", "qiao__dragon_phoenix_skill" },
    { "qiao__halberd", "qiao__halberd_skill" },
    { "qiao__kylin_bow", "qiao__kylin_bow_skill" },
    { "qiao__blade", "qiao__blade_skill" },
    { "qiao__liulongcanjia", "qiao__liulongcanjia_skill" },
    { "qiao__taigong_tactics", "qiao__taigong_tactics_skill" },
    { "qiao__wonder_map", "qiao__wonder_map_skill" },
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

function Testqiao_card_reuse:testPassiveEquipmentSkillsAreHiddenButStayAttached()
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
        lu.assertEquals(cardType.equip_skill, "qiao__inert_equip")
        lu.assertFalse(skill.visible)
      end
    end
  end
  lu.assertTrue(passive > 0)
  lu.assertTrue(active > 0)
  lu.assertTrue(Fk.skills["qiao__five_elements_fan_skill"].visible)
  lu.assertTrue(Fk.skills["qiao__five_elements_fan_skill"]:isInstanceOf(ViewAsSkill))
  lu.assertTrue(Fk.skills["qiao__spear_skill"].visible)
  lu.assertTrue(Fk.skills["qiao__luminous_pearl_skill"].visible)
  lu.assertTrue(Fk.skills["qiao__wooden_ox_skill"].visible)
  lu.assertEquals(Fk:translate("qiao__five_elements_fan"), "五行鹤翎扇")
end

function Testqiao_card_reuse:testFiveElementsFanIsClickableViewAsAfterEquip()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("qiao__five_elements_fan")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("qiao__five_elements_fan_skill"))
    lu.assertTrue(Fk.skills["qiao__five_elements_fan_skill"].visible)
    lu.assertEquals(Fk:translate("qiao__five_elements_fan"), "五行鹤翎扇")
    local description = Fk:translate(":qiao__five_elements_fan_skill")
    lu.assertEquals(description, "你可以将一张属性【杀】当任意一种其他属性【杀】使用。")
    lu.assertStrContains(Fk:translate(":qiao__five_elements_fan"), description)
  end)
end

function Testqiao_card_reuse:testWoodenOxUsesPrintedDescriptionInCardAndSkill()
  local text = require "packages.qiao.pkg.qiao_cards.data.equipment_text"
  lu.assertEquals(Fk:translate(":qiao__wooden_ox_skill"), text.qiao__wooden_ox)
  lu.assertStrContains(Fk:translate(":qiao__wooden_ox"), text.qiao__wooden_ox)
end

-- 五行鹤翎扇：单张实体属性【杀】的 ViewAs；结果属性不能与材料相同，实体牌登记为
-- 转化材料的 subcard；普通【杀】、多牌材料与已转化牌都不能作为材料。
function Testqiao_card_reuse:testFiveElementsFanViewAsUsesSingleAttributeSlash()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local fan = card("qiao__five_elements_fan")
  local fire = card("qiao__fire__slash")
  local plain = card("qiao__slash")
  local skill = Fk.skills["qiao__five_elements_fan_skill"]
  local converted
  FkTest.runInRoom(function()
    give(room, p, fan)
    use(room, p, { p }, fan)
    give(room, p, fire)
    give(room, p, plain)
    p.phase = Player.Play
    skill.interaction.data = "qiao__thunder__slash"
    lu.assertTrue(skill:cardFilter(p, fire.id, {}))
    converted = skill:viewAs(p, { fire.id })
    lu.assertNotNil(converted)
    lu.assertEquals(converted.name, "qiao__thunder__slash")
    lu.assertEquals(converted.damage_type, fk.ThunderDamage)
    lu.assertTrue(converted:isVirtual())
    lu.assertEquals(Card:getIdList(converted), { fire.id })
    -- 不能选材料自身的属性。
    skill.interaction.data = "qiao__fire__slash"
    lu.assertNil(skill:viewAs(p, { fire.id }))
    lu.assertFalse(skill:cardFilter(p, fire.id, {}))
    -- 普通【杀】不是属性【杀】，不能转化。
    skill.interaction.data = "qiao__thunder__slash"
    lu.assertNil(skill:viewAs(p, { plain.id }))
    lu.assertFalse(skill:cardFilter(p, plain.id, {}))
    -- 多张材料不是“一张属性【杀】”。
    local fire2 = card("qiao__fire__slash", Card.Diamond, 4)
    give(room, p, fire2)
    lu.assertNil(skill:viewAs(p, { fire.id, fire2.id }))
    -- 真实使用：实体材料随转化牌进入处理区并最终进入弃牌堆。
    FkTest.setNextReplies(t, { "" })
    use(room, p, { t }, converted)
  end)
  lu.assertEquals(room:getCardArea(fire.id), Card.DiscardPile)
end

-- 黑光铠：多目标伤害牌与黑色非伤害锦囊令此牌对装备者无效；单目标不触发。
function Testqiao_card_reuse:testDarkArmorNullifiesMultiTargetCardsOnly()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local armor = card("qiao__dark_armor")
  local slash = card("qiao__slash")
  local archery = card("qiao__archery_attack")
  local chain = card("qiao__iron_chain")
  FkTest.runInRoom(function()
    give(room, p, armor)
    use(room, p, { p }, armor)
    lu.assertTrue(p:hasSkill("qiao__dark_armor_skill"))
    -- 单目标【杀】不是“多目标”，此牌不无效。
    local hp = p.hp
    give(room, t, slash)
    FkTest.setNextReplies(p, { "" })
    use(room, t, { p }, slash)
    lu.assertEquals(p.hp, hp - 1)
    -- 多目标伤害牌：对装备者无效，其他目标照常结算。
    hp = p.hp
    local thp = t.hp
    give(room, t, archery)
    FkTest.setNextReplies(t, { "" })
    use(room, t, { p, t }, archery)
    lu.assertEquals(p.hp, hp)
    lu.assertEquals(t.hp, thp - 1)
    -- 黑色非伤害锦囊：对装备者无效，其他目标照常横置。
    give(room, t, chain)
    FkTest.setNextReplies(t, { "" })
    use(room, t, { p, t }, chain)
    lu.assertFalse(p.chained)
    lu.assertTrue(t.chained)
  end)
end

-- 藤甲：真实装备后，普通【杀】、南蛮入侵和万箭齐发对装备者无效；
-- 火焰伤害 +1；多目标牌仍对其他目标正常结算。
function Testqiao_card_reuse:testVineNullifiesNamedCardsAndAmplifiesFireDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local armor = card("qiao__vine")
  local sendLog = room.sendLog
  local doAnimate = room.doAnimate
  local blocked = {}
  local animations = {}
  room.sendLog = function(self, log, ...)
    if log.type == "#qiao_vine_nullifies" then table.insert(blocked, log.arg) end
    return sendLog(self, log, ...)
  end
  room.doAnimate = function(self, kind, data, ...)
    if kind == "InvokeSkill" and data.name == "qiao__vine_skill" then
      table.insert(animations, { data.player, data.skill_type })
    end
    return doAnimate(self, kind, data, ...)
  end
  FkTest.runInRoom(function()
    clearAllAreas(room)
    give(room, p, armor)
    use(room, p, { p }, armor)
    lu.assertTrue(table.contains(p:getEquipments(), armor.id), "藤甲未进入装备区")
    lu.assertTrue(p:hasSkill("qiao__vine_skill"), "藤甲技能未随装备附上")

    -- 普通【杀】：使用结算开始时即对装备者无效，无需响应【闪】。
    local hp = p.hp
    local slash = card("qiao__slash", Card.Spade, 5)
    give(room, t, slash)
    use(room, t, { p }, slash)
    lu.assertEquals(p.hp, hp, "普通【杀】不应伤害藤甲装备者")

    -- 南蛮入侵：装备者无效，另一目标正常结算且未打出【杀】。
    hp = p.hp
    local thp = t.hp
    local nanman = card("qiao__savage_assault")
    give(room, t, nanman)
    FkTest.setNextReplies(t, { "" })
    use(room, t, { p, t }, nanman)
    lu.assertEquals(p.hp, hp, "南蛮入侵不应伤害藤甲装备者")
    lu.assertEquals(t.hp, thp - 1, "南蛮入侵对其他目标仍应正常结算")

    -- 万箭齐发：装备者无效，另一目标正常结算且未打出【闪】。
    hp = p.hp
    thp = t.hp
    local archery = card("qiao__archery_attack")
    give(room, t, archery)
    FkTest.setNextReplies(t, { "" })
    use(room, t, { p, t }, archery)
    lu.assertEquals(p.hp, hp, "万箭齐发不应伤害藤甲装备者")
    lu.assertEquals(t.hp, thp - 1, "万箭齐发对其他目标仍应正常结算")

    -- 火杀不是普通【杀】，不被无效；火焰伤害 +1。
    hp = p.hp
    local fire = card("qiao__fire__slash", Card.Heart, 4)
    give(room, t, fire)
    use(room, t, { p }, fire)
    lu.assertEquals(p.hp, hp - 2, "藤甲应将实际受到的火焰伤害 +1")
    lu.assertEquals(blocked, { slash.name, nanman.name, archery.name })
    lu.assertEquals(animations, { { p.id, "defensive" }, { p.id, "defensive" }, { p.id, "defensive" } })
  end)
  room.doAnimate = doAnimate
  room.sendLog = sendLog
end

-- 防具忽略机制：青釭剑令藤甲在该次【杀】结算中失效。
function Testqiao_card_reuse:testQinggangSwordIgnoresVine()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local armor = card("qiao__vine")
  local sword = card("qiao__qinggang_sword", Card.Spade, 6)
  FkTest.runInRoom(function()
    clearAllAreas(room)
    give(room, p, armor)
    use(room, p, { p }, armor)
    give(room, t, sword)
    use(room, t, { t }, sword)
    lu.assertTrue(t:hasSkill("#qinggang_sword_skill"), "青釭剑技能未随装备附上")

    local hp = p.hp
    local slash = card("qiao__slash", Card.Club, 3)
    give(room, t, slash)
    use(room, t, { p }, slash)
    lu.assertEquals(p.hp, hp - 1, "青釭剑应令藤甲对该次普通【杀】失效")
    -- 失效只限该次结算，藤甲与技能仍在。
    lu.assertTrue(table.contains(p:getEquipments(), armor.id))
    lu.assertTrue(p:hasSkill("qiao__vine_skill"))
  end)
end

function Testqiao_card_reuse:testBreastplateBPreventsNonLethalTwoDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("qiao__breastplate")
  local hp = p.hp
  local attached, equipped
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    attached = p:hasSkill("qiao__breastplate_skill")
    equipped = table.contains(p:getEquipments(), c.id)
    FkTest.setNextReplies(p, { "1" })
    room:damage { from = t, to = p, damage = 2, damageType = fk.NormalDamage }
  end)
  lu.assertTrue(attached)
  lu.assertTrue(equipped)
  lu.assertEquals(p.hp, hp)
  lu.assertFalse(table.contains(p:getEquipments(), c.id))
end

function Testqiao_card_reuse:testDrowningARequiresEquipmentAndBothOnZhuzhan()
  local room = FkTest.room
  local p, t, bare = room.players[1], room.players[2], room.players[3]
  local c = card("qiao__drowning")
  local weapon = card("qiao__axe")
  local treasure = card("qiao__jade_seal")
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
    local skel = fk.CreateSkill { name = "#qiao_probe_drowning_order" }
    skel:addEffect(fk.DamageInflicted, {
      global = true,
      can_refresh = function(self, event, target, player, damage)
        return target == t and damage.card and damage.card.name == "qiao__drowning"
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

function Testqiao_card_reuse:testBreastplateBAllowsRejection()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("qiao__breastplate")
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

function Testqiao_card_reuse:testBreastplateLethalUsesCurrentHpNotShield()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("qiao__breastplate")
  FkTest.runInRoom(function()
    p.hp = 1
    room:changeShield(p, 1)
    give(room, p, c)
    use(room, p, { p }, c)
    -- 1 点伤害已达到当前体力值，按“致命伤害”口径可以发动；护甲不参与阈值。
    FkTest.setNextReplies(p, { "1" })
    room:damage { from = t, to = p, damage = 1, damageType = fk.NormalDamage }
  end)
  lu.assertFalse(table.contains(p:getEquipments(), c.id))
  lu.assertEquals(p.hp, 1)
  lu.assertEquals(p.shield, 1)
end

function Testqiao_card_reuse:testBreastplatePlaceRequiresEmptyArmorSlot()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("qiao__breastplate")
  local armor = card("qiao__eight_diagram")
  local skill = Fk.skills["qiao__breastplate_place"]
  local cardType = table.find(CardData.types, function(entry) return entry.id == "qiao__breastplate" end)
  FkTest.runInRoom(function()
    give(room, p, c)
    lu.assertNotNil(skill)
    lu.assertTrue(skill:isInstanceOf(ActiveSkill))
    lu.assertTrue(table.contains(cardType.special_skills or {}, "qiao__breastplate_place"))
    lu.assertTrue(table.contains(c.special_skills or {}, "qiao__breastplate_place"))
    lu.assertTrue(skill.targetFilter(skill, p, t, {}, { c.id }, nil, {}))
    room:moveCardTo({ armor.id }, Card.PlayerEquip, t, fk.ReasonPut, "test", nil, true, t)
    lu.assertFalse(skill.targetFilter(skill, p, t, {}, { c.id }, nil, {}))
  end)
end

function Testqiao_card_reuse:testTribladeFollowsRealSlashDamageTarget()
  local room = FkTest.room
  local p, t, other = room.players[1], room.players[2], room.players[3]
  local equipCard = card("qiao__triblade")
  local slash = card("qiao__slash")
  local costCard = card("qiao__peach", Card.Heart, 7)
  local hp = other.hp
  FkTest.runInRoom(function()
    give(room, p, equipCard)
    use(room, p, { p }, equipCard)
    give(room, p, slash)
    give(room, p, costCard)
    local original = room.askToChooseCardsAndPlayers
    room.askToChooseCardsAndPlayers = function()
      return { other }, { costCard.id }, true
    end
    room:useCard(UseCardData:new { from = p, tos = { t }, card = slash, extra_data = {} })
    room.askToChooseCardsAndPlayers = original
  end)
  lu.assertEquals(other.hp, hp - 1)
  lu.assertFalse(table.contains(p:getCardIds("h"), costCard.id))
end

function Testqiao_card_reuse:testDragonPhoenixADiscardsOnSlashTarget()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local equip = card("qiao__dragon_phoenix")
  local slash = card("qiao__slash")
  local victimCard = card("qiao__peach", Card.Heart, 4)
  FkTest.runInRoom(function()
    give(room, p, equip)
    use(room, p, { p }, equip)
    lu.assertTrue(p:hasSkill("qiao__dragon_phoenix_skill"))
    give(room, p, slash)
    give(room, t, victimCard)
    FkTest.setNextReplies(p, { "1" })
    FkTest.setNextReplies(t, { FkTest.ReplyDiscard({ victimCard }), "" })
    local data = UseCardData:new { from = p, tos = { t }, card = slash, extra_data = {} }
    room:useCard(data)
  end)
  lu.assertFalse(table.contains(t:getCardIds("he"), victimCard.id))
end

function Testqiao_card_reuse:testHalberdUsesQiaoEquipSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("qiao__halberd")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("qiao__halberd_skill"))
    lu.assertFalse(p:hasSkill("#sa__halberd_skill"))
  end)
end

function Testqiao_card_reuse:testHalberdExpansionFilterReusesFactionRule()
  local room = FkTest.room
  local p1, p2, p3, p4, p5, p6, p7 =
    room.players[1], room.players[2], room.players[3], room.players[4],
    room.players[5], room.players[6], room.players[7]
  local slash = card("qiao__slash")
  FkTest.runInRoom(function()
    local skill = Fk.skills["#qiao__halberd_active"]
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

function Testqiao_card_reuse:testHalberdExpandedSlashNullifiesRemainingTargetsAfterJink()
  local room = FkTest.room
  local p1, p2, p3 = room.players[1], room.players[2], room.players[3]
  local halberd, slash = card("qiao__halberd"), card("qiao__slash")
  local p2Jink = card("qiao__jink", Card.Heart, 2)
  local p3Jink = card("qiao__jink", Card.Diamond, 3)
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
      FkTest.ReplyUseSkill("#qiao__halberd_active", { p3 }),
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

function Testqiao_card_reuse:testHalberdExpandedSlashWithoutJinkDamagesAllTargets()
  local room = FkTest.room
  local p1, p2, p3 = room.players[1], room.players[2], room.players[3]
  local halberd, slash = card("qiao__halberd"), card("qiao__slash")
  FkTest.runInRoom(function()
    p1.kingdom, p2.kingdom, p3.kingdom = "han", "wei", "shu"
    give(room, p1, halberd)
    use(room, p1, { p1 }, halberd)
    give(room, p1, slash)
    local hp2, hp3 = p2.hp, p3.hp
    FkTest.setNextReplies(p1, {
      FkTest.ReplyUseSkill("#qiao__halberd_active", { p3 }),
    })
    FkTest.setNextReplies(p2, { "" })
    FkTest.setNextReplies(p3, { "" })
    use(room, p1, { p2 }, slash)
    lu.assertEquals(p2.hp, hp2 - 1)
    lu.assertEquals(p3.hp, hp3 - 1)
  end)
end

function Testqiao_card_reuse:testHalberdWithoutExpansionKeepsOtherTargets()
  local room = FkTest.room
  local p1, p2, p3 = room.players[1], room.players[2], room.players[3]
  local halberd, slash = card("qiao__halberd"), card("qiao__slash")
  local jink = card("qiao__jink", Card.Heart, 2)
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

function Testqiao_card_reuse:testBladeUsesHanJinSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("qiao__blade")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("qiao__blade_skill"))
    lu.assertFalse(p:hasSkill("#sa__blade_skill"))
    lu.assertEquals(Fk:translate("qiao__blade_skill"), "青龙偃月刀")
  end)
end

-- 青龙偃月刀：指定目标时逐目标建立限制；目标不能明置、不能使用该花色的手牌；
-- 使用结束后清除。
function Testqiao_card_reuse:testBladeRestrictsTargetRevealAndSuitHand()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local blade = card("qiao__blade")
  local slash = card("qiao__slash", Card.Spade, 5)
  local probe = card("qiao__slash", Card.Spade, 9)
  local seen = {}
  local skel = fk.CreateSkill { name = "#test_blade_probe" }
  skel:addEffect(fk.TargetConfirmed, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == t and player == target
        and data.card ~= nil and data.card.name == "qiao__slash"
    end,
    on_refresh = function(self, event, target, player, data)
      table.insert(seen, {
        reveal = target:prohibitReveal(),
        deputy = target:prohibitReveal(true),
        banned = target:prohibitUse(probe),
      })
    end,
  })
  FkTest.runInRoom(function()
    room:addSkill(skel:createSkill())
    give(room, p, blade)
    use(room, p, { p }, blade)
    give(room, p, slash)
    give(room, t, probe)
    FkTest.setNextReplies(t, { "" })
    use(room, p, { t }, slash)
  end)
  lu.assertEquals(#seen, 1)
  lu.assertTrue(seen[1].reveal)
  lu.assertTrue(seen[1].deputy)
  lu.assertTrue(seen[1].banned)
  -- 结算结束后限制解除，目标不再被禁止。
  lu.assertFalse(t:prohibitReveal())
  lu.assertFalse(t:prohibitUse(probe))
end

-- 无花色【杀】只禁明置，不建立花色限制。
function Testqiao_card_reuse:testBladeWithoutSuitOnlyRestrictsReveal()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local blade = card("qiao__blade")
  local probe = card("qiao__slash", Card.Spade, 9)
  local seen
  local skel = fk.CreateSkill { name = "#test_blade_nosuit_probe" }
  skel:addEffect(fk.TargetConfirmed, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == t and player == target
        and data.card ~= nil and data.card.name == "qiao__slash"
    end,
    on_refresh = function(self, event, target, player, data)
      seen = { reveal = target:prohibitReveal(), banned = target:prohibitUse(probe) }
    end,
  })
  FkTest.runInRoom(function()
    room:addSkill(skel:createSkill())
    give(room, p, blade)
    use(room, p, { p }, blade)
    local first = card("qiao__slash", Card.Heart, 10)
    local second = card("qiao__peach", Card.Heart, 4)
    give(room, p, first)
    give(room, p, second)
    local slash = Fk:cloneCard("qiao__slash")
    slash:addSubcards { first.id, second.id }
    lu.assertEquals(slash.suit, Card.NoSuit)
    give(room, t, probe)
    FkTest.setNextReplies(t, { "" })
    use(room, p, { t }, slash)
  end)
  lu.assertNotNil(seen)
  lu.assertTrue(seen.reveal)
  lu.assertFalse(seen.banned)
end

function Testqiao_card_reuse:testLiulongUsesHanJinDualMountSkill()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("qiao__liulongcanjia")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("qiao__liulongcanjia_skill"))
    lu.assertFalse(p:hasSkill("#liulongcanjia_skill"),
      "汉晋六龙骖驾不沿用上游固定±1坐骑技能")
    lu.assertEquals(p:getMark("@@liulongcanjia"), 0,
      "不再使用上游的坐骑封锁标记")
  end)
end

function Testqiao_card_reuse:testLuminousAInstallsZhiheng()
  local room = FkTest.room
  local p = room.players[1]
  local c = card("qiao__luminous_pearl")
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("qiao__luminous_pearl_skill"))
  end)
end

function Testqiao_card_reuse:testPeaceAPreventsAttributeDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local c = card("qiao__peace_spell")
  local hp = p.hp
  FkTest.runInRoom(function()
    give(room, p, c)
    use(room, p, { p }, c)
    lu.assertTrue(p:hasSkill("qiao__peace_spell_skill"))
    room:damage { from = t, to = p, damage = 2, damageType = fk.FireDamage }
  end)
  lu.assertEquals(p.hp, hp)
end


function Testqiao_card_reuse:testDragonPhoenixDyingTakesActualTargetHand()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local equip = card("qiao__dragon_phoenix")
  local slash = card("qiao__slash")
  local victimCard = card("qiao__peach", Card.Heart, 4)
  FkTest.runInRoom(function()
    give(room, p, equip)
    use(room, p, { p }, equip)
    give(room, p, slash)
    give(room, t, victimCard)
    t.hp = 1
    local save = card("qiao__peach", Card.Heart, 7)
    give(room, p, save)
    FkTest.setNextReplies(p, { "0", "1", victimCard.id, FkTest.ReplyCard(Fk:getCardById(save.id), { t }) })
    use(room, p, { t }, slash)
  end)
  lu.assertTrue(table.contains(p:getCardIds("h"), victimCard.id),
    "飞龙夺凤应在求桃前获得实际目标的一张手牌")
  lu.assertFalse(t.dead, "求桃后目标存活")
end

function Testqiao_card_reuse:testDragonPhoenixIgnoresNonTargetChainDamage()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local equip = card("qiao__dragon_phoenix")
  local slash = card("qiao__slash")
  local victimCard = card("qiao__peach", Card.Heart, 4)
  FkTest.runInRoom(function()
    give(room, p, equip)
    use(room, p, { p }, equip)
    give(room, t, victimCard)
    t.hp = 1
    room:damage {
      from = p, to = t, damage = 1, card = slash,
      damageType = fk.NormalDamage, chain = true,
    }
  end)
  lu.assertFalse(table.contains(p:getCardIds("h"), victimCard.id),
    "连环传导波及的非实际目标不触发飞龙夺凤")
end

function Testqiao_card_reuse:testLuminousPearlIndependentDiscardDraw()
  local room = FkTest.room
  local p = room.players[1]
  local pearl = card("qiao__luminous_pearl")
  local c1 = card("qiao__jink")
  local c2 = card("qiao__peach")
  local handBefore
  FkTest.runInRoom(function()
    give(room, p, pearl)
    use(room, p, { p }, pearl)
    give(room, p, c1)
    give(room, p, c2)
    if Fk.skills["hs__zhiheng"] then
      room:handleAddLoseSkills(p, { "hs__zhiheng" }, nil, false, true)
    end
    lu.assertTrue(p:hasSkill("qiao__luminous_pearl_skill"), "夜明珠技能与制衡并存")
    local skill = Fk.skills["qiao__luminous_pearl_skill"]
    lu.assertFalse(skill:cardFilter(p, pearl.id, {}, {}),
      "提供技能的夜明珠本身不能用于该次弃置")
    lu.assertTrue(skill:cardFilter(p, c1.id, {}, {}))
    local data = { from = p, cards = { c1.id, c2.id }, tos = {} }
    handBefore = #p:getCardIds("h")
    local invoked = 0
    local sendLog = room.sendLog
    room.sendLog = function(self, log)
      if log.type == "#InvokeSkill" and log.arg == skill.name then invoked = invoked + 1 end
      return sendLog(self, log)
    end
    room:useSkill(p, skill, function() skill:onUse(room, data) end, data)
    room.sendLog = sendLog
    lu.assertEquals(invoked, 1)
  end)
  lu.assertEquals(room:getCardArea(c1.id), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(c2.id), Card.DiscardPile)
  lu.assertEquals(#p:getCardIds("h"), handBefore, "弃置两张后摸两张")
  lu.assertEquals(p:usedSkillTimes("qiao__luminous_pearl_skill", Player.HistoryPhase), 1)
  if Fk.skills["hs__zhiheng"] then
    lu.assertEquals(p:usedSkillTimes("hs__zhiheng", Player.HistoryPhase), 0,
      "夜明珠与制衡分别计次")
  end
end

function Testqiao_card_reuse:testPeaceSpellHandLimitUsesPublicQunCount()
  local room = FkTest.room
  local p, ally = room.players[1], room.players[2]
  local peace = card("qiao__peace_spell")
  local tianCard = card("qiao__peach", Card.Heart, 6)
  local oldCard = card("qiao__peach", Card.Heart, 7)
  FkTest.runInRoom(function()
    for _, other in ipairs(room.players) do
      if other == p or other == ally then
        other.kingdom = "qun"
      else
        other.kingdom = "wei"
      end
      other.role = other.kingdom
    end
    give(room, p, peace)
    use(room, p, { p }, peace)
    lu.assertEquals(p:getMaxCards(), p.hp + 2, "同势力人数含装备者自己")
    give(room, p, tianCard)
    local Qun = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"
    room:handleAddLoseSkills(p, Qun.HONGFA, nil, false, true)
    Qun.add(p, { tianCard.id }, "test")
    lu.assertEquals(p:getMaxCards(), p.hp + 3, "群天兵通过公共人数口径计入")
    give(room, p, oldCard)
    p:addToPile("heavenly_army", { oldCard.id }, true, "test")
    lu.assertEquals(p:getMaxCards(), p.hp + 3, "旧 heavenly_army 不重复叠加")
  end)
end

function Testqiao_card_reuse:testPeaceSpellLossDrawsThenLosesHp()
  local room = FkTest.room
  local p = room.players[1]
  local peace = card("qiao__peace_spell")
  local handBefore
  FkTest.runInRoom(function()
    give(room, p, peace)
    use(room, p, { p }, peace)
    p.hp = 3
    handBefore = #p:getCardIds("h")
    room:moveCardTo(peace.id, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      "test", nil, true, p)
    lu.assertEquals(#p:getCardIds("h"), handBefore + 2, "失去太平要术后先摸两张")
    lu.assertEquals(p.hp, 2, "摸牌后体力大于1则失去1点")
  end)
end

function Testqiao_card_reuse:testLordEquipmentTemplateEntityAndDescriptionSync()
  local pack = assert(Fk.packages.qiao_cards)
  local cases = {
    { "qiao__dragon_phoenix", "qiao__dragon_phoenix_skill", "武器" },
    { "qiao__luminous_pearl", "qiao__luminous_pearl_skill", "宝物" },
    { "qiao__peace_spell", "qiao__peace_spell_skill", "防具" },
  }
  for _, case in ipairs(cases) do
    local name, skillName, label = case[1], case[2], case[3]
    local template = assert(Fk.all_card_types[name], "missing template " .. name)
    local entity = assert(table.find(pack.cards, function(c) return c.name == name end),
      "missing entity " .. name)
    lu.assertEquals(template.equip_skill.name, skillName)
    lu.assertEquals(entity.equip_skill.name, skillName)
    lu.assertEquals(template.skill.name, entity.skill.name)
    local description = Fk:translate(":" .. name)
    lu.assertTrue(description:find(label, 1, true) ~= nil, "牌面缺少类别 " .. name)
    lu.assertNil(description:find("尚未实装", 1, true), "正式牌面不应仍是空壳 " .. name)
  end
end

function Testqiao_card_reuse:testTargetCardsUsePrintedDescriptionsAfterPostLoad()
  -- 初始化后的上游复制曾覆盖本地翻译；这批牌必须以汉晋印刷牌面为准。
  local cases = {
    { "qiao__iron_chain", { "一至两名角色", "目标角色横置或重置", "重铸" }, { "武将牌" } },
    { "qiao__known_both", { "有手牌或暗置武将牌", "手牌或一张暗置武将牌", "重铸" }, { "或其手牌" } },
    { "qiao__fight_together", { "所有大势力角色或所有小势力角色", "若其已横置", "重铸" }, { "不处于连环状态" } },
    { "qiao__snatch", { "距离1且区域里有牌", "区域里的一张牌" }, { "区域内有牌" } },
    { "qiao__savage_assault", { "依次选择一项", "打出一张【杀】" }, { "否则受到" } },
    { "qiao__archery_attack", { "依次选择一项", "打出一张【闪】" }, { "否则受到" } },
    { "qiao__lightning", { "延时锦囊牌", "黑桃2～9", "移动给其下家" }, { "判定区内" } },
    { "qiao__qinggang_sword", { "攻击范围</b>：2", "防具无效", "直到此【杀】结算结束" }, { "无视目标角色的防具" } },
    { "qiao__black_chain", { "攻击范围</b>：3", "你令其横置" }, { "武将牌" } },
    { "qiao__halberd", { "攻击范围</b>：4", "不与其余目标势力相同", "对剩余目标无效" }, { "最后的手牌" } },
    { "qiao__befriend_attacking", { "一名与你势力不同的其他角色", "若此牌对任意目标生效过，你摸三张牌" }, { "有明置武将" } },
    { "qiao__alliance_feast", { "你和一个不同势力的所有角色", "选择X次", "回复1点体力" }, { "X为该势力存活角色数" } },
    { "qiao__chasing_near", { "一名其他角色", "距离大于1", "距离为1" }, { "区域里有牌的其他角色" } },
    -- 本批四张：牌面按《锦囊装备》印刷文字，不能沿用上游措辞或空壳说明。
    { "qiao__blade", { "攻击范围</b>：3", "不能明置武将牌", "不能使用此【杀】花色的手牌", "直到此【杀】结算结束" }, { "武将牌横置" } },
    { "qiao__five_elements_fan", { "攻击范围</b>：4", "将一张属性【杀】", "任意一种其他属性【杀】" }, { "改为雷【杀】", "非普通【杀】" } },
    { "qiao__bronze_sparrow", { "每回合限一次", "使用应变牌时", "无视条件应变" }, { "锁定技", "无需强化条件" } },
    { "qiao__dark_armor", { "伤害牌或黑色非伤害锦囊牌", "唯一目标", "此牌对你无效" }, { "伤害锦囊或黑色锦囊" } },
    { "qiao__vine", { "【南蛮入侵】、【万箭齐发】和普通【杀】对你无效", "当你受到火焰伤害时，此伤害+1" }, { "每当你受到火焰伤害时" } },
  }
  for _, case in ipairs(cases) do
    local description = Fk:translate(":" .. case[1])
    for _, expected in ipairs(case[2]) do
      lu.assertNotNil(description:find(expected, 1, true), case[1] .. " 缺少：" .. expected)
    end
    for _, unexpected in ipairs(case[3] or {}) do
      lu.assertNil(description:find(unexpected, 1, true), case[1] .. " 仍含上游措辞：" .. unexpected)
    end
    lu.assertNil(description:find("尚未实装", 1, true), case[1] .. " 不应是空壳牌面")
  end
end

function Testqiao_card_reuse:testRecastEntrySurvivesForPrintedRecastCards()
  local pack = assert(Fk.packages.qiao_cards)
  for _, name in ipairs({ "qiao__iron_chain", "qiao__known_both", "qiao__fight_together" }) do
    local template = assert(Fk.all_card_types[name], "missing template " .. name)
    lu.assertTrue(table.contains(template.special_skills or {}, "recast"), name .. " 模板缺少重铸入口")
    local entity = assert(table.find(pack.cards, function(c) return c.name == name end),
      "missing entity " .. name)
    lu.assertTrue(table.contains(entity.special_skills or {}, "recast"), name .. " 实体缺少重铸入口")
  end
end

function Testqiao_card_reuse:testDynamicAdaptationAndAllianceDescriptionsRemain()
  local snatch = card("qiao__snatch", Card.Diamond, 3)
  local snatchDescription = snatch:getDynamicDescription()
  lu.assertNotNil(snatchDescription:find("<b>合纵</b>", 1, true), "顺手牵羊·合缺少合纵标记")
  lu.assertNotNil(snatchDescription:find("距离1且区域里有牌", 1, true), "动态描述丢失基础牌面")

  local savage = card("qiao__savage_assault", Card.Club, 7)
  local savageDescription = savage:getDynamicDescription()
  lu.assertNotNil(savageDescription:find("<b>应变·富甲</b>：目标-1", 1, true),
    "南蛮入侵·富甲缺少动态应变")
end

function Testqiao_card_reuse:testBefriendAttackingDrawsThreeOnlyOnceForMultipleTargets()
  local room = FkTest.room
  local p1, p2, p3 = room.players[1], room.players[2], room.players[3]
  local data
  FkTest.runInRoom(function()
    clearAllAreas(room)
    p1.kingdom, p2.kingdom, p3.kingdom = "han", "wei", "shu"
    local clone = Fk:cloneCard("qiao__befriend_attacking")
    A.setCardEntries(clone, { { id = "probe_add", condition = "kongchao", effect = "add_target" } })
    local original = room.askToChoosePlayers
    room.askToChoosePlayers = function(self, player, params)
      if params.skill_name == "#qiao_adaptation_rule" then return { p3 } end
      return original(self, player, params)
    end
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    data = UseCardData:new { from = p1, tos = { p2 }, card = clone, extra_data = {} }
    room:useCard(data)
    room.askToChoosePlayers = original
  end)
  lu.assertTrue(table.contains(data.tos, p3), "额外目标应已加入")
  lu.assertEquals(#p1:getCardIds("h"), 3, "多目标远交近攻只摸三张一次")
  lu.assertEquals(#p2:getCardIds("h"), 1)
  lu.assertEquals(#p3:getCardIds("h"), 1)
end

function Testqiao_card_reuse:testBefriendAttackingStillDrawsOnceWhenFirstTargetIsNullified()
  local room = FkTest.room
  local p1, p2, p3 = room.players[1], room.players[2], room.players[3]
  FkTest.runInRoom(function()
    clearAllAreas(room)
    p1.kingdom, p2.kingdom, p3.kingdom = "han", "wei", "shu"
    local skel = fk.CreateSkill { name = "#qiao_test_nullify_befriend_first" }
    skel:addEffect(fk.PreCardEffect, {
      global = true,
      priority = 100,
      can_trigger = function(self, event, target, player, data)
        return data.card ~= nil and data.card.name == "qiao__befriend_attacking"
          and data.to == p2
      end,
      on_cost = Util.TrueFunc,
      on_use = function(self, event, target, player, data)
        data:setNullified(data.to)
      end,
    })
    local probe = skel:createSkill()
    Fk.skills[probe.name] = probe
    for _, related in ipairs(probe.related_skills or {}) do
      Fk.skills[related.name] = related
    end
    room:addSkill(probe)
    local clone = Fk:cloneCard("qiao__befriend_attacking")
    A.setCardEntries(clone, { { id = "probe_add", condition = "kongchao", effect = "add_target" } })
    local original = room.askToChoosePlayers
    room.askToChoosePlayers = function(self, player, params)
      if params.skill_name == "#qiao_adaptation_rule" then return { p3 } end
      return original(self, player, params)
    end
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    room:useCard(UseCardData:new { from = p1, tos = { p2 }, card = clone, extra_data = {} })
    room.askToChoosePlayers = original
  end)
  lu.assertEquals(#p1:getCardIds("h"), 3, "首名目标被抵消后仍应在首个生效目标摸三张一次")
  lu.assertEquals(#p2:getCardIds("h"), 0)
  lu.assertEquals(#p3:getCardIds("h"), 1)
end

function Testqiao_card_reuse:testBefriendAttackingDrawsNothingWhenAllTargetsAreNullified()
  local room = FkTest.room
  local p1, p2, p3 = room.players[1], room.players[2], room.players[3]
  FkTest.runInRoom(function()
    clearAllAreas(room)
    p1.kingdom, p2.kingdom, p3.kingdom = "han", "wei", "shu"
    local skel = fk.CreateSkill { name = "#qiao_test_nullify_befriend_all" }
    skel:addEffect(fk.PreCardEffect, {
      global = true,
      priority = 100,
      can_trigger = function(self, event, target, player, data)
        return data.card ~= nil and data.card.name == "qiao__befriend_attacking"
      end,
      on_cost = Util.TrueFunc,
      on_use = function(self, event, target, player, data)
        data:setNullified(data.to)
      end,
    })
    local probe = skel:createSkill()
    Fk.skills[probe.name] = probe
    for _, related in ipairs(probe.related_skills or {}) do
      Fk.skills[related.name] = related
    end
    room:addSkill(probe)
    local clone = Fk:cloneCard("qiao__befriend_attacking")
    A.setCardEntries(clone, { { id = "probe_add", condition = "kongchao", effect = "add_target" } })
    local original = room.askToChoosePlayers
    room.askToChoosePlayers = function(self, player, params)
      if params.skill_name == "#qiao_adaptation_rule" then return { p3 } end
      return original(self, player, params)
    end
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    room:useCard(UseCardData:new { from = p1, tos = { p2 }, card = clone, extra_data = {} })
    room.askToChoosePlayers = original
  end)
  lu.assertEquals(#p1:getCardIds("h"), 0, "全部被抵消时使用者不摸")
  lu.assertEquals(#p2:getCardIds("h"), 0)
  lu.assertEquals(#p3:getCardIds("h"), 0)
end

function Testqiao_card_reuse:testAllianceFeastResolvesUserMixedChoicesBeforeOtherTargets()
  local room = FkTest.room
  local p1, p2, p3 = room.players[1], room.players[2], room.players[3]
  local seen = {}
  FkTest.runInRoom(function()
    clearAllAreas(room)
    p1.hp = p1.maxHp - 1
    for _, q in ipairs(room.players) do
      q.kingdom, q.role = "wei", "wei"
    end
    p1.kingdom, p2.kingdom, p3.kingdom = "han", "shu", "shu"
    p2:setChainState(true)
    p3:setChainState(true)
    local c = give(room, p1, card("qiao__alliance_feast"))
    local original = room.askToChoice
    local answers = { "alliance_feast_recover:::1", "alliance_feast_draw:::1" }
    room.askToChoice = function(self, player, params)
      if params.skill_name == "alliance_feast_skill" then
        lu.assertEquals(table.contains(params.choices, "alliance_feast_recover:::1"), #seen == 0)
        table.insert(seen, {
          hand2 = #p2:getCardIds("h"),
          hand3 = #p3:getCardIds("h"),
        })
        return table.remove(answers, 1)
      end
      return original(self, player, params)
    end
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    room:useCard(UseCardData:new { from = p1, tos = { p2 }, card = c, extra_data = {} })
    room.askToChoice = original
  end)
  lu.assertEquals(#seen, 2, "使用者应按其他最终目标数选择两次")
  lu.assertEquals(seen[1].hand2, 0, "使用者结算时其他目标尚未摸牌")
  lu.assertEquals(seen[1].hand3, 0, "使用者结算时其他目标尚未摸牌")
  lu.assertEquals(seen[2].hand2, 0, "逐次选择期间其他目标仍未结算")
  lu.assertEquals(seen[2].hand3, 0, "逐次选择期间其他目标仍未结算")
  lu.assertEquals(p1.hp, p1.maxHp, "第一次选择回复1点体力")
  lu.assertEquals(#p1:getCardIds("h"), 1, "第二次选择摸一张牌")
  lu.assertEquals(#p2:getCardIds("h"), 1, "其他目标各摸一张")
  lu.assertEquals(#p3:getCardIds("h"), 1, "其他目标各摸一张")
  lu.assertFalse(p2.chained, "其他目标重置")
  lu.assertFalse(p3.chained, "其他目标重置")
end

function Testqiao_card_reuse:testChasingNearCanTargetAnEmptyOtherRole()
  local room = FkTest.room
  local p1, p2 = room.players[1], room.players[2]
  local c
  local asked = 0
  FkTest.runInRoom(function()
    clearAllAreas(room)
    c = give(room, p1, card("qiao__chasing_near"))
    lu.assertTrue(p2:isAllNude(), "前置：目标区域无牌")
    lu.assertEquals(p1:distanceTo(p2), 1)
    lu.assertTrue(p1:canUseTo(c, p2), "逐近弃远可以指定无牌的其他角色")
    local original = room.askToChooseCard
    room.askToChooseCard = function(...)
      asked = asked + 1
      return original(...)
    end
    for _, q in ipairs(room.players) do FkTest.setNextReplies(q, { "" }) end
    room:useCard(UseCardData:new { from = p1, tos = { p2 }, card = c, extra_data = {} })
    room.askToChooseCard = original
  end)
  lu.assertEquals(asked, 0, "目标区域无牌时不发起选牌")
  lu.assertTrue(p2:isAllNude())
  lu.assertEquals(room:getCardArea(c.id), Card.DiscardPile)
end

-- 麒麟弓：选牌请求以 card_data 表给出坐骑候选，引擎只对区域字符串自动生成
-- "#AskForChooseCard:..."，表形式必须由技能自带 prompt。
--
-- 只走一次真实流程：AskForCardChosen 询问的是伤害来源 p（params.target 只是
-- 被弃牌者 t），回复队列必须在 p 上依次给出“发动技能”和“所选坐骑”；请求完成后
-- room.last_request 就是本次 AskForCardChosen。随后把同一份真实 payload 交给
-- 崩溃所在的 SmartAI:handleAskForCardChosen，避免另起流程。
--
-- 断言玩家对象使用 assertIs（引用比较）。LuaUnit 的 assertEquals 对 table 会
-- 深度遍历，ServerPlayer 经 room/engine 形成大对象图，曾使套件在该用例超时。
function Testqiao_card_reuse:testKylinBowRealRequestCarriesFullPromptAndDiscardsMount()
  local room = FkTest.room
  local p, t = room.players[1], room.players[2]
  local seen
  FkTest.runInRoom(function()
    clearAllAreas(room)
    local bow = give(room, p, card("qiao__kylin_bow"))
    use(room, p, { p }, bow)
    lu.assertTrue(p:hasSkill("qiao__kylin_bow_skill"))
    local offensive = give(room, t, card("qiao__chitu"))
    local defensive = give(room, t, card("qiao__jueying"))
    local weapon = give(room, t, card("qiao__axe"))
    room:moveCardTo({ offensive.id }, Card.PlayerEquip, t, fk.ReasonPut, "test", nil, true, t)
    room:moveCardTo({ defensive.id }, Card.PlayerEquip, t, fk.ReasonPut, "test", nil, true, t)
    room:moveCardTo({ weapon.id }, Card.PlayerEquip, t, fk.ReasonPut, "test", nil, true, t)
    local slash = give(room, p, card("qiao__slash"))
    skill_test.withSkillRequests(room, "qiao__kylin_bow_skill", {
      askToChooseCard = function(self, player, params, original)
        seen = {
          player = player, target = params.target, prompt = params.prompt,
          flag = params.flag, request = nil, requested = nil, chosen = nil,
        }
        local id = original(self, player, params)
        local request = room.last_request
        if request ~= nil and request.command == "AskForCardChosen" then
          seen.request = request.data[player.id]
          seen.requested = request.players[1]
        end
        seen.chosen = id
        return id
      end,
    }, function()
      FkTest.setNextReplies(p, { "1", offensive.id })
      FkTest.setNextReplies(t, { "" })
      use(room, p, { t }, slash)
    end)

    lu.assertNotNil(seen, "麒麟弓未发起选牌请求")
    -- AskForCardChosen 询问伤害来源 p；target 只是被弃牌者 t。
    lu.assertIs(seen.player, p, "AskForCardChosen 必须询问伤害来源")
    lu.assertIs(seen.target, t)
    lu.assertIs(seen.requested, p, "请求参与者应为被询问的伤害来源")
    lu.assertIs(seen.chosen, offensive.id, "回复顺序：先发动技能，再选坐骑")
    local prompt = "#AskForChooseCard:" .. t.id .. "::qiao__kylin_bow_skill"
    lu.assertEquals(seen.prompt, prompt)
    -- AI 的 handleAskForCardChosen 用 prompt:split(":")[4] 取技能名。
    lu.assertEquals(seen.prompt:split(":")[4], "qiao__kylin_bow_skill")
    lu.assertNotNil(seen.request, "缺少真实 AskForCardChosen 请求")
    lu.assertEquals(#seen.request, 3, "请求数据应为 target/flag/prompt")
    lu.assertIs(seen.request[1], t)
    lu.assertIs(seen.request[2], seen.flag)
    lu.assertEquals(seen.request[3], prompt)
    local candidates = seen.flag.card_data[1][2]
    lu.assertEquals(#candidates, 2, "候选应恰好是两张坐骑")
    lu.assertTrue(table.contains(candidates, offensive.id))
    lu.assertTrue(table.contains(candidates, defensive.id))
    lu.assertFalse(table.contains(candidates, weapon.id), "非坐骑装备不能成为候选")
    lu.assertEquals(room:getCardArea(offensive.id), Card.DiscardPile)
    lu.assertFalse(table.contains(t:getCardIds("e"), offensive.id))
    lu.assertTrue(table.contains(t:getCardIds("e"), defensive.id), "只弃置所选坐骑")
    lu.assertTrue(table.contains(t:getCardIds("e"), weapon.id), "其他装备不受影响")

    -- 同一真实 payload：prompt 为 nil 时这里会在 prompt:split 崩溃；修复后
    -- AI 正常返回 nil（未注册 CardChosenStrategy），由服务端按候选兜底。
    local ok, reply = pcall(function()
      return p.ai:handleAskForCardChosen(seen.request)
    end)
    lu.assertTrue(ok, tostring(reply))
    lu.assertNil(reply, "未注册 CardChosenStrategy 时 AI 不应自行选牌")
  end)
end

return { name = "qiao_card_reuse" }

