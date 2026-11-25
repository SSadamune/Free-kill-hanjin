-- JIN010 伤逝/扼绝、JIN016 复礼/风物的来源与最小主流程定向用例。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local Qianxi = require "packages.qiao.pkg.qiao_generals.util.shu019_qianxi"
local JinDeck = require "packages.qiao.pkg.qiao_generals.util.jin_deck"
local SkillStatus = require "packages.qiao.pkg.qiao_mode.skill_status"
local ReqPlayCard = require "ltk.core.request_type.play_card"
local ReqUseCard = require "ltk.core.request_type.use_card"

local SHANGSHI = "qiao__skill_jin010_1"
local SHANGSHI_SLASH = "#qiao__skill_jin010_1-slash"
local SHANGSHI_DRAW = "#qiao__skill_jin010_1-draw"
local EJUE = "qiao__skill_jin010_2"
local FULI = "qiao__skill_jin016_1"

Testqiao_jin_sources = {}
Testqiao_jin_sources.tearDown = support.clearRoom

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

local function resetCards(room)
  for _, p in ipairs(room.players) do clearCards(room, p) end
end

local function give(room, player, specs)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room:obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function prepare(general)
  local room = support.initQiaoRoom()
  inRoom(function() skill_test.installBlankGenerals(room, { "jin", "jin", "wei" }) end)
  inRoom(function()
    skill_test.installDualGenerals(room, room.players[1], {
      main = general,
      deputy = "qiao_test__jin_2",
      kingdom = "jin",
    })
  end)
  resetCards(room)
  return room
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end

local function runPlayPhase(room, player, replies)
  FkTest.setNextReplies(player, replies)
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Play })):exec()
  end)
end

