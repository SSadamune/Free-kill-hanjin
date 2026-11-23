local support = __dofile("../../../tests/support/hegemony.lua")
local content = __dofile("../../../tests/support/general_exchange_content.lua")
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local H = require "packages.hegemony.util"

local G = content.generals
local S = content.skills

local function main(player) return { player = player, isDeputy = false } end
local function deputy(player) return { player = player, isDeputy = true } end

local function assertSkillCount(player, skillName, scope, expected)
  lu.assertEquals(player:usedSkillTimes(skillName, scope), expected)
end

local function assertCardOwner(room, id, player)
  local owner = room:getCardOwner(id)
  lu.assertNotNil(owner)
  lu.assertEquals(owner.id, player.id)
end

Testgeneral_exchange = {
  setup = support.initQiaoRoom,
  tearDown = function()
    support.clearRoom()
  end,
}

function Testgeneral_exchange:testSamePlayerMainDeputySwapKeepsRevealHistoryAndHp()
  local room, p = FkTest.room, FkTest.room.players[1]
  FkTest.runInRoom(function()
    content.setup(room, p, G.wei_a.name, G.deputy.name, "wei")
    room:setPlayerProperty(p, "maxHp", 7)
    room:setPlayerProperty(p, "hp", 5)
    content.use(room, p, S.limited)
    content.use(room, p, S.mainonly)
    content.use(room, p, S.deputyonly)

    local context = assert(Exchange.exchange(room, main(p), deputy(p)))
    lu.assertTrue(context.same_player)
    lu.assertEquals(p.general, G.deputy.name)
    lu.assertEquals(p.deputyGeneral, G.wei_a.name)
    lu.assertEquals(p:getMark("__heg_general"), G.deputy.name)
    lu.assertEquals(p:getMark("__heg_deputy"), G.wei_a.name)
    lu.assertTrue(p:hasSkill(S.limited))
    lu.assertFalse(p:hasSkill(S.mainonly))
    lu.assertFalse(p:hasSkill(S.deputyonly))
    assertSkillCount(p, S.limited, Player.HistoryGame, 1)
    -- Main/deputy-place skills are inactive at the wrong place, but their
    -- activation records stay on the card so moving back does not reset them.
    assertSkillCount(p, S.mainonly, Player.HistoryGame, 1)
    assertSkillCount(p, S.deputyonly, Player.HistoryGame, 1)
    lu.assertEquals(p.maxHp, 7)
    lu.assertEquals(p.hp, 5)

    assert(Exchange.exchange(room, main(p), deputy(p)))
    lu.assertEquals(p.general, G.wei_a.name)
    lu.assertEquals(p.deputyGeneral, G.deputy.name)
    lu.assertTrue(p:hasSkill(S.mainonly))
    lu.assertTrue(p:hasSkill(S.deputyonly))
    assertSkillCount(p, S.mainonly, Player.HistoryGame, 1)
    assertSkillCount(p, S.deputyonly, Player.HistoryGame, 1)
    assertSkillCount(p, S.limited, Player.HistoryGame, 1)
  end)
end

function Testgeneral_exchange:testCrossPositionSwapMovesLimitedRoundBranchAndSwitchState()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.wei_a.name, G.plain.name, "wei")
    content.setup(room, b, G.plain2.name, G.wei_b.name, "wei")
    content.use(room, a, S.limited)
    content.use(room, a, S.mainonly)
    content.use(room, b, S.round)
    content.use(room, b, S.branch)
    content.use(room, b, S.switch)
    lu.assertEquals(b:getMark("__switcher_" .. S.switch), 1)

    assert(Exchange.exchange(room, main(a), deputy(b)))
    lu.assertEquals(a.general, G.wei_b.name)
    lu.assertEquals(b.deputyGeneral, G.wei_a.name)
    lu.assertTrue(a:hasSkill(S.round))
    lu.assertTrue(a:hasSkill(S.branch))
    lu.assertTrue(a:hasSkill(S.switch))
    lu.assertFalse(a:hasSkill(S.limited))
    -- The main-place skill arrived at B's deputy position, so it is inactive,
    -- but its used-once history still moved with the card.
    lu.assertFalse(b:hasSkill(S.mainonly))
    assertSkillCount(b, S.mainonly, Player.HistoryGame, 1)
    assertSkillCount(a, S.round, Player.HistoryRound, 1)
    assertSkillCount(a, S.branch, Player.HistoryRound, 1)
    lu.assertEquals(a:usedSkillTimes(S.branch, Player.HistoryRound, "alpha"), 1)
    lu.assertEquals(a:getMark("__switcher_" .. S.switch), 1)
    lu.assertEquals(b:getMark("__switcher_" .. S.switch), 0)

    -- Swap back: counts must not reset or double.
    assert(Exchange.exchange(room, main(a), deputy(b)))
    lu.assertEquals(a.general, G.wei_a.name)
    lu.assertEquals(b.deputyGeneral, G.wei_b.name)
    lu.assertTrue(a:hasSkill(S.mainonly))
    assertSkillCount(a, S.mainonly, Player.HistoryGame, 1)
    assertSkillCount(b, S.round, Player.HistoryRound, 1)
    lu.assertEquals(b:usedSkillTimes(S.branch, Player.HistoryRound, "alpha"), 1)
    lu.assertEquals(b:getMark("__switcher_" .. S.switch), 1)
  end)
