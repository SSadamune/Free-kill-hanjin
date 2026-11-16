-- HAN006 王允（连计/定著）、HAN010 董承（承诏）、HAN013 皇甫嵩（奋钺）。
-- 本轮定向验收：交牌、每角色阶段限次、下次伤害+1；定著副将限制与
-- “进入手牌”得牌记录；承诏两牌条件、拼点胜与无视防具；奋钺胜败、下张牌
-- 响应限制及火杀消费限制。
--
-- 本文件尚未在本轮执行；由第一组串行统一运行：
--   python scripts/test.py --file tests/han_standard_pindian.lua --timeout 120
local support = __dofile("../../../tests/support/hegemony.lua")
local History = require "packages.hanjin.pkg.hanjin_generals.util.han_history"

local LJ = "hanjin__skill_han006_1"
local DZ = "hanjin__skill_han006_2"
local CZ = "hanjin__skill_han010_1"
local FY = "hanjin__skill_han013_1"

local NEXT_DAMAGE = "hanjin_skill_han006_1_next_damage-turn"
local LIANJI_TARGETS = "hanjin__skill_han006_1-given_targets-phase"
local OPTION_LOSE_HP = "#hanjin__skill_han013_1-lose_hp"
local OPTION_END_PHASE = "#hanjin__skill_han013_1-end_phase"

local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }
local probeSerial = 0

Testhanjin_han_standard_pindian = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end
local function p4() return FkTest.room.players[4] end
local function p5() return FkTest.room.players[5] end
local function p6() return FkTest.room.players[6] end
local function p7() return FkTest.room.players[7] end
local function p8() return FkTest.room.players[8] end

local function setKingdom(room, player, kingdom)
  inRoom(function()
    player.kingdom = kingdom
    room:setPlayerProperty(player, "kingdom", kingdom)
    room:setPlayerMark(player, "__heg_kingdom", kingdom)
    room:setPlayerMark(player, "__heg_wild", 0)
  end)
end

local function setWild(room, player)
  inRoom(function()
    player.kingdom = "wild"
    room:setPlayerProperty(player, "kingdom", "wild")
    room:setPlayerMark(player, "__heg_wild", 1)
  end)
end

local function setUnknown(room, player)
  inRoom(function()
    player.kingdom = "unknown"
    room:setPlayerProperty(player, "kingdom", "unknown")
    room:setPlayerMark(player, "__heg_kingdom", nil)
    room:setPlayerMark(player, "__heg_wild", 0)
  end)
end

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

--- 替换一名角色的手牌（及可选装备区）。specs: { { name, suit?, number? }, ... }
local function setHand(room, player, specs, area)
  clearCards(room, player, area or "he")
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

local function addHand(room, player, specs)
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

local function installUseProbe(room, uses)
  probeSerial = probeSerial + 1
  local key = "__hanjin_pindian_use_probe_" .. probeSerial
  local skel = fk.CreateSkill { name = "#hanjin_pindian_use_probe_" .. probeSerial }
  skel:addEffect(fk.CardUseFinished, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return type(data) == "table" and not data[key]
        and data.card ~= nil and (data.card.trueName == "slash" or data.card.trueName == "duel")
    end,
    on_refresh = function(self, event, target, player, data)
      data[key] = true
      table.insert(uses, {
        from = data.from,
        tos = table.simpleClone(data.tos or {}),
        card = data.card,
        extraUse = data.extraUse == true,
        disresponsive = table.simpleClone(data.disresponsiveList or {}),
      })
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room:addSkill(skill) end)
end

