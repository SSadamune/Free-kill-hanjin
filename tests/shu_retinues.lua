-- 蜀势力翼从：白马义从、象兵、周仓、西凉精骑。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local BAIMA = "qiao__retinue_skill_baima_yicong"
local XIANGBING = "qiao__retinue_skill_xiangbing"
local ZHOUCANG = "qiao__retinue_skill_zhoucang"
local XILIANG = "qiao__retinue_skill_xiliang_jingqi"
local DEFAULT_KINGDOMS = { "shu", "shu", "shu", "shu", "shu", "shu", "shu", "shu" }

local function room() return FkTest.room end
local function p(n) return room().players[n] end
local function inRoom(fn) local r; FkTest.runInRoom(function() r = fn() end); return r end
local function grant(player, name) inRoom(function() player.room:handleAddLoseSkills(player, name, nil, false, true) end) end
local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end
local function clearCards(player)
  inRoom(function()
    local ids = player:getCardIds("hej")
    if #ids > 0 then room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false) end
  end)
end
local function prepare()
  Fk.currentResponsePattern = nil
  local r = support.initQiaoRoom()
  inRoom(function() skill_test.installBlankGenerals(r, DEFAULT_KINGDOMS) end)
  return r
end
local function teardown() Fk.currentResponsePattern = nil; support.clearRoom() end

Testqiao_shu_retinues = { setup = prepare, tearDown = teardown }

function Testqiao_shu_retinues:testBaimaGainsResponderCardOnJink()
  local p1, p2 = p(1), p(2)
  grant(p1, BAIMA)
  clearCards(p1)
  clearCards(p2)
  local jink = give(p1, "qiao__jink", Card.Heart, 3)
  local steal = give(p2, "qiao__peach", Card.Diamond, 4)
  local slash = give(p2, "qiao__slash", Card.Spade, 8)
  inRoom(function()
    room().current = p2
    p2.phase = Player.Play
    p1.hp = p1.maxHp
  end)
  FkTest.setNextReplies(p1, { FkTest.ReplyCard(Fk:getCardById(jink)) })
  skill_test.withSkillRequests(room(), BAIMA, {
    askToSkillInvoke = function() return true end,
    askToChooseCards = function(self, player, params, original)
      if params.skill_name == BAIMA then return { steal } end
      return original(self, player, params)
    end,
  }, function()
    inRoom(function()
      room():useCard(UseCardData:new { from = p2, tos = { p1 }, card = Fk:getCardById(slash), extra_data = {} })
    end)
  end)
  lu.assertEquals(p1.hp, p1.maxHp)
  lu.assertTrue(table.contains(p1:getCardIds("he"), steal))
  local assertMoveViews = __dofile("../../../tests/support/move_visibility.lua")
  assertMoveViews(steal, Card.PlayerHand, Card.PlayerHand, { p1, p2 })
end

function Testqiao_shu_retinues:testXiangbingSlashSpawnsOneNanmanOnDamagedTargets()
  local p1, p2 = p(1), p(2)
  grant(p1, XIANGBING)
  clearCards(p1)
  clearCards(p2)
  local slash = give(p1, "qiao__slash", Card.Spade, 8)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p2.hp = p2.maxHp
  end)
  inRoom(function()
    room():useCard(UseCardData:new { from = p1, tos = { p2 }, card = Fk:getCardById(slash), extra_data = {} })
  end)
  lu.assertEquals(p2.hp, p2.maxHp - 2) -- 杀 1 点 + 视为南蛮 1 点
end

function Testqiao_shu_retinues:testXiangbingFireHitsBothNeighborsOnce()
  local p1, p2, p3 = p(1), p(2), p(8)
  grant(p1, XIANGBING)
  for _, q in ipairs({ p1, p2, p3 }) do clearCards(q) end
  inRoom(function()
    p1.hp = p1.maxHp
    p2.hp = p2.maxHp
    p3.hp = p3.maxHp
    room():damage { from = p(4), to = p1, damage = 1, damageType = fk.FireDamage, skillName = "test" }
  end)
  lu.assertEquals(p2.hp, p2.maxHp - 2) -- 杀 1 + 此杀伤害触发的南蛮 1
  lu.assertEquals(p3.hp, p3.maxHp - 2)
