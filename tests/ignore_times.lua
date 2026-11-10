local support = __dofile("../../../tests/support/hegemony.lua")
local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
Testhanjin_ignore_times = { setup = support.initHanjinRoom, tearDown = support.clearRoom }

local CARD_NAME = "hanjin__thunder__slash"

local function physical(suit, number)
  return assert(table.find(Fk.cards, function(card)
    return card.name == CARD_NAME and card.suit == suit and card.number == number
  end), "Missing physical HanJin Thunder Slash")
end

local function setSlashHistory(player, n)
  player.cardUsedHistory["slash"] = { n, n, n, n }
end

local function prepare(player, room)
  player.phase = Player.Play
  player.kingdom = "han"
  player.role = "han"
  player.hp = 4
  setSlashHistory(player, 0)
  for index, p in ipairs(room.players) do
    if index > 1 then
      p.kingdom = "wei"
      p.role = "wei"
    end
  end
end

local function give(room, player, card)
  if not table.contains(player:getCardIds("h"), card.id) then
    room:obtainCard(player, card.id, true, fk.ReasonJustMove, player, "test")
  end
  return card
end

local function use(room, player, target, card)
  FkTest.setNextReplies(target, { "" })
  local data = UseCardData:new { from = player, tos = { target }, card = card, extra_data = {} }
  room:useCard(data)
  return data
end

function Testhanjin_ignore_times:testFormalPackHasExactlySpadeNineAndTenWithThunderSlashData()
  local cards = table.filter(Fk.cards, function(card) return card.name == CARD_NAME end)
  lu.assertEquals(#cards, 2)
  local nine, ten = physical(Card.Spade, 9), physical(Card.Spade, 10)
  lu.assertEquals(nine.package, Fk.packages.hanjin_cards)
  lu.assertEquals(ten.package, Fk.packages.hanjin_cards)
  lu.assertEquals(nine.extensionName or nine.package.extensionName, "hanjin")
  lu.assertNotEquals(nine.id, ten.id)
  for _, card in ipairs({ nine, ten }) do
    lu.assertEquals(card.trueName, "slash")
    lu.assertEquals(card.type, Card.TypeBasic)
    lu.assertEquals(card.damage_type, fk.ThunderDamage)
    lu.assertEquals(card.skill.name, "hanjin__thunder_slash_skill")
    lu.assertNotEquals(card.skill.name, "slash_skill")
    lu.assertNotEquals(card.skill.name, "thunder__slash_skill")
    lu.assertTrue(A.isAdaptationCard(card))
    local entries = A.getEntries(card)
    lu.assertEquals(#entries, 1)
    lu.assertEquals(entries[1].condition, "gujun")
    lu.assertEquals(entries[1].effect, "ignore_times")
  end
  local specs = Fk.packages.hanjin_cards.card_specs
  lu.assertEquals(#specs, 2)
  for _, spec in ipairs(specs) do
    lu.assertEquals(spec[1], CARD_NAME)
    lu.assertEquals(spec[2], Card.Spade)
    lu.assertTrue(spec[3] == 9 or spec[3] == 10)
  end
  -- Both formal cards enter this room's actual deck; they are not printed on demand.
  local room = FkTest.room
  local inRoom = {}
  local function scan(ids) for _, id in ipairs(ids) do inRoom[id] = true end end
  scan(room.draw_pile)
  for _, p in ipairs(room.players) do scan(p:getCardIds("he")) end
  lu.assertTrue(inRoom[nine.id])
  lu.assertTrue(inRoom[ten.id])
end

function Testhanjin_ignore_times:testSelectionAndTargetingOnlyExemptTheLimitWithoutSideEffects()
  local room = FkTest.room
  local player, adjacent, distant = room.players[1], room.players[2], room.players[4]
  local card = physical(Card.Spade, 9)
  local events = 0
  local skel = fk.CreateSkill { name = "#hanjin_test_ignore_times_selection_observer" }
  skel:addEffect(A.Triggered, {
    global = true,
    can_refresh = function(self, event, target, player, data) return target == player end,
    on_refresh = function() events = events + 1 end,
  })
  FkTest.runInRoom(function()
    prepare(player, room)
    give(room, player, card)
    setSlashHistory(player, 1)
    room:addSkill(skel:createSkill())
    local hand = player:getHandcardNum()
    lu.assertTrue(player:canUse(card))
    lu.assertTrue(player:canUseTo(card, adjacent))
    lu.assertNotIsTrue(player:canUseTo(card, distant))
    local targets = card:getAvailableTargets(player)
    lu.assertTrue(table.contains(targets, adjacent))
    lu.assertFalse(table.contains(targets, distant))
    -- Query only. No lock, token, effect, draw, discard or success event.
    lu.assertEquals(player:getHandcardNum(), hand)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 1)
    lu.assertEquals(events, 0)
  end)
end

function Testhanjin_ignore_times:testGujunRequiresKnownKingdomAndNoLivingSameKingdomPlayer()
  local room = FkTest.room
  local player = room.players[1]
  local card = physical(Card.Spade, 9)
  FkTest.runInRoom(function()
    prepare(player, room)
    give(room, player, card)
    setSlashHistory(player, 1)
    lu.assertTrue(player:canUse(card))
    player.kingdom = "unknown"
    lu.assertNotIsTrue(player:canUse(card))
    player.kingdom = "han"
    room.players[3].kingdom = "han"
    room.players[3].role = "han"
    lu.assertNotIsTrue(player:canUse(card))
    room.players[3].kingdom = "wei"
    room.players[3].role = "wei"
    lu.assertTrue(player:canUse(card))
  end)
end

function Testhanjin_ignore_times:testFullLimitUseUnderGujunDoesNotCountButStillDealsThunderDamage()
  local room = FkTest.room
  local player, target = room.players[1], room.players[2]
  local card = physical(Card.Spade, 9)
  local damageType
  local skel = fk.CreateSkill { name = "#hanjin_test_ignore_times_damage_observer" }
  skel:addEffect(fk.DamageInflicted, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == player and data.card and data.card.name == CARD_NAME
    end,
    on_refresh = function(self, event, target, player, data) damageType = data.damageType end,
  })
  FkTest.runInRoom(function() room:addSkill(skel:createSkill()) end)
  local data
  local hp = target.hp
  FkTest.runInRoom(function()
    prepare(player, room)
    give(room, player, card)
    setSlashHistory(player, 1)
    data = use(room, player, target, card)
  end)
  lu.assertEquals(target.hp, hp - 1)
  lu.assertEquals(damageType, fk.ThunderDamage)
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 1)
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryTurn), 1)
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryRound), 1)
  lu.assertTrue(A.getResult(data).triggered)
  lu.assertEquals(A.getResult(data).triggered_count, 1)
  lu.assertEquals(A.getResult(data).effects.ignore_times, 1)
  lu.assertTrue(A.getResult(data).entries[1].triggered)
  lu.assertTrue(A.getResult(data).entries[1].satisfied)
