-- JIN003 挟征 / JIN004 悖弑：真实用牌、显式目标、伤害归属与取消分支。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local XIEZHENG = "qiao__skill_jin003_2"
local BEISHI = "qiao__skill_jin004_2"

Testqiao_jin_reactive = {}
Testqiao_jin_reactive.tearDown = support.clearRoom

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function prepare(main)
  local room = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(room, { "jin", "jin", "wei" })
    skill_test.installDualGenerals(room, room.players[1], {
      main = main,
      deputy = "qiao_test__jin_2",
      kingdom = "jin",
    })
    room.current = room.players[1]
    room.players[1].phase = Player.Play
  end)
  return room
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

function Testqiao_jin_reactive:testXiezhengBasicAsSlashActuallyUsed()
  local room = prepare("qiao_heg__jin003")
  local p, user, victim = room.players[1], room.players[2], room.players[3]
  local basic = give(room, user, { { "slash", Card.Spade, 3 } })[1]
  inRoom(function() victim.hp = 4 end)

  FkTest.setNextReplies(user, { "1", basic })
  inRoom(function()
    room:handleUseCardReply(p, FkTest.ReplyUseSkill(XIEZHENG, { user, victim }, {}))
  end)

  -- 实际用出后不进入惩罚；只验证原杀已使用并造成伤害。
  lu.assertEquals(victim.hp, 3)
  lu.assertEquals(room:getCardArea(basic), Card.DiscardPile)
end