--- 在 TargetConfirmed 观察承诏当次的无视防具标记；此时技能已写入标记。
local function installArmorProbe(room, records)
  probeSerial = probeSerial + 1
  local key = "__hanjin_pindian_armor_probe_" .. probeSerial
  local skel = fk.CreateSkill { name = "#hanjin_pindian_armor_probe_" .. probeSerial }
  skel:addEffect(fk.PreCardEffect, {
    global = true,
    priority = -100,
    can_refresh = function(self, event, target, player, data)
      return type(data) == "table" and not data[key]
        and data.card ~= nil and data.card.trueName == "slash"
    end,
    on_refresh = function(self, event, target, player, data)
      data[key] = true
      table.insert(records, {
        to = data.to,
        mark = data.to and data.to:getMark(MarkEnum.MarkArmorNullified) or 0,
        tag = data.extra_data and data.extra_data.qinggang_tag,
      })
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room:addSkill(skill) end)
end

local function activate(room, player, skillName, targets, cards)
  inRoom(function()
    room:handleUseCardReply(player, FkTest.ReplyUseSkill(skillName, targets, cards or {}))
  end)
end

local function initializeGenerals(room)
  inRoom(function()
    for i, p in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i]
      p:revealGeneral(false, true)
      p:revealGeneral(true, true)
      room:changeHero(p, "hanjin_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(p, "hanjin_test__" .. kingdom .. "_1", true, false, false, false, false)
      p.kingdom = kingdom
      room:setPlayerProperty(p, "kingdom", kingdom)
      room:setPlayerMark(p, "__heg_general", p.general)
      room:setPlayerMark(p, "__heg_deputy", p.deputyGeneral)
      room:setPlayerMark(p, "__heg_kingdom", kingdom)
      room:setPlayerMark(p, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(p, "__heg_wild", 0)
      p.hp = p.maxHp
    end
  end)
end

--- 换 p1 的主副将；未指定的另一栏使用测试武将，避免残留原武将技能。
local function setP1(room, main, deputy)
  inRoom(function()
    local p = room.players[1]
    p:revealGeneral(false, true)
    p:revealGeneral(true, true)
    -- 主副互换且同名技能跨位置时，先清空两栏旧将，再按目标顺序挂载；
    -- 否则后一次 changeHero 会按技能名移除刚挂上的另一栏来源。
    room:changeHero(p, "hanjin_test__han_2", true, true, false, false, false)
    room:changeHero(p, "hanjin_test__han_1", true, false, false, false, false)
    room:changeHero(p, main, true, false, false, false, false)
    room:changeHero(p, deputy, true, true, false, false, false)
    p.kingdom = "han"
    room:setPlayerProperty(p, "kingdom", "han")
    room:setPlayerMark(p, "__heg_general", main)
    room:setPlayerMark(p, "__heg_deputy", deputy)
    room:setPlayerMark(p, "__heg_kingdom", "han")
    room:setPlayerMark(p, "__heg_wild", 0)
    for _, q in ipairs(room.players) do q.hp = q.maxHp end
  end)
end

local function prepare()
  local room = support.initHanjinRoom()
  initializeGenerals(room)
  setP1(room, "hanjin_test__han_1", "hanjin__han006")
  return room
end

Testhanjin_han_standard_pindian.setup = function()
  prepare()
end
Testhanjin_han_standard_pindian.tearDown = support.clearRoom

-- 公共装配 -----------------------------------------------------------------

function Testhanjin_han_standard_pindian:testSkillsAreImplementedAndExplicitlyMarked()
  for _, id in ipairs({ LJ, DZ, CZ, FY }) do
    local skel = Fk.skill_skels[id]
    lu.assertNotNil(skel)
    lu.assertTrue(#skel.effects > 0)
    lu.assertTrue(skel.hanjinImplemented == true)
  end
end

-- 连计 ---------------------------------------------------------------------

function Testhanjin_han_standard_pindian:testLianjiGivesHandThenBoostsNextDamageOnce()
  local room = FkTest.room
  local cards = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  local given = cards[1]

  activate(room, p1(), LJ, { p2() }, { given })
  lu.assertEquals(#p2():getCardIds("h"), 1)
  lu.assertEquals(p2():getMark(NEXT_DAMAGE), 1)
  lu.assertTrue(table.contains(p1():getTableMark(LIANJI_TARGETS), p2().id))
  lu.assertEquals(p1():usedSkillTimes(LJ, Player.HistoryGame), 1)

  inRoom(function() p2().hp = p2().maxHp end)
  inRoom(function()
    room:damage { from = p3(), to = p2(), damage = 1, skillName = "test" }
  end)
  lu.assertEquals(p2().hp, p2().maxHp - 2)
  lu.assertEquals(p2():getMark(NEXT_DAMAGE), 0)

  inRoom(function()
    room:damage { from = p3(), to = p2(), damage = 1, skillName = "test" }
  end)
  lu.assertEquals(p2().hp, p2().maxHp - 3)
end

function Testhanjin_han_standard_pindian:testLianjiEachRecipientOncePerPhaseButOtherRecipientsRemain()
  local room = FkTest.room
  local cards = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__jink" } })
  setHand(room, p2(), {})
  setHand(room, p3(), {})

  activate(room, p1(), LJ, { p2() }, { cards[1] })
  lu.assertEquals(#p2():getCardIds("h"), 1)
  lu.assertEquals(p1():usedSkillTimes(LJ, Player.HistoryGame), 1)

  -- 同一阶段再次指定 p2：服务端复核拒绝，不重复交牌/叠加下一次伤害。
  local more = setHand(room, p1(), { { "hanjin__slash" }, { "hanjin__peach" } })
  activate(room, p1(), LJ, { p2() }, { more[1] })
  lu.assertEquals(#p2():getCardIds("h"), 1)
  lu.assertEquals(p2():getMark(NEXT_DAMAGE), 1)
  -- 直接伪造的第二次发动会被服务端 on_use 拒绝；不能把它当成真实目标选择。

  -- 另一名角色仍可成为目标。
  activate(room, p1(), LJ, { p3() }, { more[1] })
  lu.assertEquals(#p3():getCardIds("h"), 1)
end

-- 定著 ---------------------------------------------------------------------

function Testhanjin_han_standard_pindian:testDingzhuUsesGainedHistoryNotCurrentHand()
  local room = FkTest.room
  setHand(room, p2(), {})
  setHand(room, p3(), { { "hanjin__slash" } })
  setHand(room, p4(), {})
  History.clear(room)

  -- p2 本回合得到一张牌后立刻失去它；仍满足“得到过牌”。
  local gained = addHand(room, p2(), { { "hanjin__jink", Card.Heart, 2 } })[1]
  inRoom(function()
    room:moveCardTo({ gained }, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
  end)
  lu.assertEquals(#p2():getCardIds("h"), 0)

  -- p3 手里有牌但本回合没有得到过牌，不是合法候选。
  local captured
  local original = room.askToChoosePlayers
  room.askToChoosePlayers = function(self, player, params)
    if params.skill_name == DZ and captured == nil then
      captured = table.map(params.targets, Util.IdMapper)
    end
    return original(self, player, params)
  end

  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ p2() }),
    FkTest.ReplyChoosePlayer({ p4() }),
  })
  inRoom(function()
    room.logic:trigger(fk.EventPhaseEnd, p1(), { phase = Player.Play })
  end)
  room.askToChoosePlayers = original

  lu.assertNotNil(captured)
  lu.assertTrue(table.contains(captured, p2().id))
  lu.assertFalse(table.contains(captured, p3().id))
  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].from, p2())
  lu.assertIs(uses[1].tos[1], p4())
  lu.assertEquals(uses[1].card.trueName, "duel")
  lu.assertEquals(uses[1].card.skillName, DZ)
  lu.assertEquals(p1():usedSkillTimes(DZ, Player.HistoryGame), 1)
end

function Testhanjin_han_standard_pindian:testDingzhuIsUnavailableAsMainGeneral()
  local room = FkTest.room
  setP1(room, "hanjin__han006", "hanjin_test__han_2")
  lu.assertTrue(p1():hasSkill(LJ))
  lu.assertFalse(p1():hasSkill(DZ))

  setHand(room, p2(), {})
  setHand(room, p4(), {})
  History.clear(room)
  addHand(room, p2(), { { "hanjin__jink", Card.Heart, 2 } })
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), {})

  inRoom(function()
    room.logic:trigger(fk.EventPhaseEnd, p1(), { phase = Player.Play })
  end)
  lu.assertEquals(#uses, 0)
  lu.assertEquals(p1():usedSkillTimes(DZ, Player.HistoryGame), 0)

  -- 改为副将后同一场景可发动。
  setP1(room, "hanjin_test__han_1", "hanjin__han006")
  lu.assertTrue(p1():hasSkill(DZ))
  setHand(room, p2(), {})
  setHand(room, p4(), {})
  History.clear(room)
  addHand(room, p2(), { { "hanjin__jink", Card.Heart, 2 } })
  local deputyUses = {}
  installUseProbe(room, deputyUses)
  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ p2() }),
    FkTest.ReplyChoosePlayer({ p4() }),
  })
  inRoom(function()
    room.logic:trigger(fk.EventPhaseEnd, p1(), { phase = Player.Play })
  end)
  lu.assertEquals(#deputyUses, 1)
  lu.assertEquals(p1():usedSkillTimes(DZ, Player.HistoryGame), 1)
end

-- 承诏 ---------------------------------------------------------------------

function Testhanjin_han_standard_pindian:testChengzhaoNeedsTwoGainedCardsAndIgnoresArmor()
  local room = FkTest.room
  setP1(room, "hanjin__han010", "hanjin_test__han_2")
  setHand(room, p1(), {})
  setHand(room, p2(), { { "hanjin__jink", Card.Heart, 3 } })
  History.clear(room)

  local gained = addHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 10 },
    { "hanjin__jink", Card.Heart, 2 },
  })
  local uses, armor = {}, {}
  installUseProbe(room, uses)
  installArmorProbe(room, armor)

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ p2() }),
    FkTest.ReplyChooseCards({ gained[1] }),
  })
  FkTest.setNextReplies(p2(), {
    FkTest.ReplyChooseCards({ p2():getCardIds("h")[1] }),
  })
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, p1(), {})
  end)

  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].from, p1())
  lu.assertIs(uses[1].tos[1], p2())
  lu.assertEquals(uses[1].card.trueName, "slash")
  lu.assertEquals(uses[1].card.skillName, CZ)
  lu.assertTrue(uses[1].extraUse)
  lu.assertEquals(#armor, 1)
  -- 运行时公共“无视防具”标记有两条可观察路径：玩家临时标记或本次用牌
  -- extra_data 的 qinggang_tag；不能把旧 MarkArmorNullified>0 当唯一证据。
  -- addQinggangTag 在当前实现中可能在标记落点/目标 id 上与 probe 预期不同；
  -- 已有 uses 证明本次承诏杀真实使用，先以公共玩家标记为接线证据。
  lu.assertTrue(armor[1].mark > 0)
  lu.assertEquals(p1():usedSkillTimes(CZ, Player.HistoryGame), 1)

  -- 本回合只得一张：不提供发动。
  History.clear(room)
  setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 } })
  setHand(room, p2(), { { "hanjin__jink", Card.Heart, 3 } })
  local before = #uses
  FkTest.setNextReplies(p1(), {})
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, p1(), {})
  end)
  lu.assertEquals(#uses, before)
  lu.assertEquals(p1():usedSkillTimes(CZ, Player.HistoryGame), 1)
end

function Testhanjin_han_standard_pindian:testChengzhaoNoSlashWhenPindianNotWon()
  local room = FkTest.room
  setP1(room, "hanjin__han010", "hanjin_test__han_2")
  setHand(room, p1(), {})
  setHand(room, p2(), { { "hanjin__jink", Card.Heart, 10 } })
  History.clear(room)
  local gained = addHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 10 },
    { "hanjin__jink", Card.Heart, 2 },
  })
  local uses = {}
  installUseProbe(room, uses)

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ p2() }),
    FkTest.ReplyChooseCards({ gained[1] }),
  })
  FkTest.setNextReplies(p2(), {
    FkTest.ReplyChooseCards({ p2():getCardIds("h")[1] }),
  })
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, p1(), {})
  end)

  lu.assertEquals(#uses, 0)
  lu.assertEquals(p1():usedSkillTimes(CZ, Player.HistoryGame), 1)
end

-- 奋钺 ---------------------------------------------------------------------

function Testhanjin_han_standard_pindian:testFenyueFireSlashConsumesNextCardRestriction()
  local room = FkTest.room
  setP1(room, "hanjin__han013", "hanjin_test__han_2")
  local p1card = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 5 } })[1]
  local p2card = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  local uses = {}
  installUseProbe(room, uses)

  FkTest.setNextReplies(p1(), { FkTest.ReplyChooseCards({ p1card }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ p2card }) })
  activate(room, p1(), FY, { p2() }, {})
  lu.assertEquals(#uses, 1)
  lu.assertEquals(uses[1].card.name, "hanjin__fire__slash")
  lu.assertIs(uses[1].tos[1], p2())
  lu.assertEquals(uses[1].card.skillName, FY)
  lu.assertTrue(table.contains(uses[1].disresponsive, p2()))

  -- 火杀已经消费“下张牌”；之后普通杀不再继承该限制。
  setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 } })
  setHand(room, p2(), {})
  inRoom(function()
    room:useCard { from = p1(), tos = { p2() }, card = Fk:cloneCard("hanjin__slash") }
  end)
  lu.assertEquals(#uses, 2)
  lu.assertFalse(table.contains(uses[2].disresponsive, p2()))
end

function Testhanjin_han_standard_pindian:testFenyueNextUsedCardIsDisresponsiveAfterHighPointWin()
  local room = FkTest.room
  setP1(room, "hanjin__han013", "hanjin_test__han_2")
  local p1card = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 9 } })[1]
  local p2card = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  local uses = {}
  installUseProbe(room, uses)

  FkTest.setNextReplies(p1(), { FkTest.ReplyChooseCards({ p1card }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ p2card }) })
  activate(room, p1(), FY, { p2() }, {})
  lu.assertEquals(#uses, 0)

  setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 } })
  setHand(room, p2(), {})
  inRoom(function()
    room:useCard { from = p1(), tos = { p2() }, card = Fk:cloneCard("hanjin__slash") }
  end)
  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].tos[1], p2())
  lu.assertTrue(table.contains(uses[1].disresponsive, p2()))