end

function Testgeneral_exchange:testRoundAndBranchResetOnlyAtOriginalResetPoint()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.wei_b.name, G.plain.name, "wei")
    content.setup(room, b, G.plain2.name, G.plain.name, "wei")
    content.use(room, a, S.round)
    content.use(room, a, S.branch)
    assert(Exchange.exchange(room, main(a), main(b)))
    assertSkillCount(b, S.round, Player.HistoryRound, 1)
    lu.assertEquals(b:usedSkillTimes(S.branch, Player.HistoryRound, "alpha"), 1)
    lu.assertFalse(Fk.skill_skels[S.round]:withinTimesLimit(b, Player.HistoryRound))

    -- Enter the next round: the engine clears round history; the recorder also
    -- clears the same ledger scope.
    room:clearHistory(Player.HistoryRound)
    Exchange.clearLedgerScope(room, Player.HistoryRound)
    assert(Exchange.exchange(room, main(b), main(a)))
    assertSkillCount(a, S.round, Player.HistoryRound, 0)
    lu.assertEquals(a:usedSkillTimes(S.branch, Player.HistoryRound, "alpha"), 0)
    lu.assertTrue(Fk.skill_skels[S.round]:withinTimesLimit(a, Player.HistoryRound))
  end)
end

function Testgeneral_exchange:testPilesTransferWithOrderAndOtherPilesStay()
  local room = FkTest.room
  local a, b, c = room.players[1], room.players[2], room.players[3]
  local idsA, idsB, idsC, other
  FkTest.runInRoom(function()
    content.setup(room, a, G.pile_a.name, G.pile_other.name, "wei")
    content.setup(room, b, G.pile_b.name, G.plain.name, "wei")
    content.setup(room, c, G.pile_c.name, G.plain2.name, "wei")
    idsA = content.putPile(room, a, content.pile, 2)
    idsB = content.putPile(room, b, content.pile, 1)
    idsC = content.putPile(room, c, content.pile, 1)
    other = content.putPile(room, a, "qiao_exchange_other", 1)

    assert(Exchange.exchange(room, main(a), main(b)))
    lu.assertEquals(a:getPile(content.pile), idsB)
    lu.assertEquals(b:getPile(content.pile), idsA)
    lu.assertEquals(c:getPile(content.pile), idsC)
    lu.assertEquals(a:getPile("qiao_exchange_other"), other)
    for _, id in ipairs(idsB) do
      assertCardOwner(room, id, a)
      lu.assertEquals(room:getCardArea(id), Card.PlayerSpecial)
    end
    for _, id in ipairs(idsA) do
      assertCardOwner(room, id, b)
      lu.assertEquals(room:getCardArea(id), Card.PlayerSpecial)
    end
  end)
end

function Testgeneral_exchange:testSamePlayerSwapDoesNotMoveSharedPile()
  local room, p = FkTest.room, FkTest.room.players[1]
  local ids
  FkTest.runInRoom(function()
    content.setup(room, p, G.pile_a.name, G.pile_b.name, "wei")
    ids = content.putPile(room, p, content.pile, 3)
    assert(Exchange.exchange(room, main(p), deputy(p)))
    lu.assertEquals(p:getPile(content.pile), ids)
    for _, id in ipairs(ids) do
      assertCardOwner(room, id, p)
      lu.assertEquals(room:getCardArea(id), Card.PlayerSpecial)
    end
  end)
