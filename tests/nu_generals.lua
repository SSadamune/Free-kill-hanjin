local rooms = __dofile("../../../tests/support/hegemony.lua")
local fixture = __dofile("../../../tests/support/skill_test.lua")
local D = require "packages.qiao.pkg.qiao_bingqing.data.nu"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local E = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local function id(code) return "qiao__skill_" .. code end
local function run(fn)
  local done = false
  FkTest.runInRoom(function()
    local room = FkTest.room
    fn(room, table.unpack(room.players))
    done = true
  end)
  lu.assertTrue(done, "场景应运行到最后一个断言")
end
local function general(room, p, key)
  fixture.installDualGenerals(room, p, { main = "qiao_heg__" .. key, deputy = "qiao_test__han_2", kingdom = "han" })
end
local function card(room, p, name, suit, number)
  local c = room:printCard(name, suit or Card.Club, number or 7)
  room:obtainCard(p, c, false, fk.ReasonJustMove)
  return c
end
local function playSkill(room, p, name, tos, cards, choice)
  local reply = FkTest.ReplyUseSkill(name, tos, cards)
  reply.interaction_data = choice
  room:handleUseCardReply(p, reply)
end
local function grant(p, name, pos)
  return R.grant(p, { general = "qiao_heg__retinue_" .. name, skill = "qiao__retinue_skill_" .. name, position = pos or "main" })
end
local function runStartPhase(room, current, name, action, timing)
  local probe = fk.CreateSkill { name = name }
  local ran = false
  probe:addEffect(timing or fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, p)
      return not ran and p == current and target == current and (timing == fk.TurnEnd or p.phase == Player.Start)
    end,
    on_refresh = function()
      ran = true
      action()
    end,
  })
  local sk = probe:createSkill()
  Fk.skills[name] = sk
  room:addSkill(sk)
  GameEvent.Turn:create(TurnData:new(current, "game_rule", { Player.Start })):exec()
  lu.assertTrue(ran)
end

