-- HAN002 刘辩（诗怨、毒逝）与 HAN018 蹇硕（集兵）核心行为。
-- 默认国战套件用例；复用真实汉晋测试房间、真实目标/伤害/回合事件。
local support = __dofile("../../../tests/support/hegemony.lua")

local SY = "hanjin__skill_han002_1"
local DS = "hanjin__skill_han002_2"
local JB = "hanjin__skill_han018_1"

Testhanjin_han_standard = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end
local function p4() return FkTest.room.players[4] end

local function setKingdom(room, player, kingdom)
  inRoom(function()
    player.kingdom = kingdom
    room:setPlayerProperty(player, "kingdom", kingdom)
    room:setPlayerMark(player, "__heg_kingdom", kingdom)
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

local function prepare()
  local room = support.createRoom { mode = "hanjin_heg_mode" }
  inRoom(function()
    for i, player in ipairs(room.players) do
      local kingdom = i <= 3 and "han" or "wei"
      player:revealGeneral(false, true)
      player:revealGeneral(true, true)
      room:changeHero(player, "hanjin_test__han_1", true, false, false, false, false)
      room:changeHero(player, "hanjin_test__han_2", true, true, false, false, false)
      player.kingdom = kingdom
      room:setPlayerProperty(player, "kingdom", kingdom)
      room:setPlayerMark(player, "__heg_general", player.general)
      room:setPlayerMark(player, "__heg_deputy", player.deputyGeneral)
      room:setPlayerMark(player, "__heg_kingdom", kingdom)
      room:setPlayerMark(player, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(player, "__heg_wild", 0)
    end
    room:changeHero(p1(), "hanjin__han002", true, false, false, false, false)
    room:setPlayerMark(p1(), "__heg_general", "hanjin__han002")
    room:changeHero(p2(), "hanjin__han018", true, false, false, false, false)
    room:setPlayerMark(p2(), "__heg_general", "hanjin__han018")
    for _, player in ipairs(room.players) do player.hp = player.maxHp end
    p1().hp = 3
    p2().hp = 4
  end)
  return room
end

Testhanjin_han_standard.setup = function()
  prepare()
end
Testhanjin_han_standard.tearDown = support.clearRoom

local function useSlash(room, from, to)
  inRoom(function()
    room:useCard {
      from = from,
      tos = { to },
      card = Fk:cloneCard("slash"),
    }
  end)
end

function Testhanjin_han_standard:testFixtureHasFormalSkills()
  lu.assertTrue(p1():hasSkill(SY))
  lu.assertTrue(p1():hasSkill(DS))
  lu.assertTrue(p2():hasSkill(JB))
end

function Testhanjin_han_standard:testShiyuanGreaterBranchOncePerTurn()
  local room = FkTest.room
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  p1().hp = 3
  p2().hp = 4

  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p2(), p1())
  lu.assertEquals(#p1():getCardIds("h"), 2)
  lu.assertEquals(p1():usedSkillTimes(SY, Player.HistoryTurn), 1)

  -- 同一档本回合第二次成为目标：不再询问、不再摸牌。
  FkTest.setNextReplies(p1(), { "" })
  useSlash(room, p2(), p1())
  lu.assertEquals(#p1():getCardIds("h"), 2)
  lu.assertEquals(p1():usedSkillTimes(SY, Player.HistoryTurn), 1)
end

function Testhanjin_han_standard:testShiyuanNotGreaterBranchOncePerTurn()
  local room = FkTest.room
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  p1().hp = 3
  p2().hp = 2

  FkTest.setNextReplies(p1(), { "1", "" })
  useSlash(room, p2(), p1())
  lu.assertEquals(#p1():getCardIds("h"), 1)

  -- 第一张杀造成伤害后 p1 体力下降；p2 仍不大于 p1，继续落在同一档。
  FkTest.setNextReplies(p1(), { "" })
  useSlash(room, p2(), p1())
  lu.assertEquals(#p1():getCardIds("h"), 1)
  lu.assertEquals(p1():usedSkillTimes(SY, Player.HistoryTurn), 1)
end

function Testhanjin_han_standard:testDushiOnlyProhibitsOthersPeach()
  local room = FkTest.room
  p1().hp = p1().maxHp - 2
  p2().hp = p2().maxHp - 2
  local peach = room:printCard("peach")

  lu.assertFalse(p2():canUseTo(peach, p1()))

  -- 刘辩自己和其他角色对自己使用【桃】仍允许。
  local before = p1().hp
  local selfPeach = room:printCard("peach")
  inRoom(function()
    room:obtainCard(p1(), selfPeach, false, fk.ReasonJustMove)
    room:useCard { from = p1(), tos = { p1() }, card = selfPeach }
  end)
  lu.assertEquals(p1().hp, before + 1)

  p2().hp = p2().maxHp - 2
  local otherPeach = room:printCard("peach")
  before = p2().hp
  inRoom(function()
    room:obtainCard(p2(), otherPeach, false, fk.ReasonJustMove)
    room:useCard { from = p2(), tos = { p2() }, card = otherPeach }
  end)
  lu.assertEquals(p2().hp, before + 1)
end

function Testhanjin_han_standard:testDushiHiddenKillerGetsSkill()
  local room = FkTest.room
  p1().hp = 1
  inRoom(function()
    p2():hideGeneral(false)
    room:killPlayer { who = p1(), killer = p2() }
  end)
  lu.assertTrue(p2():hasSkill(DS, false, true))
end

function Testhanjin_han_standard:testJibingCountsSameKingdomIncludingSelfAndPenalizes()
  local room = FkTest.room
  setKingdom(room, p1(), "han")
  setKingdom(room, p2(), "han")
  setKingdom(room, p3(), "han")
  setKingdom(room, p4(), "wei")
  setHand(room, p2(), {})
  p2().hp = 4

  FkTest.setNextReplies(p2(), { "1" })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p2(), "game_rule", { Player.Draw })):exec()
  end)
  -- 同势力为 p1、p2、p3 共 3 人：摸牌阶段 2+3=5；本回合伤害 0<3，失去 1 点体力。
  lu.assertEquals(#p2():getCardIds("h"), 5)
  lu.assertEquals(p2().hp, 3)
end

function Testhanjin_han_standard:testJibingDeclineDoesNotDrawExtraOrLoseHp()
  local room = FkTest.room
  setKingdom(room, p1(), "han")
  setKingdom(room, p2(), "han")
  setKingdom(room, p3(), "han")
  setKingdom(room, p4(), "wei")
  setHand(room, p2(), {})
  p2().hp = 4

  FkTest.setNextReplies(p2(), { "" })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p2(), "game_rule", { Player.Draw })):exec()
  end)
  lu.assertEquals(#p2():getCardIds("h"), 2)
  lu.assertEquals(p2().hp, 4)
end

function Testhanjin_han_standard:testJibingDamageAtLeastXNoHpLoss()
  local room = FkTest.room
  setKingdom(room, p1(), "han")
  setKingdom(room, p2(), "han")
  setKingdom(room, p3(), "wei")
  setKingdom(room, p4(), "wei")
  setHand(room, p2(), {})
  p3().hp = 4
  p2().hp = 4

  -- 真实伤害事件，发生在摸牌阶段结束、回合结束之前。
  local name = "#hanjin_han_standard_draw_damage_probe"
  local skel = fk.CreateSkill { name = name }
  skel:addEffect(fk.EventPhaseEnd, {
    global = true,
    can_trigger = function(self, event, target, owner, data)
      return target == p2() and owner == p2() and data.phase == Player.Draw
    end,
    on_cost = Util.TrueFunc,
    on_use = function()
      room:damage { from = p2(), to = p3(), damage = 2 }
    end,
  })
  local probe = skel:createSkill()
  Fk.skills[name] = probe
  inRoom(function() room:addSkill(probe) end)

  FkTest.setNextReplies(p2(), { "1" })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p2(), "game_rule", { Player.Draw })):exec()
  end)
  -- X=2（p1、p2），造成 2 点伤害，未低于 X，不失去体力。
  lu.assertEquals(#p2():getCardIds("h"), 4)
  lu.assertEquals(p2().hp, 4)
end

return { name = "hanjin_han_standard" }
