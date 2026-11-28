local rooms = __dofile("../../../tests/support/hegemony.lua")
local fixture = __dofile("../../../tests/support/skill_test.lua")
local generals = require "packages.qiao.pkg.qiao_bingqing.data.shi_vector"
local Ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local E = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local function id(key) return "qiao__skill_" .. key end
local function give(room, p, name, suit)
  local card = room:printCard(name, suit or Card.Club, 7)
  room:obtainCard(p, card, false, fk.ReasonJustMove)
  return card
end
local function asGeneral(room, p, key, deputy)
  fixture.installDualGenerals(room, p, {
    main = deputy and "qiao_test__han_1" or "qiao_heg__" .. key,
    deputy = deputy and "qiao_heg__" .. key or "qiao_test__han_2",
    kingdom = "han",
  })
end
local function run(fn)
  local finished = false
  FkTest.runInRoom(function()
    local room = FkTest.room
    fn(room, table.unpack(room.players))
    finished = true
  end)
  lu.assertTrue(finished, "场景必须运行到最后一个断言")
end

Testqiao_shi_vector = {
  setup = function()
    rooms.initQiaoRoom()
    run(function(room, first)
      fixture.installBlankGenerals(room, "han")
      room.current = first
      first.phase = Player.Play
    end)
  end,
  tearDown = rooms.clearRoom,
}
local T = Testqiao_shi_vector

