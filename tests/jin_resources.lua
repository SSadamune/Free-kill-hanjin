-- JIN002/JIN007/JIN008 资源类技能与腹心死士：泰然、夷灭、恤下、宜室、识度。
-- 规则依据：docs/rules/generals/jin002-simashi.md、jin007-wangyuanji.md、
-- jin008-xiahouhui.md。
local support = __dofile("../../../tests/support/hegemony.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local H = require "packages.hegemony.util"

local TAIRAN = "qiao__skill_jin002_1"
local YIMIE = "qiao__skill_jin002_2"
local XUXIA = "qiao__skill_jin007_2"
local YISHI = "qiao__skill_jin008_1"
local SHIDU = "qiao__skill_jin008_2"
local FUXIN = "qiao__retinue_skill_fuxin_sishi"
local RULE = "qiao__jin_resources_rule"

Testqiao_jin_resources = {}
Testqiao_jin_resources.tearDown = support.clearRoom

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

local function setHand(room, player, specs)
  clearCards(room, player)
  return give(room, player, specs)
end

local function addEquip(room, player, name)
  inRoom(function()
    local card = room:printCard(name, Card.Spade, 1)
    room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
  end)
end

local function install(room, player, main, deputy, kingdom)
  inRoom(function()
    skill_test.installDualGenerals(room, player, {
      main = main,
      deputy = deputy or "qiao_test__jin_2",
      kingdom = kingdom or "jin",
    })
  end)
end

local function prepare()
  local room = support.initQiaoRoom()
  inRoom(function() skill_test.installBlankGenerals(room, { "jin", "jin", "wei" }) end)
  resetCards(room)
  return room
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end

local function triggerPlayStart(room, player)
  inRoom(function()
    room.current = player
    player.phase = Player.Play
    room.logic:trigger(fk.EventPhaseStart, player, { phase = Player.Play })
  end)
end

local function triggerTurnEnd(room, player)
  inRoom(function()
    room.current = player
    room.logic:trigger(fk.TurnEnd, player, TurnData:new(player, "game_rule", { Player.Start }))
  end)
end

local function damage(room, from, to, num)
  inRoom(function()
    room:damage { from = from, to = to, damage = num or 1, skillName = "test" }
  end)
end

-- 泰然 ---------------------------------------------------------------------

function Testqiao_jin_resources:testTairanRecordsAndSettlesAtTurnEnd()
  local room = prepare()
  local p = p1()
  install(room, p, "qiao_heg__jin002")
  local card = setHand(room, p, { { "jink" } })[1]
  inRoom(function() p.hp = p.maxHp end)

  FkTest.setNextReplies(p, { "1", FkTest.ReplyDiscard({ card }) })
  skill_test.withSkillRequests(room, TAIRAN, {
    askToNumber = function() return 1 end,
  }, function() triggerPlayStart(room, p) end)

  lu.assertEquals(p.hp, p.maxHp - 1)
  lu.assertEquals(#p:getCardIds("h"), 0)
  lu.assertEquals(#p:getTableMark("qiao_jin002_1_records-turn"), 1)

  triggerTurnEnd(room, p)
  lu.assertEquals(p.hp, p.maxHp)
  lu.assertEquals(#p:getCardIds("h"), 1)
  lu.assertEquals(#p:getTableMark("qiao_jin002_1_records-turn"), 0)
end

function Testqiao_jin_resources:testTairanTwoRecordsSettleSeparatelyAfterSkillLoss()
  local room = prepare()
  local p = p1()
  install(room, p, "qiao_heg__jin002")
  inRoom(function() p.hp = p.maxHp end)

  for _ = 1, 2 do
    local card = give(room, p, { { "jink" } })[1]
    FkTest.setNextReplies(p, { "1", FkTest.ReplyDiscard({ card }) })
    skill_test.withSkillRequests(room, TAIRAN, {
      askToNumber = function() return 1 end,
    }, function() triggerPlayStart(room, p) end)
  end
  lu.assertEquals(#p:getTableMark("qiao_jin002_1_records-turn"), 2)
  lu.assertEquals(p.hp, p.maxHp - 2)

  -- 后续不得依赖当前仍有泰然。
  inRoom(function()
    room:handleAddLoseSkills(p, "-" .. TAIRAN, nil, false, true)
  end)
  lu.assertFalse(p:hasSkill(TAIRAN))
  triggerTurnEnd(room, p)
  lu.assertEquals(p.hp, p.maxHp)
  lu.assertEquals(#p:getCardIds("h"), 2)
end

function Testqiao_jin_resources:testTairanRecordsActualLossBeforeRescue()
  local room = prepare()
  local p = p1()
  install(room, p, "qiao_heg__jin002")
  local card = setHand(room, p, { { "jink" } })[1]
  inRoom(function() p.hp = 1 end)

  -- 模拟濒死救回：在 HpChanged 后插入回复1，旧的前后体力差会错误记0。
  local healed = false
  local skel = fk.CreateSkill { name = "#qiao_jin_resources_rescue_probe" }
  skel:addEffect(fk.HpChanged, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return not healed and data ~= nil and data.reason == "loseHp"
        and data.hpLostEvent ~= nil and data.hpLostEvent.skillName == TAIRAN
    end,
    on_refresh = function(self, event, target, player, data)
      healed = true
      player.room:recover {
        who = data.who, num = 1, recoverBy = data.who, skillName = "test_rescue",
      }
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)

  FkTest.setNextReplies(p, { "1", FkTest.ReplyDiscard({ card }) })
  skill_test.withSkillRequests(room, TAIRAN, {
    askToNumber = function() return 1 end,
  }, function() triggerPlayStart(room, p) end)

  local records = p:getTableMark("qiao_jin002_1_records-turn")
  lu.assertEquals(#records, 1)
  lu.assertEquals(records[1].hp, 1) -- 实际失去1，不因救回变0
  lu.assertEquals(records[1].cards, 1)

  triggerTurnEnd(room, p)
  lu.assertEquals(p.hp, 2)
  lu.assertEquals(#p:getCardIds("h"), 1)
end

-- 夷灭 ---------------------------------------------------------------------

function Testqiao_jin_resources:testYimieDoublesOnlyEligibleDamageOnce()
  local room = prepare()
  local p, target = p1(), p2()
  install(room, p, "qiao_heg__jin002")
  inRoom(function()
    p.hp = 3
    target.hp = 3
  end)
  FkTest.setNextReplies(p, { "1" })
  damage(room, p, target)
  lu.assertEquals(target.hp, 1)
  lu.assertEquals(p:usedSkillTimes(YIMIE, Player.HistoryGame), 1)

  -- 第二次伤害不再翻倍。
  inRoom(function() target.hp = 3 end)
  damage(room, p, target)
  lu.assertEquals(target.hp, 2)
  lu.assertEquals(p:usedSkillTimes(YIMIE, Player.HistoryGame), 1)
end

function Testqiao_jin_resources:testYimieRequiresTargetHpNotLower()
  local room = prepare()
  local p, target = p1(), p2()
  install(room, p, "qiao_heg__jin002")
  inRoom(function()
    p.hp = 4
    target.hp = 3
  end)
  damage(room, p, target)
  lu.assertEquals(target.hp, 2)
  lu.assertEquals(p:usedSkillTimes(YIMIE, Player.HistoryGame), 0)
end

-- 恤下 ---------------------------------------------------------------------

function Testqiao_jin_resources:testXuxiaGivesTwoThenDrawsTwo()
  local room = prepare()
  local p, target = p1(), p2()
  install(room, p, "qiao_heg__jin007")
  inRoom(function() target:hideGeneral(true) end)
  local hand = setHand(room, p, { { "jink" } })[1]
  addEquip(room, p, "jueying")
  local equip = p:getCardIds("e")[1]
  local before = #target:getCardIds("h")

  lu.assertTrue(p:hasSkill(XUXIA))
  FkTest.setNextReplies(p, { FkTest.ReplyChooseCards({ hand, equip }) })
  FkTest.setRoomBreakpoint(p, "AskForUseActiveSkill", function(data)
    return data[2] == "#qiao__skill_jin007_2-give::" .. target.id
  end)
  damage(room, p3(), target)
  FkTest.runInClient(function()
    local handler = ClientInstance.current_request_handler
    lu.assertEquals(handler.skill_name, "choose_cards_skill")
    local me = handler.player
    local handCards, equips = me.player_cards[Player.Hand], me.player_cards[Player.Equip]
    me.player_cards[Player.Hand], me.player_cards[Player.Equip] = { hand }, { equip }
    local CardItem = require("ui_emu.common").CardItem
    if not handler.scene:getAllItems("CardItem")[hand] then
      handler.scene:addItem(CardItem:new(handler.scene, hand))
    end
    handler:setup()
    lu.assertTrue(handler:cardValidity(hand))
    lu.assertTrue(handler:cardValidity(equip))
    handler:update("CardItem", hand, "click", { selected = true })
    lu.assertFalse(handler.scene:getAllItems("Button").OK.enabled)
    handler:update("CardItem", equip, "click", { selected = true })
    lu.assertTrue(handler.scene:getAllItems("Button").OK.enabled)
    lu.assertEquals(handler.selected_targets, {})
    lu.assertFalse(handler:targetValidity(me.id))
    local reply, notify = nil, ClientInstance.notifyUI
    ClientInstance.notifyUI = function(_, name, data)
      if name == "ReplyToServer" then reply = data end
    end
    local ok, err = pcall(handler.doOKButton, handler)
    ClientInstance.notifyUI = notify
    if not ok then error(err, 0) end
    lu.assertEquals(reply.card.subcards, { hand, equip })
    lu.assertEquals(reply.targets, {})
    me.player_cards[Player.Hand], me.player_cards[Player.Equip] = handCards, equips
  end)
  FkTest.resumeRoom()

  lu.assertEquals(#target:getCardIds("h"), before + 2)
  lu.assertTrue(table.contains(target:getCardIds("h"), hand))
  lu.assertTrue(table.contains(target:getCardIds("h"), equip))
  lu.assertEquals(#p:getCardIds("h"), 2)
  lu.assertEquals(p:usedSkillTimes(XUXIA, Player.HistoryTurn), 1)
end

function Testqiao_jin_resources:testXuxiaNeedsFewerRevealedAndTwoCards()
  local room = prepare()
  local p, target = p1(), p2()
  install(room, p, "qiao_heg__jin007")
  setHand(room, p, { { "jink" } })

  -- 目标明置数与王元姬相同：不触发。
  damage(room, p3(), target)
  lu.assertEquals(p:usedSkillTimes(XUXIA, Player.HistoryTurn), 0)

  -- 目标明置数较少但王元姬只有一张牌：仍不触发。
  inRoom(function() target:hideGeneral(true) end)
  damage(room, p3(), target)
  lu.assertEquals(p:usedSkillTimes(XUXIA, Player.HistoryTurn), 0)
end

-- 宜室 ---------------------------------------------------------------------

function Testqiao_jin_resources:testYishiGivesOneThenGainsOne()
  local room = prepare()
  local p, proposer, owner = p1(), p2(), p3()
  install(room, p, "qiao_heg__jin008")
  local cards = setHand(room, owner, { { "jink" }, { "peach" }, { "slash" } })
  local beforeP = #p:getCardIds("h")
  local beforeProposer = #proposer:getCardIds("h")

  FkTest.setNextReplies(p, {
    "1",
    cards[1],
    cards[2],
  })
  inRoom(function()
    room:throwCard({ cards[1], cards[2], cards[3] }, "test", owner, proposer)
  end)

  lu.assertEquals(#proposer:getCardIds("h"), beforeProposer + 1)
  lu.assertEquals(#p:getCardIds("h"), beforeP + 1)
  lu.assertEquals(room:getCardArea(cards[3]), Card.DiscardPile)
  lu.assertEquals(p:usedEffectTimes(YISHI, Player.HistoryTurn), 1)
end

function Testqiao_jin_resources:testYishiUsesProposerKingdomNotOwner()
  local room = prepare()
  local p, proposer, owner = p1(), p2(), p3()
  install(room, p, "qiao_heg__jin008")
  local cards = setHand(room, owner, { { "jink" }, { "peach" } })

  -- 弃置操作者是异势力 p3，即使被弃牌属于同势力 p2，也不触发。
  FkTest.setNextReplies(p, {})
  inRoom(function()
    room:throwCard({ cards[1], cards[2] }, "test", owner, proposer)
  end)
  lu.assertEquals(p:usedEffectTimes(YISHI, Player.HistoryTurn), 0)
  lu.assertEquals(#p:getCardIds("h"), 0)
end

-- 识度 ---------------------------------------------------------------------

function Testqiao_jin_resources:testShiduWinsThenGivesHalfCurrentHand()
  local room = prepare()
  local p, target = p1(), p2()
  install(room, p, "qiao_heg__jin008")
  local high = setHand(room, p, { { "jink", Card.Spade, 13 }, { "peach" } })
  local low = setHand(room, target, { { "slash", Card.Spade, 2 }, { "jink" } })

  -- 拼点由 p1、p2 各选一张；赢后 p1 再选择交还的 1 张。
  FkTest.setNextReplies(p, {
    FkTest.ReplyChooseCards({ high[1] }),
  })
  FkTest.setNextReplies(target, {
    FkTest.ReplyChooseCards({ low[1] }),
  })

  inRoom(function()
    room.current = p
    local original = room.askToUseActiveSkill
    room.askToUseActiveSkill = function(self, chooser, params)
      if params.prompt == "#qiao__skill_jin008_2-give:::1" then
        lu.assertFalse(params.extra_data.include_equip == true)
        FkTest.setNextReplies(chooser, { client_room.confirmCards(self, chooser, params, { high[2] }) })
      end
      return original(self, chooser, params)
    end
    room:handleUseCardReply(p, FkTest.ReplyUseSkill(SHIDU, { target }, {}))
    room.askToUseActiveSkill = original
  end)

  -- p1 拼点牌离手后剩 1 张，赢后获得 p2 剩余手牌共 2 张，交还 1 张。
  lu.assertEquals(#p:getCardIds("h"), 1)
  lu.assertEquals(#target:getCardIds("h"), 1)
  lu.assertTrue(table.contains(target:getCardIds("h"), high[2]))
end

function Testqiao_jin_resources:testShiduTieDoesNotGainHand()
  local room = prepare()
  local p, target = p1(), p2()
  install(room, p, "qiao_heg__jin008")
  local mine = setHand(room, p, { { "jink", Card.Spade, 13 } })
  local theirs = setHand(room, target, { { "slash", Card.Spade, 13 }, { "peach" } })

  FkTest.setNextReplies(p, { FkTest.ReplyChooseCards({ mine[1] }) })
  FkTest.setNextReplies(target, { FkTest.ReplyChooseCards({ theirs[1] }) })
  inRoom(function()
    room.current = p
    room:handleUseCardReply(p, FkTest.ReplyUseSkill(SHIDU, { target }, {}))
  end)

  lu.assertEquals(#p:getCardIds("h"), 0)
  lu.assertEquals(#target:getCardIds("h"), 1)
end

-- 腹心死士 -----------------------------------------------------------------

function Testqiao_jin_resources:testFuxinUnusedLimitedGivesCard()
  local room = prepare()
  local holder, turnPlayer = p1(), p2()
  install(room, holder, "qiao_test__jin_1")
  install(room, turnPlayer, "qiao_heg__jin002")
  local own = setHand(room, holder, { { "jink" } })[1]
  setHand(room, turnPlayer, {})
  inRoom(function()
    room:handleAddLoseSkills(holder, FUXIN, nil, false, true)
  end)
  lu.assertTrue(holder:hasSkill(FUXIN))

  FkTest.setNextReplies(holder, { "1", FkTest.ReplyChooseCards({ own }) })
  triggerTurnEnd(room, turnPlayer)

  -- 摸一张后交给其一张：持有者仍剩一张，当前回合角色得到一张。
  lu.assertEquals(#holder:getCardIds("h"), 1)
  lu.assertEquals(#turnPlayer:getCardIds("h"), 1)
end

function Testqiao_jin_resources:testFuxinSelfTargetOnlyDrawsNoSelfGive()
  local room = prepare()
  local p = p1()
  install(room, p, "qiao_heg__jin002")
  inRoom(function() room:handleAddLoseSkills(p, FUXIN, nil, false, true) end)
  setHand(room, p, {})

  FkTest.setNextReplies(p, { "1" })
  triggerTurnEnd(room, p)

  -- 目标就是持有者：不能把牌交给自己，只执行可执行的摸一张。
  lu.assertEquals(#p:getCardIds("h"), 1)
end

function Testqiao_jin_resources:testFuxinUsedLimitedSlashUsesTurnPlayersRange()
  local room = prepare()
  local holder, turnPlayer, victim = p1(), p2(), room.players[4]
  install(room, holder, "qiao_test__jin_1")
  install(room, turnPlayer, "qiao_test__jin_1")
  inRoom(function()
    room:handleAddLoseSkills(holder, FUXIN, nil, false, true)
    victim.hp = 3
  end)
  -- 当前回合角色攻击范围为 2；持有者仍为 1。目标 p4 只在其范围内。
  addEquip(room, turnPlayer, "qinggang_sword")

  -- 用测试限定技制造“本回合发动过限定技”的真实技能使用历史。
  local probeSkel = fk.CreateSkill {
    name = "#qiao_jin_resources_limited_probe",
    tags = { Skill.Limited },
  }
  probeSkel:addEffect("active", {
    can_use = Util.TrueFunc,
    card_num = 0,
    target_num = 0,
    card_filter = Util.FalseFunc,
    target_filter = Util.FalseFunc,
    on_use = function() end,
  })
  local probe = probeSkel:createSkill()
  Fk.skills[probeSkel.name] = probe
  inRoom(function()
    room:addSkill(probe)
    room:handleAddLoseSkills(turnPlayer, probeSkel.name, nil, false, true)
    room:handleUseCardReply(turnPlayer, FkTest.ReplyUseSkill(probeSkel.name, {}, {}))
  end)

  FkTest.setNextReplies(holder, { FkTest.ReplyChoosePlayer({ victim }) })
  triggerTurnEnd(room, turnPlayer)

  -- 目标范围锚定当前回合角色（p2），不是翼从持有者；p3 应受到【杀】伤害。
  lu.assertEquals(victim.hp, 2)
end

function Testqiao_jin_resources:testXuxiaRealDarkSourceIsRegisteredAndTriggers()
  local room = prepare()
  local p, target = p1(), p2()
  install(room, p, "qiao_heg__jin007")
  inRoom(function()
    p:hideGeneral(false)
    p:hideGeneral(true)
    target:hideGeneral(false)
    target:hideGeneral(true)
    p:prelightSkill(Fk.skills[XUXIA], true)
  end)
  -- 真来源必须已把 fk.Damaged 效果注册到房间；fixture 不成立时明确失败待验。
  local registered = table.find(room.logic.skill_table[fk.Damaged] or {}, function(s)
    local skel = s and s.getSkeleton and s:getSkeleton()
    return s ~= nil and (s.name == XUXIA or (skel and skel.name == XUXIA))
  end)
  lu.assertNotNil(registered)
  lu.assertEquals(H.getGeneralsRevealedNum(p), 0)
  lu.assertEquals(H.getGeneralsRevealedNum(target), 0)
  lu.assertTrue(p:hasSkill(XUXIA))

  local hand = setHand(room, p, { { "jink" }, { "peach" } })
  local before = #target:getCardIds("h")
  inRoom(function()
    lu.assertTrue(registered:triggerable(nil, target, p, { from = p3(), to = target, damage = 1 }),
      "恤下暗将的来源、预测明置数及两张牌条件应满足")
  end)
  -- TriggerSkill:doCost adds a fake-skill confirmation when the test backend
  -- completes all cost requests in under one second. Keep that real request.
  FkTest.setNextReplies(p, { FkTest.ReplyChooseCards({ hand[1], hand[2] }), "1" })
  inRoom(function() room.current = p end)
  damage(room, p3(), target)

  lu.assertEquals(p:usedSkillTimes(XUXIA, Player.HistoryTurn), 1)
  lu.assertTrue(H.getGeneralsRevealedNum(p) >= 1)
  lu.assertEquals(#target:getCardIds("h"), before + 2)
end
return { name = "qiao_jin_resources" }