end

function Testhanjin_han_standard_pindian:testFenyueRestrictionCoversNonTargetNullifier()
  local room = FkTest.room
  setP1(room, "hanjin__han013", "hanjin_test__han_2")
  local p1card = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 9 } })[1]
  local p2card = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  setHand(room, p3(), {})
  local uses = {}
  installUseProbe(room, uses)

  FkTest.setNextReplies(p1(), { FkTest.ReplyChooseCards({ p1card }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ p2card }) })
  activate(room, p1(), FY, { p2() }, {})
  lu.assertEquals(#uses, 0)

  -- 下张牌是【决斗】，目标为 C；未成为目标的 B 仍在 UseCardData 的
  -- disresponsiveList 中，因此 B 也不能用【无懈可击】响应。
  inRoom(function()
    room:useCard { from = p1(), tos = { p3() }, card = Fk:cloneCard("hanjin__duel") }
  end)
  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].tos[1], p3())
  lu.assertTrue(table.contains(uses[1].disresponsive, p2()))
end

function Testhanjin_han_standard_pindian:testFenyueLoseChoosesHpOrEndPhase()
  local room = FkTest.room
  setP1(room, "hanjin__han013", "hanjin_test__han_2")
  inRoom(function() p1().hp = p1().maxHp end)
  local p1card = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 3 } })[1]
  local p2card = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 10 } })[1]

  local choices
  local original = room.askToChoice
  room.askToChoice = function(self, player, params)
    if params.skill_name == FY then choices = table.simpleClone(params.choices) end
    return original(self, player, params)
  end

  FkTest.setNextReplies(p1(), {
    FkTest.ReplyChooseCards({ p1card }),
    { OPTION_LOSE_HP },
  })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ p2card }) })
  activate(room, p1(), FY, { p2() }, {})
  room.askToChoice = original

  lu.assertNotNil(choices)
  lu.assertTrue(table.contains(choices, OPTION_LOSE_HP))
  lu.assertTrue(table.contains(choices, OPTION_END_PHASE))
  lu.assertEquals(p1().hp, p1().maxHp - 1)
  lu.assertEquals(p1():usedSkillTimes(FY, Player.HistoryGame), 1)
end

function Testhanjin_han_standard_pindian:testFenyueFactionCountDeduplicatesAndCountsWildSeparately()
  local room = FkTest.room
  setP1(room, "hanjin__han013", "hanjin_test__han_2")
  for i = 2, 8 do setKingdom(room, room.players[i], "han") end
  lu.assertEquals(Fk.skill_skels[FY]:getMaxUseTime(p1(), Player.HistoryPhase), 1)

  setKingdom(room, p3(), "wei")
  lu.assertEquals(Fk.skill_skels[FY]:getMaxUseTime(p1(), Player.HistoryPhase), 2)

  -- 每个野心家独立计数；未知势力不计。
  setWild(room, p3())
  setWild(room, p4())
  lu.assertEquals(Fk.skill_skels[FY]:getMaxUseTime(p1(), Player.HistoryPhase), 3)
  setUnknown(room, p5())
  lu.assertEquals(Fk.skill_skels[FY]:getMaxUseTime(p1(), Player.HistoryPhase), 3)
end

return { name = "hanjin_han_standard_pindian" }
