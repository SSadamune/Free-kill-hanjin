-- 魏 标准包：阶段与转换组 8 技能定向验收文件（洛神、神速、设变、巧变、
-- 断粮、励战、倾国、轻辎）。
-- 规则依据：rules/standard-generals.md 魏区原文、
-- rulebook/terms/game-flow-terms/phase.md；接口核对锁定 0.5.25 与 hegemony。
-- 定向运行：
--   python scripts/test.py --file tests/wei_phases.lua --timeout 120
local support = __dofile("../../../tests/support/hegemony.lua")

local QG = "hanjin__skill_wei007_1"
local LS = "hanjin__skill_wei007_2"
local SS = "hanjin__skill_wei008_1"
local SB = "hanjin__skill_wei008_2"
local QB = "hanjin__skill_wei009_1"
local DL = "hanjin__skill_wei010_1"
local LZ = "hanjin__skill_wei011_2"
local QZ = "hanjin__skill_wei006_1"
local W = require "packages.hanjin.pkg.hanjin_generals.util.wei_phases"
local GRANT_MARK = "hanjin__skill_wei006_1_granted"

local DEFAULT_KINGDOMS = { "wei", "wei", "wei", "wei", "wei", "wei", "wei", "wei" }
local probeSerial = 0

Testhanjin_wei_phases = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end
local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end
local function p4() return FkTest.room.players[4] end
local function p5() return FkTest.room.players[5] end
local function p6() return FkTest.room.players[6] end
local function p7() return FkTest.room.players[7] end
local function p8() return FkTest.room.players[8] end

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

local function setHand(room, player, specs)
  clearCards(room, player, "he")
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