end

-- 周仓主流程：真实红【杀】使用完成后交给第三名角色，该角色用自己手里的
-- 合法【杀】指定“在周仓攻击范围内、不在其自身攻击范围内”的角色。
-- 目标 p8 与周仓（1 号位）距离 1，与受赠者（3 号位）距离 3。
function Testqiao_shu_retinues:testZhoucangRedSlashLetsThirdPlayerUseOwnSlashInZhoucangRange()
  local p1, p2, p3, p8 = p(1), p(2), p(3), p(8)
  grant(p1, ZHOUCANG)
  for _, q in ipairs({ p1, p2, p3, p8 }) do clearCards(q) end
  local red = give(p1, "qiao__slash", Card.Heart, 5)
  local component = give(p1, "qiao__jink", Card.Spade, 4)
  local own = give(p3, "qiao__slash", Card.Spade, 9)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p1.hp = p1.maxHp
    p2.hp = p2.maxHp
    p8.hp = p8.maxHp
  end)
  lu.assertTrue(inRoom(function() return p8:inMyAttackRange(p1) end))
  lu.assertFalse(inRoom(function() return p8:inMyAttackRange(p3) end))
  lu.assertNotIsTrue(p3:canUseTo(Fk:getCardById(own), p8))

  FkTest.setNextReplies(p2, { "__cancel" }) -- 不打出【闪】，红【杀】按普通流程结束
  FkTest.setNextReplies(p3, { FkTest.ReplyCard(Fk:getCardById(own), { p8 }) })
  FkTest.setNextReplies(p8, { "__cancel" })

  skill_test.withSkillRequests(room(), ZHOUCANG, {
    askToChooseCardsAndPlayers = function(_, _, params)
      lu.assertItemsEquals(params.expand_pile, { red, component })
      return { p3 }, { red }, true
    end,
  }, function()
    inRoom(function()
      local slash = Fk:cloneCard("qiao__slash")
      slash:addSubcards({red, component})
      room():useCard(UseCardData:new { from = p1, tos = { p2 }, card = slash, extra_data = {} })
    end)
  end)

  lu.assertEquals(p8.hp, p8.maxHp - 1)
  lu.assertTrue(table.contains(p3:getCardIds("h"), red)) -- 受赠者实际拿到周仓的红【杀】
  lu.assertTrue(table.contains(p3:getCardIds("h"), component)) -- 转化杀的所有实体牌一起交给
  lu.assertFalse(table.contains(p3:getCardIds("h"), own)) -- 打出的是自己的实体【杀】
  lu.assertEquals(room():getCardArea(own), Card.DiscardPile)
  -- 效果结算中真实使用的杀带 extraUse，不占通常次数。
  lu.assertEquals(p3:usedCardTimes("slash", Player.HistoryPhase), 0)
  -- 夹具中的双材料转化【杀】由效果直接生成，也不占空闲出杀额度。
  lu.assertEquals(p1:usedCardTimes("slash", Player.HistoryPhase), 0)


end