function Testqiao_jin_reactive:testXiezhengRefusalEntersPenalty()
  local room = prepare("qiao_heg__jin003")
  local p, user, victim = room.players[1], room.players[2], room.players[3]
  local theirs = give(room, user, { { "peach", Card.Heart, 7 } })[1]
  inRoom(function()
    p.hp = 4
    local own = p:getCardIds("he")
    if #own > 0 then
      room:moveCardTo(own, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end)

  -- 获得后还须返还等同其体力值的牌。明确交出另一张牌，避免默认
  -- 选择恰好将刚获得的桃原样返还，不能仅凭最终归属推断是否进入罚则。
  local returned = give(room, p, { { "jink", Card.Club, 9 } })[1]
  inRoom(function() user.hp = 1 end)
  local requested = false
  FkTest.setNextReplies(user, { "" })
  inRoom(function()
    skill_test.withSkillRequests(room, XIEZHENG, {
      askToChooseCardsAndPlayers = function(_, chooser, params)
        requested = true
        lu.assertEquals(chooser.id, p.id)
        lu.assertEquals(params.min_card_num, 1)
        lu.assertEquals(params.max_card_num, 1)
        lu.assertTrue(table.contains(p:getCardIds("h"), theirs))
        return { p }, { returned }
      end,
    }, function()
      room:handleUseCardReply(p, FkTest.ReplyUseSkill(XIEZHENG, { user, victim }, {}))
    end)
  end)
  lu.assertTrue(requested)
  lu.assertTrue(table.contains(user:getCardIds("h"), returned))

  lu.assertFalse(table.contains(user:getCardIds("h"), theirs))
  lu.assertTrue(table.contains(p:getCardIds("h"), theirs))
end

function Testqiao_jin_reactive:testXiezhengExplicitVictimBeyondAttackRange()
  local room = prepare("qiao_heg__jin003")
  local p, user, victim = room.players[1], room.players[2], room.players[5]
  local basic = give(room, user, { { "jink", Card.Heart, 3 } })[1]
  inRoom(function() victim.hp = 4 end)
  lu.assertFalse(user:inMyAttackRange(victim))
  FkTest.setNextReplies(user, { "1", basic })
  inRoom(function()
    room:handleUseCardReply(p, FkTest.ReplyUseSkill(XIEZHENG, { user, victim }, {}))
  end)
  lu.assertEquals(victim.hp, 3)
  lu.assertEquals(room:getCardArea(basic), Card.DiscardPile)
end

function Testqiao_jin_reactive:testBeishiDistantOtherVictimDoesNotAvoidHpLoss()
  local room = prepare("qiao_heg__jin004")
  local p, source, other = room.players[1], room.players[2], room.players[4]
  local mine = give(room, p, { { "jink", Card.Heart, 4 } })[1]
  local slash = give(room, source, { { "slash", Card.Spade, 5 } })[1]
  inRoom(function() p.hp = 4; other.hp = 4 end)
  lu.assertFalse(p:inMyAttackRange(other))
  FkTest.setNextReplies(p, { "1", FkTest.ReplyDiscard({ mine }), FkTest.ReplyCard(Fk:getCardById(slash), { other }) })
  inRoom(function() room:useCard { from = source, tos = { p }, card = Fk:getCardById(slash) } end)
  lu.assertEquals(other.hp, 3)
  lu.assertEquals(p.hp, 3)
end

function Testqiao_jin_reactive:testBeishiFreeUseRejectsInjectedPassiveCard()
  local room = prepare("qiao_heg__jin004")
  local p, source = room.players[1], room.players[2]
  local discarded = give(room, p, { { "jink", Card.Heart, 4 } })[1]
  local injected = give(room, p, { { "jink", Card.Diamond, 6 } })[1]
  local slash = give(room, source, { { "slash", Card.Spade, 5 } })[1]
  inRoom(function() p.hp = 4 end)

  local captured
  skill_test.withSkillRequests(room, BEISHI, {
    askToUseCard = function(self, player, params, original)
      captured = params
      return original(self, player, params)
    end,
  }, function()
    FkTest.setNextReplies(p, {
      "1",
      FkTest.ReplyDiscard({ discarded }),
      FkTest.ReplyCard(Fk:getCardById(injected), {}),
    })
    inRoom(function()
      room:useCard { from = source, tos = { p }, card = Fk:getCardById(slash) }
    end)
  end)

  lu.assertNotNil(captured, "悖弑必须发出真实的自由用牌请求")
  lu.assertEquals(captured.pattern, ".")
  lu.assertTrue(captured.extra_data ~= nil and captured.extra_data.not_passive == true,
    "悖弑自由用牌请求必须声明 not_passive")
  lu.assertTrue(table.contains(p:getCardIds("h"), injected),
    "服务端应在 validateUse 被动分支早拒注入的【闪】")
  lu.assertEquals(p.hp, 3, "拒绝用牌后仍按未造成伤害失去1点体力")
end

function Testqiao_jin_reactive:testBeishiDamagesOriginalUserAvoidsHpLoss()
  local room = prepare("qiao_heg__jin004")
  local p, source = room.players[1], room.players[2]
  local mine = give(room, p, { { "jink", Card.Heart, 4 } })[1]
  local slash = give(room, source, { { "slash", Card.Spade, 5 } })[1]
  inRoom(function() p.hp = 4; source.hp = 4 end)
  FkTest.setNextReplies(p, { "1", FkTest.ReplyDiscard({ mine }), FkTest.ReplyCard(Fk:getCardById(slash), { source }) })
  inRoom(function() room:useCard { from = source, tos = { p }, card = Fk:getCardById(slash) } end)
  lu.assertEquals(source.hp, 3)
  lu.assertEquals(p.hp, 4)
end

function Testqiao_jin_reactive:testBeishiCancelsOnlyTargetAndLosesHpWhenNoDamage()
  local room = prepare("qiao_heg__jin004")
  local p, source = room.players[1], room.players[2]
  local mine = give(room, p, { { "jink", Card.Heart, 4 } })[1]
  local slash = give(room, source, { { "slash", Card.Spade, 5 } })[1]
  inRoom(function() p.hp = 4 end)

  FkTest.setNextReplies(p, { "1", FkTest.ReplyDiscard({ mine }), "" })
  inRoom(function()
    room:useCard {
      from = source,
      tos = { p },
      card = Fk:getCardById(slash),
    }
  end)

  -- 取消目标并取得原牌材料；后续不使用时仍失去1点体力。
  lu.assertTrue(table.contains(p:getCardIds("h"), slash))
  lu.assertEquals(p.hp, 3)
end

return { name = "qiao_jin_reactive" }

