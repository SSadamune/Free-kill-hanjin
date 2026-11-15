-- JIN011/JIN012/JIN014 晋标准包首批：果毅、慈威、弘训、膂力、夺气。
-- 规则依据：rules/generals/jin011-zhanghu-yuechen.md、
-- rules/generals/jin012-yanghuiyu.md、rules/generals/jin014-wenyang.md。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local GUOYI = "hanjin__skill_jin011_1"
local GUOYI_ACTIVE = GUOYI
local GUOYI_EQUIP = "hanjin__skill_jin011_1-equip"
local GUOYI_HAND = "hanjin__skill_jin011_1-hand"

local CIWEI = "hanjin__skill_jin012_1"

local HONGXUN = "hanjin__skill_jin012_2"

local LVLI = "hanjin__skill_jin014_1"
local LVLI_DRAW = "hanjin__skill_jin014_1-draw"
local LVLI_RECOVER = "hanjin__skill_jin014_1-recover"

local DUOQI = "hanjin__skill_jin014_2"

Testhanjin_jin_basic = {}
Testhanjin_jin_basic.tearDown = support.clearRoom

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
  local id
  inRoom(function()
    local card = room:printCard(name, Card.Spade, 1)
    room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

local function install(room, general)
  inRoom(function()
    skill_test.installDualGenerals(room, room.players[1], {
      main = general,
      deputy = "hanjin_test__jin_2",
      kingdom = "jin",
    })
  end)
end

local function prepare(general)
  local room = support.initHanjinRoom()
  inRoom(function() skill_test.installBlankGenerals(room, { "jin", "jin", "wei" }) end)
  install(room, general)
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

--- 在真实 Turn 的 TurnStart 时机执行 fn，保证 room.current 就是该角色。
local function runTurnStart(room, player, fn)
  local fired = false
  local skel = fk.CreateSkill { name = "#hanjin_jin_basic_turn_probe" }
  skel:addEffect(fk.TurnStart, {
    global = true,
    can_refresh = function(self, event, target, probe_player)
      return not fired and target == player and probe_player == player
    end,
    on_refresh = function()
      fired = true
      -- 直接创建的 Turn 事件不经过 Round，不会自动写入 current；真实回合由
      -- Round 设置。慈威的“其回合内”判定需要这一公开状态。
      room:setCurrent(player)
      fn()
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Play })):exec()
  end)
end

local function triggerFinish(room, player)
  inRoom(function()
    room.current = player
    player.phase = Player.Finish
    room.logic:trigger(fk.EventPhaseStart, player, { phase = Player.Finish })
  end)
end

local function dealDamage(room, from, to, num)
  inRoom(function()
    room:damage { from = from, to = to, damage = num or 1, skillName = "test" }
  end)
end

-- 果毅 ---------------------------------------------------------------------

function Testhanjin_jin_basic:testGuoyiBothBranchesAndDamage()
  local room = prepare("hanjin__jin011")
  local p = p1()
  local basics = setHand(room, p, { { "slash" }, { "jink" } })
  local equip = addEquip(room, p2(), "jueying")
  local hand = setHand(room, p3(), { { "peach" } })[1]
  inRoom(function() p3().hp = p3().maxHp end)
  local before = p2().hp

  runPlayPhase(room, p, {
    FkTest.ReplyUseSkill(GUOYI_ACTIVE, { p2(), p3() }, basics),
    FkTest.ReplyChoosePlayer({ p2() }),
  })

  lu.assertEquals(#p:getCardIds("h"), 1) -- 获得 p3 的一张手牌；两张基本牌已弃置
  lu.assertTrue(table.contains(p:getCardIds("h"), hand))
  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)
  lu.assertEquals(p2().hp, before - 1)
  lu.assertEquals(p:usedSkillTimes(GUOYI, Player.HistoryGame), 1)
end