local function addEquip(room, player, name, suit, number)
  local id
  inRoom(function()
    local card = room:printCard(name, suit or Card.Spade, number or 1)
    room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

--- 把牌置于牌堆顶；后插入的牌先被摸到/判定到。
local function seedDrawPile(room, specs)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      table.removeOne(room.draw_pile, card.id)
      table.insert(room.draw_pile, 1, card.id)
      room.card_place[card.id] = Card.DrawPile
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function initializeGenerals(room)
  inRoom(function()
    for i, pl in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i]
      pl:revealGeneral(false, true)
      pl:revealGeneral(true, true)
      room:changeHero(pl, "hanjin_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(pl, "hanjin_test__" .. kingdom .. "_1", true, false, false, false, false)
      pl.kingdom = kingdom
      room:setPlayerProperty(pl, "kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_general", pl.general)
      room:setPlayerMark(pl, "__heg_deputy", pl.deputyGeneral)
      room:setPlayerMark(pl, "__heg_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_wild", 0)
      -- 标记写入后按白板双将重算体力上限，避免硬编码掩盖武将贡献。
      pl.maxHp = pl:getGeneralMaxHp()
      pl.hp = pl.maxHp
    end
  end)
end

---@param general string 主将 id
---@param deputy? string 配将 id，默认该势力的测试武将
local function setHero(room, player, general, deputy)
  inRoom(function()
    player:revealGeneral(false, true)
    player:revealGeneral(true, true)
    room:changeHero(player, general, true, false, false, false, false)
    room:changeHero(player, deputy or "hanjin_test__wei_2", true, true, false, false, false)
    player.kingdom = "wei"
    room:setPlayerProperty(player, "kingdom", "wei")
    room:setPlayerMark(player, "__heg_general", general)
    room:setPlayerMark(player, "__heg_deputy", player.deputyGeneral)
    room:setPlayerMark(player, "__heg_kingdom", "wei")
    room:setPlayerMark(player, "__heg_init_kingdom", "wei")
    room:setPlayerMark(player, "__heg_wild", 0)
    player.maxHp = player:getGeneralMaxHp()
    player.hp = player.maxHp
  end)
end

local function triggerPhase(room, player, phase, event)
  inRoom(function()
    local old = player.phase
    player.phase = phase
    room.logic:trigger(event or fk.EventPhaseStart, player, PhaseData:new {
      who = player,
      reason = "game_rule",
      phase = phase,
    })
    player.phase = old
  end)
end

local function prepare()
  local room = support.initHanjinRoom()
  initializeGenerals(room)
  return room
end

Testhanjin_wei_phases.setup = function() prepare() end
Testhanjin_wei_phases.tearDown = support.clearRoom

--- 统计指定技能产生的“获得”移动，用于确认一次性获得。
---@param room Room
---@param expected table
local function installObtainProbe(room, expected)
  probeSerial = probeSerial + 1
  local key = "__hanjin_wei_phase_obtain_" .. probeSerial
  local skel = fk.CreateSkill { name = "#hanjin_wei_phase_obtain_" .. probeSerial }
  skel:addEffect(fk.AfterCardsMove, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      -- 全局 refresh 技能会按角色各回调一次；只统计一次。
      return player == expected.player
    end,
    on_refresh = function(self, event, target, player, data)
      for _, move in ipairs(data) do
        if move.toArea == Card.PlayerHand and move.to == expected.player
          and move.skillName == expected.skill then
          expected.count = expected.count + 1
          expected.cards = expected.cards + #move.moveInfo
        end
      end
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room:addSkill(skill) end)
end

-- 洛神 ---------------------------------------------------------------------

function Testhanjin_wei_phases:testLuoshenObtainsAllBlackJudgedCardsInOneMove()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei007")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  -- 判定顺序：黑桃、梅花、红桃。前两次黑色后各询问一次是否重复。
  seedDrawPile(room, {
    { "hanjin__jink", Card.Heart, 2 },
    { "hanjin__jink", Card.Club, 4 },
    { "hanjin__jink", Card.Spade, 3 },
  })
  local expected = { player = p1(), skill = LS, count = 0, cards = 0 }
  installObtainProbe(room, expected)

  FkTest.setNextReplies(p1(), { "1", "1" })
  triggerPhase(room, p1(), Player.Start)

  local hand = p1():getCardIds("h")
  lu.assertEquals(#hand, 2)
  for _, id in ipairs(hand) do
    lu.assertEquals(Fk:getCardById(id).color, Card.Black)
  end
  -- 一次性获得：只产生一次得到移动，且包含两张判定牌。
  lu.assertEquals(expected.count, 1)
  lu.assertEquals(expected.cards, 2)
  lu.assertEquals(p1():usedSkillTimes(LS, Player.HistoryGame), 1)
end

-- 神速：三个对应阶段 -------------------------------------------------------

function Testhanjin_wei_phases:testShensuJudgePhaseSkipsJudgeAndDraw()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local hp = p2().hp

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ p2() }),
  })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p1(), "game_rule", {
      Player.Judge, Player.Draw,
    })):exec()
  end)

  -- 判定与摸牌都被跳过：没有摸到牌。
  lu.assertEquals(#p1():getCardIds("h"), 0)
  lu.assertEquals(p1():usedSkillTimes(SS, Player.HistoryGame), 1)
  lu.assertEquals(p2().hp, hp - 1)
end

function Testhanjin_wei_phases:testShensuPlayPhaseDiscardsEquipmentAndSkipsPlay()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local equip = addEquip(room, p1(), "hanjin__chixiao_sword", Card.Club, 5)
  local hp = p2().hp

  local data = PhaseData:new { who = p1(), reason = "game_rule", phase = Player.Play }
  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChooseCardAndPlayers({ p2() }, { equip }),
  })
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, p1(), data) end)

  lu.assertTrue(data.skipped)
  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)
  lu.assertEquals(p2().hp, hp - 1)
  lu.assertEquals(p1():usedSkillTimes(SS, Player.HistoryGame), 1)
end

function Testhanjin_wei_phases:testShensuDiscardPhaseLosesHpAndSkipsDiscard()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local myHp = p1().hp
  local hp = p2().hp

  local data = PhaseData:new { who = p1(), reason = "game_rule", phase = Player.Discard }
  FkTest.setNextReplies(p1(), { "1", FkTest.ReplyChoosePlayer({ p2() }) })
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, p1(), data) end)

  lu.assertTrue(data.skipped)
  lu.assertEquals(p1().hp, myHp - 1)
  lu.assertEquals(p2().hp, hp - 1)
  lu.assertEquals(p1():usedSkillTimes(SS, Player.HistoryGame), 1)
end

function Testhanjin_wei_phases:testShensuDoesNotConsumeAlreadySkippedPhase()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})

  local data = PhaseData:new { who = p1(), reason = "game_rule", phase = Player.Play }
  data.skipped = true
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, p1(), data) end)

  lu.assertTrue(data.skipped)
  lu.assertEquals(p1():usedSkillTimes(SS, Player.HistoryGame), 0)