end

local markerFixture = __dofile("../../../tests/support/marker_cards.lua")

function Testgeneral_exchange:testZhouTaiKeepsScarsHiddenAndTakesThemToNewDeputyPosition()
  local room = FkTest.room
  local a, b = room.players[1], room.players[2]
  local scars
  FkTest.runInRoom(function()
    content.setup(room, a, "qiao_heg__wu013", "qiao_heg__wu004", "wu")
    content.setup(room, b, "qiao_heg__wu011", "qiao_heg__wu012", "wu")
    -- 再明置会读取选将时锁定的势力；同步本场景的吴势力配将。
    room:setPlayerMark(a, "__heg_kingdom", "wu")
    room:setPlayerMark(b, "__heg_kingdom", "wu")
    scars = { markerFixture.scar(room, a, Card.Heart), markerFixture.scar(room, a, Card.Club) }
    a:hideGeneral(false)
    lu.assertEquals(a:getPile("创"), scars)
    a:revealGeneral(false)
    lu.assertEquals(a:getPile("创"), scars)
    assert(Exchange.exchange(room, main(a), deputy(b)))
  end)
  lu.assertEquals(b.deputyGeneral, "qiao_heg__wu013")
  lu.assertEquals(a:getPile("创"), {})
  lu.assertEquals(b:getPile("创"), scars)
  FkTest.runInRoom(function()
    b:hideGeneral(true)
    lu.assertEquals(b:getPile("创"), scars)
    H.removeGeneral(b, true)
  end)
  lu.assertNotEquals(b.deputyGeneral, "qiao_heg__wu013")
  lu.assertEquals(b:getPile("创"), {})
  for _, id in ipairs(scars) do lu.assertEquals(room:getCardArea(id), Card.DiscardPile) end
end

local function assertZhouTaiScarsDiscarded(remove)
  local room, player = FkTest.room, FkTest.room.players[1]
  local scars
  FkTest.runInRoom(function()
    content.setup(room, player, "qiao_heg__wu004", "qiao_heg__wu013", "wu")
    scars = { markerFixture.scar(room, player, Card.Heart), markerFixture.scar(room, player, Card.Club) }
    remove(room, player)
  end)
  lu.assertEquals(player:getPile("创"), {})
  for _, id in ipairs(scars) do lu.assertEquals(room:getCardArea(id), Card.DiscardPile) end
end

function Testgeneral_exchange:testScarsDiscardedWhenShownBuquIsLost()
  assertZhouTaiScarsDiscarded(function(room, player)
    room:handleAddLoseSkills(player, "-qiao__skill_wu013_1")
  end)
end

function Testgeneral_exchange:testScarsDiscardedWhenHiddenBuquIsPermanentlyLost()
  local loss = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"
  assertZhouTaiScarsDiscarded(function(room, player)
    player:hideGeneral(true)
    assert(loss.loseCardSkill(room, player, true, "qiao__skill_wu013_1"))
  end)
end

function Testgeneral_exchange:testScarsDiscardedWhenHiddenZhouTaiIsReplaced()
  assertZhouTaiScarsDiscarded(function(room, player)
    player:hideGeneral(true)
    room:changeHero(player, "qiao_heg__wu012", false, true, false, false, false)
  end)
end

function Testgeneral_exchange:testRemovingZhouTaiDiscardsScarsEvenWithAnotherBuquSource()
  assertZhouTaiScarsDiscarded(function(room, player)
    -- 另一来源仍授予同名技能，但旧“创”属于被移走的周泰牌。
    player:addSkill("qiao__skill_wu013_1", "qiao__skill_wu004_1")
    H.removeGeneral(player, true)
    lu.assertTrue(player:hasSkill("qiao__skill_wu013_1"))
  end)
end

