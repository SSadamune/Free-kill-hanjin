-- HAN004 张让：滔乱。默认国战套件用例（加入 tests/all.lua 后生效）。
local support = __dofile("../../../tests/support/hegemony.lua")

local TL = "hanjin__skill_han004_1"
local ACT = "hanjin__skill_han004_1-activations-turn"
local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }

Testhanjin_han004 = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end

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
    for _, spec in ipairs(specs or {}) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room:obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function runPlayPhase(room, player, replies)
  FkTest.setNextReplies(player, replies)
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Play })):exec()
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
    end
    room:changeHero(p1(), "hanjin__han004", true, false, false, false, false)
    room:setPlayerMark(p1(), "__heg_general", "hanjin__han004")
    for _, p in ipairs(room.players) do p.hp = p.maxHp end
  end)
  return room
end

local function prepare()
  return initializeGenerals(support.initHanjinRoom())
end

Testhanjin_han004.setup = function() prepare() end
Testhanjin_han004.tearDown = support.clearRoom

function Testhanjin_han004:testTaoluanActiveUseThenTurnEndCollectAndHide()
  local room = FkTest.room
  setHand(room, p1(), {})
  local gift = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 2 } })
  inRoom(function()
    p1():hideGeneral(false)
  end)

  local use = FkTest.ReplyUseSkill(TL, { p2() }, {})
  use.interaction_data = "hanjin__slash"
  FkTest.setNextReplies(p2(), { "", FkTest.ReplyChooseCards({ gift[1] }) })
  -- 同一真实 Turn 内完成使用与回合末收牌；TurnEnd 后 turn 标记已清理，
  -- 因此不再在回合外断言 ACT。出牌阶段开始先有国战主动明置询问，此处取消
  -- 以保持暗置发动滔乱。
  runPlayPhase(room, p1(), {
    { "Cancel" },
    use,
    "",
    FkTest.ReplyChoosePlayer({ p2() }),
    { "m" },
  })

  lu.assertTrue(table.contains(p1():getCardIds("h"), gift[1]))
  lu.assertFalse(table.contains(p2():getCardIds("h"), gift[1]))
  lu.assertEquals(p1().general, "anjiang")
  lu.assertNotEquals(p1().deputyGeneral, "anjiang")
  -- 视为使用仍按正常【杀】计入用牌历史，不绕过出牌阶段次数。
  lu.assertEquals(p1():usedCardTimes("slash", Player.HistoryGame), 1)
end

function Testhanjin_han004:testTaoluanCanUseJinkOutsideTurn()
  local room = FkTest.room
  setHand(room, p1(), {})
  setHand(room, p2(), { { "hanjin__slash", Card.Spade, 3 } })
  inRoom(function()
    p1():hideGeneral(false)
    -- 纯打出请求（cardResponsing=true）不提供滔乱；使用窗口才提供。
    lu.assertFalse(Fk.skills[TL]:enabledAtResponse(p1(), true))
    lu.assertTrue(Fk.skills[TL]:enabledAtResponse(p1(), false))
  end)
  local hp = p1().hp
  local use = FkTest.ReplyUseSkill(TL, {}, {})
  use.interaction_data = "hanjin__jink"
  FkTest.setNextReplies(p1(), { use })
  inRoom(function()
    room:useCard {
      from = p2(),
      tos = { p1() },
      card = Fk:cloneCard("hanjin__slash", Card.Spade, 1),
    }
  end)

  lu.assertEquals(p1().hp, hp)
  lu.assertEquals(p1().general, "hanjin__han004")
  -- 回合外使用窗口不产生 TurnEnd 清理，ACT 应保留。
  lu.assertEquals(p1():getMark(ACT), 1)
end

function Testhanjin_han004:testTaoluanCannotTriggerAfterReveal()
  local room = FkTest.room
  setHand(room, p1(), {})
  inRoom(function()
    p1():revealGeneral(false)
  end)
  -- 主副将均已明置时仍尝试以滔乱转化使用：服务端 view_as 不提供来源，
  -- 本次使用应被取消，而不是无条件放行。
  local use = FkTest.ReplyUseSkill(TL, { p2() }, {})
  use.interaction_data = "hanjin__slash"
  local hp = p2().hp

  runPlayPhase(room, p1(), { use, "" })
  lu.assertEquals(#p1():getCardIds("h"), 0)
  lu.assertEquals(p1().general, "hanjin__han004")
  lu.assertEquals(p2().hp, hp)
  lu.assertEquals(p1():getMark(ACT), 0)
end

return { name = "hanjin_han004" }