end

function Testhanjin_ignore_times:testUnderTheLimitGujunUseAlsoDoesNotCount()
  local room = FkTest.room
  local player, target = room.players[1], room.players[2]
  local card = physical(Card.Spade, 10)
  local data
  FkTest.runInRoom(function()
    prepare(player, room)
    give(room, player, card)
    setSlashHistory(player, 0)
    data = use(room, player, target, card)
  end)
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 0)
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryTurn), 0)
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryRound), 0)
  lu.assertEquals(A.getResult(data).triggered_count, 1)
end

function Testhanjin_ignore_times:testWithoutGujunFullLimitIsUnavailableAndNormalUseCounts()
  local room = FkTest.room
  local player, target = room.players[1], room.players[2]
  local card = physical(Card.Spade, 9)
  local data
  FkTest.runInRoom(function()
    prepare(player, room)
    player.kingdom = "unknown"
    give(room, player, card)
    setSlashHistory(player, 1)
    lu.assertNotIsTrue(player:canUse(card))
    lu.assertNotIsTrue(player:canUseTo(card, target))
    setSlashHistory(player, 0)
    data = use(room, player, target, card)
  end)
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 1)
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryTurn), 1)
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryRound), 1)
  lu.assertFalse(A.getResult(data).triggered)
  lu.assertNil(A.getResult(data).effects.ignore_times)
end