function Testgeneral_exchange:testDeputyToDeputySwap()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.plain.name, G.wei_a.name, "wei")
    content.setup(room, b, G.plain2.name, G.wei_b.name, "wei")
    content.use(room, a, S.limited)
    content.use(room, b, S.round)
    assert(Exchange.exchange(room, deputy(a), deputy(b)))
    lu.assertEquals(a.general, G.plain.name)
    lu.assertEquals(b.general, G.plain2.name)
    lu.assertEquals(a.deputyGeneral, G.wei_b.name)
    lu.assertEquals(b.deputyGeneral, G.wei_a.name)
    lu.assertTrue(a:hasSkill(S.round))
    lu.assertFalse(a:hasSkill(S.limited))
    lu.assertTrue(b:hasSkill(S.limited))
    assertSkillCount(a, S.round, Player.HistoryRound, 1)
    assertSkillCount(b, S.limited, Player.HistoryGame, 1)
  end)
end

function Testgeneral_exchange:testHpContributionIsNotRecalculated()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.hp.name, G.plain.name, "wei")
    content.setup(room, b, G.plain2.name, G.plain.name, "wei")
    room:setPlayerProperty(a, "maxHp", 9)
    room:setPlayerProperty(a, "hp", 6)
    room:setPlayerProperty(b, "maxHp", 4)
    room:setPlayerProperty(b, "hp", 2)
    assert(Exchange.exchange(room, main(a), deputy(b)))
    lu.assertEquals(a.maxHp, 9)
    lu.assertEquals(a.hp, 6)
    lu.assertEquals(b.maxHp, 4)
    lu.assertEquals(b.hp, 2)
  end)
end

function Testgeneral_exchange:testEnemiesHiddenCardsAndSamePositionAreRejectedWithoutMoving()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.wei_a.name, G.plain.name, "wei")
    content.setup(room, b, G.shu.name, G.plain.name, "shu")

    local ok, reason = Exchange.exchange(room, main(a), main(b))
    lu.assertFalse(ok)
    lu.assertEquals(reason, "different_kingdom")
    lu.assertEquals(a.general, G.wei_a.name)
    lu.assertEquals(b.general, G.shu.name)

    ok, reason = Exchange.exchange(room, main(a), main(a))
    lu.assertFalse(ok)
    lu.assertEquals(reason, "same_position")

    a:hideGeneral(false)
    ok, reason = Exchange.exchange(room, main(a), main(b))
    lu.assertFalse(ok)
    lu.assertEquals(reason, "not_revealed")
    lu.assertEquals(a.general, "anjiang")
    lu.assertEquals(b.general, G.shu.name)
  end)
end

function Testgeneral_exchange:testUnselectedHiddenPositionDoesNotBlock()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.wei_a.name, G.plain.name, "wei")
    content.setup(room, b, G.plain2.name, G.plain.name, "wei")
    a:hideGeneral(true)
    lu.assertEquals(a.deputyGeneral, "anjiang")
    assert(Exchange.exchange(room, main(a), main(b)))
    lu.assertEquals(a.general, G.plain2.name)
    lu.assertEquals(b.general, G.wei_a.name)
    lu.assertEquals(a.deputyGeneral, "anjiang")
    lu.assertEquals(a:getMark("__heg_deputy"), G.plain.name)
  end)
end

function Testgeneral_exchange:testLordCardsCannotBeExchangedWhileWildAndCrossKingdomNeedExceptions()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.wild.name, G.plain.name, "wei")
    content.setup(room, b, G.plain2.name, G.plain.name, "wei")
    local ok, reason = Exchange.exchange(room, main(a), main(b))
    lu.assertFalse(ok)
    lu.assertEquals(reason, "restricted_wild")
    lu.assertNotNil(Exchange.exchange(room, main(a), main(b), { allow_wild = true }))
    lu.assertEquals(b.general, G.wild.name)

    content.setup(room, a, G.plain.name, G.plain.name, "wei")
    content.setup(room, b, G.shu.name, G.plain.name, "shu")
    ok, reason = Exchange.exchange(room, main(a), main(b))
    lu.assertFalse(ok)
    lu.assertEquals(reason, "different_kingdom")
    lu.assertNotNil(Exchange.exchange(room, main(a), main(b), { cross_kingdom = true }))
    lu.assertEquals(a.general, G.shu.name)
    lu.assertEquals(b.general, G.plain.name)

    -- A lord card is protected by its actual identity.  No option may relax it,
    -- and the other position is still judged by its own card.
    content.setup(room, a, G.lord.name, G.plain.name, "wei")
    content.setup(room, b, G.plain2.name, G.plain.name, "wei")
    ok, reason = Exchange.exchange(room, main(a), main(b))
    lu.assertFalse(ok)
    lu.assertEquals(reason, "restricted_lord")
    ok, reason = Exchange.exchange(room, main(a), main(b), { allow_lord = true })
    lu.assertFalse(ok)
    lu.assertEquals(reason, "restricted_lord")
    ok, reason = Exchange.exchange(room, main(a), main(b),
      { allowed_generals = { [G.lord.name] = true } })
    lu.assertFalse(ok)
    lu.assertEquals(reason, "restricted_lord")
    lu.assertEquals(a.general, G.lord.name)
    lu.assertEquals(b.general, G.plain2.name)
    lu.assertFalse(Exchange.exchange(room, main(a), deputy(a)))
  end)
