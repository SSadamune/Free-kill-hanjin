-- HAN 翼从：穆顺、西园军。默认国战套件用例（加入 tests/all.lua 后生效）。
-- 夹具直接授予正式翼从技能，以验证技能本身；翼从取得流程由统领公共套件覆盖。
local support = __dofile("../../../tests/support/hegemony.lua")

local MS = "hanjin__retinue_skill_mushun"
local XY = "hanjin__retinue_skill_xiyuanjun"
local LOCK = "hanjin_retinue_xiyuanjun_lock-turn-inhand"
local DEFAULT_KINGDOMS = { "han", "han", "han", "wei", "wei", "shu", "shu", "wei" }

Testhanjin_han_retinues = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end

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

local function grant(player, skillName)
  inRoom(function()
    player.room:handleAddLoseSkills(player, skillName, nil, false, true)
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
  return room
end

local function prepare()
  return initializeGenerals(support.initHanjinRoom())
end

Testhanjin_han_retinues.setup = function() prepare() end
Testhanjin_han_retinues.tearDown = support.clearRoom

function Testhanjin_han_retinues:testMushunObtainsThenPunishesNextDiscard()
  local room = FkTest.room
  grant(p1(), MS)
  local theirs = setHand(room, p2(), {
    { "hanjin__slash", Card.Spade, 1 },
    { "hanjin__jink", Card.Heart, 2 },
  })
  inRoom(function() p1().hp = 4 end)

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChooseCards({ theirs[1] }),
  })
  inRoom(function()
    room:throwCard({ theirs[1] }, MS, p2(), p1())
  end)
  lu.assertTrue(table.contains(p1():getCardIds("h"), theirs[1]))
  lu.assertIs(p1().hp, 4)

  -- 本回合下一次同条件弃牌：不再取得，直接失去 1 点体力。
  inRoom(function()
    room:throwCard({ theirs[2] }, MS, p2(), p1())
  end)
  lu.assertIs(p1().hp, 3)
  lu.assertFalse(table.contains(p1():getCardIds("h"), theirs[2]))
end

function Testhanjin_han_retinues:testXiyuanjunRevealsLocksAndSourceObtainsAfterDamage()
  local room = FkTest.room
  grant(p1(), XY)
  -- 当前出牌阶段角色 p2 空手；被选牌角色 p4 为敌方（魏）也可选。
  setHand(room, p2(), {})
  local card = setHand(room, FkTest.room.players[4], { { "hanjin__jink", Card.Heart, 5 } })[1]
  setHand(room, p3(), {})

  local p4 = FkTest.room.players[4]
  local original = room.askToChooseCard
  room.askToChooseCard = function(self, player, params) return card end

  -- 在同一个出牌阶段内部检查公开/锁定/转化禁用，并在受伤害取牌后继续
  -- 检查；回合结束后的断言只用于确认 -turn 标记已清理。
  local done = false
  local skel = fk.CreateSkill { name = "#hanjin_retinue_play_probe" }
  skel:addEffect(fk.BeforePlayCard, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return not done and target == p2()
    end,
    on_refresh = function(self, event, target, player, data)
      done = true
      lu.assertTrue(p3():cardVisible(card))
      lu.assertTrue(p4:prohibitUse(Fk:getCardById(card)))
      local virtual = Fk:cloneCard("hanjin__slash")
      virtual:addSubcard(card)
      lu.assertTrue(p4:prohibitUse(virtual))
      lu.assertEquals(Fk:getCardById(card):getMark(LOCK), 1)

      room:damage { from = p3(), to = p4, damage = 1 }
      lu.assertTrue(table.contains(p3():getCardIds("h"), card))
      lu.assertFalse(table.contains(p4:getCardIds("h"), card))
      lu.assertEquals(Fk:getCardById(card):getMark(LOCK), 0)
    end,
  })
  local probe = skel:createSkill()
  Fk.skills[skel.name] = probe
  inRoom(function() room:addSkill(probe) end)

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ FkTest.room.players[4] }),
  })
  FkTest.setNextReplies(p2(), { "" })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p2(), "game_rule", { Player.Play })):exec()
  end)
  room.askToChooseCard = original

  lu.assertTrue(done)
  -- TurnEnd 后 -turn 公开与锁定标记均应清理；生产清理逻辑未放宽。
  lu.assertFalse(p3():cardVisible(card))
  lu.assertFalse(p4:prohibitUse(Fk:getCardById(card)))
  lu.assertEquals(Fk:getCardById(card):getMark(LOCK), 0)
end

return { name = "hanjin_han_retinues" }