function Testhanjin_ignore_times:testGujunLostAfterOneExemptUseMakesTheNextUseCountAndThenBlock()
  local room = FkTest.room
  local player, target = room.players[1], room.players[2]
  local nine, ten = physical(Card.Spade, 9), physical(Card.Spade, 10)
  local first, second
  FkTest.runInRoom(function()
    prepare(player, room)
    give(room, player, nine)
    give(room, player, ten)
    setSlashHistory(player, 0)
    first = use(room, player, target, nine)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 0)
    -- A living same-kingdom player ends 孤军; the next use is not exempt.
    room.players[3].kingdom = "han"
    room.players[3].role = "han"
    lu.assertTrue(player:canUse(ten))
    second = use(room, player, target, ten)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 1)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryTurn), 1)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryRound), 1)
    -- Now the ordinary limit is full and 孤军 is gone, so no further use.
    lu.assertNotIsTrue(player:canUse(nine))
  end)
  lu.assertTrue(A.getResult(first).triggered)
  lu.assertFalse(A.getResult(second).triggered)
end

local function lateStateChange(room, player, kingdom)
  local skel = fk.CreateSkill { name = "#hanjin_test_ignore_times_late_state_change" }
  skel:addEffect(fk.PreCardUse, {
    global = true, priority = -200,
    can_trigger = function(self, event, target, p, data)
      return target == p and p == player and data.card.name == CARD_NAME
    end,
    on_cost = Util.TrueFunc,
    on_use = function() player.kingdom = kingdom end,
  })
  local skill = skel:createSkill()
  Fk.skills[skill.name] = skill
  room:addSkill(skill)
end

function Testhanjin_ignore_times:testLockedGujunSurvivesAStateLossBeforeResolution()
  local room = FkTest.room
  local player, target = room.players[1], room.players[2]
  local card = physical(Card.Spade, 9)
  local data
  FkTest.runInRoom(function()
    prepare(player, room)
    give(room, player, card)
    setSlashHistory(player, 1)
    lateStateChange(room, player, "unknown")
    data = use(room, player, target, card)
  end)
  -- The condition was locked before count even though the state changed later.
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 1)
  lu.assertTrue(A.getResult(data).entries[1].locked)
  lu.assertTrue(A.getResult(data).entries[1].triggered)
end

function Testhanjin_ignore_times:testLockedMissingGujunCannotBeRetroactivelyEnabled()
  local room = FkTest.room
  local player, target = room.players[1], room.players[2]
  local card = physical(Card.Spade, 10)
  local data
  FkTest.runInRoom(function()
    prepare(player, room)
    player.kingdom = "unknown"
    give(room, player, card)
    setSlashHistory(player, 1)
    lateStateChange(room, player, "han")
    data = use(room, player, target, card)
  end)
  -- Gaining 孤军 during PreCardUse is too late to exempt this use or trigger it.
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 2)
  lu.assertTrue(A.getResult(data).entries[1].locked)
  lu.assertFalse(A.getResult(data).entries[1].triggered)
end

function Testhanjin_ignore_times:testDistanceIsStillEnforcedWhenTimesAreBypassed()
  local room = FkTest.room
  local player, adjacent, distant = room.players[1], room.players[2], room.players[4]
  local card = physical(Card.Spade, 9)
  FkTest.runInRoom(function()
    prepare(player, room)
    give(room, player, card)
    setSlashHistory(player, 1)
    lu.assertTrue(player:canUseTo(card, adjacent))
    lu.assertNotIsTrue(player:canUseTo(card, distant))
    local targets = card:getAvailableTargets(player)
    lu.assertTrue(table.contains(targets, adjacent))
    lu.assertFalse(table.contains(targets, distant))
  end)
end

function Testhanjin_ignore_times:testPaoxiaoOnlyBypassesLimitAndStillCounts()
  local room = FkTest.room
  local player, target = room.players[1], room.players[2]
  local card = physical(Card.Spade, 9)
  local data
  FkTest.runInRoom(function()
    prepare(player, room)
    player.kingdom = "unknown" -- no 孤军: only the state skill may help
    give(room, player, card)
    setSlashHistory(player, 1)
    player:addSkill("paoxiao")
    lu.assertTrue(player:canUse(card))
    data = use(room, player, target, card)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 2)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryTurn), 2)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryRound), 2)
    player:loseSkill("paoxiao")
    lu.assertFalse(player:hasSkill("paoxiao"))
    lu.assertNotIsTrue(player:canUse(card))
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 2)
  end)
  lu.assertFalse(A.getResult(data).triggered)