function Testhanjin_jin_basic:testGuoyiOneBranchOnlyNoDamage()
  local room = prepare("hanjin__jin011")
  local p = p1()
  local basics = setHand(room, p, { { "slash" }, { "jink" } })
  local h2 = setHand(room, p2(), { { "peach" } })[1]
  local h3 = setHand(room, p3(), { { "peach" } })[1]
  local before = p2().hp

  runPlayPhase(room, p, {
    FkTest.ReplyUseSkill(GUOYI_ACTIVE, { p2(), p3() }, basics),
  })

  lu.assertTrue(table.contains(p:getCardIds("h"), h2))
  lu.assertTrue(table.contains(p:getCardIds("h"), h3))
  lu.assertEquals(p2().hp, before)
  lu.assertEquals(p:usedSkillTimes(GUOYI, Player.HistoryGame), 1)
end

function Testhanjin_jin_basic:testGuoyiTargetWithBothBranchesChoosesOne()
  local room = prepare("hanjin__jin011")
  local p = p1()
  local basics = setHand(room, p, { { "slash" }, { "jink" } })
  local equip = addEquip(room, p2(), "jueying")
  give(room, p2(), { { "peach" } })
  setHand(room, p3(), { { "peach" } })
  local seen
  local before = p2().hp

  skill_test.withSkillRequests(room, GUOYI, {
    askToChoice = function(self, player, params, original)
      if player == p2() and params.skill_name == GUOYI then
        seen = table.simpleClone(params.choices)
        return GUOYI_EQUIP
      end
      return original(self, player, params)
    end,
  }, function()
    runPlayPhase(room, p, {
      FkTest.ReplyUseSkill(GUOYI_ACTIVE, { p2(), p3() }, basics),
      FkTest.ReplyChoosePlayer({ p2() }),
    })
  end)

  lu.assertEquals(seen, { GUOYI_EQUIP, GUOYI_HAND })
  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)
  lu.assertEquals(p2().hp, before - 1)
end

function Testhanjin_jin_basic:testGuoyiRejectsMismatchedCardAndTargetCounts()
  local room = prepare("hanjin__jin011")
  local p = p1()
  local basics = setHand(room, p, { { "slash" }, { "jink" } })
  local equip = addEquip(room, p2(), "jueying")
  setHand(room, p3(), { { "peach" } })

  -- 一张基本牌却指定两名目标：服务端复核后不弃牌、不结算。
  runPlayPhase(room, p, {
    FkTest.ReplyUseSkill(GUOYI_ACTIVE, { p2(), p3() }, { basics[1] }),
  })

  lu.assertTrue(table.contains(p:getCardIds("h"), basics[1]))
  lu.assertEquals(room:getCardArea(equip), Card.PlayerEquip)
end

-- 慈威 ---------------------------------------------------------------------