function T:testRosterPackageAndGuestFrameColors()
  run(function(room)
    local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
    lu.assertEquals(#generals.generals, 12)
    for _, entry in ipairs(generals.generals) do
      local g = Fk.generals[entry.id]
      lu.assertEquals(g.package.name, "qiao_bingqing")
      lu.assertEquals(g.prefix, "qiao_prefix_shi_vec")
      for _, sk in ipairs(entry.skills) do
        lu.assertTrue(#Fk.skill_skels[sk.id].effects > 0)
        lu.assertEquals(Fk:translate(":" .. sk.id), sk.text)
      end
    end
    lu.assertFalse(table.contains(room.disabled_packs, "qiao_bingqing"))
    lu.assertItemsEquals(Guest.guestKingdoms("qiao_heg__han047"), { "wei", "qun" })
    lu.assertItemsEquals(Guest.guestKingdoms("qiao_heg__wei035"), { "han", "shu" })
    lu.assertEquals(Guest.guestKingdoms("qiao_heg__shu091"), { "wei" })
    local tian, xiahou = Fk.generals.qiao_heg__han047, Fk.generals.qiao_heg__wei003
    room:setBanner("all_kingdoms", { "han", "wei", "shu", "wu", "qun", "jin" })
    lu.assertFalse(tian:isCompanionWith(xiahou))
    room:setBanner("all_kingdoms", { "wei", "shu", "wu", "jin" })
    lu.assertTrue(xiahou:isCompanionWith(tian))
  end)
end

function T:testMizhongPreventsOnlyAtExactHandSize()
  run(function(room, p, other)
    asGeneral(room, p, "wu032")
    room:throwCard(p:getCardIds("h"), "test", p, p)
    p.hp = 2
    give(room, p, "qiao__slash")
    give(room, p, "qiao__slash")
    room:damage { from = other, to = p, damage = 1 }
    lu.assertEquals(p.hp, 2)
    give(room, p, "qiao__slash")
    room:damage { from = other, to = p, damage = 1 }
    lu.assertEquals(p.hp, 1)
  end)
end

function T:testPindiRecordsActualTypeAndTargetAndChainsOnlyOnce()
  run(function(room, chen, a, b)
    asGeneral(room, chen, "wei035")
    a.hp = a.maxHp - 1
    local slash, duel = give(room, chen, "qiao__slash"), give(room, chen, "qiao__duel")
    local beforeA, beforeB = a:getHandcardNum(), b:getHandcardNum()
    fixture.withSkillRequests(room, id("wei035_1"), { askToChoice = function(_, _, params) return params.choices[1] end }, function()
      room:handleUseCardReply(chen, FkTest.ReplyUseSkill(id("wei035_1"), { a }, { slash.id }))
      room:handleUseCardReply(chen, FkTest.ReplyUseSkill(id("wei035_1"), { b }, { duel.id }))
    end)
    lu.assertEquals(a:getHandcardNum(), beforeA + 1)
    lu.assertEquals(b:getHandcardNum(), beforeB + 2)
    lu.assertTrue(chen.chained)
    lu.assertEquals(#chen:getTableMark("qiao_pindi_targets-turn"), 2)
  end)
end

function T:testPindiKeepsItsTurnChoicesAfterExchange()
  run(function(room, chen, receiver, first, second)
    local name = id("wei035_1")
    asGeneral(room, chen, "wei035")
    fixture.withSkillRequests(room, name, {
      askToChoice = function(_, _, params) return params.choices[1] end,
    }, function()
      local firstCost = give(room, chen, "qiao__slash")
      room:handleUseCardReply(chen, FkTest.ReplyUseSkill(name, { first }, { firstCost.id }))
      assert(E.exchange(room, { player = chen }, { player = receiver }))
      lu.assertEquals(chen:getMark("qiao_pindi_types-turn"), 0)
      lu.assertEquals(chen:getMark("qiao_pindi_targets-turn"), 0)
      lu.assertEquals(receiver:getTableMark("qiao_pindi_types-turn"), { Card.TypeBasic })
      lu.assertEquals(receiver:getTableMark("qiao_pindi_targets-turn"), { first.id })

      local duel = give(room, receiver, "qiao__duel")
      local before = second:getHandcardNum()
      fixture.withSkillRequests(room, "#qiao_shi_pindi_select", {
        askToUseActiveSkill = function()
          return true, { cards = { duel.id }, targets = { second } }
        end,
      }, function()
        room:damage { from = first, to = receiver, damage = 1 }
      end)
      lu.assertEquals(second:getHandcardNum(), before + 2)
      lu.assertEquals(receiver:getTableMark("qiao_pindi_targets-turn"), { first.id, second.id })
    end)
  end)
end

function T:testFaenChainsAndStacksButNotUnchainsOrDuplicateChain()
  run(function(room, chen, to)
    asGeneral(room, chen, "wei035")
    local n = to:getHandcardNum()
    fixture.withSkillRequests(room, id("wei035_2"), { askToSkillInvoke = function() return true end }, function()
      to:setChainState(true)
      to:setChainState(true)
      to:setChainState(false)
      to:turnOver()
      to:turnOver()
    end)
    lu.assertEquals(to:getHandcardNum(), n + 2)
  end)
end

function T:testDuduanUseAndResponseAreSealedByTrueName()
  run(function(room, yang)
    asGeneral(room, yang, "shu091")
    local n = yang:getHandcardNum()
    room:handleUseCardReply(yang, FkTest.ReplyUseSkill(id("shu091_1"), {}, {}))
    lu.assertEquals(yang:getHandcardNum(), n + 2)
    lu.assertTrue(yang:prohibitUse(Fk:cloneCard("qiao__fire__slash")))
    lu.assertTrue(yang:prohibitResponse(Fk:cloneCard("qiao__slash")))
    lu.assertFalse(yang:prohibitUse(Fk:cloneCard("qiao__jink")))
    fixture.withSkillRequests(room, id("shu091_1"), { askToChoice = function() return "jink" end }, function()
      room.logic:trigger(fk.AskForCardUse, yang, { pattern = "jink" })
      room.logic:trigger(fk.AskForCardResponse, yang, { pattern = "jink" })
    end)
    lu.assertEquals(yang:getHandcardNum(), n + 4)
    lu.assertTrue(yang:prohibitResponse(Fk:cloneCard("qiao__jink")))
  end)
end

function T:testGufenRestrictionsFollowActualHandCards()
  run(function(room, yang)
    asGeneral(room, yang, "shu091")
    local duel = give(room, yang, "qiao__duel", Card.Diamond)
    local delay = give(room, yang, "qiao__indulgence", Card.Diamond)
    local black = give(room, yang, "qiao__duel", Card.Spade)
    lu.assertTrue(yang:prohibitUse(duel))
    lu.assertTrue(yang:prohibitUse(delay))
    lu.assertFalse(yang:prohibitUse(black))
    local OnlyAs = require "packages.qiao.pkg.qiao_mode.rules.only_as"
    lu.assertTrue(table.contains(OnlyAs.availableTargets(room, yang, delay.id, "use"), "qiao__analeptic"))
  end)
end

function T:testYangdaoGrantsTiedWeaponsButNeverCreatesEquipment()
  run(function(room, p, a, b)
    asGeneral(room, p, "jin037")
    local spear = room:printCard("qiao__spear", Card.Spade, 12)
    local blade = room:printCard("qiao__blade", Card.Spade, 5)
    room:moveCardTo(spear, Card.PlayerEquip, a, fk.ReasonPut)
    room:moveCardTo(blade, Card.PlayerEquip, b, fk.ReasonPut)
    lu.assertEquals(p:getAttackRange(), 3)
    lu.assertEquals(#p:getEquipments(Card.SubtypeWeapon), 0)
    for _, card in ipairs({ spear, blade }) do
      for _, sk in ipairs(card:getEquipSkills(p)) do lu.assertTrue(p:hasSkill(sk.name), sk.name) end
    end
    room:throwCard(spear, "test", a, a)
    for _, sk in ipairs(spear:getEquipSkills(p)) do lu.assertFalse(p:hasSkill(sk.name)) end
  end)
end

function T:testChumingUsesWineOnRecipientThenGivesSlashAndHandlesNoWeapon()
  run(function(room, user, brothers)
    asGeneral(room, brothers, "jin037")
    local material = give(room, user, "qiao__fire__slash")
    local before = user:usedCardTimes("analeptic", Player.HistoryTurn)
    user:addCardUseHistory("analeptic", 1)
    local choices = 0
    fixture.withSkillRequests(room, id("jin037_2"), {
      askToChoice = function() choices = choices + 1; return "qiao__collateral" end,
      askToChoosePlayers = function(_, _, params) return { params.targets[1] } end,
    }, function()
      room:handleUseCardReply(user, FkTest.ReplyUseSkill("qiao__chuming_other&", { brothers }, { material.id }))
    end)
    lu.assertEquals(choices, 1)
    lu.assertTrue(room:getCardOwner(material.id) == brothers)
    lu.assertEquals(brothers.drank, 1)
    lu.assertEquals(user.drank, 0)
    lu.assertEquals(user:usedCardTimes("analeptic", Player.HistoryTurn), before + 1)
  end)
end

function T:testChunyiRecipientConsumesCiAndGetsRealWine()
  run(function(room, user, chengpu)
    asGeneral(room, chengpu, "wu027")
    local chosen = "qiao_heg__shu003"
    Ci.save(room, user, { chosen })
    local name = "qiao__chunyi_other&"
    lu.assertTrue(user:hasSkill(name))
    local reply = FkTest.ReplyUseSkill(name, { user }, {})
    reply.interaction_data = chosen
    room:handleUseCardReply(user, reply)
    lu.assertEquals(user.drank, 1)
    lu.assertEquals(#Ci.cards(user), 0)
    lu.assertTrue(table.contains(Discard.list(room), chosen))
  end)
end

function T:testHufenMovesToDeputyAndUsesDependantSkills()
  run(function(room, p)
    asGeneral(room, p, "jin066")
    lu.assertTrue(p:hasShownSkill(id("jin066_1")))
    local exchanged = E.exchange(room, { player = p }, { player = p, isDeputy = true })
    lu.assertNotNil(exchanged)
    lu.assertEquals(p.deputyGeneral, "qiao_heg__jin066")
    lu.assertTrue(p:hasShownSkill(id("jin066_2")))
    lu.assertFalse(p:hasShownSkill(id("jin066_1")))
    lu.assertEquals(p:getAttackRange(), 2)
  end)
end

function T:testJingchuRemovesUntilTwoRemainAndOnlyThenDrawsAndGives()
  run(function(room, tian, remaining, a, b)
    asGeneral(room, tian, "han047")
    local before, others = tian:getHandcardNum(), remaining:getHandcardNum()
    local queue = table.filter(room:getPresentPlayers(), function(to) return to ~= tian and to ~= remaining end)
    local count = #queue
    fixture.withSkillRequests(room, id("han047_2"), {
      askToChoosePlayers = function(_, _, params)
        lu.assertFalse(table.contains(params.targets, tian))
        return { table.remove(queue, 1) }
      end,
      askToCards = function() return { tian:getCardIds("h")[1] } end,
      askToChoice = function() return "Cancel" end,
    }, function()
      for i = 1, count do
        room.logic:trigger(fk.CardUseFinished, tian, { from = tian, card = Fk:cloneCard("qiao__slash"), tos = {} })
        if i < count then lu.assertEquals(tian:getHandcardNum(), before) end
      end
    end)
    lu.assertTrue(a:isRemoved() and b:isRemoved())
    lu.assertEquals(tian:getHandcardNum(), before + 1)
    lu.assertEquals(remaining:getHandcardNum(), others + 1)
  end)
end

function T:testJingchuTransfersSkillsAfterPrelightAndReveal()
  run(function(room, tian, chen)
    asGeneral(room, tian, "han047")
    asGeneral(room, chen, "wei035")
    local jingchu, pindi = id("han047_2"), id("wei035_1")
    local tianSkills = { id("han047_1"), jingchu }
    local chenSkills = { pindi, id("wei035_2") }
    for _, pair in ipairs({ { tian, tianSkills }, { chen, chenSkills } }) do
      local player, skills = table.unpack(pair)
      room:setPlayerMark(player, "__heg_kingdom", "wei")
      player:hideGeneral(false)
      for _, name in ipairs(skills) do
        player:prelightSkill(name, true)
        lu.assertTrue(player:isFakeSkill(name), name)
        lu.assertTrue(player:hasSkill(name), name)
      end
      player:revealGeneral(false)
      for _, name in ipairs(skills) do lu.assertTrue(player:hasShownSkill(name), name) end
    end
    lu.assertEquals({ tian.kingdom, chen.kingdom }, { "wei", "wei" })

    local queue = table.filter(room:getPresentPlayers(), function(p) return p ~= tian and p ~= chen end)
    fixture.withSkillRequests(room, jingchu, {
      askToChoosePlayers = function() return { table.remove(queue, 1) } end,
      askToCards = function() return { tian:getCardIds("h")[1] } end,
      askToChoice = function(_, chooser, params)
        lu.assertIs(chooser, chen)
        local choice = "qiao_shi_exchange:::qiao_heg__wei035:qiao_heg__han047"
        lu.assertTrue(table.contains(params.choices, choice))
        return choice
      end,
    }, function()
      for _ = 1, #queue do
        assert(rooms.playCard(room, tian, give(room, tian, "qiao__foresight"), { tian }))
      end
    end)

    lu.assertEquals({ tian.general, chen.general }, { "qiao_heg__wei035", "qiao_heg__han047" })
    for _, name in ipairs(tianSkills) do
      lu.assertFalse(tian:hasSkill(name, true, true), name)
      lu.assertTrue(chen:hasShownSkill(name), name)
    end
    for _, name in ipairs(chenSkills) do
      lu.assertTrue(tian:hasShownSkill(name), name)
      lu.assertFalse(chen:hasSkill(name, true, true), name)
    end
  end)
end

function T:testSuolingCanGiveSecondBlackCardAndChooseYuanweiAsSlashTarget()
  run(function(room, yuan, receiver)
    asGeneral(room, yuan, "han051")
    room:throwCard(receiver:getCardIds("h"), "test", receiver, receiver)
    local first = give(room, receiver, "qiao__jink", Card.Club)
    local gift = give(room, yuan, "qiao__jink", Card.Spade)
    local hp = yuan.hp
    fixture.withSkillRequests(room, id("han051_1"), {
      askToCards = function(_, who)
        lu.assertTrue(who == receiver)
        return { first.id, gift.id }
      end,
    }, function()
      room:handleUseCardReply(yuan, FkTest.ReplyUseSkill(id("han051_1"), { receiver, yuan }, { gift.id }))
    end)
    lu.assertEquals(yuan.hp, hp - 1)
    lu.assertEquals(room:getCardArea(gift.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(first.id), Card.DiscardPile)
  end)
end

function T:testTuoxianLetsChosenAllyDecideWhichPositionsToExchange()
  run(function(room, cheng, dying, chooser)
    asGeneral(room, cheng, "wei044")
    local main = dying.general
    local other = chooser.deputyGeneral
    local decisions = 0
    fixture.withSkillRequests(room, id("wei044_2"), {
      askToChoosePlayers = function() return { chooser } end,
      askToChoice = function(_, who, params)
        lu.assertTrue(who == chooser)
        decisions = decisions + 1
        local key = "qiao_shi_exchange:::" .. other .. ":" .. main
        lu.assertTrue(table.contains(params.choices, key))
        return key
      end,
    }, function()
      room.logic:trigger(fk.EnterDying, dying, { who = dying })
    end)
    lu.assertEquals(decisions, 1)
    lu.assertEquals(dying.general, other)
    lu.assertEquals(chooser.deputyGeneral, main)
  end)
end

function T:testBingzhengResolvesOnlyAtDongyunsTurnEnd()
  run(function(room, dong, other)
    asGeneral(room, dong, "shu048")
    other.hp = other:getHandcardNum() + 1
    local before = dong:getHandcardNum()
    fixture.withSkillRequests(room, id("shu048_1"), {
      askToChoosePlayers = function() return { other } end,
      askToChoice = function(_, who, params)
        lu.assertTrue(who == dong)
        lu.assertEquals(params.choices, { "draw1", "discard1" })
        lu.assertEquals(Fk:translate("discard1"), "弃一张牌")
        return "draw1"
      end,
      askToCards = function() return {} end,
    }, function()
      room.logic:trigger(fk.TurnEnd, other, { who = other })
      lu.assertEquals(other:getHandcardNum(), other.hp - 1)
      room.logic:trigger(fk.TurnEnd, dong, { who = dong })
    end)
    lu.assertEquals(other:getHandcardNum(), other.hp)
    lu.assertEquals(dong:getHandcardNum(), before + 1)
  end)
end

function T:testXianzhuRecoversBeforeRecipientSelectsDamageTarget()
  run(function(room, cai, other, target)
    asGeneral(room, cai, "qun033")
    local spear = room:printCard("qiao__spear", Card.Spade, 12)
    room:moveCardTo(spear, Card.PlayerEquip, cai, fk.ReasonPut)
    cai.hp = cai.maxHp - 1
    local hp = target.hp
    fixture.withSkillRequests(room, id("qun033_2"), {
      askToChoosePlayers = function(_, chooser, params)
        lu.assertTrue(chooser == other)
        lu.assertEquals(cai.hp, cai.maxHp)
        lu.assertTrue(table.contains(params.targets, target))
        return { target }
      end,
    }, function()
      room:handleUseCardReply(cai, FkTest.ReplyUseSkill(id("qun033_2"), { other }, {}))
    end)
    lu.assertTrue(room:getCardOwner(spear.id) == other)
    lu.assertEquals(room:getCardArea(spear.id), Card.PlayerHand)
    lu.assertEquals(target.hp, hp - 1)
  end)
end

function T:testXizhenIncludesUnknownButExcludesAllies()
  run(function(room, gao, unknown, ally, enemy)
    asGeneral(room, gao, "qun079")
    room:setPlayerProperty(unknown, "kingdom", "unknown")
    room:setPlayerProperty(enemy, "kingdom", "wei")
    local cost = give(room, gao, "qiao__jink")
    fixture.withSkillRequests(room, id("qun079_1"), {
      askToDiscard = function() return { cost.id } end,
      askToChoice = function() return "qiao_xizhen_ban" end,
    }, function()
      room.logic:trigger(fk.EventPhaseStart, gao, { phase = Player.Play })
    end)
    local jink = Fk:cloneCard("qiao__jink")
    lu.assertTrue(unknown:prohibitResponse(jink))
    lu.assertTrue(enemy:prohibitUse(jink))
    lu.assertFalse(ally:prohibitResponse(jink))
    lu.assertEquals(room:getCardArea(cost.id), Card.DiscardPile)
  end)
end

function T:testTiejiChainDamageReplenishesEachEmptyFishOnce()
  run(function(room, pu, target, ally, nextTarget)
    asGeneral(room, pu, "wu027")
    local a, b = give(room, pu, "qiao__jink"), give(room, pu, "qiao__jink")
    for _, to in ipairs({ target, nextTarget }) do to:setChainState(true) end
    room:setPlayerMark(pu, "@!!yinyangfish", 0)
    room:setPlayerMark(ally, "@!!yinyangfish", 2)
    local hp1, hp2 = target.hp, nextTarget.hp
    fixture.withSkillRequests(room, id("wu027_1"), { askToChoosePlayers = function() return { ally } end }, function()
      room:handleUseCardReply(pu, FkTest.ReplyUseSkill(id("wu027_1"), { target }, { a.id, b.id }))
    end)
    lu.assertEquals(target.hp, hp1 - 1)
    lu.assertEquals(nextTarget.hp, hp2 - 1)
    lu.assertEquals(pu:getMark("@!!yinyangfish"), 1)
    lu.assertEquals(ally:getMark("@!!yinyangfish"), 2)
  end)
end


function T:testYangdaoInvalidationAndPhysicalWeaponTakeover()
  run(function(room, p, other)
    asGeneral(room, p, "jin037")
    local spear = room:printCard("qiao__spear", Card.Spade, 12)
    room:moveCardTo(spear, Card.PlayerEquip, other, fk.ReasonPut)
    local weaponSkill = spear:getEquipSkills(p)[1].name
    lu.assertTrue(p:hasSkill(weaponSkill))
    room:invalidateSkill(p, id("jin037_1"))
    lu.assertFalse(p:hasSkill(weaponSkill))
    room:validateSkill(p, id("jin037_1"))
    lu.assertTrue(p:hasSkill(weaponSkill))
    room:moveCardTo(spear, Card.PlayerEquip, p, fk.ReasonPut)
    lu.assertTrue(p:hasSkill(weaponSkill))
    room:invalidateSkill(p, id("jin037_1"))
    lu.assertTrue(p:hasSkill(weaponSkill))
    room:throwCard(spear, "test", p, p)
    lu.assertFalse(p:hasSkill(weaponSkill))
  end)
end


function T:testQietingUsesTargetKingdomAndActualHandCard()
  run(function(room, user, to, cai)
    asGeneral(room, cai, "qun033")
    local mark = "qiao_qieting_foreign-turn"
    room:setPlayerProperty(to, "kingdom", "unknown")
    rooms.playCard(room, user, give(room, user, "qiao__slash"), { to })
    lu.assertEquals(user:getMark(mark), 0)
    room:setPlayerProperty(to, "kingdom", "wei")
    room:useCard { from = user, tos = { to }, card = Fk:cloneCard("qiao__slash") }
    lu.assertEquals(user:getMark(mark), 0)
    rooms.playCard(room, user, give(room, user, "qiao__slash"), { to })
    lu.assertEquals(user:getMark(mark), 1)
  end)
end

function T:testSheyanAddsTargetOnlyOnFirstCommonTrick()
  run(function(room, user, dong, extra)
    asGeneral(room, dong, "shu048")
    local queries, before = 0, extra:getHandcardNum()
    local indulgence = give(room, user, "qiao__indulgence")
    room:useCard { from = user, tos = { dong }, card = indulgence }
    lu.assertTrue(table.contains(dong:getCardIds("j"), indulgence.id))
    fixture.withSkillRequests(room, id("shu048_2"), {
      askToChoosePlayers = function(_, _, params)
        queries = queries + 1
        lu.assertTrue(table.contains(params.targets, extra))
        lu.assertFalse(table.contains(params.targets, dong))
        return { extra }
      end,
    }, function()
      for i = 1, 2 do
        room:useCard { from = user, tos = { dong }, card = Fk:cloneCard("ex_nihilo") }
      end
    end)
    lu.assertEquals(queries, 1)
    lu.assertEquals(extra:getHandcardNum(), before + 2)
  end)
end


function T:testLianzhanUsesTwoLegalTargetsAfterExchange()
  run(function(room, hu, a, b)
    asGeneral(room, hu, "jin066")
    local ha, hb = a.hp, b.hp
    local n = 0
    fixture.withSkillRequests(room, id("jin066_2"), {
      askToUseVirtualCard = function(_, who, params)
        n = n + 1
        lu.assertTrue(who == hu)
        local card = Fk:cloneCard("qiao__slash")
        card.skillName = params.skill_name
        return { from = who, card = card, tos = { a, b } }
      end,
    }, function()
      E.exchange(room, { player = hu }, { player = hu, isDeputy = true })
    end)
    lu.assertEquals(n, 1)
    lu.assertEquals(a.hp, ha - 1)
    lu.assertEquals(b.hp, hb - 1)
  end)
end


function T:testSuolingSecondOptionUsesTwoConvertedSlashesOnRecipient()
  run(function(room, yuan, a, b)
    asGeneral(room, yuan, "han051")
    room:throwCard(a:getCardIds("h"), "test", a, a)
    local hp = a.hp
    local gift = give(room, yuan, "qiao__jink", Card.Spade)
    local first, second = give(room, b, "qiao__jink"), give(room, b, "qiao__jink")
    local todo = { first, second }
    fixture.withSkillRequests(room, id("han051_1"), {
      askToUseCard = function(_, p)
        lu.assertTrue(p == b)
        local c = table.remove(todo, 1)
        if not c then return end
        local slash = Fk:cloneCard("qiao__fire__slash")
        slash:addSubcard(c.id)
        return { from = b, tos = { a }, card = slash }
      end,
    }, function() room:handleUseCardReply(yuan, FkTest.ReplyUseSkill(id("han051_1"), { a, b }, { gift.id })) end)
    lu.assertEquals(a.hp, hp - 2)
    lu.assertEquals(room:getCardArea(second.id), Card.DiscardPile)
    lu.assertEquals(b:usedCardTimes("slash", Player.HistoryTurn), 0)
  end)
end


function T:testQietingOnlyDrawsWhenTheOnlyEquipmentIsProtected()
  run(function(room, sun, cai)
    asGeneral(room, sun, "em_wu001")
    asGeneral(room, cai, "qun033")
    local treasure = give(room, sun, "qiao__bronze_sparrow")
    room:moveCardIntoEquip(sun, treasure.id)
    local before = cai:getHandcardNum()
    local invoke = room.askToSkillInvoke
    room.askToSkillInvoke = function(self, who, params, ...)
      if who == cai and params.skill_name:find(id("qun033_1"), 1, true) then return true end
      return invoke(self, who, params, ...)
    end
    fixture.withSkillRequests(room, id("qun033_1"), {
      askToChoice = function() error("受保护的宝物不应出现移动选项") end,
    }, function() room.logic:trigger(fk.EventPhaseStart, sun, { phase = Player.Finish }) end)
    room.askToSkillInvoke = invoke
    lu.assertEquals(cai:getHandcardNum(), before + 1)
    lu.assertIs(room:getCardOwner(treasure.id), sun)
  end)
end

local function checkSuolingFocus(suit)
  run(function(room, yuan, receiver, target)
    asGeneral(room, yuan, "han051")
    room:throwCard(receiver:getCardIds("h"), "test", receiver, receiver)
    give(room, receiver, "qiao__jink", suit)
    local gift = give(room, yuan, "qiao__jink", Card.Spade)
    local choosing, focus = false, 0
    local notify = room.doBroadcastNotify
    room.doBroadcastNotify = function(self, command, data, ...)
      if choosing and command == "MoveFocus" and table.contains(data[1], receiver.id) then focus = focus + 1 end
      return notify(self, command, data, ...)
    end
    fixture.withSkillRequests(room, id("han051_1"), {
      askToCards = function(self, who, params, original)
        choosing = true
        local reply = original(self, who, params)
        choosing = false
        return reply
      end,
      askToUseCard = function() return nil end,
    }, function()
      room:handleUseCardReply(yuan, FkTest.ReplyUseSkill(id("han051_1"), { receiver, target }, { gift.id }))
    end)
    room.doBroadcastNotify = notify
    lu.assertEquals(focus, 1)
    lu.assertIs(room:getCardOwner(gift.id), receiver)
  end)
end
function T:testSuolingPublicFocusWithBlackHandCard() checkSuolingFocus(Card.Club) end
function T:testSuolingPublicFocusWithRedHandCard() checkSuolingFocus(Card.Heart) end

function T:testChumingUsesCollateralSecondaryTargetRules()
  run(function(room, user, brothers, victim)
    asGeneral(room, brothers, "jin037")
    local slash = give(room, user, "qiao__slash")
    local prohibited = user.isProhibited
    user.isProhibited = function(self, to, card, ...)
      if to == victim and card.trueName == "collateral" then return true end
      return prohibited(self, to, card, ...)
    end
    local trick = Fk:cloneCard("qiao__collateral")
    lu.assertTrue(trick.skill:targetFilter(user, victim, { brothers }, {}, trick))
    local chosen
    fixture.withSkillRequests(room, id("jin037_2"), {
      askToChoice = function() return trick.name end,
      askToChoosePlayers = function(_, _, params)
        lu.assertTrue(table.contains(params.targets, victim))
        chosen = victim
        return { victim }
      end,
    }, function()
      room:handleUseCardReply(user, FkTest.ReplyUseSkill("qiao__chuming_other&", { brothers }, { slash.id }))
    end)
    user.isProhibited = prohibited
    lu.assertIs(chosen, victim)
  end)
end

function T:testCombinedRevealDispatchesHufenAndMifurenOnce()
  run(function(room, player)
    fixture.installBlankGenerals(room, { "han", "wei" })
    fixture.installDualGenerals(room, player, {
      main = "qiao_heg__jin066", deputy = "qiao_heg__shu021", kingdom = "han",
    })
    player:hideGeneral(false)
    player:hideGeneral(true)
    local before = player:getHandcardNum()
    local invoked = 0
    local probe = fk.CreateSkill { name = "qiao_test_shi_combined_reveal" }
    probe:addEffect(fk.EventPhaseStart, {
      global = true,
      can_refresh = function(self, event, target, p)
        return target == player and p == player and p.phase == Player.Start
      end,
      on_refresh = function() player:revealGenerals() end,
    })
    local callback = probe:createSkill()
    Fk.skills[probe.name] = callback
    room:addSkill(callback)
    fixture.withSkillRequests(room, id("jin066_1"), {
      askToSkillInvoke = function()
        invoked = invoked + 1
        return true
      end,
    }, function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Start })):exec()
    end)
    lu.assertEquals(invoked, 1)
    lu.assertEquals(player:getHandcardNum(), before + 3)
  end)
end

return { name = "qiao_shi_vector" }
