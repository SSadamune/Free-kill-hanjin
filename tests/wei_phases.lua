-- 魏 标准包：阶段与转换组 8 技能定向验收文件（洛神、神速、设变、巧变、
-- 断粮、励战、倾国、轻辎）。
-- 规则依据：docs/rules/standard-generals.md 魏区原文、
-- rulebook/terms/game-flow-terms/phase.md；接口核对锁定 0.5.25 与 hegemony。
-- 定向运行：
--   python scripts/test.py --file tests/wei_phases.lua --timeout 120
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local ReqPlayCard = require "ltk.core.request_type.play_card"
local ReqUseCard = require "ltk.core.request_type.use_card"

local QG = "qiao__skill_wei007_1"
local LS = "qiao__skill_wei007_2"
local SS = "qiao__skill_wei008_1"
local SB = "qiao__skill_wei008_2"
local QB = "qiao__skill_wei009_1"
local DL = "qiao__skill_wei010_1"
local LZ = "qiao__skill_wei011_2"
local QZ = "qiao__skill_wei006_1"
local W = require "packages.qiao.pkg.qiao_generals.util.wei_phases"
local GRANT_MARK = "qiao__skill_wei006_1_granted"

local DEFAULT_KINGDOMS = { "wei", "wei", "wei", "wei", "wei", "wei", "wei", "wei" }
local probeSerial = 0

Testqiao_wei_phases = {}

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
      room:changeHero(pl, "qiao_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(pl, "qiao_test__" .. kingdom .. "_1", true, false, false, false, false)
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
    room:changeHero(player, deputy or "qiao_test__wei_2", true, true, false, false, false)
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
  -- 客户端响应 pattern 是全局状态；每个用例从干净窗口开始。
  Fk.currentResponsePattern = nil
  local room = support.initQiaoRoom()
  initializeGenerals(room)
  return room
end

Testqiao_wei_phases.setup = function() prepare() end
Testqiao_wei_phases.tearDown = support.clearRoom

--- 统计指定技能产生的“获得”移动，用于确认一次性获得。
---@param room Room
---@param expected table
local function installObtainProbe(room, expected)
  probeSerial = probeSerial + 1
  local key = "__qiao_wei_phase_obtain_" .. probeSerial
  local skel = fk.CreateSkill { name = "#qiao_wei_phase_obtain_" .. probeSerial }
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

function Testqiao_wei_phases:testLuoshenObtainsAllBlackJudgedCardsInOneMove()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei007")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  -- 判定顺序：黑桃、梅花、红桃。前两次黑色后各询问一次是否重复。
  seedDrawPile(room, {
    { "qiao__jink", Card.Heart, 2 },
    { "qiao__jink", Card.Club, 4 },
    { "qiao__jink", Card.Spade, 3 },
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

function Testqiao_wei_phases:testShensuJudgePhaseSkipsJudgeAndDraw()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local hp = p2().hp

  FkTest.setNextReplies(p1(), {
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

function Testqiao_wei_phases:testShensuPlayPhaseDiscardsEquipmentAndSkipsPlay()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local equip = addEquip(room, p1(), "qiao__chixiao_sword", Card.Club, 5)
  local hp = p2().hp

  local data = PhaseData:new { who = p1(), reason = "game_rule", phase = Player.Play }
  FkTest.setNextReplies(p1(), {
    FkTest.ReplyChooseCardAndPlayers({ p2() }, { equip }),
  })
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, p1(), data) end)

  lu.assertTrue(data.skipped)
  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)
  lu.assertEquals(p2().hp, hp - 1)
  lu.assertEquals(p1():usedSkillTimes(SS, Player.HistoryGame), 1)
end

function Testqiao_wei_phases:testShensuDiscardPhaseLosesHpAndSkipsDiscard()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local myHp = p1().hp
  local hp = p2().hp

  local data = PhaseData:new { who = p1(), reason = "game_rule", phase = Player.Discard }
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p2() }) })
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, p1(), data) end)

  lu.assertTrue(data.skipped)
  lu.assertEquals(p1().hp, myHp - 1)
  lu.assertEquals(p2().hp, hp - 1)
  lu.assertEquals(p1():usedSkillTimes(SS, Player.HistoryGame), 1)