function Testhanjin_jin_basic:testCiweiSecondRealUseNullifiesBasicTarget()
  local room = prepare("hanjin__jin012")
  local p, user, victim = p1(), p2(), p3()
  local equipped = give(room, user, { { "jueying" } })[1]
  local responded = give(room, user, { { "jink" } })[1]
  local slash = give(room, user, { { "slash" } })[1]
  local cost = give(room, p, { { "peach" } })[1]
  local hp = victim.hp

  FkTest.setNextReplies(p, {
    "1", FkTest.ReplyDiscard({ cost }), FkTest.ReplyChoosePlayer({ victim }),
  })
  runTurnStart(room, user, function()
    -- 已在 TurnStart 的房间协程内，直接执行真实用牌事件，不再嵌套 runInRoom。
    room:useCard { from = user, tos = { user }, card = Fk:getCardById(equipped) }
    -- 纯“打出”只生成 RespondCard，不计入本回合使用牌数。
    room:responseCard { from = user, card = Fk:getCardById(responded) }
    room:useCard { from = user, tos = { victim }, card = Fk:getCardById(slash) }
  end)

  lu.assertEquals(victim.hp, hp)
  lu.assertFalse(victim.chained)
  lu.assertFalse(user.chained)
  lu.assertEquals(#p:getCardIds("h"), 0)
  lu.assertEquals(p:usedSkillTimes(CIWEI, Player.HistoryGame), 1)
end

function Testhanjin_jin_basic:testCiweiCommonTrickTargetNullified()
  local room = prepare("hanjin__jin012")
  local p, user, victim = p1(), p2(), p3()
  local equipped = give(room, user, { { "jueying" } })[1]
  local duel = give(room, user, { { "duel" } })[1]
  local cost = give(room, p, { { "peach" } })[1]
  local hp = victim.hp

  FkTest.setNextReplies(p, {
    "1", FkTest.ReplyDiscard({ cost }), FkTest.ReplyChoosePlayer({ victim }),
  })
  runTurnStart(room, user, function()
    room:useCard { from = user, tos = { user }, card = Fk:getCardById(equipped) }
    room:useCard { from = user, tos = { victim }, card = Fk:getCardById(duel) }
  end)

  -- 目标无效：不进入【决斗】的响应，受害者不受伤。
  lu.assertEquals(victim.hp, hp)
  lu.assertEquals(p:usedSkillTimes(CIWEI, Player.HistoryGame), 1)
end

function Testhanjin_jin_basic:testCiweiEquipmentBranchChainsUser()
  local room = prepare("hanjin__jin012")
  local p, user = p1(), p2()
  local first = give(room, user, { { "slash" } })[1]
  local equip = give(room, user, { { "jueying" } })[1]
  local cost = give(room, p, { { "peach" } })[1]

  FkTest.setNextReplies(p, { "1", FkTest.ReplyDiscard({ cost }) })
  runTurnStart(room, user, function()
    room:useCard { from = user, tos = { p3() }, card = Fk:getCardById(first) }
    room:useCard { from = user, tos = { user }, card = Fk:getCardById(equip) }
  end)

  lu.assertTrue(user.chained)
  lu.assertTrue(table.contains(user:getCardIds("e"), equip))
  lu.assertEquals(p:usedSkillTimes(CIWEI, Player.HistoryGame), 1)
end

function Testhanjin_jin_basic:testCiweiDelayedTrickBranchChainsUser()
  local room = prepare("hanjin__jin012")
  local p, user, victim = p1(), p2(), p3()
  local first = give(room, user, { { "slash" } })[1]
  local delayed = give(room, user, { { "indulgence" } })[1]
  local cost = give(room, p, { { "peach" } })[1]

  FkTest.setNextReplies(p, { "1", FkTest.ReplyDiscard({ cost }) })
  runTurnStart(room, user, function()
    room:useCard { from = user, tos = { victim }, card = Fk:getCardById(first) }
    room:useCard { from = user, tos = { victim }, card = Fk:getCardById(delayed) }
  end)

  lu.assertTrue(user.chained)
  lu.assertTrue(table.contains(victim:getCardIds("j"), delayed))
  lu.assertEquals(p:usedSkillTimes(CIWEI, Player.HistoryGame), 1)
end

-- 弘训 ---------------------------------------------------------------------

function Testhanjin_jin_basic:testHongxunWoundedAndChainedBothExecute()
  local room = prepare("hanjin__jin012")
  local p = p1()
  inRoom(function()
    p.hp = p.maxHp - 1
    p:setChainState(true)
  end)
  local before = #p:getCardIds("h")

  triggerFinish(room, p)

  lu.assertEquals(#p:getCardIds("h"), before + 2)
  lu.assertFalse(p.chained)
end

function Testhanjin_jin_basic:testHongxunSameKingdomOnlyAndConditionsSeparate()
  local room = prepare("hanjin__jin012")
  local p, ally, other = p1(), p2(), p3()

  -- 同势力已受伤：摸一张。
  inRoom(function() ally.hp = ally.maxHp - 1 end)
  local before = #ally:getCardIds("h")
  triggerFinish(room, ally)
  lu.assertEquals(#ally:getCardIds("h"), before + 1)
  lu.assertFalse(ally.chained)

  -- 同势力已横置但未受伤：只重置并摸一张。
  inRoom(function()
    ally.hp = ally.maxHp
    ally:setChainState(true)
  end)
  before = #ally:getCardIds("h")
  triggerFinish(room, ally)
  lu.assertEquals(#ally:getCardIds("h"), before + 1)
  lu.assertFalse(ally.chained)

  -- 不同势力：不摸牌、不重置。
  inRoom(function()
    other.hp = other.maxHp - 1
    other:setChainState(true)
  end)
  before = #other:getCardIds("h")
  triggerFinish(room, other)
  lu.assertEquals(#other:getCardIds("h"), before)
  lu.assertTrue(other.chained)
end

-- 膂力 ---------------------------------------------------------------------

function Testhanjin_jin_basic:testLvliDrawToCurrentHp()
  local room = prepare("hanjin__jin014")
  local p = p1()
  inRoom(function() p.hp = 3 end)
  FkTest.setNextReplies(p, { "1", { LVLI_DRAW } })

  dealDamage(room, p, p2())

  lu.assertEquals(#p:getCardIds("h"), 3)
  lu.assertEquals(p:usedSkillTimes(LVLI, Player.HistoryTurn), 1)
end

function Testhanjin_jin_basic:testLvliDiscardAllHandAndRecoverToCount()
  local room = prepare("hanjin__jin014")
  local p = p1()
  setHand(room, p, { { "slash" }, { "jink" } })
  inRoom(function() p.hp = 1 end)
  FkTest.setNextReplies(p, { "1", { LVLI_RECOVER } })

  dealDamage(room, p, p2())

  lu.assertEquals(#p:getCardIds("h"), 0)
  lu.assertEquals(p.hp, 2)
  lu.assertEquals(p:usedSkillTimes(LVLI, Player.HistoryTurn), 1)
end

function Testhanjin_jin_basic:testLvliSecondOptionAvailabilityAndNoHpReduction()
  local room = prepare("hanjin__jin014")
  local p = p1()
  setHand(room, p, { { "slash" }, { "jink" } })
  inRoom(function() p.hp = 3 end)

  local seen
  skill_test.withSkillRequests(room, LVLI, {
    askToChoice = function(self, player, params, original)
      if player == p and params.skill_name == LVLI then
        seen = table.simpleClone(params.choices)
        return LVLI_RECOVER
      end
      return original(self, player, params)
    end,
  }, function()
    FkTest.setNextReplies(p, { "1" })
    dealDamage(room, p, p2())
  end)

  lu.assertEquals(seen, { LVLI_DRAW, LVLI_RECOVER })
  lu.assertEquals(#p:getCardIds("h"), 0)
  lu.assertEquals(p.hp, 3) -- 弃置2张后回复至2，不把较高的体力降为2
end

function Testhanjin_jin_basic:testLvliDrawOptionHiddenWhenHandNotBelowHp()
  local room = prepare("hanjin__jin014")
  local p = p1()
  setHand(room, p, { { "slash" }, { "jink" } })
  inRoom(function() p.hp = 2 end)

  local seen
  skill_test.withSkillRequests(room, LVLI, {
    askToChoice = function(self, player, params, original)
      if player == p and params.skill_name == LVLI then
        seen = table.simpleClone(params.choices)
        return LVLI_RECOVER
      end
      return original(self, player, params)
    end,
  }, function()
    FkTest.setNextReplies(p, { "1" })
    dealDamage(room, p, p2())
  end)

  lu.assertEquals(seen, { LVLI_RECOVER })
  lu.assertEquals(#p:getCardIds("h"), 0)
  lu.assertEquals(p.hp, 2)
end

function Testhanjin_jin_basic:testLvliResolvesInDamageBeforeDamaged()
  local room = prepare("hanjin__jin014")
  local p = p1()
  inRoom(function() p.hp = 3 end)
  local order
  local skel = fk.CreateSkill { name = "#hanjin_jin_basic_damaged_probe" }
  skel:addEffect(fk.Damaged, {
    global = true,
    can_refresh = function(self, event, target, player)
      return target == p2()
    end,
    on_refresh = function()
      order = p:usedSkillTimes(LVLI, Player.HistoryTurn)
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)
  FkTest.setNextReplies(p, { "1", { LVLI_DRAW } })

  dealDamage(room, p, p2())

  -- fk.Damage 时膂力已结算；若仍用 DamageFinished，则 Damaged 时为 0。
  lu.assertEquals(order, 1)
  lu.assertEquals(#p:getCardIds("h"), 3)
end

function Testhanjin_jin_basic:testLvliEmptyHandOnlyDrawOptionAndOncePerTurn()
  local room = prepare("hanjin__jin014")
  local p = p1()
  inRoom(function() p.hp = 3 end)

  local seen
  skill_test.withSkillRequests(room, LVLI, {
    askToChoice = function(self, player, params, original)
      if player == p and params.skill_name == LVLI then
        seen = table.simpleClone(params.choices)
        return LVLI_DRAW
      end
      return original(self, player, params)
    end,
  }, function()
    FkTest.setNextReplies(p, { "1" })
    dealDamage(room, p, p2())
  end)
  lu.assertEquals(seen, { LVLI_DRAW })
  lu.assertEquals(p:usedSkillTimes(LVLI, Player.HistoryTurn), 1)

  local hand = #p:getCardIds("h")
  dealDamage(room, p, p2())
  lu.assertEquals(#p:getCardIds("h"), hand)
  lu.assertEquals(p:usedSkillTimes(LVLI, Player.HistoryTurn), 1)
end

-- 夺气 ---------------------------------------------------------------------

function Testhanjin_jin_basic:testDuoqiTurnEndQueuesExtraTurn()
  local room = prepare("hanjin__jin014")
  local p, turnPlayer = p1(), p2()
  FkTest.setNextReplies(p, { "1" })

  inRoom(function()
    room.current = turnPlayer
    room.logic:trigger(fk.TurnEnd, turnPlayer, TurnData:new(turnPlayer, "game_rule", { Player.Start }))
  end)

  lu.assertEquals(#room.extra_turn_list, 1)
  lu.assertIs(room.extra_turn_list[1].who, p)
  lu.assertEquals(room.extra_turn_list[1].reason, DUOQI)
  lu.assertEquals(p:usedSkillTimes(DUOQI, Player.HistoryGame), 1)
  room.extra_turn_list = {}
end

function Testhanjin_jin_basic:testDuoqiNotFinishPhaseAndNeedsEmptyHand()
  local room = prepare("hanjin__jin014")
  local p, turnPlayer = p1(), p2()
  inRoom(function() room.current = turnPlayer end)

  -- 结束阶段不触发；只有回合结束时检查。
  inRoom(function()
    room.logic:trigger(fk.EventPhaseStart, turnPlayer, { phase = Player.Finish })
  end)
  lu.assertEquals(#room.extra_turn_list, 0)

  -- 当前回合角色仍有手牌时不触发。
  give(room, turnPlayer, { { "peach" } })
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, turnPlayer, TurnData:new(turnPlayer, "game_rule", { Player.Start }))
  end)
  lu.assertEquals(#room.extra_turn_list, 0)
  lu.assertEquals(p:usedSkillTimes(DUOQI, Player.HistoryGame), 0)
end

function Testhanjin_jin_basic:testDuoqiLimitedToOncePerGame()
  local room = prepare("hanjin__jin014")
  local p, turnPlayer = p1(), p2()
  FkTest.setNextReplies(p, { "1" })
  inRoom(function()
    room.current = turnPlayer
    room.logic:trigger(fk.TurnEnd, turnPlayer, TurnData:new(turnPlayer, "game_rule", { Player.Start }))
  end)
  lu.assertEquals(#room.extra_turn_list, 1)
  room.extra_turn_list = {}

  inRoom(function()
    room.logic:trigger(fk.TurnEnd, turnPlayer, TurnData:new(turnPlayer, "game_rule", { Player.Start }))
  end)
  lu.assertEquals(#room.extra_turn_list, 0)
  lu.assertEquals(p:usedSkillTimes(DUOQI, Player.HistoryGame), 1)
end

return { name = "hanjin_jin_basic" }