end

function Testgeneral_exchange:testWildExclusiveCannotMoveToDeputyPosition()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.wild.name, G.plain.name, "wei")
    content.setup(room, b, G.plain2.name, G.plain.name, "wei")
    local ok, reason = Exchange.exchange(room, main(a), deputy(b), { allow_wild = true })
    lu.assertFalse(ok)
    lu.assertEquals(reason, "restricted_wild_deputy")
    lu.assertEquals(a.general, G.wild.name)
    lu.assertEquals(b.deputyGeneral, G.plain.name)
  end)
end

function Testgeneral_exchange:testLordPerCardExceptionIsIgnoredAndStaleSelection()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.lord.name, G.plain.name, "wei")
    content.setup(room, b, G.plain2.name, G.plain.name, "wei")
    local ok, reason = Exchange.exchange(room, main(a), main(b),
      { allowed_generals = { [G.lord.name] = true } })
    lu.assertFalse(ok)
    lu.assertEquals(reason, "restricted_lord")
    lu.assertEquals(a.general, G.lord.name)
    lu.assertEquals(b.general, G.plain2.name)

    ok, reason = Exchange.exchange(room,
      { player = b, isDeputy = false, general = G.wei_a.name }, deputy(b))
    lu.assertFalse(ok)
    lu.assertEquals(reason, "stale_selection")
  end)
end

function Testgeneral_exchange:testSoldiersAndRetinuesMoveWithSkillsAndCardFace()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  local seen
  FkTest.runInRoom(function()
    content.setup(room, a, "blank_shibing", G.plain.name, "wei")
    content.setup(room, b, G.retinue.name, G.plain.name, "wei")
    lu.assertTrue(Exchange.isSoldier("blank_shibing"))
    lu.assertEquals(Exchange.soldierKind("blank_shibing"), "white")
    lu.assertEquals(Exchange.soldierKind(G.retinue.name), "retinue")

    local listener
    listener = Exchange.addCompletionListener(function(notifiedRoom, context)
      seen = context
      -- The completion entry point observes fully updated positions.
      lu.assertEquals(a.general, G.retinue.name)
      lu.assertEquals(b.general, "blank_shibing")
      lu.assertTrue(notifiedRoom == room)
    end)
    local ok, context = pcall(function()
      return assert(Exchange.exchange(room, main(a), main(b)))
    end)
    Exchange.removeCompletionListener(listener)
    lu.assertTrue(ok)
    lu.assertNotNil(seen)
    lu.assertEquals(seen.sides[1].general, G.retinue.name)
    lu.assertEquals(seen.sides[2].general, "blank_shibing")
    lu.assertEquals(#seen.obtained_soldiers, 1)
    lu.assertEquals(seen.obtained_soldiers[1].player.id, b.id)
    lu.assertEquals(seen.obtained_soldiers[1].isDeputy, false)
    lu.assertEquals(seen.obtained_soldiers[1].general, "blank_shibing")
    lu.assertTrue(seen.obtained_soldiers[1].same_player == false)

    lu.assertEquals(a.general, G.retinue.name)
    lu.assertEquals(b.general, "blank_shibing")
    lu.assertEquals(b:getMark("__heg_general"), "blank_shibing")
    lu.assertEquals(H.getActualGeneral(b), "blank_shibing")
    lu.assertTrue(a:hasSkill(S.retinue))
    lu.assertFalse(b:hasSkill(S.retinue))
  end)
end

function Testgeneral_exchange:testSameNameSkillFromAnotherPositionIsNotRemoved()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.wei_c.name, G.shared_deputy.name, "wei")
    content.setup(room, b, G.plain2.name, G.plain.name, "wei")
    lu.assertTrue(a:hasSkill(S.shared))
    assert(Exchange.exchange(room, main(a), main(b)))
    -- The departing main card owned S.shared too, but the deputy still grants
    -- the same-named skill, so it must remain active on A.
    lu.assertTrue(a:hasSkill(S.shared))
    lu.assertFalse(a:hasSkill(S.limited))
    lu.assertTrue(b:hasSkill(S.shared))
    lu.assertTrue(b:hasSkill(S.limited))
  end)