end

function Testqiao_wei_phases:testShensuDoesNotConsumeAlreadySkippedPhase()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})

  local data = PhaseData:new { who = p1(), reason = "game_rule", phase = Player.Play }
  data.skipped = true
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, p1(), data) end)

  lu.assertTrue(data.skipped)
  lu.assertEquals(p1():usedSkillTimes(SS, Player.HistoryGame), 0)
end

--- 神速首次确认复用对应阶段的提示键，直接写明三种不同代价。
function Testqiao_wei_phases:testShensuInvokePromptUsesCurrentPhase()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei008")
  local cases = {
    { phase = Player.Judge, key = "#qiao__skill_wei008_1-judge",
      name = "判定阶段", cost = "摸牌阶段" },
    { phase = Player.Play, key = "#qiao__skill_wei008_1-play",
      name = "出牌阶段", cost = "装备牌" },
    { phase = Player.Discard, key = "#qiao__skill_wei008_1-discard",
      name = "弃牌阶段", cost = "失去1点体力" },
  }
  for _, case in ipairs(cases) do
    setHand(room, p1(), {})
    setHand(room, p2(), {})
    if case.phase == Player.Play then
      addEquip(room, p1(), "qiao__chixiao_sword", Card.Club, 5)
    end
    local prompt
    local function observe(self, who, params, original)
      if params.skill_name ~= SS then return original(self, who, params) end
      prompt = params.prompt
      return {}
    end
    skill_test.withSkillRequests(room, SS, {
      askToChoosePlayers = observe,
      askToChooseCardsAndPlayers = observe,
    }, function()
      if case.phase == Player.Judge then
        inRoom(function()
          GameEvent.Turn:create(TurnData:new(p1(), "game_rule", {
            Player.Judge, Player.Draw,
          })):exec()
        end)
      else
        inRoom(function()
          local data = PhaseData:new { who = p1(), reason = "game_rule", phase = case.phase }
          room.logic:trigger(fk.EventPhaseChanging, p1(), data)
        end)
      end
    end)
    lu.assertEquals(prompt, case.key, "首次确认应复用对应阶段的提示键")
    local text = Fk:translate(prompt)
    lu.assertTrue(text:find(case.name, 1, true) ~= nil,
      "确认提示应点名阶段：" .. text)
    lu.assertTrue(text:find(case.cost, 1, true) ~= nil,
      "确认提示应说明该阶段代价：" .. text)
  end
end

-- 设变 ---------------------------------------------------------------------

function Testqiao_wei_phases:testShebianMovesBoardCardAfterHpLoss()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  -- 两步移牌的第一步要求选出的两名角色之间确有可移动牌；双方都给装备，
  -- 避免选牌组合被过滤。公开选牌弹窗回复所选牌 ID 的数组。
  local equip = addEquip(room, p2(), "qiao__chixiao_sword")
  addEquip(room, p1(), "qiao__vine", Card.Heart, 4)

  FkTest.setNextReplies(p1(), {
    "1",
    { card = { skill = "choose_players_to_move_card_in_board", subcards = {} },
      targets = { p1().id, p2().id } },
    { equip },
  })
  inRoom(function() room:loseHp(p1(), 1, "test") end)

  lu.assertEquals(room:getCardOwner(equip).id, p1().id)
  lu.assertEquals(p1():usedSkillTimes(SB, Player.HistoryGame), 1)
end

function Testqiao_wei_phases:testShebianDoesNotTriggerOnDamage()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei008")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  addEquip(room, p2(), "qiao__chixiao_sword")

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