--- 真实 ClientPlayer 夹具：不伪造 player.room，临时替换 Fk.currentRoom。
local function withClientRoom(current, fn)
  local ClientPlayer = require "ltk.client.clientplayer"
  local clients = {}
  for _, original in ipairs(current.players) do
    local copy = ClientPlayer:new(original._splayer)
    for key, value in pairs(original) do
      if key ~= "room" and key ~= "class" and key ~= "serverplayer" then copy[key] = value end
    end
    local cards = {}
    for area, ids in pairs(copy.player_cards or {}) do cards[area] = table.simpleClone(ids) end
    copy.player_cards = cards
    table.insert(clients, copy)
  end
  for index, player in ipairs(clients) do
    player.next = clients[index % #clients + 1]
  end
  local clientRoom = setmetatable(
    { players = clients, alive_players = clients, current = clients[1] },
    { __index = current })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = pcall(function() fn(clients, clientRoom) end)
  Fk.currentRoom = originalRoom
  if not ok then error(err) end
  return clients, clientRoom
end

function Testqiao_jin_sources:testEjueLosesNamedGeneralSkillAndRaisesDamage()
  local room = prepare("qiao_heg__jin010")
  local owner, victim = p1(), p2()
  inRoom(function() victim.hp = victim.maxHp end)
  lu.assertTrue(owner:hasSkill(SHANGSHI))
  lu.assertTrue(owner:hasSkill(EJUE))

  skill_test.withSkillRequests(room, EJUE, {
    askToChoice = function(self, player, params, original)
      for _, choice in ipairs(params.choices) do
        if tostring(choice):find("伤逝", 1, true) then return choice end
      end
      return params.choices[1]
    end,
  }, function()
    inRoom(function()
      room:damage {
        from = owner,
        to = victim,
        damage = 1,
        damageType = fk.NormalDamage,
      }
    end)
  end)

  lu.assertFalse(owner:hasSkill(SHANGSHI))
  lu.assertEquals(victim.hp, victim.maxHp - 2)
  lu.assertTrue(owner:hasSkill(EJUE))
end

function Testqiao_jin_sources:testEjueOffersOnlyTheFourGeneralSkillsInTheReportedPair()
  local room = prepare("qiao_heg__jin010")
  local owner, victim = p1(), p2()
  local ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
  local retinues = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
  local commander = "qiao_commander_ability"
  local vanguard = "vanguard_skill&"
  local wenhu = "qiao__retinue_skill_wenhu"
  local equip = "qiao__kylin_bow_skill"
  local taikang = "qiao__skill_em_jin001_1"
  inRoom(function()
    skill_test.installDualGenerals(room, owner, {
      main = "qiao_heg__em_jin001", deputy = "qiao_heg__jin010", kingdom = "jin",
    })
    room:handleAddLoseSkills(owner, ci.SKILL, taikang, false, true)
    room:handleAddLoseSkills(owner, commander .. "|" .. vanguard, "qiao__general_card_skills_rule", false, true)
    ci.save(room, owner, { "qiao_heg__jin004" })
    retinues.grant(owner, { general = "qiao_heg__retinue_wenhu", skill = wenhu, origin = "granted" })
    local bow = room:printCard("qiao__kylin_bow", Card.Heart, 5)
    room:moveCardTo(bow, Card.PlayerEquip, owner, fk.ReasonJustMove)
  end)
  for _, name in ipairs({ ci.SKILL, ci.CONSUME, commander, vanguard, wenhu, equip }) do
    lu.assertTrue(owner:hasSkill(name, true, true), name)
  end

  local options
  skill_test.withSkillRequests(room, EJUE, {
    askToChoice = function(_, _, params)
      options = params.choices
      return "Cancel"
    end,
  }, function()
    inRoom(function() room:damage { from = owner, to = victim, damage = 1 } end)
  end)

  lu.assertNotNil(options)
  lu.assertEquals(table.map(options, function(label) return label:match("^%[%d+%] (.-)（") end), {
    Fk:translate(taikang), Fk:translate("qiao__skill_em_jin001_2"),
    Fk:translate("qiao__skill_em_jin001_3"), Fk:translate(SHANGSHI),
  })
end

function Testqiao_jin_sources:testEjueCanLoseAGrantedGeneralSkill()
  local room = prepare("qiao_heg__jin010")
  local owner, victim = p1(), p2()
  local direct = "qiao__skill_han001_1"
  local derived = "qiao__skill_jin001_2"
  local startedHp = victim.hp
  inRoom(function()
    room:handleAddLoseSkills(owner, direct, nil, false, true)
    room:handleAddLoseSkills(owner, derived, SHANGSHI, false, true)
  end)
  lu.assertTrue(owner:hasSkill(direct))
  lu.assertTrue(owner:hasSkill(derived))

  local options
  skill_test.withSkillRequests(room, EJUE, {
    askToChoice = function(_, _, params)
      options = params.choices
      return table.find(options, function(label)
        return label:find(Fk:translate(derived), 1, true) ~= nil
      end) or "Cancel"
    end,
  }, function()
    inRoom(function() room:damage { from = owner, to = victim, damage = 1 } end)
  end)

  lu.assertNotNil(options)
  lu.assertTrue(table.find(options, function(label) return label:find(Fk:translate(direct), 1, true) ~= nil end) ~= nil)
  lu.assertFalse(owner:hasSkill(derived))
  lu.assertTrue(owner:hasSkill(direct))
  lu.assertTrue(owner:hasSkill(SHANGSHI))
  lu.assertEquals(victim.hp, startedHp - 2)
end

function Testqiao_jin_sources:testShangshiDrawsToLostHpAtAnotherFinishPhase()
  local room = prepare("qiao_heg__jin010")
  local owner, target = p1(), p2()
  inRoom(function()
    owner.maxHp = 4
    owner.hp = 2
  end)
  give(room, owner, { { "qiao__jink" } })
  give(room, target, { { "qiao__peach" }, { "qiao__peach" } })

  FkTest.setNextReplies(owner, { { SHANGSHI_DRAW } })
  skill_test.withSkillRequests(room, SHANGSHI, {
    askToChoice = function(self, player, params, original)
      lu.assertEquals(params.choices, { SHANGSHI_SLASH, SHANGSHI_DRAW })
      lu.assertTrue(params.cancelable)
      return original(self, player, params)
    end,
  }, function()
    inRoom(function()
      target.phase = Player.Finish
      room.logic:trigger(fk.EventPhaseStart, target, { phase = Player.Finish })
    end)
  end)

  lu.assertEquals(#owner:getCardIds("h"), 2)
  lu.assertEquals(target.hp, target.maxHp)
  lu.assertEquals(owner:usedSkillTimes(SHANGSHI, Player.HistoryGame), 1)
end

function Testqiao_jin_sources:testFuliDrawsExtraThenGivesShownCardAndMarksSuit()
  local room = prepare("qiao_heg__jin016")
  local zhangHua, drawer = p1(), p2()
  local shown
  skill_test.withSkillRequests(room, FULI, {
    askToSkillInvoke = function() return true end,
    askToCards = function(self, player, params, original)
      shown = player:getCardIds("h")[1]
      return { shown }
    end,
  }, function()
    inRoom(function()
      local data = { n = 2 }
      room.logic:trigger(fk.DrawNCards, drawer, data)
      lu.assertEquals(data.n, 3)
      room:drawCards(drawer, data.n, "test")
      room.logic:trigger(fk.AfterDrawNCards, drawer, data)
    end)
  end)

  lu.assertNotNil(shown)
  lu.assertTrue(table.contains(zhangHua:getCardIds("h"), shown))
  lu.assertEquals(drawer:getMark("qiao_jin016_1_suit" .. Fk:getCardById(shown).suit .. "-turn"), 1)
  withClientRoom(room, function(clients)
    local player = clients[2]
    local state = table.find(SkillStatus.forPlayer(player), function(entry) return entry.id == "fuli" end)
    lu.assertNotNil(state)
    lu.assertEquals(state.value, JinDeck.suitSymbols({ Fk:getCardById(shown).suit }))
    player:setMark(SkillStatus.fuliSuitMark(Fk:getCardById(shown).suit), 0)
    lu.assertNil(table.find(SkillStatus.forPlayer(player), function(entry) return entry.id == "fuli" end))
  end)
end

function Testqiao_jin_sources:testFengwuClientCanUseWithoutPlayerRoom()
  local room = prepare("qiao_heg__jin016")
  inRoom(function() p1().phase = Player.Play end)

  withClientRoom(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    lu.assertEquals(me.class.name, "ClientPlayer")
    local handler = ReqPlayCard:new(me)
    handler.skill_name = "qiao__skill_jin016_2"
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity("qiao__skill_jin016_2"))
    handler:_finish()
  end)
end

function Testqiao_jin_sources:testFengwuFreeUseHidesPassiveCardsAndRejectsInjectedJink()
  local room = prepare("qiao_heg__jin016")
  local owner, user = p1(), p2()
  inRoom(function() owner.hp = owner.maxHp end)
  local jink = give(room, user, { { "qiao__jink", Card.Spade, 6 } })[1]
  local equip = give(room, user, { { "qinggang_sword", Card.Diamond, 4 } })[1]
  local ownerHand, userHand = #owner:getCardIds("h"), #user:getCardIds("h")

  -- 风物请求：目标回复一张【闪】（无响应时机），服务端必须拒绝并视为放弃。
  local captured
  skill_test.withSkillRequests(room, "qiao__skill_jin016_2", {
    askToUseCard = function(self, player, params, original)
      captured = params
      return original(self, player, params)
    end,
  }, function()
    FkTest.setNextReplies(user, { FkTest.ReplyCard(Fk:getCardById(jink, true), {}) })
    runPlayPhase(room, owner, {
      FkTest.ReplyUseSkill("qiao__skill_jin016_2", { user }, {}),
    })
  end)

  lu.assertNotNil(captured, "风物必须发出真实的自由用牌请求")
  lu.assertEquals(captured.pattern, ".")
  lu.assertTrue(captured.extra_data ~= nil and captured.extra_data.not_passive == true,
    "自由用牌请求必须声明 not_passive")
  lu.assertTrue(table.contains(user:getCardIds("h"), jink),
    "服务端应拒绝注入的【闪】，牌不得被使用")
  lu.assertTrue(table.contains(user:getCardIds("h"), equip), "合法牌不受影响")
  lu.assertEquals(#user:getCardIds("h"), userHand)
  lu.assertEquals(#owner:getCardIds("h"), ownerHand,
    "被拒绝的用牌不得计入风物花色检查")

  -- 真实客户端按同一请求数据判断：无响应时机的被动牌不可选，合法牌仍可选。
  withClientRoom(room, function(clients)
    local me = clients[2]
    local handler = ReqUseCard:new(me, {
      nil, captured.pattern, "", true, captured.extra_data,
    })
    handler:setup()
    lu.assertFalse(handler:cardValidity(jink),
      "客户端不应允许直接选中无响应时机的【闪】")
    lu.assertTrue(handler:cardValidity(equip), "客户端仍应允许合法牌")
    handler:_finish()
  end)
end

local function checkFengwuSlashQuota(ordinaryFirst)
  local room = prepare("qiao_heg__jin016")
  local owner, target = p1(), p2()
  local skillName = "qiao__skill_jin016_2"
  local ordinary, extra = table.unpack(give(room, owner, {
    { "qiao__slash", Card.Spade, 5 }, { "qiao__slash", Card.Heart, 7 },
  }))
  local selectable
  local probe = fk.CreateSkill { name = "#qiao_test_fengwu_slash_request" }
  probe:addEffect(fk.AskForCardUse, {
    global = true,
    can_refresh = function(self, event, who, player, data)
      return who == owner and player == owner and data.skillName == skillName
    end,
    on_refresh = function(self, event, who, player, data)
      withClientRoom(room, function(clients)
        local handler = ReqUseCard:new(clients[1], { nil, data.pattern, "", true, data.extraData })
        handler:setup()
        selectable = handler:cardValidity(extra)
        handler:_finish()
      end)
    end,
  })
  inRoom(function()
    room:addSkill(probe:createSkill())
    room.current, owner.phase = owner, Player.Play
    target.hp = 4
    if ordinaryFirst then support.playCard(room, owner, Fk:getCardById(ordinary), { target }) end
  end)
  FkTest.setNextReplies(owner, { FkTest.ReplyCard(Fk:getCardById(extra), { target }) })
  inRoom(function() room:handleUseCardReply(owner, FkTest.ReplyUseSkill(skillName, { owner }, {})) end)
  lu.assertTrue(selectable)
  lu.assertFalse(table.contains(owner:getCardIds("h"), extra))
  lu.assertEquals(owner:usedCardTimes("slash", Player.HistoryPhase), ordinaryFirst and 1 or 0)
  if not ordinaryFirst then
    withClientRoom(room, function(clients)
      local handler = ReqPlayCard:new(clients[1])
      handler:setup()
      lu.assertTrue(handler:cardValidity(ordinary))
      handler:_finish()
    end)
    inRoom(function() support.playCard(room, owner, Fk:getCardById(ordinary), { target }) end)
  end
  lu.assertEquals(owner:usedCardTimes("slash", Player.HistoryPhase), 1)
  lu.assertEquals(target.hp, 2)
end

function Testqiao_jin_sources:testFengwuCanUseSlashAfterOrdinarySlash()
  checkFengwuSlashQuota(true)
end

function Testqiao_jin_sources:testFengwuSlashLeavesOrdinaryQuotaAvailable()
  checkFengwuSlashQuota(false)
end

function Testqiao_jin_sources:testFengwuThirdSuitThenFourthDrawsAndRecovers()
  local room = prepare("qiao_heg__jin016")
  local owner, user, other = p1(), p2(), p3()
  inRoom(function() owner.hp = owner.maxHp - 1 end)
  local spade = give(room, user, { { "jueying", Card.Spade, 1 } })[1]
  local heart = give(room, user, { { "chitu", Card.Heart, 2 } })[1]
  local club = give(room, other, { { "dilu", Card.Club, 3 } })[1]
  local diamond = give(room, user, { { "qinggang_sword", Card.Diamond, 4 } })[1]

  local prepared = false
  local probe = fk.CreateSkill { name = "#jin016_fengwu_prior" }
  probe:addEffect(fk.StartPlayCard, {
    global = true,
    can_refresh = function(self, event, target, player)
      return target == owner and not prepared
    end,
    on_refresh = function()
      prepared = true
      room:useCard { from = user, tos = { user }, card = Fk:getCardById(spade) }
      room:useCard { from = user, tos = { user }, card = Fk:getCardById(heart) }
      room:useCard { from = other, tos = { other }, card = Fk:getCardById(club) }
    end,
  })
  inRoom(function() room:addSkill(probe:createSkill()) end)

  local hp, hand = owner.hp, #owner:getCardIds("h")
  FkTest.setNextReplies(user, { FkTest.ReplyCard(Fk:getCardById(diamond), { user }) })
  runPlayPhase(room, owner, {
    FkTest.ReplyUseSkill("qiao__skill_jin016_2", { user }, {}),
  })

  lu.assertEquals(owner.hp, hp + 1)
  lu.assertEquals(#owner:getCardIds("h"), hand + 2)
end

function Testqiao_jin_sources:testEjueLostCardSkillDoesNotReturnAfterExchange()
  local room = prepare("qiao_heg__jin010")
  local owner, other = p1(), p2()
  local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  local Duanchang = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"
  inRoom(function() Duanchang.loseCardSkill(room, owner, false, SHANGSHI) end)
  lu.assertFalse(owner:hasSkill(SHANGSHI))

  inRoom(function()
    assert(Exchange.exchange(room, { player = owner, isDeputy = false },
      { player = other, isDeputy = false }))
  end)
  lu.assertFalse(other:hasSkill(SHANGSHI))
end

function Testqiao_jin_sources:testExtraSkillLossDoesNotTravelWithExchange()
  local room = prepare("qiao_heg__jin010")
  local owner, other = p1(), p2()
  local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  local EXTRA = "qiao__skill_han001_1"
  inRoom(function() room:handleAddLoseSkills(owner, EXTRA, nil, true, false) end)
  lu.assertTrue(owner:hasSkill(EXTRA))

  inRoom(function()
    assert(Exchange.exchange(room, { player = owner, isDeputy = false },
      { player = other, isDeputy = false }))
  end)
  lu.assertTrue(owner:hasSkill(EXTRA))
  lu.assertFalse(other:hasSkill(EXTRA))

  inRoom(function() room:handleAddLoseSkills(owner, "-" .. EXTRA, nil, true, false) end)
  lu.assertFalse(owner:hasSkill(EXTRA))
end

function Testqiao_jin_sources:testShangshiRequiresHandMaterialAndDoesNotCountCancellation()
  local room = prepare("qiao_heg__jin010")
  local owner, target = p1(), p2()
  inRoom(function()
    owner.maxHp = 4
    owner.hp = 4
  end)
  give(room, target, { { "qiao__peach" } })
  local hp = target.hp
  local requests = 0

  skill_test.withSkillRequests(room, SHANGSHI, {
    askToChoice = function()
      requests = requests + 1
      return "Cancel"
    end,
  }, function()
    inRoom(function()
      target.phase = Player.Finish
      room.logic:trigger(fk.EventPhaseStart, target, { phase = Player.Finish })
    end)
  end)

  lu.assertEquals(requests, 0)
  lu.assertEquals(target.hp, hp)
  lu.assertEquals(#owner:getCardIds("h"), 0)
  lu.assertEquals(owner:usedSkillTimes(SHANGSHI, Player.HistoryGame), 0)

  local materials = give(room, owner, { { "qiao__jink" } })
  give(room, target, { { "qiao__peach" } })
  skill_test.withSkillRequests(room, SHANGSHI, {
    askToChoice = function()
      requests = requests + 1
      return "Cancel"
    end,
  }, function()
    inRoom(function()
      Qianxi.ensureRule(room)
      Qianxi.addRestriction(room, owner, target, Card.Black)
      room.logic:trigger(fk.EventPhaseStart, target, { phase = Player.Finish })
      Qianxi.clear(room)
    end)
  end)
  lu.assertEquals(requests, 0, "唯一手牌受潜袭限制时冰杀项不可用")

  skill_test.withSkillRequests(room, SHANGSHI, {
    askToChoice = function(self, player, params, original)
      lu.assertEquals(params.choices, { SHANGSHI_SLASH })
      lu.assertEquals(params.all_choices, { SHANGSHI_SLASH, SHANGSHI_DRAW })
      return original(self, player, params)
    end,
    askToCards = function(self, player, params, original)
      lu.assertEquals(params.min_num, 1)
      lu.assertTrue(params.cancelable)
      return original(self, player, params)
    end,
  }, function()
    FkTest.setNextReplies(owner, { { SHANGSHI_SLASH }, "" })
    inRoom(function() room.logic:trigger(fk.EventPhaseStart, target, { phase = Player.Finish }) end)
    lu.assertEquals(owner:usedSkillTimes(SHANGSHI, Player.HistoryGame), 0)
    lu.assertEquals(target.hp, hp)

    FkTest.setNextReplies(owner, { { SHANGSHI_SLASH }, FkTest.ReplyChooseCards(materials), "" })
    inRoom(function() room.logic:trigger(fk.EventPhaseStart, target, { phase = Player.Finish }) end)
    lu.assertEquals(owner:usedSkillTimes(SHANGSHI, Player.HistoryGame), 1)
    lu.assertEquals(target.hp, hp - 1)
    lu.assertEquals(room:getCardArea(materials[1]), Card.DiscardPile)
  end)
end

function Testqiao_jin_sources:testShangshiCanUseTwoCardsWhenSingleSuitIsProhibited()
  local room = prepare("qiao_heg__jin010")
  local owner, target = p1(), p2()
  local materials = give(room, owner, { { "qiao__jink" }, { "qiao__jink" } })
  give(room, target, { { "qiao__peach" }, { "qiao__peach" }, { "qiao__peach" } })
  local hp = target.hp
  FkTest.setNextReplies(owner, { { SHANGSHI_SLASH }, FkTest.ReplyChooseCards(materials), "" })
  inRoom(function()
    target.phase = Player.Finish
    JinDeck.banSuit(room, owner, Card.Spade)
    local single = Fk:cloneCard("qiao__ice__slash")
    single:addSubcard(materials[1])
    lu.assertTrue(owner:prohibitUse(single))
    room.logic:trigger(fk.EventPhaseStart, target, { phase = Player.Finish })
  end)
  lu.assertEquals(target.hp, hp - 1)
  lu.assertEquals(#owner:getCardIds("h"), 0)
end

function Testqiao_jin_sources:testFuliPromiseStillResolvesAfterSkillLost()
  local room = prepare("qiao_heg__jin016")
  local zhangHua, drawer = p1(), p2()
  local shown
  skill_test.withSkillRequests(room, FULI, {
    askToSkillInvoke = function() return true end,
    askToCards = function(self, player, params, original)
      shown = player:getCardIds("h")[1]
      return { shown }
    end,
  }, function()
    inRoom(function()
      local data = { n = 2 }
      room.logic:trigger(fk.DrawNCards, drawer, data)
      lu.assertEquals(data.n, 3)
      -- 承诺已建立后、摸牌完成前失去复礼，独立 rule 仍须兑现。
      room:handleAddLoseSkills(zhangHua, "-" .. FULI, nil, true, false)
      lu.assertFalse(zhangHua:hasSkill(FULI))
      room:drawCards(drawer, data.n, "test")
      room.logic:trigger(fk.AfterDrawNCards, drawer, data)
    end)
  end)

  lu.assertNotNil(shown)
  lu.assertTrue(table.contains(zhangHua:getCardIds("h"), shown))
  lu.assertEquals(drawer:getMark("qiao_jin016_1_suit" .. Fk:getCardById(shown).suit .. "-turn"), 1)
end

return { name = "qiao_jin_sources" }