end

-- 设变 ---------------------------------------------------------------------

function Testhanjin_wei_phases:testShebianMovesBoardCardAfterHpLoss()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  -- 两步移牌的第一步要求选出的两名角色之间确有可移动牌；双方都给装备，
  -- 避免选牌组合被过滤。回复 schema 依锁定客户端 QML：
  -- { cardId = <cards 中的牌 id>, pos = cardsPosition[该牌下标] }。
  local equip = addEquip(room, p2(), "hanjin__chixiao_sword")
  addEquip(room, p1(), "hanjin__vine", Card.Heart, 4)

  FkTest.setNextReplies(p1(), {
    "1",
    { card = { skill = "choose_players_to_move_card_in_board", subcards = {} },
      targets = { p1().id, p2().id } },
    { cardId = equip, pos = 1 },
  })
  inRoom(function() room:loseHp(p1(), 1, "test") end)

  lu.assertEquals(room:getCardOwner(equip).id, p1().id)
  lu.assertEquals(p1():usedSkillTimes(SB, Player.HistoryGame), 1)
end

function Testhanjin_wei_phases:testShebianDoesNotTriggerOnDamage()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  addEquip(room, p2(), "hanjin__chixiao_sword")

  inRoom(function()
    room:damage {
      from = p2(),
      to = p1(),
      damage = 1,
      skillName = "test",
    }
  end)
  lu.assertEquals(p1():usedSkillTimes(SB, Player.HistoryGame), 0)
end

-- 巧变 ---------------------------------------------------------------------

function Testhanjin_wei_phases:testQiaobianDrawPhaseSkipGainsOneHandCard()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei009")
  local mine = setHand(room, p1(), { { "hanjin__jink", Card.Heart, 2 } })
  local theirs = setHand(room, p2(), { { "hanjin__peach", Card.Heart, 3 } })
  setHand(room, p3(), {})

  local data = PhaseData:new { who = p1(), reason = "game_rule", phase = Player.Draw }
  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyDiscard({ mine[1] }),
    FkTest.ReplyChoosePlayer({ p2() }),
  })
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, p1(), data) end)

  lu.assertTrue(data.skipped)
  lu.assertEquals(room:getCardArea(mine[1]), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(theirs[1]), Card.PlayerHand)
  lu.assertEquals(room:getCardOwner(theirs[1]).id, p1().id)
  lu.assertEquals(p1():usedSkillTimes(QB, Player.HistoryGame), 1)
end

function Testhanjin_wei_phases:testQiaobianPlayPhaseMovesBoardCard()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei009")
  local mine = setHand(room, p1(), { { "hanjin__jink", Card.Heart, 2 } })
  setHand(room, p2(), {})
  local equip = addEquip(room, p2(), "hanjin__chixiao_sword")
  addEquip(room, p1(), "hanjin__vine", Card.Heart, 4)

  local data = PhaseData:new { who = p1(), reason = "game_rule", phase = Player.Play }
  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyDiscard({ mine[1] }),
    { card = { skill = "choose_players_to_move_card_in_board", subcards = {} },
      targets = { p1().id, p2().id } },
    { cardId = equip, pos = 1 },
  })
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, p1(), data) end)

  lu.assertTrue(data.skipped)
  lu.assertEquals(room:getCardOwner(equip).id, p1().id)
  lu.assertEquals(p1():usedSkillTimes(QB, Player.HistoryGame), 1)
end

-- 断粮 ---------------------------------------------------------------------