end

function Testgeneral_exchange:testUpstreamSwapDeputyStillWorksWithoutOurEntryPoint()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  local listenerCalled = false
  local listener = Exchange.addCompletionListener(function() listenerCalled = true end)
  FkTest.runInRoom(function()
    content.setup(room, a, G.plain.name, G.wei_a.name, "wei")
    content.setup(room, b, G.plain2.name, G.wei_b.name, "wei")
    lu.assertTrue(H.swapDeputy(room, a, b))
    lu.assertEquals(a.deputyGeneral, G.wei_b.name)
    lu.assertEquals(b.deputyGeneral, G.wei_a.name)
  end)
  Exchange.removeCompletionListener(listener)
  lu.assertFalse(listenerCalled)
end

function Testgeneral_exchange:testMalformedPositionsDoNotPartiallyMove()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.wei_a.name, G.plain.name, "wei")
    content.setup(room, b, G.plain2.name, G.plain.name, "wei")
    local ok, reason = Exchange.exchange(room, nil, main(b))
    lu.assertFalse(ok)
    lu.assertEquals(reason, "invalid_position")
    ok, reason = Exchange.exchange(room, { player = { id = 999 }, isDeputy = false }, main(b))
    lu.assertFalse(ok)
    lu.assertEquals(reason, "invalid_player")
    lu.assertEquals(a.general, G.wei_a.name)
    lu.assertEquals(b.general, G.plain2.name)
  end)
end

function Testgeneral_exchange:testHistoryWrittenOutsideRecorderFallsBackSymmetrically()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  FkTest.runInRoom(function()
    content.setup(room, a, G.wei_a.name, G.plain.name, "wei")
    content.setup(room, b, G.plain2.name, G.plain.name, "wei")
    -- Simulate a pre-existing history entry that the activation-time recorder
    -- did not see (for example an old save or a direct engine write).
    a:addSkillUseHistory(S.limited)
    lu.assertEquals(a:usedSkillTimes(S.limited, Player.HistoryGame), 1)

    assert(Exchange.exchange(room, main(a), main(b)))
    lu.assertEquals(b:usedSkillTimes(S.limited, Player.HistoryGame), 1)
    assert(Exchange.exchange(room, main(b), main(a)))
    lu.assertEquals(a:usedSkillTimes(S.limited, Player.HistoryGame), 1)
    lu.assertEquals(b:usedSkillTimes(S.limited, Player.HistoryGame), 0)
  end)
end

