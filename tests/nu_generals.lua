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
local function equip(room, owner, name)
  local equipment = card(room, owner, name)
  room:moveCardIntoEquip(owner, equipment.id)
  return equipment
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
local function healWithRetinue(room, user, target)
  local a, b = card(room, user, "qiao__slash"), card(room, user, "qiao__slash")
  playSkill(room, user, jiefanwei, { target }, { a.id, b.id })
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
return { name = "qiao_nu_generals" }
