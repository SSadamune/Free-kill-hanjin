-- HAN009 伏完：谋溃。定向验收文件。
-- 规则依据：rules/standard-generals.md 的 HAN009 原文、
-- rulebook/events/use-card.md、rulebook/terms/resolution-terms/cancel.md。
-- 本文件尚未执行；由基础组统一运行：
--   python scripts/test.py --file tests/han009_fuwan.lua --timeout 120
local support = __dofile("../../../tests/support/hegemony.lua")

local MC = "hanjin__skill_han009_1"
local OPTION_DRAW = "#hanjin__skill_han009_1-draw"
local OPTION_DISCARD = "#hanjin__skill_han009_1-discard"

local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }

Testhanjin_han009 = {}

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

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

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

local function setP1(room)
  inRoom(function()
    local p = room.players[1]
    p:revealGeneral(false, true)
    p:revealGeneral(true, true)
    room:changeHero(p, "hanjin__han009", true, false, false, false, false)
    room:changeHero(p, "hanjin_test__han_2", true, true, false, false, false)
    p.kingdom = "han"
    room:setPlayerProperty(p, "kingdom", "han")
    room:setPlayerMark(p, "__heg_general", "hanjin__han009")
    room:setPlayerMark(p, "__heg_deputy", "hanjin_test__han_2")
    room:setPlayerMark(p, "__heg_kingdom", "han")
    room:setPlayerMark(p, "__heg_wild", 0)
    for _, q in ipairs(room.players) do q.hp = q.maxHp end
  end)
end

local function prepare()
  local room = support.initHanjinRoom()
  initializeGenerals(room)
  setP1(room)
  return room
end

Testhanjin_han009.setup = function() prepare() end
Testhanjin_han009.tearDown = support.clearRoom

-- 单选 ---------------------------------------------------------------------

function Testhanjin_han009:testMoukuiSingleOptionsWithoutCounter()
  local room = FkTest.room
  local extra = setHand(room, p1(), { { "hanjin__peach" } })[1]
  setHand(room, p2(), {})
  local p3card = setHand(room, p3(), { { "hanjin__peach" } })[1]

  -- 只摸一张：目标没有任何牌，弃牌选项不可选。
  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ p2() }),
  })
  inRoom(function()
    room:useCard { from = p1(), tos = { p2() }, card = Fk:cloneCard("hanjin__slash") }
  end)
  lu.assertEquals(#p1():getCardIds("h"), 2)

  -- 只弃一张：先选择目标，再选择“弃置其一张牌”。
  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ p3() }),
    { OPTION_DISCARD },
    p3card,
  })
  inRoom(function()
    room:useCard { from = p1(), tos = { p3() }, card = Fk:cloneCard("hanjin__slash") }
  end)
  lu.assertEquals(room:getCardArea(p3card), Card.DiscardPile)
  lu.assertEquals(p1():usedSkillTimes(MC, Player.HistoryGame), 2)
  lu.assertTrue(table.contains(p1():getCardIds("h"), extra))
end

-- 双选后的抵消 -------------------------------------------------------------

function Testhanjin_han009:testMoukuiDoubleSelectionCounterDiscardsOwnerCard()
  local room = FkTest.room
  local extra = setHand(room, p1(), { { "hanjin__peach" } })[1]
  local p2cards = setHand(room, p2(), {
    { "hanjin__jink", Card.Heart, 2 },
    { "hanjin__peach", Card.Heart, 3 },
  })
  local jink, discardCard = p2cards[1], p2cards[2]

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ p2() }),
    { OPTION_DRAW, OPTION_DISCARD },
    discardCard,
  })
  FkTest.setNextReplies(p2(), {
    FkTest.ReplyCard(Fk:getCardById(jink)),
    extra,
  })
  inRoom(function()
    room:useCard { from = p1(), tos = { p2() }, card = Fk:cloneCard("hanjin__slash") }
  end)

  lu.assertEquals(room:getCardArea(discardCard), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(extra), Card.DiscardPile)
  lu.assertFalse(table.contains(p2():getCardIds("h"), jink))
  lu.assertEquals(p1():usedSkillTimes(MC, Player.HistoryGame), 1)
end

-- 其他目标抵消不反弃 -------------------------------------------------------

function Testhanjin_han009:testMoukuiOtherTargetCancelsNoCounter()
  local room = FkTest.room
  local extra = setHand(room, p1(), { { "hanjin__peach" } })[1]
  local p2card = setHand(room, p2(), { { "hanjin__peach" } })[1]
  local p3card = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 2 } })[1]

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ p2() }),
    { OPTION_DRAW, OPTION_DISCARD },
    p2card,
  })
  FkTest.setNextReplies(p3(), {
    FkTest.ReplyCard(Fk:getCardById(p3card)),
  })
  inRoom(function()
    room:useCard { from = p1(), tos = { p2(), p3() }, card = Fk:cloneCard("hanjin__slash") }
  end)

  lu.assertEquals(room:getCardArea(p2card), Card.DiscardPile)
  lu.assertTrue(table.contains(p1():getCardIds("h"), extra))
  lu.assertEquals(p1():usedSkillTimes(MC, Player.HistoryGame), 1)
end

return { name = "hanjin_han009" }