function Testgeneral_exchange:testHiddenLordPositionIsProtectedWithoutSideEffects()
  local room, a, b = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  local LORD = "qiao_heg__em_shu001"
  FkTest.runInRoom(function()
    content.setup(room, a, "qiao_heg__shu001", G.plain.name, "shu")
    content.setup(room, b, G.shu.name, G.plain.name, "shu")
    assert(A.ascend(room, a, LORD, "shu", { kind = "lord" }))
    lu.assertEquals(a.general, LORD)
    a:hideGeneral(false)
    lu.assertEquals(a.general, "anjiang")
    lu.assertEquals(a:getMark("__heg_general"), LORD)
    lu.assertTrue(Exchange.isLordPosition(a, false))
    lu.assertFalse(Exchange.isLordPosition(a, true))

    -- The hidden lord position cannot be exchanged; the normal deputy position
    -- is judged on its own and can still be exchanged.
    local ok, reason = Exchange.exchange(room, main(a), deputy(a))
    lu.assertFalse(ok)
    lu.assertEquals(reason, "not_revealed")
    lu.assertNotNil(Exchange.exchange(room, deputy(a), main(b)))
    lu.assertEquals(a.general, "anjiang")
    lu.assertEquals(a:getMark("__heg_general"), LORD)
    lu.assertEquals(a.deputyGeneral, G.shu.name)
    lu.assertEquals(b.general, G.plain.name)

    -- Removal/transform/changeHero must reject before the card is revealed,
    -- loses skills or returns to the general pile.
    lu.assertFalse(H.removeGeneral(a, false))
    lu.assertFalse(Discard.contains(room, LORD))
    lu.assertFalse(H.transformGeneral(room, a, true))
    lu.assertFalse(room:changeHero(a, G.plain.name, false, false, false, false, false))
    lu.assertEquals(a.general, "anjiang")
    lu.assertEquals(a:getMark("__heg_general"), LORD)
    lu.assertFalse(table.contains(room.general_pile, LORD))

    -- Candidate display and settlement agree: no candidate and no selection.
    lu.assertEquals(#Change.candidates(room, a, false), 0)
    lu.assertFalse(Change.change(room, a, false, { num = 3 }))
    lu.assertEquals(a:getMark("__heg_general"), LORD)

    -- The other position keeps normal removal behavior.
    lu.assertNil(H.removeGeneral(a, true))
    lu.assertTrue(a.deputyGeneral ~= G.shu.name)
    lu.assertEquals(a:getMark("__heg_general"), LORD)
  end)
end

function Testgeneral_exchange:testRemovedGeneralsCannotBeDrawnAgain()
  local room, player = FkTest.room, FkTest.room.players[1]
  local seen = {}
  local probe = fk.CreateSkill { name = "#qiao_test_general_removed_pile" }
  local prevent = true
  probe:addEffect(H.GeneralRemoving, {
    can_trigger = function(self, event, target, owner) return prevent and target == player and owner == player end,
    on_trigger = function() return true end,
  })
  probe:addEffect(H.GeneralRemoved, {
    can_refresh = function(self, event, target, owner) return target == player and owner == player end,
    on_refresh = function(self, event, target, owner, data)
      seen[#seen + 1] = data.origName
      lu.assertTrue(Discard.contains(room, data.origName))
      lu.assertNil(room:findGeneral(data.origName), "移除后时机中也不能检索到旧将")
      if #seen == 1 then room:returnToGeneralPile({ G.plain.name }) end
    end,
  })
  local watcher = probe:createSkill()
  Fk:addSkill(watcher)
  local finished = false
  FkTest.runInRoom(function()
    content.setup(room, player, G.wei_a.name, G.deputy.name, "wei")
    room.general_pile = {}
    room:addSkill(watcher)
    H.removeGeneral(player, true)
    lu.assertEquals(player.deputyGeneral, G.deputy.name)
    lu.assertFalse(Discard.contains(room, G.deputy.name))
    lu.assertEquals(seen, {})
    prevent = false
    H.removeGeneral(player, true)
    H.removeGeneral(player, false)
    lu.assertTrue(Exchange.isWhiteSoldier(player.general))
    lu.assertTrue(Exchange.isWhiteSoldier(player.deputyGeneral))
    H.removeGeneral(player, true)
    lu.assertEquals(seen, { G.deputy.name, G.wei_a.name })
    lu.assertEquals(Discard.list(room), seen)
    room:returnToGeneralPile({ G.wei_a.name, G.deputy.name }, "top")
    lu.assertEquals(room:findGenerals(function(name) return name == G.deputy.name end, 1), {})
    lu.assertEquals(room:getNGenerals(1), { G.plain.name })
    finished = true
  end)
  lu.assertTrue(finished)
end

function Testgeneral_exchange:testAscensionAndLordDeathFlipStillWork()
  local room, a = FkTest.room, FkTest.room.players[1]
  local LORD, NORMAL = "qiao_heg__em_shu001", "qiao_heg__shu001"
  FkTest.runInRoom(function()
    content.setup(room, a, NORMAL, G.plain.name, "shu")
    lu.assertTrue(A.ascend(room, a, LORD, "shu", { kind = "lord" }))
    lu.assertEquals(a.general, LORD)
    a:hideGeneral(false)
    lu.assertEquals(a.general, "anjiang")
    A.flip_lord_for_death(room, a)
    lu.assertEquals(a.general, LORD)
    lu.assertEquals(a:getMark("__heg_general"), LORD)
  end)
end

return { name = "general_exchange" }