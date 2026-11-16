-- JIN009 权变/骤霆：真实用牌入口与处理区顶牌。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local D = require "packages.hanjin.pkg.hanjin_generals.util.jin_deck"

local QIANBIAN = "hanjin__skill_jin009_1"
local ZHOUTING = "hanjin__skill_jin009_2"

Testhanjin_jin_deck = {}
Testhanjin_jin_deck.tearDown = support.clearRoom

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function clearCards(room, player)
  local ids = player:getCardIds("he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
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

local function prepare()
  local room = support.initHanjinRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "wei" })
    for _, p in ipairs(room.players) do
      local ids = p:getCardIds("he")
      if #ids > 0 then
        room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
      end
    end
    skill_test.installDualGenerals(room, room.players[1], {
      main = "hanjin__jin009",
      deputy = "hanjin_test__jin_2",
      kingdom = "jin",
    })
    room.current = room.players[1]
    room.players[1].phase = Player.Play
  end)
  return room
end

local function seedDrawPile(room, names)
  local ids = {}
  for _, spec in ipairs(names) do
    local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
    inRoom(function()
      table.removeOne(room.draw_pile, card.id)
      table.insert(room.draw_pile, 1, card.id)
      room.card_place[card.id] = Card.DrawPile
    end)
    table.insert(ids, card.id)
  end
  return ids
end

-- 权变 ---------------------------------------------------------------------

function Testhanjin_jin_deck:testQianbianFirstHeartBansHandNotResponse()
  local room = prepare()
  local p, target = room.players[1], room.players[2]
  local cards = give(room, p, {
    { "slash", Card.Heart, 7 },
    { "jink", Card.Heart, 8 },
    { "slash", Card.Spade, 9 },
  })
  local heartSlash, heartJink, spade = cards[1], cards[2], cards[3]
  local captured = {}

  -- 在真实 Phase 事件内用牌，HistoryPhase 才能定位；在 PhaseEnd 清理前捕获。
  local fired = false
  local skel = fk.CreateSkill { name = "#hanjin_jin_deck_phase_probe" }
  skel:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target2, player, data)
      return not fired and target2 == p and player == p and data.phase == Player.Play
    end,
    on_refresh = function()
      fired = true
      room:useCard { from = p, tos = { target }, card = Fk:getCardById(heartSlash) }
      captured.banned = table.simpleClone(D.bannedSuits(p))
      captured.prohibitUse = p:prohibitUse(Fk:getCardById(heartJink))
      captured.prohibitResponse = p:prohibitResponse(Fk:getCardById(heartJink))
      captured.spade = p:prohibitUse(Fk:getCardById(spade))
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)

  FkTest.setNextReplies(p, { "1", "" })
  skill_test.withSkillRequests(room, QIANBIAN, {
    askToGuanxing = function(self, player, params)
      return { top = params.cards, bottom = {} }
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(p, "game_rule", { Player.Play })):exec()
    end)
  end)

  lu.assertTrue(table.contains(captured.banned, Card.Heart))
  lu.assertTrue(captured.prohibitUse)
  lu.assertFalse(captured.prohibitResponse)
  lu.assertFalse(captured.spade)
end

-- 骤霆 ---------------------------------------------------------------------

function Testhanjin_jin_deck:testZhoutingUsesProcessingTopThenStopsOnUnusable()
  local room = prepare()
  local p, target = room.players[1], room.players[2]
  inRoom(function() target.hp = 4 end)
  local seeded = seedDrawPile(room, {
    { "jink", Card.Heart, 2 }, -- 最后一张不可用，用来停止
    { "duel", Card.Club, 3 },
    { "slash", Card.Spade, 4 },
  })
  local slash, duel, jink = seeded[3], seeded[2], seeded[1]

  FkTest.setNextReplies(p, {
    FkTest.ReplyUseSkill("userealcard_skill", { target }, { slash }),
    FkTest.ReplyUseSkill("userealcard_skill", { target }, { duel }),
  })
  inRoom(function()
    room:handleUseCardReply(p, FkTest.ReplyUseSkill(ZHOUTING, {}, {}))
  end)

  -- 两败俱伤：杀与决斗各造成1点，未出现 double-use。
  lu.assertEquals(target.hp, 2)
  lu.assertEquals(p:usedSkillTimes(ZHOUTING, Player.HistoryGame), 1)
  lu.assertEquals(room:getCardArea(slash), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(duel), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(jink), Card.DiscardPile)
end

function Testhanjin_jin_deck:testZhoutingCannotSubstituteHandCard()
  local room = prepare()
  local p, target = room.players[1], room.players[2]
  local hand = give(room, p, { { "slash", Card.Heart, 6 } })[1]
  local seeded = seedDrawPile(room, {
    { "jink", Card.Heart, 2 },
    { "slash", Card.Spade, 4 },
  })
  local top = seeded[2]

  -- 不提供回复：askToUseRealCard 的 cancelable=false 会取合法默认目标，
  -- 但 pattern={id} 必须只允许当前处理区牌，不能改用手里的杀。
  FkTest.setNextReplies(p, {})
  inRoom(function()
    room:handleUseCardReply(p, FkTest.ReplyUseSkill(ZHOUTING, {}, {}))
  end)

  lu.assertEquals(room:getCardArea(top), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(hand), Card.PlayerHand)
  lu.assertTrue(table.contains(p:getCardIds("h"), hand))
end

return { name = "hanjin_jin_deck" }