function Testqiao_wei_phases:testQiaobianDrawPhaseSkipGainsOneHandCard()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei009")
  local mine = setHand(room, p1(), { { "qiao__jink", Card.Heart, 2 } })
  local theirs = setHand(room, p2(), { { "qiao__peach", Card.Heart, 3 } })
  setHand(room, p3(), {})

  local data = PhaseData:new { who = p1(), reason = "game_rule", phase = Player.Draw }
  FkTest.setNextReplies(p1(), {
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

function Testqiao_wei_phases:testQiaobianPlayPhaseMovesBoardCard()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei009")
  local mine = setHand(room, p1(), { { "qiao__jink", Card.Heart, 2 } })
  setHand(room, p2(), {})
  local equip = addEquip(room, p2(), "qiao__chixiao_sword")
  addEquip(room, p1(), "qiao__vine", Card.Heart, 4)

  local data = PhaseData:new { who = p1(), reason = "game_rule", phase = Player.Play }
  FkTest.setNextReplies(p1(), {
    FkTest.ReplyDiscard({ mine[1] }),
    { card = { skill = "choose_players_to_move_card_in_board", subcards = {} },
      targets = { p1().id, p2().id } },
    { equip },
  })
  inRoom(function() room.logic:trigger(fk.EventPhaseChanging, p1(), data) end)

  lu.assertTrue(data.skipped)
  lu.assertEquals(room:getCardOwner(equip).id, p1().id)
  lu.assertEquals(p1():usedSkillTimes(QB, Player.HistoryGame), 1)
end

--- 弃牌请求同时作为巧变的发动选择：每阶段只发起一次，提示点名阶段并保留
--- 摸牌/出牌阶段的可选后效；取消弃牌则不跳过、不支付。
function Testqiao_wei_phases:testQiaobianDiscardRequestNamesPhaseAndCancelDoesNotSkip()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei009")
  local cases = {
    { phase = Player.Judge, name = "判定阶段" },
    { phase = Player.Draw, name = "摸牌阶段", follow = "各一张手牌", optional = true },
    { phase = Player.Play, name = "出牌阶段", follow = "移动场上一张牌", optional = true },
    { phase = Player.Discard, name = "弃牌阶段" },
  }
  for _, case in ipairs(cases) do
    local mine = setHand(room, p1(), { { "qiao__jink", Card.Heart, 2 } })
    local discardPrompt
    local asked = 0
    local data
    FkTest.setNextReplies(p1(), { "" })
    skill_test.withSkillRequests(room, QB, {
      askToDiscard = function(self, who, params, original)
        if params.skill_name ~= QB then return original(self, who, params) end
        discardPrompt = params.prompt
        asked = asked + 1
        return original(self, who, params)
      end,
    }, function()
      inRoom(function()
        data = PhaseData:new { who = p1(), reason = "game_rule", phase = case.phase }
        room.logic:trigger(fk.EventPhaseChanging, p1(), data)
      end)
    end)
    lu.assertEquals(asked, 1, "每个阶段应只发起一次弃牌请求")
    lu.assertNotNil(discardPrompt, "应有弃牌请求提示")
    lu.assertFalse(not not data.skipped, "取消弃牌后不得跳过阶段")
    lu.assertEquals(room:getCardArea(mine[1]), Card.PlayerHand, "取消弃牌后不应支付牌")
    lu.assertEquals(p1():usedSkillTimes(QB, Player.HistoryGame), 0,
      "取消弃牌不应计为发动巧变")
    local discardText = Fk:translate(discardPrompt)
    lu.assertTrue(discardText:find(case.name, 1, true) ~= nil,
      "弃牌提示应点名当前阶段 " .. case.name .. "：" .. discardText)
    if case.follow ~= nil then
      lu.assertTrue(discardText:find(case.follow, 1, true) ~= nil,
        "弃牌提示应说明可选后效：" .. discardText)
    end
    if case.optional then
      lu.assertTrue(discardText:find("然后你可以", 1, true) ~= nil,
        "后效应明确为可选项：" .. discardText)
    end
  end
end

-- 断粮 ---------------------------------------------------------------------

function Testqiao_wei_phases:testDuanliangTriggersOnAnyOthersDrawPhaseSkipped()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei010")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  seedDrawPile(room, { { "qiao__peach", Card.Heart, 7 } })

  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p1() }) })
  triggerPhase(room, p2(), Player.Draw, fk.EventPhaseSkipped)

  lu.assertEquals(#p1():getCardIds("h"), 1)
  lu.assertEquals(p1():usedSkillTimes(DL, Player.HistoryGame), 1)
end

--- 断粮转化素材筛选的聚焦回归。真实房间临时授予技能后，以真实 ClientPlayer
--- 走 ReqPlayCard→selectSkill→cardValidity/targetValidity/feasible；确认键产生的
--- 回包交给服务端 handleUseCardReply 完成一次真实使用。
--- 根因：filter_pattern 的第 4、5 字段留空时，exppattern.parseMatcher 会把它们
--- 解析成空匹配表，位置和完整牌名永远不匹配；必须显式写通配符 "."。
function Testqiao_wei_phases:testDuanliangClientMaterialFilterAndConfirmedUse()
  local room = FkTest.room
  -- 纯客户端选牌查询不继承任何残留的响应窗口 pattern。
  Fk.currentResponsePattern = nil
  inRoom(function()
    room:handleAddLoseSkills(p1(), DL, nil, false, true)
    room.current = p1()
    p1().phase = Player.Play
  end)
  setHand(room, p2(), {})
  setHand(room, p3(), {})

  local ids = setHand(room, p1(), {
    { "qiao__slash", Card.Spade, 2 },
    { "qiao__chixiao_sword", Card.Club, 5 },
    { "qiao__duel", Card.Club, 7 },
    { "qiao__peach", Card.Heart, 3 },
  })
  local blackBasic, blackEquip, blackTrick, redBasic =
    ids[1], ids[2], ids[3], ids[4]
  -- 装备区的黑色装备也应可选；ReqActiveSkill.expandPiles 在没有 include_equip
  -- 时会依据 cardValidity 自动展开装备区。
  local equipped = addEquip(room, p1(), "qiao__jueying", Card.Spade, 6)
  lu.assertEquals(p1():distanceTo(p2()), 1)
  lu.assertTrue(p1():distanceTo(p3()) > 1)

  local confirmed
  client_room.run(room, function(clients)
    local me = clients[1]
    local handler = ReqPlayCard:new(me)
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity(DL), "断粮按钮应可用")
    handler:selectSkill(DL, { selected = true })
    lu.assertEquals(handler.skill_name, DL)

    -- 正向：黑色基本牌、手牌中的黑色装备牌、装备区的黑色装备牌。
    lu.assertTrue(handler:cardValidity(blackBasic), "黑色基本牌应可选")
    lu.assertTrue(handler:cardValidity(blackEquip), "黑色装备牌应可选")
    lu.assertTrue(handler:cardValidity(equipped), "装备区黑色装备牌应可选")
    lu.assertTrue(
      table.contains(handler.expanded_piles["_equip"] or {}, equipped),
      "装备区应经展开后进入候选")
    -- 反向：黑色锦囊不是非锦囊牌；红色基本牌不满足黑色。
    lu.assertFalse(handler:cardValidity(blackTrick), "黑色锦囊牌不应可选")
    lu.assertFalse(handler:cardValidity(redBasic), "红色基本牌不应可选")

    handler:selectCard(blackBasic, { selected = true })
    lu.assertTrue(handler:targetValidity(p2().id), "距离 1 的目标应合法")
    lu.assertFalse(handler:targetValidity(p1().id), "不能指定自己")
    lu.assertFalse(handler:targetValidity(p3().id), "距离大于 1 的目标不应合法")
    handler:selectTarget(p2().id, { selected = true })
    lu.assertTrue(handler:feasible(), "素材与合法目标齐全时确认应可用")

    -- 捕获确认键实际产生的回包，其形状与线上 ReqActiveSkill.doOKButton 一致。
    local notify = ClientInstance.notifyUI
    ClientInstance.notifyUI = function(_, name, data)
      if name == "ReplyToServer" then
        confirmed = data
        return
      end
      return notify(_, name, data)
    end
    local ok, err = pcall(handler.doOKButton, handler)
    ClientInstance.notifyUI = notify
    if not ok then error(err, 0) end
    handler:_finish()
  end)

  lu.assertNotNil(confirmed, "确认键应产生服务端回包")
  lu.assertEquals(confirmed.card.skill, DL)
  lu.assertEquals(confirmed.card.subcards, { blackBasic })
  lu.assertEquals(confirmed.targets, { p2().id })

  inRoom(function() room:handleUseCardReply(p1(), confirmed, nil) end)
  lu.assertEquals(room:getCardArea(blackBasic), Card.PlayerJudge)
  lu.assertEquals(room:getCardOwner(blackBasic).id, p2().id)
  lu.assertEquals(p1():usedSkillTimes(DL, Player.HistoryGame), 1)