end

function Testhanjin_ignore_times:testCrossbowOnlyBypassesLimitAndStillCounts()
  local room = FkTest.room
  local player, target = room.players[1], room.players[2]
  local card = physical(Card.Spade, 10)
  local data
  FkTest.runInRoom(function()
    prepare(player, room)
    player.kingdom = "unknown"
    give(room, player, card)
    setSlashHistory(player, 1)
    player:addSkill("#crossbow_skill")
    lu.assertTrue(player:canUse(card))
    data = use(room, player, target, card)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 2)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryTurn), 2)
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryRound), 2)
    player:loseSkill("#crossbow_skill")
    lu.assertNotIsTrue(player:canUse(card))
    lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 2)
  end)
  lu.assertFalse(A.getResult(data).triggered)
end

function Testhanjin_ignore_times:testOriginalAdaptationOrderEmitsOneIgnoreTimesSuccessEvent()
  local room = FkTest.room
  local player, target = room.players[1], room.players[2]
  local card = Fk:cloneCard(CARD_NAME)
  A.setCardEntries(card, {
    { id = "ignore", condition = "gujun", effect = "ignore_times" },
    { id = "draw", condition = "canqu", effect = "draw" },
  })
  local seen = {}
  local skel = fk.CreateSkill { name = "#hanjin_test_ignore_times_order_observer" }
  skel:addEffect(A.Triggered, {
    global = true,
    can_refresh = function(self, event, target, player, data) return target == player end,
    on_refresh = function(self, event, target, player, data)
      table.insert(seen, data.entry.effect)
      -- Reentrant resolution must not send a second success event.
      if data.entry.effect == "ignore_times" then A.resolve(room, data.use) end
    end,
  })
  local data
  local hand
  FkTest.runInRoom(function()
    prepare(player, room)
    player.hp = 1
    setSlashHistory(player, 1)
    room:addSkill(skel:createSkill())
    hand = player:getHandcardNum()
    data = use(room, player, target, card)
  end)
  lu.assertEquals(seen, { "ignore_times", "draw" })
  lu.assertEquals(player:usedCardTimes("slash", Player.HistoryPhase), 1)
  lu.assertEquals(player:getHandcardNum(), hand + 1)
  lu.assertEquals(A.getResult(data).triggered_count, 2)
  lu.assertEquals(A.getResult(data).effects.ignore_times, 1)
end

function Testhanjin_ignore_times:testOtherEntriesKeepOneTokenOneEntryRule()
  local room = FkTest.room
  local player, target = room.players[1], room.players[2]
  local card = Fk:cloneCard(CARD_NAME)
  A.setCardEntries(card, {
    { id = "ignore", condition = "gujun", effect = "ignore_times" },
    { id = "damage", condition = "canqu", effect = "damage" },
  })
  local seen = {}
  local skel = fk.CreateSkill { name = "#hanjin_test_ignore_times_token_observer" }
  skel:addEffect(A.Triggered, {
    global = true,
    can_refresh = function(self, event, target, player, data) return target == player end,
    on_refresh = function(self, event, target, player, data) table.insert(seen, data.entry.effect) end,
  })
  local data
  FkTest.runInRoom(function()
    prepare(player, room)
    player.kingdom = "unknown"
    player.hp = 2
    setSlashHistory(player, 1)
    room:addSkill(skel:createSkill())
    data = UseCardData:new { from = player, tos = { target }, card = card, extra_data = {} }
    A.grantIgnore(data, "test_source")
    FkTest.setNextReplies(target, { "" })
    room:useCard(data)
  end)
  lu.assertEquals(seen, { "damage" })
  lu.assertEquals(data.additionalDamage, 1)
  lu.assertFalse(A.getResult(data).entries[1].triggered)
  lu.assertTrue(A.getResult(data).entries[1].locked)
  lu.assertEquals(A.getResult(data).entries[2].ignored_by, "test_source")
end

return { name = "hanjin_ignore_times" }