Testqiao_nu_generals = {
  setup = function()
    rooms.initQiaoRoom()
    run(function(room, p)
      fixture.installBlankGenerals(room, { "han", "han", "han", "wei" })
      room.current = p
      p.phase = Player.Play
    end)
  end,
  tearDown = rooms.clearRoom,
}
local T = Testqiao_nu_generals
function T:testAllGeneralsAndCommandersRegistered()
  run(function(room)
    local commanders, kinds = 0, {}
    lu.assertEquals(#D.generals, 12)
    for _, entry in ipairs(D.generals) do
      local g = Fk.generals[entry.id]
      lu.assertEquals(g.package.name, "qiao_bingqing")
      lu.assertEquals(g.prefix, "qiao_prefix_nu")
      if entry.commander then
        commanders = commanders + 1
        table.insertIfNeed(kinds, entry.commander.retinue)
        lu.assertTrue(Commander.isCommander(entry.id))
        lu.assertTrue(Commander.isRetinue(entry.commander.retinue))
        lu.assertTrue(Fk.generals[entry.commander.retinue].hidden)
      end
      for _, sk in ipairs(entry.skills) do
        lu.assertTrue(#Fk.skill_skels[sk.id].effects > 0)
        lu.assertEquals(Fk:translate(":" .. sk.id), sk.text)
      end
    end
    lu.assertEquals(commanders, 9)
    lu.assertEquals(#kinds, 7)
    lu.assertFalse(table.contains(room.disabled_packs, "qiao_bingqing"))
  end)
end
function T:testLizhiDrawThresholdAndRealDistributionOnDying()
  run(function(room, tao, a, b)
    general(room, tao, "han055")
    local n, hp = a:getHandcardNum(), a.hp
    room.logic:trigger(fk.EventPhaseStart, a, { phase = Player.Finish })
    lu.assertEquals(a.hp, hp - 1)
    lu.assertEquals(a:getHandcardNum(), n + 2)
    for i = 1, 3 do card(room, tao, "qiao__slash") end
    local ids = tao:getCardIds("h")
    tao.hp = 0
    fixture.withSkillRequests(room, id("han055_2"), {
      askToYiji = function() return { [a.id] = { ids[1], ids[2] }, [b.id] = { ids[3] } } end,
    }, function() room.logic:trigger(fk.EnterDying, tao, { who = tao }) end)
    lu.assertEquals(tao.hp, 1)
    lu.assertTrue(room:getCardOwner(ids[1]) == a and room:getCardOwner(ids[3]) == b)
  end)
end
function T:testGongqiChangesRangeAndDiscardsOpponentsCard()
  run(function(room, han, to)
    general(room, han, "wu028")
    local weapon = card(room, han, "qiao__spear")
    local robbed = card(room, to, "qiao__slash")
    local base = han:getAttackRange()
    fixture.withSkillRequests(room, id("wu028_1"), {
      askToChoosePlayers = function() return { to } end,
      askToChooseCard = function() return robbed.id end,
    }, function() playSkill(room, han, id("wu028_1"), {}, { weapon.id }) end)
    lu.assertEquals(han:getAttackRange(), base + 4)
    lu.assertEquals(room:getCardArea(weapon.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(robbed.id), Card.DiscardPile)
    lu.assertFalse(Fk.skills[id("wu028_1")]:canUse(han))
  end)
end
function T:testDianjunPaysHealthAndSealsSecondConversion()
  run(function(room, zhang, to)
    general(room, zhang, "shu054")
    local material = card(room, zhang, "qiao__jink")
    local hp, victimHp = zhang.hp, to.hp
    fixture.withSkillRequests(room, id("shu054_2"), { askToChoice = function() return "Cancel" end }, function()
      playSkill(room, zhang, id("shu054_1"), { to }, { material.id })
    end)
    lu.assertEquals(zhang.hp, hp - 1)
    lu.assertEquals(to.hp, victimHp - 1)
    lu.assertEquals(zhang:getMark("qiao_dianjun-turn"), 1)
    lu.assertEquals(room:getCardArea(material.id), Card.DiscardPile)
  end)
end
function T:testKangruiChangesNextDamageAndThenMaxHandBase()
  run(function(room, actor, zhang, victim)
    general(room, zhang, "shu054")
    local base, hp = actor:getMaxCards(), victim.hp
    fixture.withSkillRequests(room, id("shu054_2"), { askToChoice = function() return "qiao_kangrui_damage" end }, function()
      room:loseHp(actor, 1, "test")
      lu.assertEquals(actor:getMark("qiao_kangrui_limit-turn"), 0)
      room:damage { from = actor, to = victim, damage = 1 }
    end)
    lu.assertEquals(victim.hp, hp - 2)
    lu.assertEquals(actor:getMark("qiao_kangrui_limit-turn"), 1)
    lu.assertTrue(actor:getMaxCards() < base)
  end)
end
function T:testXieweiPlacesPhysicalBaitAndMovesWithGuanhai()
  run(function(room, guan, to, ally)
    general(room, guan, "qun139")
    local material = card(room, guan, "qiao__jink")
    local hp = to.hp
    playSkill(room, guan, id("qun139_1"), { to }, { material.id }, "slash")
    lu.assertEquals(guan:getPile("qiao_nu_er"), { material.id })
    lu.assertEquals(to.hp, hp - 1)
    lu.assertEquals(guan:getMark("qiao_xiewei_slash-round"), 1)
    lu.assertNotNil(E.exchange(room, { player = guan }, { player = ally }))
    lu.assertEquals(ally:getPile("qiao_nu_er"), { material.id })
    lu.assertEquals(#guan:getPile("qiao_nu_er"), 0)
  end)
end
function T:testJinuGivesHandlyCardsAndSurvivesExchange()
  run(function(room, meng, ally)
    general(room, meng, "jin076")
    local stored = card(room, meng, "qiao__jink")
    fixture.withSkillRequests(room, id("jin076_1"), { askToCards = function() return { stored.id } end }, function()
      room.logic:trigger(fk.EventPhaseStart, meng, { phase = Player.Finish })
    end)
    lu.assertTrue(table.contains(meng:getHandlyIds(true), stored.id))
    lu.assertEquals(meng:getPile("qiao_nu_jinu"), { stored.id })
    lu.assertNotNil(E.exchange(room, { player = meng }, { player = ally }))
    lu.assertTrue(table.contains(ally:getHandlyIds(true), stored.id))
    lu.assertEquals(ally:getPile("qiao_nu_jinu"), { stored.id })
  end)
end
function T:testShizhongSingleTargetStillDrawsOnce()
  run(function(room, li, target)
    general(room, li, "jin067")
    local n = li:getHandcardNum()
    fixture.withSkillRequests(room, id("jin067_2"), { askToSkillInvoke = function() return true end }, function()
      for _ = 1, 2 do room:useCard { from = li, tos = { target }, card = Fk:cloneCard("qiao__slash") } end
    end)
    lu.assertEquals(li:getHandcardNum(), n + 1)
  end)
end
function T:testHuajiaCountsTwoDanyangInstancesOnOnePlayerOnce()
  run(function(room, he, other)
    general(room, he, "wu048")
    grant(other, "danyang_qingjin", "main")
    grant(other, "danyang_qingjin", "deputy")
    local weapon = room:printCard("qiao__spear", Card.Spade, 11)
    local base = he:getMaxCards()
    room:moveCardTo(weapon, Card.PlayerEquip, other, fk.ReasonPut)
    lu.assertEquals(he:getMaxCards(), base + 1)
  end)
end

function T:testYuexianRejectsOldJinkAndAcceptsDrawnJinkInNextUse()
  run(function(room, zhang, to)
    general(room, zhang, "shu036")
    local old = card(room, to, "qiao__jink")
    local hp = to.hp
    local n = 0
    fixture.withSkillRequests(room, id("shu036_1"), {
      askToChoice = function() n = n + 1; return n == 1 and "0" or "1" end,
    }, function()
      FkTest.setNextReplies(to, { { card = old.id } })
      room:useCard { from = zhang, tos = { to }, card = Fk:cloneCard("qiao__slash") }
      lu.assertEquals(to.hp, hp - 1)
      lu.assertEquals(room:getCardArea(old.id), Card.PlayerHand)
      local fresh = room:printCard("qiao__jink", Card.Heart, 9)
      room:moveCards { ids = { fresh.id }, toArea = Card.DrawPile, drawPilePosition = 1, moveReason = fk.ReasonPut }
      FkTest.setNextReplies(to, { { card = fresh.id } })
      room:useCard { from = zhang, tos = { to }, card = Fk:cloneCard("qiao__slash") }
      lu.assertEquals(to.hp, hp - 1)
      lu.assertEquals(room:getCardArea(fresh.id), Card.DiscardPile)
    end)
    lu.assertEquals(n, 2)
  end)
end
function T:testHuanjiaBorrowsWeaponAndReturnsOnlyToEmptySlot()
  run(function(room, gao, target)
    general(room, gao, "qun029")
    local sword = room:printCard("qiao__spear", Card.Spade, 12)
    room:moveCardIntoEquip(target, sword.id)
    local asks = 0
    fixture.withSkillRequests(room, id("qun029_2"), {
      askToSkillInvoke = function() asks = asks + 1; return true end,
      askToChooseCard = function() return sword.id end,
    }, function()
      room:useCard { from = gao, tos = { target }, card = Fk:cloneCard("qiao__slash") }
    end)
    lu.assertEquals(asks, 1)
    lu.assertTrue(room:getCardOwner(sword.id) == target)
    lu.assertEquals(room:getCardArea(sword.id), Card.PlayerEquip)
  end)
end
function T:testHubaoqiFirstSlashOffersOnePhysicalFollowup()
  run(function(room, cao, target, ally)
    general(room, cao, "wei034")
    grant(ally, "hubaoqi")
    local slash = card(room, ally, "qiao__slash")
    local hp, n = target.hp, ally:getHandcardNum()
    local used = 0
    room:throwCard(target:getCardIds("h"), "test", target, target)
    fixture.withSkillRequests(room, "qiao__retinue_skill_hubaoqi", {
      askToUseCard = function(_, actor)
        lu.assertTrue(actor == ally)
        used = used + 1
        return { from = ally, tos = { target }, card = slash }
      end,
    }, function()
      for _ = 1, 2 do room:useCard { from = ally, tos = { target }, card = Fk:cloneCard("qiao__slash"), extraUse = true } end
    end)
    lu.assertEquals(used, 1)
    lu.assertEquals(ally:getHandcardNum(), n)
    lu.assertEquals(target.hp, hp - 3)
    lu.assertEquals(room:getCardArea(slash.id), Card.DiscardPile)
  end)
end
function T:testJiefanweiEachCopyWorksOnceAndMustHealWounded()
  run(function(room, p, to)
    local name = "qiao__retinue_skill_jiefanwei"
    grant(p, "jiefanwei", "main")
    grant(p, "jiefanwei", "deputy")
    lu.assertFalse(Fk.skills[name]:targetFilter(p, to, {}, {}, nil))
    to.hp = to.maxHp - 2
    for _ = 1, 2 do
      lu.assertTrue(Fk.skills[name]:canUse(p))
      local a, b = card(room, p, "qiao__slash"), card(room, p, "qiao__slash")
      playSkill(room, p, name, { to }, { a.id, b.id })
    end
    lu.assertEquals(to.hp, to.maxHp)
    lu.assertFalse(Fk.skills[name]:canUse(p))
  end)
end
function T:testYangfengUsesLordFactionAndSharesWeaponWithoutMovingIt()
  run(function(room, yang, friend, victim)
    general(room, yang, "han043")
    local Y = require "packages.qiao.pkg.qiao_bingqing.bajia"
    local sword = room:printCard("qiao__chixiao_sword", Card.Spade, 2)
    room:moveCardIntoEquip(victim, sword.id)
    yang:hideGeneral(false)
    fixture.withSkillRequests(room, id("han043_1"), {
      askToChoosePlayers = function() return { victim } end,
      askToChooseCard = function() return sword.id end,
    }, function() yang:revealGeneral(false) end)
    lu.assertTrue(room:getCardOwner(sword.id) == yang)
    lu.assertEquals(Y.lordKingdoms(yang), { "han" })
    lu.assertEquals(#friend:getEquipments(Card.SubtypeWeapon), 0)
    lu.assertEquals(friend:getAttackRange(), sword:getAttackRange(friend))
    local sk = sword:getEquipSkills(friend)[1]
    lu.assertTrue(friend:hasSkill(sk))
    room:throwCard(sword, "test", yang, yang)
    lu.assertFalse(friend:hasSkill(sk))
  end)
end


function T:testYouqueTieDiscardsBothHigherHandsWithoutThunderSlash()
  run(function(room, guan, to)
    general(room, guan, "qun139")
    room:throwCard(guan:getCardIds("h"), "test", guan, guan)
    room:throwCard(to:getCardIds("h"), "test", to, to)
    local bait = card(room, guan, "qiao__slash", Card.Club, 7)
    local mine = card(room, guan, "qiao__slash", Card.Spade, 13)
    local his = card(room, to, "qiao__slash", Card.Heart, 13)
    local seven = card(room, to, "qiao__slash", Card.Diamond, 7)
    guan:addToPile("qiao_nu_er", bait, true, "test")
    FkTest.setNextReplies(to, { FkTest.ReplyChooseCards({ seven.id }) })
    local hp1, hp2 = guan.hp, to.hp
    playSkill(room, guan, id("qun139_2"), { to }, { bait.id })
    for _, c in ipairs({ bait, seven, mine, his }) do lu.assertEquals(room:getCardArea(c.id), Card.DiscardPile) end
    lu.assertEquals(guan.hp, hp1)
    lu.assertEquals(to.hp, hp2)
  end)
end
function T:testTijunReplacesExistingWeaponAndChangesOnlyThatPhase()
  run(function(room, li, target)
    general(room, li, "jin067")
    local old = card(room, target, "qiao__spear")
    local new = card(room, li, "qiao__blade")
    room:moveCardIntoEquip(target, old.id)
    local data = { phase = Player.Judge }
    fixture.withSkillRequests(room, id("jin067_1"), {
      askToSkillInvoke = function() return true end,
      askToChooseCard = function() return new.id end,
      askToChoosePlayers = function() return { target } end,
    }, function() room.logic:trigger(fk.EventPhaseChanging, li, data) end)
    lu.assertEquals(data.phase, Player.Play)
    lu.assertTrue(room:getCardOwner(new.id) == target)
    lu.assertEquals(room:getCardArea(new.id), Card.PlayerEquip)
    lu.assertEquals(room:getCardArea(old.id), Card.DiscardPile)
  end)
end
function T:testJinuBlackJinkJudgesAndTianshuDrawsOnSecondColor()
  run(function(room, meng, to)
    general(room, meng, "jin076")
    local jink = card(room, meng, "qiao__jink")
    fixture.withSkillRequests(room, id("jin076_1"), { askToCards = function() return { jink.id } end }, function()
      room.logic:trigger(fk.EventPhaseStart, meng, { phase = Player.Finish })
    end)
    local function topBlack()
      local c = room:printCard("qiao__slash", Card.Club, 3)
      room:moveCards { ids = { c.id }, toArea = Card.DrawPile, drawPilePosition = 1, moveReason = fk.ReasonPut }
      return c
    end
    topBlack()
    room:judge { who = to, reason = "test" }
    local nextJudge = topBlack()
    local n = meng:getHandcardNum()
    fixture.withSkillRequests(room, id("jin076_2"), { askToSkillInvoke = function() return true end }, function()
      room:responseCard { from = meng, card = jink }
    end)
    lu.assertEquals(room:getCardArea(nextJudge.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(jink.id), Card.DiscardPile)
    lu.assertEquals(meng:getHandcardNum(), n + 1)
  end)
end
function T:testEightDiagramCannotProvideFreeJinkAgainstYuexian()
  run(function(room, zhang, target)
    general(room, zhang, "shu036")
    local armour = card(room, target, "qiao__eight_diagram")
    room:moveCardIntoEquip(target, armour.id)
    local red = room:printCard("qiao__slash", Card.Heart, 12)
    room:moveCards { ids = { red.id }, toArea = Card.DrawPile, drawPilePosition = 1, moveReason = fk.ReasonPut }
    local hp, invoked = target.hp, 0
    fixture.withSkillRequests(room, id("shu036_1"), { askToChoice = function() return "0" end }, function()
      fixture.withSkillRequests(room, "qiao__eight_diagram_skill", { askToSkillInvoke = function() invoked = invoked + 1; return true end }, function()
        room:useCard { from = zhang, tos = { target }, card = Fk:cloneCard("qiao__slash") }
      end)
    end)
    lu.assertEquals(target.hp, hp - 1)
    lu.assertEquals(invoked, 0)
    lu.assertEquals(room:getCardArea(red.id), Card.DrawPile)
  end)
end


function T:testDanyangCopiesRememberEachTargetIndependently()
  run(function(room, p, ally)
    grant(p, "danyang_qingjin")
    grant(p, "danyang_qingjin", "deputy")
    grant(ally, "danyang_qingjin")
    local before = p:getHandcardNum()
    local function use()
      room:useCard { from = p, tos = { ally }, card = Fk:cloneCard("qiao__peach"), extraUse = true }
    end
    ally.hp = 1
    use()
    lu.assertEquals(p:getHandcardNum(), before + 2)
    use()
    lu.assertEquals(p:getHandcardNum(), before + 2)
    grant(p, "danyang_qingjin")
    use()
    lu.assertEquals(p:getHandcardNum(), before + 3)
  end)
end

function T:testXianzhenyingTwoCopiesPayTwoSeparateLegalCards()
  run(function(room, p, target)
    local name = "qiao__retinue_skill_xianzhenying"
    grant(p, "xianzhenying")
    grant(p, "xianzhenying", "deputy")
    local peach, wine = card(room, p, "qiao__peach"), card(room, p, "qiao__analeptic")
    local jink = card(room, p, "qiao__jink")
    local offered, hp = 0, target.hp
    room:throwCard(target:getCardIds("h"), "test", target, target)
    fixture.withSkillRequests(room, name, {
      askToDiscard = function(_, actor, params)
        local cost = offered == 0 and peach or wine
        local pattern = Exppattern:Parse(params.pattern)
        lu.assertTrue(pattern:match(cost))
        lu.assertFalse(pattern:match(jink))
        offered = offered + 1
        return { cost.id }
      end,
    }, function()
      room:useCard { from = p, tos = { target }, card = Fk:cloneCard("qiao__slash") }
    end)
    lu.assertEquals(offered, 2)
    lu.assertEquals(hp - target.hp, 3)
    lu.assertEquals(room:getCardArea(peach.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(wine.id), Card.DiscardPile)
  end)
end

function T:testBajiaLordAssignmentsIncludeSecondGenerationAndWild()
  run(function(room, p)
    local Y = require "packages.qiao.pkg.qiao_bingqing.bajia"
    local cases = {
      { "qiao__sihai_liuqian", "han" }, { "qiao__zhoujun_lingbingyin", "wei" },
      { "qiao__jinxiu_zhengpao", "shu" }, { "qiao__feiyun_gaihai", "wu" },
      { "qiao__shenshou_sizhao", "qun" }, { "qiao__xuehai_mowangzun", "qun" },
      { "qiao__zouyu_fan", "jin" }, { "qiao__xuwang_zhimian", "wild" },
    }
    for _, spec in ipairs(cases) do
      local eq = room:printCard(spec[1], Card.Spade, 3)
      room:moveCardIntoEquip(p, eq.id)
      room:setPlayerMark(p, Y.mark, { eq.id })
      lu.assertEquals(Y.lordKingdoms(p), { spec[2] })
      room:throwCard(eq, "test", p, p)
    end
  end)
end


function T:testDuruiBoostsSlashAgainstOnlyWoundedSurvivor()
  run(function(room, cao, victim, ally)
    general(room, cao, "wei061")
    room:throwCard(victim:getCardIds("h"), "test", victim, victim)
    room:setPlayerProperty(victim, "maxHp", 6)
    victim.hp = 6
    local asked = 0
    fixture.withSkillRequests(room, id("wei061_1"), {
      askToUseVirtualCard = function(_, p)
        asked = asked + 1
        local slash = Fk:cloneCard("qiao__slash")
        slash.skillName = id("wei061_1")
        return { from = p, tos = { victim }, card = slash, extraUse = true }
      end,
    }, function()
      runStartPhase(room, ally, "qiao_test_nu_durui_turn", function()
        room:damage { from = ally, to = victim, damage = 2 }
      end)
    end)
    lu.assertEquals(asked, 1)
    lu.assertEquals(victim.hp, 2)
  end)
end

function T:testShizhongAddsTargetAndDrawsForDifferentBoardSizes()
  run(function(room, li, first, extra)
    general(room, li, "jin067")
    local spear = card(room, li, "qiao__spear")
    room:moveCardIntoEquip(li, spear.id)
    local axe = card(room, extra, "qiao__axe")
    room:moveCardIntoEquip(extra, axe.id)
    local count, hp1, hp2 = li:getHandcardNum(), first.hp, extra.hp
    for _, to in ipairs({ first, extra }) do room:throwCard(to:getCardIds("h"), "test", to, to) end
    fixture.withSkillRequests(room, id("jin067_2"), {
      askToSkillInvoke = function() return true end,
      askToChoosePlayers = function(_, _, params)
        lu.assertTrue(table.contains(params.targets, extra))
        return { extra }
      end,
    }, function()
      room:useCard { from = li, tos = { first }, card = Fk:cloneCard("qiao__slash") }
    end)
    lu.assertEquals(first.hp, hp1 - 1)
    lu.assertEquals(extra.hp, hp2 - 1)
    lu.assertEquals(li:getHandcardNum(), count + 2)
  end)
end

function T:testJiefanweiRefreshesGongqiForASecondUse()
  run(function(room, han)
    general(room, han, "wu028")
    grant(han, "jiefanwei")
    local gongqi, jiefan = id("wu028_1"), "qiao__retinue_skill_jiefanwei"
    local base = han:getAttackRange()
    playSkill(room, han, gongqi, {}, { card(room, han, "qiao__slash").id })
    local a, b = card(room, han, "qiao__slash"), card(room, han, "qiao__slash")
    han.hp = han.maxHp - 1
    fixture.withSkillRequests(room, jiefan, {
      askToChoice = function(_, _, params)
        lu.assertTrue(table.contains(params.choices, gongqi))
        return gongqi
      end,
    }, function() playSkill(room, han, jiefan, { han }, { a.id, b.id }) end)
    lu.assertEquals(han:usedSkillTimes(gongqi, Player.HistoryPhase), 0)
    playSkill(room, han, gongqi, {}, { card(room, han, "qiao__slash").id })
    lu.assertEquals(han:getAttackRange(), base + 8)
  end)
end

function T:testBajiaLossOnlyPenalizesInsideAPhase()
  run(function(room, yang, friend, current)
    general(room, yang, "han043")
    local Y = require "packages.qiao.pkg.qiao_bingqing.bajia"
    local hp = yang.hp
    for _, inside in ipairs({ false, true }) do
      local armour = room:printCard("qiao__eight_diagram", Card.Club, 4)
      room:moveCardIntoEquip(friend, armour.id)
      yang:hideGeneral(false)
      fixture.withSkillRequests(room, id("han043_1"), {
        askToChoosePlayers = function() return { friend } end,
        askToChooseCard = function() return armour.id end,
      }, function() yang:revealGeneral(false) end)
      lu.assertEquals(#Y.cards(yang), 1)
      local function lose()
        room:throwCard(armour, "test", yang, yang)
        lu.assertEquals(yang.hp, hp)
      end
      if inside then runStartPhase(room, current, "qiao_test_nu_bajia_phase", lose) else lose() end
      lu.assertEquals(yang.hp, inside and hp - 1 or hp)
      lu.assertEquals(yang:hasShownSkill(id("han043_1")), not inside)
    end
  end)
end


function T:testSizhenJinkResponseAllowsDistantSlashAtPhaseEnd()
  run(function(room, cao, current, _, far)
    general(room, cao, "wei034")
    local jink = card(room, cao, "qiao__jink")
    room:throwCard(far:getCardIds("h"), "test", far, far)
    local hp, asked = far.hp, 0
    lu.assertFalse(cao:inMyAttackRange(far))
    fixture.withSkillRequests(room, id("wei034_1"), {
      askToUseVirtualCard = function(_, p)
        asked = asked + 1
        local slash = Fk:cloneCard("qiao__slash")
        slash.skillName = id("wei034_1")
        return { from = p, tos = { far }, card = slash }
      end,
    }, function()
      runStartPhase(room, current, "qiao_test_nu_sizhen_jink", function()
        FkTest.setNextReplies(cao, { { card = jink.id } })
        room:useCard { from = current, tos = { cao }, card = Fk:cloneCard("qiao__slash") }
        lu.assertEquals(room:getCardArea(jink.id), Card.DiscardPile)
      end)
    end)
    lu.assertEquals(asked, 1)
    lu.assertEquals(far.hp, hp - 1)
  end)
end

function T:testSuweiJudgesTwiceUsesTwoColorsAgainstDistantCurrentPlayer()
  run(function(room, p, _, _, current)
    local name = "qiao__retinue_skill_suwei_zhongjun"
    grant(p, "suwei_zhongjun")
    room:throwCard(current:getCardIds("h"), "test", current, current)
    local hp = current.hp
    lu.assertFalse(p:inMyAttackRange(current))
    fixture.withSkillRequests(room, name, { askToSkillInvoke = function() return true end }, function()
      runStartPhase(room, current, "qiao_test_nu_suwei_turn", function()
        for _, equip in ipairs({ "qiao__eight_diagram", "qiao__dark_armor" }) do
          room:useCard { from = p, tos = { p }, card = card(room, p, equip) }
        end
        for _, suit in ipairs({ Card.Heart, Card.Club }) do
          local judge = room:printCard("qiao__jink", suit, 3)
          room:moveCards { ids = { judge.id }, toArea = Card.DrawPile, drawPilePosition = 1, moveReason = fk.ReasonPut }
        end
      end)
    end)
    lu.assertEquals(current.hp, hp - 2)
  end)
end


function T:testHuanjiaReturnsBothSaddlesAfterBorrowedDualMountWasReplaced()
  run(function(room, gao, other)
    general(room, gao, "qun029")
    local mount = room:printCard("qiao__liulongcanjia", Card.Heart, 13)
    local attack = room:printCard("qiao__chitu", Card.Heart, 5)
    local defense = room:printCard("qiao__jueying", Card.Spade, 5)
    local Placement = require "packages.qiao.pkg.qiao_mode.rules.mount_placement"
    local prior = room:printCard("qiao__zixing", Card.Diamond, 13)
    Placement.put(room, gao, prior.id, "test")
    room:moveCardIntoEquip(other, mount.id)
    room:throwCard(other:getCardIds("h"), "test", other, other)
    local damage, exchanged = room.damage, false
    room.damage = function(self, data)
      if data.to == other and not exchanged then
        exchanged = true
        lu.assertTrue(room:getCardOwner(mount.id) == gao)
        lu.assertEquals(room:getCardArea(prior.id), Card.DiscardPile)
        Placement.put(room, gao, attack.id, "test")
        Placement.put(room, gao, defense.id, "test")
      end
      return damage(self, data)
    end
    fixture.withSkillRequests(room, id("qun029_2"), {
      askToSkillInvoke = function() return true end,
      askToChooseCard = function() return mount.id end,
    }, function()
      room:useCard { from = gao, tos = { other }, card = Fk:cloneCard("qiao__slash") }
    end)
    room.damage = damage
    lu.assertTrue(exchanged)
    lu.assertEquals(room:getCardArea(mount.id), Card.DiscardPile)
    lu.assertTrue(room:getCardOwner(attack.id) == other)
    lu.assertTrue(room:getCardOwner(defense.id) == other)
  end)
end


local bajia = id("han043_1")
local Yu = require "packages.qiao.pkg.qiao_bingqing.bajia"
local function pickYu(room, yang, owner, equip, deputy)
  if (deputy and yang.deputyGeneral or yang.general) ~= "anjiang" then yang:hideGeneral(deputy == true) end
  fixture.withSkillRequests(room, bajia, {
    askToChoosePlayers = function() return { owner } end,
    askToChooseCard = function() return equip.id end,
  }, function() yang:revealGeneral(deputy == true) end)
  lu.assertTrue(table.contains(yang:getTableMark(Yu.mark), equip.id))
end

local function withBajiaReveal(room, yang, accept, fn)
  local original, asks = room.askToSkillInvoke, 0
  room.askToSkillInvoke = function(self, actor, params)
    local sk = Fk.skills[params.skill_name]
    if actor == yang and sk and sk:getSkeleton().name == bajia then
      asks = asks + 1
      return accept
    end
    return original(self, actor, params)
  end
  fn()
  room.askToSkillInvoke = original
  return asks
end

function T:testBajiaYuPersistsAndBothSharedEffectsRequireShownEffectiveSkill()
  run(function(room, yang, ally, source, enemy)
    general(room, yang, "han043")
    local shu = room.players[5]
    room:setPlayerProperty(shu, "kingdom", "shu")
    local sword = room:printCard("qiao__chixiao_sword", Card.Heart, 9)
    local armour = room:printCard("qiao__jinxiu_zhengpao", Card.Spade, 2)
    room:moveCardIntoEquip(source, sword.id)
    room:moveCardIntoEquip(source, armour.id)
    pickYu(room, yang, source, sword)
    local function check(active, both)
      local use = UseCardData:new { from = yang, tos = { enemy }, card = Fk:cloneCard("qiao__slash") }
      room.logic:trigger(fk.CardUsing, yang, use)
      lu.assertEquals(table.contains(use.disresponsiveList or {}, ally), active)
      lu.assertFalse(table.contains(use.disresponsiveList or {}, enemy))
      lu.assertEquals(table.contains(use.disresponsiveList or {}, shu), active and both)
      lu.assertEquals(ally:hasSkill(sword:getEquipSkills(ally)[1]), active)
      lu.assertEquals(ally:hasSkill(armour:getEquipSkills(ally)[1]), active and both)
      lu.assertEquals(#Yu.cards(yang), both and 2 or 1)
      lu.assertEquals(sword:getMark("@qiao_bajia_yu"), 1)
    end
    check(true, false)
    yang:hideGeneral(false)
    check(false, false)
    fixture.withSkillRequests(room, bajia, {
      askToChoosePlayers = function() return { source } end,
      askToChooseCard = function() return armour.id end,
    }, function() yang:revealGeneral(false) end)
    check(true, true)
    room:invalidateSkill(yang, bajia)
    check(false, true)
    room:validateSkill(yang, bajia)
    check(true, true)
    room:handleAddLoseSkills(yang, "-" .. bajia)
    check(false, true)
    room:handleAddLoseSkills(yang, bajia)
    check(true, true)
    room:handleAddLoseSkills(yang, "-" .. bajia)
    room:moveCardIntoEquip(source, sword.id)
    lu.assertEquals(sword:getMark("@qiao_bajia_yu"), 0)
    lu.assertEquals(#Yu.cards(yang), 1)
    lu.assertEquals(#Yu.cards(source), 0)
    room:moveCardIntoEquip(yang, sword.id)
    lu.assertEquals(sword:getMark("@qiao_bajia_yu"), 0)
  end)
end

function T:testBajiaHiddenDeputyMayRevealOnLossAndTakeNewYuBeforePayment()
  run(function(room, yang, ally, source)
    fixture.installDualGenerals(room, yang, { main = "qiao_test__han_2", deputy = Yu.general, kingdom = "han" })
    local sword = room:printCard("qiao__spear", Card.Spade, 12)
    local armour = room:printCard("qiao__eight_diagram", Card.Club, 2)
    room:moveCardIntoEquip(source, sword.id)
    room:moveCardIntoEquip(source, armour.id)
    pickYu(room, yang, source, sword, true)
    yang:hideGeneral(true)
    yang:prelightSkill(bajia, true)
    local hp = yang.hp
    runStartPhase(room, ally, "qiao_test_bajia_hidden_deputy", function()
      fixture.withSkillRequests(room, bajia, {
        askToChoosePlayers = function() return { source } end,
        askToChooseCard = function() return armour.id end,
      }, function()
        local asks = withBajiaReveal(room, yang, true, function() room:throwCard(sword, "test", yang, yang) end)
        lu.assertEquals(asks, 1)
      end)
      lu.assertEquals(yang.deputyGeneral, Yu.general)
      lu.assertEquals(yang:getTableMark(Yu.mark), { armour.id })
      lu.assertTrue(ally:hasSkill(armour:getEquipSkills(ally)[1]))
      lu.assertEquals(yang.hp, hp)
    end)
    lu.assertEquals(yang.hp, hp - 1)
    lu.assertEquals(yang.deputyGeneral, "anjiang")
    lu.assertEquals(armour:getMark("@qiao_bajia_yu"), 1)
    lu.assertFalse(ally:hasSkill(armour:getEquipSkills(ally)[1]))
  end)
end

function T:testBajiaHiddenDeclineOrInvalidityDoesNotSchedulePayment()
  run(function(room, yang, current, source)
    general(room, yang, "han043")
    local hp = yang.hp
    for i = 1, 2 do
      local equip = room:printCard("qiao__spear", Card.Spade, 12)
      room:moveCardIntoEquip(source, equip.id)
      pickYu(room, yang, source, equip)
      yang:hideGeneral(false)
      yang:prelightSkill(bajia, true)
      if i == 2 then room:invalidateSkill(yang, bajia) end
      runStartPhase(room, current, "qiao_test_bajia_pass_" .. i, function()
        local asks = withBajiaReveal(room, yang, false, function() room:throwCard(equip, "test", yang, yang) end)
        lu.assertEquals(asks, i == 1 and 1 or 0)
        lu.assertEquals(equip:getMark("@qiao_bajia_yu"), 0)
        lu.assertEquals(yang.general, "anjiang")
      end)
      lu.assertEquals(yang.hp, hp)
    end
  end)
end

function T:testBajiaTwoYuLostInOneMoveOnlyChargeTheirOwner()
  run(function(room, yang, ally, source)
    general(room, yang, "han043")
    local sword = room:printCard("qiao__spear", Card.Spade, 12)
    local armour = room:printCard("qiao__eight_diagram", Card.Club, 2)
    room:moveCardIntoEquip(source, sword.id)
    room:moveCardIntoEquip(source, armour.id)
    pickYu(room, yang, source, sword)
    pickYu(room, yang, source, armour)
    -- 另一名角色也有自己的「舆」，同一阵营共享装备效果仍各自计算失去。
    local otherYu = room:printCard("qiao__chixiao_sword", Card.Heart, 9)
    general(room, ally, "han043")
    room:moveCardIntoEquip(source, otherYu.id)
    pickYu(room, ally, source, otherYu)
    local hp, allyHp = yang.hp, ally.hp
    runStartPhase(room, ally, "qiao_test_bajia_batch_loss", function()
      room:throwCard({ sword.id, armour.id }, "test", yang, yang)
      lu.assertEquals(#Yu.cards(yang), 0)
      lu.assertEquals(yang.hp, hp)
      room:invalidateSkill(yang, bajia)
    end)
    lu.assertEquals(yang.hp, hp - 2)
    lu.assertEquals(yang.general, "anjiang")
    lu.assertEquals(ally.hp, allyHp)
    lu.assertEquals(ally.general, Yu.general)
    lu.assertEquals(ally:getTableMark(Yu.mark), { otherYu.id })
  end)
end

function T:testBajiaPhaseOutsideRevealHasNoPaymentInNextPhase()
  run(function(room, yang, ally, source)
    general(room, yang, "han043")
    local sword = room:printCard("qiao__spear", Card.Spade, 12)
    local armour = room:printCard("qiao__eight_diagram", Card.Club, 2)
    room:moveCardIntoEquip(source, sword.id)
    room:moveCardIntoEquip(source, armour.id)
    pickYu(room, yang, source, sword)
    yang:hideGeneral(false)
    yang:prelightSkill(bajia, true)
    local hp = yang.hp
    runStartPhase(room, ally, "qiao_test_bajia_turn_end", function()
      fixture.withSkillRequests(room, bajia, {
        askToChoosePlayers = function() return { source } end,
        askToChooseCard = function() return armour.id end,
      }, function()
        local asks = withBajiaReveal(room, yang, true, function() room:throwCard(sword, "test", yang, yang) end)
        lu.assertEquals(asks, 1)
      end)
    end, fk.TurnEnd)
    lu.assertEquals(yang.general, Yu.general)
    lu.assertEquals(yang:getTableMark(Yu.mark), { armour.id })
    runStartPhase(room, ally, "qiao_test_bajia_outside", function() end)
    lu.assertEquals(yang.hp, hp)
    lu.assertEquals(yang.general, Yu.general)
  end)
end


-- 在原生事件中插入一次嵌套动作，仍由引擎执行两次用牌或整批移动。
local function onceAt(room, name, timing, accepts, action)
  local probe = fk.CreateSkill { name = name }
  local ran = false
  probe:addEffect(timing, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return not ran and accepts(target, player, data)
    end,
    on_refresh = function(self, event, target, player, data)
      ran = true
      action(data)
    end,
  })
  local installed = probe:createSkill()
  Fk.skills[name] = installed
  room:addSkill(installed)
  return function() return ran end
end

local function checkNestedHubaoqi(addTarget)
  run(function(room, user, first, nested, extra)
    grant(user, "hubaoqi")
    card(room, user, "qiao__slash")
    local outer = Fk:cloneCard("qiao__slash")
    local ran = onceAt(room, addTarget and "#qiao_test_hubao_multi" or "#qiao_test_hubao_single",
      fk.TargetConfirmed, function(target, player, data)
        return player == first and target == first and data.card == outer
      end, function(aim)
        room:useCard { from = user, tos = { nested }, card = Fk:cloneCard("qiao__slash"), extraUse = true }
        if addTarget then aim:addTarget(extra) end
      end)
    local offers = {}
    fixture.withSkillRequests(room, "qiao__retinue_skill_hubaoqi", {
      askToUseCard = function(_, _, params)
        table.insert(offers, params.extra_data.exclusive_targets[1])
        return nil
      end,
    }, function() room:useCard { from = user, tos = { first }, card = outer, extraUse = true } end)
    lu.assertTrue(ran())
    lu.assertEquals(offers, { addTarget and nested.id or first.id })
  end)
end
function T:testHubaoqiNestedSlashKeepsFirstDeclaredTarget() checkNestedHubaoqi(false) end
function T:testHubaoqiFallsBackWhenFirstSlashGainsATarget() checkNestedHubaoqi(true) end

local function equip(room, owner, name)
  local equipment = card(room, owner, name)
  room:moveCardIntoEquip(owner, equipment.id)
  return equipment
end

function T:testProtectedTreasureExcludedFromHuanjiaAndBajia()
  run(function(room, gao, yang, sun)
    general(room, gao, "qun029")
    general(room, yang, "han043")
    general(room, sun, "em_wu001")
    local treasure = equip(room, sun, "qiao__bronze_sparrow")
    local original = equip(room, gao, "qiao__luminous_pearl")
    fixture.withSkillRequests(room, id("qun029_2"), {
      askToSkillInvoke = function() error("只有受保护的宝物时不能发动擐甲") end,
    }, function()
      room:useCard { from = gao, tos = { sun }, card = Fk:cloneCard("qiao__slash"), extraUse = true }
    end)
    lu.assertEquals(gao:getEquipments(Card.SubtypeTreasure), { original.id })
    local weapon = equip(room, sun, "qiao__spear")
    yang:hideGeneral(false)
    local asked = false
    fixture.withSkillRequests(room, id("han043_1"), {
      askToChoosePlayers = function() return { sun } end,
      askToChooseCard = function(_, _, params)
        lu.assertEquals(params.flag.card_data[1][2], { weapon.id })
        asked = true
        return weapon.id
      end,
    }, function() yang:revealGeneral(false) end)
    lu.assertTrue(asked)
    lu.assertIs(room:getCardOwner(weapon.id), yang)
    lu.assertEquals(sun:getEquipments(Card.SubtypeTreasure), { treasure.id })
  end)
end

function T:testTijunCannotReplaceSunsProtectedTreasure()
  run(function(room, li, sun)
    general(room, li, "jin067")
    general(room, sun, "em_wu001")
    local old = equip(room, sun, "qiao__luminous_pearl")
    local new = card(room, li, "qiao__bronze_sparrow")
    local offered = false
    local phase = { phase = Player.Judge }
    fixture.withSkillRequests(room, id("jin067_1"), {
      askToSkillInvoke = function() return true end,
      askToChooseCard = function() return new.id end,
      askToChoosePlayers = function(_, _, params)
        lu.assertFalse(table.contains(params.targets, sun))
        offered = true
        return { sun } -- 过期回复也不能强行置入。
      end,
    }, function() room.logic:trigger(fk.EventPhaseChanging, li, phase) end)
    lu.assertTrue(offered)
    lu.assertEquals(phase.phase, Player.Judge)
    lu.assertEquals(sun:getEquipments(Card.SubtypeTreasure), { old.id })
    lu.assertEquals(room:getCardArea(new.id), Card.PlayerHand)
  end)
end

local function checkTijunReplacement(block)
  run(function(room, li)
    general(room, li, "jin067")
    local new = card(room, li, "qiao__bronze_sparrow")
    local old = equip(room, li, "qiao__luminous_pearl")
    local ran
    if block then
      ran = onceAt(room, "#qiao_test_tijun_block_" .. block, fk.BeforeCardsMove,
        function(_, player, moves)
          return player == li and table.find(moves, function(move) return move.skillName == id("jin067_1") end)
        end, function(moves) room:cancelMove(moves, { block == "incoming" and new.id or old.id }) end)
    end
    local phase = { phase = Player.Judge }
    fixture.withSkillRequests(room, id("jin067_1"), {
      askToSkillInvoke = function() return true end,
      askToChooseCard = function() return new.id end,
      askToChoosePlayers = function() return { li } end,
    }, function() room.logic:trigger(fk.EventPhaseChanging, li, phase) end)
    if block then
      lu.assertTrue(ran())
      lu.assertEquals(phase.phase, Player.Judge)
      lu.assertEquals(room:getCardArea(new.id), Card.PlayerHand)
      lu.assertEquals(li:getEquipments(Card.SubtypeTreasure), { old.id })
    else
      lu.assertEquals(phase.phase, Player.Play)
      lu.assertEquals(room:getCardArea(old.id), Card.DiscardPile)
      lu.assertEquals(li:getEquipments(Card.SubtypeTreasure), { new.id })
    end
  end)
end
function T:testTijunCommitsActualReplacement() checkTijunReplacement() end
function T:testTijunIncomingBlockedKeepsOldEquipment() checkTijunReplacement("incoming") end
function T:testTijunOutgoingBlockedKeepsIncomingInHand() checkTijunReplacement("outgoing") end

local function checkJinuSpear(storedFirst)
  run(function(room, meng, target)
    general(room, meng, "jin076")
    equip(room, meng, "qiao__spear")
    local stored = card(room, meng, "qiao__jink")
    local hand = card(room, meng, "qiao__jink")
    fixture.withSkillRequests(room, id("jin076_1"), {
      askToCards = function() return { stored.id } end,
    }, function() room.logic:trigger(fk.EventPhaseStart, meng, { phase = Player.Finish }) end)
    local materials = storedFirst and { stored.id, hand.id } or { hand.id, stored.id }
    local spear = Fk.skills["qiao__spear_skill"]
    lu.assertTrue(spear:cardFilter(meng, materials[1], {}, {}))
    lu.assertTrue(spear:cardFilter(meng, materials[2], { materials[1] }, {}))
    local judge = room.judge
    room.judge = function(self, data)
      lu.assertNotEquals(data.reason, id("jin076_1"), "丈八转化的杀不应触发积弩判定")
      return judge(self, data)
    end
    room:useCard { from = meng, tos = { target }, card = spear:viewAs(meng, materials), extraUse = true }
    room.judge = judge
    lu.assertEquals(room:getCardArea(stored.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(hand.id), Card.DiscardPile)
  end)
end
function T:testJinuSpearWithStoredMaterialFirst() checkJinuSpear(true) end
function T:testJinuSpearWithStoredMaterialLast() checkJinuSpear(false) end

local jiefanwei = "qiao__retinue_skill_jiefanwei"
local function healWithRetinue(room, user, target)
  local a, b = card(room, user, "qiao__slash"), card(room, user, "qiao__slash")
  playSkill(room, user, jiefanwei, { target }, { a.id, b.id })
end

function T:testJiefanweiCannotRestoreItsOwnLimitedUseByHealingSelf()
  run(function(room, user)
    grant(user, "jiefanwei")
    user.hp = user.maxHp - 2
    fixture.withSkillRequests(room, jiefanwei, {
      askToChoice = function() error("自己没有用过出牌阶段限一次的技能") end,
    }, function() healWithRetinue(room, user, user) end)
    lu.assertEquals(user.hp, user.maxHp - 1)
    lu.assertFalse(Fk.skills[jiefanwei]:canUse(user))
  end)
end


function T:testJiefanweiTwoAlliesRestoreTwoSpentCopies()
  run(function(room, holder, first, second)
    grant(holder, "jiefanwei", "main")
    grant(holder, "jiefanwei", "deputy")
    grant(first, "jiefanwei")
    grant(second, "jiefanwei")
    holder.hp = holder.maxHp - 2
    first.hp = first.maxHp - 2
    healWithRetinue(room, holder, first)
    healWithRetinue(room, holder, first)
    lu.assertFalse(Fk.skills[jiefanwei]:canUse(holder))
    local restored = 0
    fixture.withSkillRequests(room, jiefanwei, {
      askToChoice = function(_, _, params)
        lu.assertTrue(table.contains(params.choices, jiefanwei))
        restored = restored + 1
        return jiefanwei
      end,
    }, function()
      healWithRetinue(room, first, holder)
      healWithRetinue(room, second, holder)
    end)
    lu.assertEquals(restored, 2)
    for _, instance in ipairs(R.instancesForSkill(holder, jiefanwei)) do lu.assertEquals(instance.uses, 0) end
  end)
end

local function checkLordReset(key, activate)
  run(function(room, user, lord)
    general(room, lord, key)
    grant(user, "jiefanwei")
    local limited = id(key .. "_3")
    local invoked = 0
    local function useLimitedSkill()
      fixture.withSkillRequests(room, limited, {
        askToSkillInvoke = function(_, _, params)
          if not params.prompt:find("invoke", 1, true) then return false end
          invoked = invoked + 1
          return true
        end,
      }, function() activate(room, lord) end)
    end
    useLimitedSkill()
    lu.assertEquals(invoked, 1)
    lord.hp = 1
    fixture.withSkillRequests(room, jiefanwei, {
      askToChoice = function(_, chooser, params)
        lu.assertIs(chooser, user)
        lu.assertTrue(table.contains(params.choices, limited))
        return limited
      end,
    }, function() healWithRetinue(room, user, lord) end)
    useLimitedSkill()
    lu.assertEquals(invoked, 2)
    useLimitedSkill()
    lu.assertEquals(invoked, 2)
  end)
end
function T:testJiefanweiRestoresJizhaoForNextDying()
  checkLordReset("em_shu001", function(room, lord)
    lord.hp = 0
    room.logic:trigger(fk.EnterDying, lord, { who = lord })
  end)
end
function T:testJiefanweiRestoresDingfeiForNextFinish()
  checkLordReset("em_jin001", function(room, lord)
    room:setPlayerProperty(lord, "kingdom", "jin")
    lord.phase = Player.Finish
    lord.hp = 1
    room.logic:trigger(fk.EventPhaseStart, lord, { phase = Player.Finish })
  end)
end

return { name = "qiao_nu_generals" }