function Testhanjin_wei_phases:testDuanliangTriggersOnAnyOthersDrawPhaseSkipped()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei010")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  seedDrawPile(room, { { "hanjin__peach", Card.Heart, 7 } })

  FkTest.setNextReplies(p1(), { "1", FkTest.ReplyChoosePlayer({ p1() }) })
  triggerPhase(room, p2(), Player.Draw, fk.EventPhaseSkipped)

  lu.assertEquals(#p1():getCardIds("h"), 1)
  lu.assertEquals(p1():usedSkillTimes(DL, Player.HistoryGame), 1)
end

-- 励战 ---------------------------------------------------------------------

function Testhanjin_wei_phases:testLizhanWoundedCharactersEachDraw()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei011")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  inRoom(function() p2().hp = p2().maxHp - 1 end)

  FkTest.setNextReplies(p1(), { "1", FkTest.ReplyChoosePlayer({ p2() }) })
  triggerPhase(room, p1(), Player.Finish)

  lu.assertEquals(#p2():getCardIds("h"), 1)
  lu.assertEquals(#p1():getCardIds("h"), 0)
  lu.assertEquals(p1():usedSkillTimes(LZ, Player.HistoryGame), 1)
end

-- 倾国 ---------------------------------------------------------------------

function Testhanjin_wei_phases:testQingguoConvertsBlackHandCardOnly()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei007")
  local black = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 2 } })
  addEquip(room, p1(), "hanjin__chixiao_sword", Card.Club, 3)
  local skill = Fk.skills[QG]
  lu.assertNotNil(skill)

  local virtual
  inRoom(function() virtual = skill:viewAs(p1(), { black[1] }) end)
  lu.assertNotNil(virtual)
  lu.assertEquals(virtual.name, "hanjin__jink")
  lu.assertEquals(virtual.trueName, "jink")
  lu.assertEquals(virtual.skillName, QG)

  -- 只授权手牌：黑色手牌合法，红色手牌与装备区的黑色牌不合法。
  inRoom(function()
    local filter = Exppattern:Parse(".|.|black|^equip")
    lu.assertTrue(filter:match(Fk:getCardById(black[1])))
    local red = room:printCard("hanjin__slash", Card.Heart, 2)
    room:obtainCard(p1(), red, false, fk.ReasonJustMove)
    lu.assertFalse(filter:match(Fk:getCardById(red.id)))
    local equipId = p1():getCardIds("e")[1]
    lu.assertFalse(filter:match(Fk:getCardById(equipId)))

    -- 使用与打出均可用。
    lu.assertTrue(skill:enabledAtPlay(p1()))
    lu.assertTrue(skill:enabledAtResponse(p1(), Fk:cloneCard("hanjin__slash")))
  end)
end

-- 轻辎 ---------------------------------------------------------------------

--- 让轻辎弃置目标一张装备并授予神速；返回被弃置的牌 id。
local function grantGodSpeed(room, target, equip)
  local original = room.askToChooseCard
  room.askToChooseCard = function() return equip end
  FkTest.setNextReplies(p1(), { "1", FkTest.ReplyChoosePlayer({ target }) })
  triggerPhase(room, p1(), Player.Start)
  room.askToChooseCard = original
end

function Testhanjin_wei_phases:testQingziGrantCrossesCasterTurnEndAndExpiresAtTargetTurnEnd()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei006")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local equip = addEquip(room, p2(), "hanjin__chixiao_sword", Card.Spade, 6)

  grantGodSpeed(room, p2(), equip)
  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)
  lu.assertTrue(p2():hasSkill(SS))
  lu.assertTrue(p2():getMark(GRANT_MARK) > 0)

  -- 施加者（郭嘉）回合结束：授予状态必须保留，不能被 -turn 标记清除。
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, p1(), TurnData:new(p1(), "game_rule", { Player.Start }))
  end)
  lu.assertTrue(p2():hasSkill(SS))
  lu.assertTrue(p2():getMark(GRANT_MARK) > 0)

  -- 目标回合结束：回收轻辎来源授予的“神速”。
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, p2(), TurnData:new(p2(), "game_rule", { Player.Start }))
  end)
  lu.assertFalse(p2():hasSkill(SS))
  lu.assertEquals(p2():getMark(GRANT_MARK), 0)
end

function Testhanjin_wei_phases:testQingziKeepsNativeAndOtherSourcesOfShensu()
  local room = FkTest.room
  setHero(room, p1(), "hanjin__wei006")
  setHand(room, p1(), {})
  setHero(room, p2(), "hanjin__wei008")
  setHand(room, p2(), {})
  local equip = addEquip(room, p2(), "hanjin__chixiao_sword", Card.Spade, 6)

  grantGodSpeed(room, p2(), equip)
  lu.assertTrue(p2():hasSkill(SS))

  -- 另一个来源也授予同名技能；轻辎到期只能移除自己的来源。
  inRoom(function()
    room:handleAddLoseSkills(p2(), SS, "hanjin_test_other_god_speed_source", false, true)
  end)
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, p2(), TurnData:new(p2(), "game_rule", { Player.Start }))
  end)
  lu.assertTrue(p2():hasSkill(SS))
end

return { name = "hanjin_wei_phases" }