-- 西凉精骑主流程：结束阶段真实使用手牌【杀】，目标相邻（在目标自身攻击范围内
-- 不含西凉精骑，故不进入弃牌分支），【杀】实体耗去且不增加通常次数。
function Testqiao_shu_retinues:testXiliangFinishPhaseReallyUsesSlashWithoutNormalTimes()
  local p1, p2 = p(1), p(2)
  grant(p1, XILIANG)
  clearCards(p1)
  clearCards(p2)
  local slash = give(p1, "qiao__slash", Card.Spade, 8)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Finish
    p1.hp = p1.maxHp
    p2.hp = p2.maxHp
  end)
  lu.assertTrue(inRoom(function() return p1:inMyAttackRange(p2) end))
  lu.assertTrue(inRoom(function() return p2:inMyAttackRange(p1) end)) -- 非“攻击范围内没有你”的弃牌分支

  FkTest.setNextReplies(p1, { FkTest.ReplyCard(Fk:getCardById(slash), { p2 }) })
  FkTest.setNextReplies(p2, { "__cancel" })

  skill_test.withSkillRequests(room(), XILIANG, {
    askToSkillInvoke = function() error("西凉精骑应在用杀请求中确认") end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.EventPhaseStart, p1,
        PhaseData:new { who = p1, reason = "game_rule", phase = Player.Finish })
    end)
  end)

  lu.assertEquals(p2.hp, p2.maxHp - 1)
  lu.assertFalse(table.contains(p1:getCardIds("h"), slash))
  lu.assertEquals(room():getCardArea(slash), Card.DiscardPile)
  lu.assertEquals(p1:usedCardTimes("slash", Player.HistoryPhase), 0)
end

-- 白马义从“打出”入口：【万箭齐发】要求打出【闪】时触发 CardResponding，
-- 取得万箭使用者的一张手牌/装备。
function Testqiao_shu_retinues:testBaimaTakesArcheryUserCardWhenPlayingJink()
  local p1, p3 = p(1), p(3)
  grant(p1, BAIMA)
  clearCards(p1)
  clearCards(p3)
  local jink = give(p1, "qiao__jink", Card.Heart, 3)
  local archery = give(p3, "qiao__archery_attack", Card.Heart, 1)
  local peach = give(p3, "qiao__peach", Card.Diamond, 4)
  inRoom(function()
    room().current = p3
    p1.hp = p1.maxHp
    p3.hp = p3.maxHp
  end)

  FkTest.setNextReplies(p1, { FkTest.ReplyCard(Fk:getCardById(jink)) })
  skill_test.withSkillRequests(room(), BAIMA, {
    askToSkillInvoke = function() return true end,
    askToChooseCards = function() return { peach } end,
  }, function()
    inRoom(function()
      room():useCard(UseCardData:new {
        from = p3, tos = {}, card = Fk:getCardById(archery), extra_data = {},
      })
    end)
  end)

  lu.assertEquals(p1.hp, p1.maxHp) -- 打出【闪】抵消万箭伤害
  lu.assertTrue(table.contains(p1:getCardIds("h"), peach))
  lu.assertFalse(table.contains(p3:getCardIds("he"), peach))
  local assertMoveViews = __dofile("../../../tests/support/move_visibility.lua")
  assertMoveViews(peach, Card.PlayerHand, Card.PlayerHand, { p1, p3 })
  lu.assertEquals(room():getCardArea(jink), Card.DiscardPile)
end

function Testqiao_shu_retinues:testXiliangTargetOutsideAttackRangeMustDiscard()
  local p1, p2 = p(1), p(4)
  grant(p1, "qiao__retinue_skill_xiliang_jingqi")
  clearCards(p1)
  clearCards(p2)
  local slash = give(p1, "qiao__slash", Card.Spade, 8)
  local card = give(p2, "qiao__jink", Card.Heart, 3)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p2.hp = p2.maxHp
  end)
  FkTest.setNextReplies(p1, { "qiao__retinue_skill_xiliang_jingqi", "1" })
  FkTest.setNextReplies(p2, { FkTest.ReplyCard(Fk:getCardById(card)) })
  inRoom(function()
    room():useCard(UseCardData:new { from = p1, tos = { p2 }, card = Fk:getCardById(slash), extra_data = {} })
  end)
  lu.assertFalse(table.contains(p2:getCardIds("he"), card)) -- 目标自行弃置，不是周仓/使用者选
end

return { name = "qiao_shu_retinues" }