end

-- 励战 ---------------------------------------------------------------------

function Testqiao_wei_phases:testLizhanWoundedCharactersEachDraw()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei011")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  inRoom(function() p2().hp = p2().maxHp - 1 end)

  -- 选人窗口本身就是发动确认：只有一个可取消的合法选人请求。
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({ p2() }) })
  triggerPhase(room, p1(), Player.Finish)

  lu.assertEquals(#p2():getCardIds("h"), 1)
  lu.assertEquals(#p1():getCardIds("h"), 0)
  lu.assertEquals(p1():usedSkillTimes(LZ, Player.HistoryGame), 1)
end

function Testqiao_wei_phases:testLizhanCancelDoesNotCount()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei011")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  inRoom(function() p2().hp = p2().maxHp - 1 end)

  -- 取消同一个选人窗口即不发动，也不增加技能使用次数。
  FkTest.setNextReplies(p1(), { FkTest.ReplyChoosePlayer({}) })
  triggerPhase(room, p1(), Player.Finish)

  lu.assertEquals(#p2():getCardIds("h"), 0)
  lu.assertEquals(p1():usedSkillTimes(LZ, Player.HistoryGame), 0)
end

-- 倾国 ---------------------------------------------------------------------

function Testqiao_wei_phases:testQingguoConvertsBlackHandCardOnly()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei007")
  local black = setHand(room, p1(), { { "qiao__slash", Card.Spade, 2 } })
  addEquip(room, p1(), "qiao__chixiao_sword", Card.Club, 3)
  local skill = Fk.skills[QG]
  lu.assertNotNil(skill)

  local virtual
  inRoom(function() virtual = skill:viewAs(p1(), { black[1] }) end)
  lu.assertNotNil(virtual)
  lu.assertEquals(virtual.name, "qiao__jink")
  lu.assertEquals(virtual.trueName, "jink")
  lu.assertEquals(virtual.skillName, QG)

  -- 只授权手牌：黑色手牌合法，红色手牌与装备区的黑色牌不合法。
  inRoom(function()
    local filter = Exppattern:Parse(".|.|black|^equip")
    lu.assertTrue(filter:match(Fk:getCardById(black[1])))
    local red = room:printCard("qiao__slash", Card.Heart, 2)
    room:obtainCard(p1(), red, false, fk.ReasonJustMove)
    lu.assertFalse(filter:match(Fk:getCardById(red.id)))
    local equipId = p1():getCardIds("e")[1]
    lu.assertFalse(filter:match(Fk:getCardById(equipId)))

    -- 使用与打出均可用。
    lu.assertTrue(skill:enabledAtPlay(p1()))
    lu.assertTrue(skill:enabledAtResponse(p1(), Fk:cloneCard("qiao__slash")))
  end)
end

--- 真实客户端响应入口：杀询问【闪】时走 ReqUseCard，而不是直接调用 viewAs。
--- 根因是响应 pattern 必须用 trueName（"jink"），不能用程序牌名
--- "qiao__jink"；否则客户端技能按钮根本不亮，直接 viewAs 测试无法发现。
function Testqiao_wei_phases:testQingguoClientResponseSelectsBlackHandCard()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei007")
  local ids = setHand(room, p1(), { { "qiao__slash", Card.Spade, 2 } })
  local black = ids[1]
  addEquip(room, p1(), "qiao__chixiao_sword", Card.Club, 3)
  local red
  inRoom(function()
    red = room:printCard("qiao__slash", Card.Heart, 2)
    room:obtainCard(p1(), red, false, fk.ReasonJustMove)
  end)
  local equipId = inRoom(function() return p1():getCardIds("e")[1] end)

  local confirmed
  client_room.run(room, function(clients)
    local me = clients[1]
    Fk.currentResponsePattern = "jink"
    local handler = ReqUseCard:new(me, { "jink", "jink", "", true, {} })
    handler:setup()

    lu.assertTrue(handler:skillButtonValidity(QG),
      "要求【闪】的响应窗口应出现倾国按钮")
    handler:selectSkill(QG, { selected = true })
    lu.assertTrue(handler:cardValidity(black), "黑色手牌应可作为倾国材料")
    lu.assertFalse(handler:cardValidity(red.id), "红色手牌不应可作为倾国材料")
    lu.assertFalse(handler:cardValidity(equipId), "装备区黑色牌不应作为倾国材料")
    handler:selectCard(black, { selected = true })
    lu.assertTrue(handler:feasible(), "黑色手牌与【闪】目标条件齐备时应可确认")

    local notify = ClientInstance.notifyUI
    ClientInstance.notifyUI = function(_, name, data)
      if name == "ReplyToServer" then
        confirmed = data
        return
      end
      return notify(_, name, data)
    end
    local ok, err = pcall(handler.doOKButton, handler)
    ClientInstance.notifyUI = notify
    handler:_finish()
    if not ok then error(err, 0) end

    -- 非【闪】请求不得亮起倾国，证明按钮按请求 pattern 而非正式牌 ID 判定。
    Fk.currentResponsePattern = "slash"
    local wrong = ReqUseCard:new(me, { "jink", "slash", "", true, {} })
    wrong:setup()
    lu.assertFalse(wrong:skillButtonValidity(QG),
      "要求【杀】的窗口不得出现倾国按钮")
    wrong:_finish()
    Fk.currentResponsePattern = nil
  end)

  lu.assertNotNil(confirmed, "确认键应产生服务端回包")
  lu.assertEquals(confirmed.card.skill, QG)
  lu.assertEquals(confirmed.card.subcards, { black })
  lu.assertEquals(confirmed.targets, {})

  local use
  inRoom(function()
    use = room:handleUseCardReply(p1(), confirmed, {
      pattern = "jink",
      skill_name = "jink",
      is_response = true,
    })
  end)
  lu.assertNotNil(use, "服务端应接受倾国转化出的【闪】")
  lu.assertEquals(use.card.name, "qiao__jink")
  lu.assertEquals(use.card.trueName, "jink")
  lu.assertEquals(use.card.skillName, QG)
  lu.assertEquals(Card:getIdList(use.card), { black })
end

-- 轻辎 ---------------------------------------------------------------------

--- 让轻辎弃置目标一张装备并授予神速；返回被弃置的牌 id。
local function grantGodSpeed(room, target, equip)
  local original = room.askToChooseCard
  room.askToChooseCard = function() return equip end
  FkTest.setNextReplies(p1(), { "1" })
  triggerPhase(room, p1(), Player.Start)
  room.askToChooseCard = original
end

function Testqiao_wei_phases:testQingziGrantCrossesCasterTurnEndAndExpiresAtTargetTurnEnd()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei006")
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local equip = addEquip(room, p2(), "qiao__chixiao_sword", Card.Spade, 6)

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

function Testqiao_wei_phases:testQingziKeepsNativeAndOtherSourcesOfShensu()
  local room = FkTest.room
  setHero(room, p1(), "qiao_heg__wei006")
  setHand(room, p1(), {})
  setHero(room, p2(), "qiao_heg__wei008")
  setHand(room, p2(), {})
  local equip = addEquip(room, p2(), "qiao__chixiao_sword", Card.Spade, 6)

  grantGodSpeed(room, p2(), equip)
  lu.assertTrue(p2():hasSkill(SS))

  -- 另一个来源也授予同名技能；轻辎到期只能移除自己的来源。
  inRoom(function()
    room:handleAddLoseSkills(p2(), SS, "qiao_test_other_god_speed_source", false, true)
  end)
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, p2(), TurnData:new(p2(), "game_rule", { Player.Start }))
  end)
  lu.assertTrue(p2():hasSkill(SS))
end

return { name = "qiao_wei_phases" }
