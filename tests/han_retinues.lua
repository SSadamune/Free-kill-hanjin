-- HAN 翼从：穆顺、西园军。默认国战套件用例（加入 tests/all.lua 后生效）。
-- 夹具直接授予正式翼从技能，以验证技能本身；翼从取得流程由统领公共套件覆盖。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local MS = "qiao__retinue_skill_mushun"
local XY = "qiao__retinue_skill_xiyuanjun"
local LOCK = "qiao_retinue_xiyuanjun_lock-turn-inhand"
local DEFAULT_KINGDOMS = { "han", "han", "han", "wei", "wei", "shu", "shu", "wei" }

Testqiao_han_retinues = {}

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
      room:changeHero(p, "qiao_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(p, "qiao_test__" .. kingdom .. "_1", true, false, false, false, false)
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
  return initializeGenerals(support.initQiaoRoom())
end

Testqiao_han_retinues.setup = function() prepare() end
Testqiao_han_retinues.tearDown = support.clearRoom

function Testqiao_han_retinues:testMushunObtainsThenPunishesNextDiscard()
  local room = FkTest.room
  grant(p1(), MS)
  local theirs = setHand(room, p2(), {
    { "qiao__slash", Card.Spade, 1 },
    { "qiao__jink", Card.Heart, 2 },
  })
  -- 自己的手牌不是候选：旧实现用 askToCards 的默认手牌候选会把它一并显示。
  local own = setHand(room, p1(), { { "qiao__jink", Card.Club, 3 } })[1]
  inRoom(function() p1().hp = 4 end)

  FkTest.setNextReplies(p1(), { "1" })
  local offered
  local asked = false
  skill_test.withSkillRequests(room, MS, {
    askToChooseCards = function(self, player, params)
      asked = true
      lu.assertIs(player, p1())
      offered = {}
      for _, pile in ipairs(params.flag.card_data) do
        table.insertTable(offered, pile[2])
      end
      return { theirs[1] }
    end,
  }, function()
    inRoom(function()
      room:throwCard({ theirs[1] }, MS, p2(), p1())
    end)
  end)
  lu.assertTrue(asked, "穆顺应从实际弃置牌中选择，而不是提供默认手牌候选")
  lu.assertEquals(offered, { theirs[1] }, "穆顺的候选只能是实际仍在弃牌堆的本次弃置牌")
  lu.assertTrue(table.contains(p1():getCardIds("h"), theirs[1]))
  lu.assertTrue(table.contains(p1():getCardIds("h"), own), "自己原有的手牌不应被移走")
  lu.assertIs(p1().hp, 4)

  -- 本回合下一次同条件弃牌：不再取得，直接失去 1 点体力。
  inRoom(function()
    room:throwCard({ theirs[2] }, MS, p2(), p1())
  end)
  lu.assertIs(p1().hp, 3)
  lu.assertFalse(table.contains(p1():getCardIds("h"), theirs[2]))
end

function Testqiao_han_retinues:testXiyuanjunRevealsLocksAndSourceObtainsAfterDamage()
  local room = FkTest.room
  grant(p1(), XY)
  -- 未标记的手牌仍由引擎决定可见性；西园军不得把全场手牌统一翻背。
  local own = setHand(room, p1(), { { "qiao__jink", Card.Club, 3 } })[1]
  -- 当前出牌阶段角色 p2 空手；被选牌角色 p4 为敌方（魏）也可选。
  setHand(room, p2(), {})
  local p4 = FkTest.room.players[4]
  local p4cards = setHand(room, p4, {
    { "qiao__jink", Card.Heart, 5 },
    { "qiao__slash", Card.Diamond, 6 },
  })
  local card, other = p4cards[1], p4cards[2]
  setHand(room, p3(), {})

  lu.assertTrue(inRoom(function() return p1():cardVisible(own) end),
    "获得西园军后，自己未标记的手牌仍应可见")

  local original = room.askToChooseCard
  room.askToChooseCard = function(self, player, params) return card end

  -- 在同一个出牌阶段内部检查公开/锁定/转化禁用，并在受伤害取牌后继续
  -- 检查；回合结束后的断言只用于确认 -turn 标记已清理。
  local done = false
  local skel = fk.CreateSkill { name = "#qiao_retinue_play_probe" }
  skel:addEffect(fk.BeforePlayCard, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return not done and target == p2()
    end,
    on_refresh = function(self, event, target, player, data)
      done = true
      lu.assertTrue(p3():cardVisible(card))
      lu.assertFalse(p3():cardVisible(other), "未标记的敌方手牌应交给引擎判定为不可见")
      lu.assertTrue(p4:cardVisible(other), "未标记的手牌对其持有者仍应可见")
      lu.assertTrue(p4:prohibitUse(Fk:getCardById(card)))
      local virtual = Fk:cloneCard("qiao__slash")
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
    FkTest.ReplyChoosePlayer({ FkTest.room.players[4] }),
  })
  FkTest.setNextReplies(p2(), { "" })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p2(), "game_rule", { Player.Play })):exec()
  end)
  room.askToChooseCard = original

  lu.assertTrue(done)
  -- TurnEnd 后 -turn 公开与锁定标记均应清理；生产清理逻辑未放宽。
  -- 牌已被伤害来源取得，因此改由其他角色确认它不再因公开标记而对全场可见。
  lu.assertFalse(p2():cardVisible(card))
  lu.assertFalse(p4:prohibitUse(Fk:getCardById(card)))
  lu.assertEquals(Fk:getCardById(card):getMark(LOCK), 0)
end

return { name = "qiao_han_retinues" }
