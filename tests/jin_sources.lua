-- JIN010 伤逝/扼绝、JIN016 复礼/风物的来源与最小主流程定向用例。
-- 本轮只写用例，未运行共享 runtime。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local ReqPlayCard = require "ltk.core.request_type.play_card"

local SHANGSHI = "qiao__skill_jin010_1"
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

function Testqiao_jin_sources:testShangshiDrawsToLostHpAtAnotherFinishPhase()
  local room = prepare("qiao_heg__jin010")
  local owner, target = p1(), p2()
  inRoom(function()
    owner.maxHp = 4
    owner.hp = 2
  end)

  skill_test.withSkillRequests(room, SHANGSHI, {
    askToSkillInvoke = function() return true end,
    askToChoice = function(self, player, params, original)
      for _, choice in ipairs(params.choices) do
        if tostring(choice):find("摸牌", 1, true) then return choice end
      end
      return params.choices[#params.choices]
    end,
  }, function()
    inRoom(function()
      target.phase = Player.Finish
      room.logic:trigger(fk.EventPhaseStart, target, { phase = Player.Finish })
    end)
  end)

  lu.assertEquals(#owner:getCardIds("h"), 2)
end

function Testqiao_jin_sources:testFuliDrawsExtraThenGivesShownCardAndMarksSuit()
  local room = prepare("qiao_heg__jin016")
  local zhangHua, drawer = p1(), p2()
  local shown
  skill_test.withSkillRequests(room, FULI, {
    askToSkillInvoke = function() return true end,
    askToChooseCard = function(self, player, params, original)
      shown = params.target:getCardIds("h")[1]
      return shown
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

function Testqiao_jin_sources:testShangshiZeroMaterialIceSlashIsExplicitUse()
  local room = prepare("qiao_heg__jin010")
  local owner, target = p1(), p2()
  inRoom(function()
    owner.maxHp = 4
    owner.hp = 4
  end)
  give(room, target, { { "qiao__peach" } })
  local hp = target.hp

  skill_test.withSkillRequests(room, SHANGSHI, {
    askToSkillInvoke = function() return true end,
    askToChoice = function(self, player, params, original)
      return "#qiao__skill_jin010_1-slash"
    end,
  }, function()
    inRoom(function()
      target.phase = Player.Finish
      room.logic:trigger(fk.EventPhaseStart, target, { phase = Player.Finish })
    end)
  end)

  lu.assertEquals(target.hp, hp - 1)
  lu.assertEquals(#owner:getCardIds("h"), 0)
  lu.assertEquals(owner:usedSkillTimes(SHANGSHI, Player.HistoryGame), 1)
end

function Testqiao_jin_sources:testFuliPromiseStillResolvesAfterSkillLost()
  local room = prepare("qiao_heg__jin016")
  local zhangHua, drawer = p1(), p2()
  local shown
  skill_test.withSkillRequests(room, FULI, {
    askToSkillInvoke = function() return true end,
    askToChooseCard = function(self, player, params, original)
      shown = params.target:getCardIds("h")[1]
      return shown
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
