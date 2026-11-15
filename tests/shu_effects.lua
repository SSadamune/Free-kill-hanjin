-- 蜀势力标准包第二批：突阵、藏机、烈勇、狂骨、看破、淑慎、神智。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local TUDEN = "hanjin__skill_shu005_2"
local CANGJI = "hanjin__skill_shu007_2"
local LIEYONG = "hanjin__skill_shu008_1"
local KUANGGU = "hanjin__skill_shu009_1"
local KANPO = "hanjin__skill_shu011_3"
local SHUSHEN = "hanjin__skill_shu016_1"
local SHENZHI = "hanjin__skill_shu016_2"

local DEFAULT_KINGDOMS = { "shu", "shu", "shu", "shu", "shu", "shu", "shu", "shu" }

local function room() return FkTest.room end
local function p(n) return room().players[n] end

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function grant(player, name)
  inRoom(function() player.room:handleAddLoseSkills(player, name, nil, false, true) end)
end

local function revoke(player, name)
  inRoom(function() player.room:handleAddLoseSkills(player, "-" .. name, nil, false, true) end)
end

local function clearCards(player)
  inRoom(function()
    local ids = player:getCardIds("he")
    if #ids > 0 then
      room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end)
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function equip(player, id)
  inRoom(function() room():moveCardIntoEquip(player, id, "test", true, player) end)
end

local function use(player, card, targets)
  inRoom(function()
    room():useCard(UseCardData:new {
      from = player, tos = targets or {}, card = card, extra_data = {},
    })
  end)
end

local function setPlayPhase(player)
  inRoom(function()
    room().current = player
    player.phase = Player.Play
    room():setBanner("RoundCount", 1)
  end)
end

local function prepare()
  Fk.currentResponsePattern = nil
  local r = support.initHanjinRoom()
  inRoom(function() skill_test.installBlankGenerals(r, DEFAULT_KINGDOMS) end)
  return r
end

local function teardown()
  Fk.currentResponsePattern = nil
  support.clearRoom()
end

Testhanjin_shu_effects = { setup = prepare, tearDown = teardown }

function Testhanjin_shu_effects:testTudenThirdPartyNullificationDoesNotTrigger()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p1, TUDEN)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  local trick = give(p1, "hanjin__dismantlement", Card.Diamond, 3)
  give(p2, "hanjin__jink", Card.Spade, 4)
  local null = give(p3, "hanjin__nullification", Card.Club, 5)
  setPlayPhase(p1)
  FkTest.setNextReplies(p3, { FkTest.ReplyCard(Fk:getCardById(null)) })
  local invoked = false
  skill_test.withSkillRequests(room(), TUDEN, {
    askToSkillInvoke = function() invoked = true; return true end,
  }, function()
    use(p1, Fk:getCardById(trick), { p2 })
  end)
  lu.assertFalse(invoked)
  lu.assertTrue(p2:getCardIds("h")[1] ~= nil) -- 无懈成功，拆牌未结算
end

function Testhanjin_shu_effects:testTudenRedCardCancelledByTargetDamagesAnother()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p1, TUDEN)
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p2.hp = p2.maxHp; p3.hp = p3.maxHp end)
  local slash = give(p1, "hanjin__slash", Card.Heart, 7)
  local jink = give(p2, "hanjin__jink", Card.Diamond, 2)
  setPlayPhase(p1)

  FkTest.setNextReplies(p2, { FkTest.ReplyCard(Fk:getCardById(jink)) })
  FkTest.setNextReplies(p1, { "1" })
  skill_test.withSkillRequests(room(), TUDEN, {
    askToChoosePlayers = function(self, player, params)
      lu.assertIs(player, p1)
      lu.assertNil(table.find(params.targets, function(t) return t == p2 or t == p1 end))
      return { p3 }
    end,
  }, function()
    use(p1, Fk:getCardById(slash), { p2 })
  end)
  lu.assertEquals(p3.hp, p3.maxHp - 1)
  lu.assertEquals(p2.hp, p2.maxHp)
end

function Testhanjin_shu_effects:testCangjiCancelsOnlyOwnEquipDiscardOnce()
  local p1 = p(1)
  grant(p1, CANGJI)
  clearCards(p1)
  local sword = give(p1, "hanjin__qinggang_sword", Card.Spade, 5)
  equip(p1, sword)
  local ride = give(p1, "hanjin__chitu", Card.Heart, 5)
  equip(p1, ride)

  FkTest.setNextReplies(p1, { "1" })
  inRoom(function() room():throwCard({ sword }, "test", p1, p1) end)
  lu.assertEquals(room():getCardArea(sword), Card.PlayerEquip)

  -- 每回合一次：第二张非坐骑装备不再被阻止。
  local sword2 = give(p1, "hanjin__qinggang_sword", Card.Spade, 6)
  equip(p1, sword2)
  inRoom(function() room():throwCard({ sword2 }, "test", p1, p1) end)
  lu.assertEquals(room():getCardArea(sword2), Card.DiscardPile)

  -- 坐骑本身不能成为目标。
  inRoom(function() room():throwCard({ ride }, "test", p1, p1) end)
  lu.assertEquals(room():getCardArea(ride), Card.DiscardPile)
end

function Testhanjin_shu_effects:testLieyongRangeAndChooseDamage()
  local p1, p2 = p(1), p(2)
  grant(p1, LIEYONG)
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p1.hp = p1.maxHp - 2; p2.hp = p2.maxHp end)
  lu.assertEquals(inRoom(function() return p1:getAttackRange() end), 3) -- 基础1 + 已损失2
  local slash = give(p1, "hanjin__slash", Card.Spade, 7)
  setPlayPhase(p1)
  FkTest.setNextReplies(p1, { "1" })
  skill_test.withSkillRequests(room(), LIEYONG, {
    askToChoice = function(self, player, params)
      lu.assertIs(player, p1)
      -- 在伤害结算前失去烈勇，已建立的本次【杀】+1 仍应由模式持续效果生效。
      room():handleAddLoseSkills(p1, "-" .. LIEYONG, nil, false, true)
      return "#hanjin__skill_shu008_1-damage"
    end,
  }, function()
    use(p1, Fk:getCardById(slash), { p2 })
  end)
  lu.assertFalse(p1:hasSkill(LIEYONG))
  lu.assertEquals(p2.hp, p2.maxHp - 2)
end

function Testhanjin_shu_effects:testKuanguPerDamageChoiceBonusSurvivesSkillLoss()
  local p1, p2 = p(1), p(2)
  grant(p1, KUANGGU)
  inRoom(function() p1.hp = 2; p2.hp = p2.maxHp end)
  local choices = {
    "#hanjin__skill_shu009_1-draw",
    "#hanjin__skill_shu009_1-recover",
  }
  local index = 0
  FkTest.setNextReplies(p1, { "1", "1" })
  skill_test.withSkillRequests(room(), KUANGGU, {
    askToChoice = function(self, player, params)
      index = index + 1
      return choices[index] or choices[1]
    end,
  }, function()
    inRoom(function()
      room():damage { from = p1, to = p2, damage = 1, skillName = "test" }
      room():damage { from = p1, to = p2, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(index, 2)
  -- 第一次没有“上次”，不加次数；第二次与上次不同，+1。
  local residue = MarkEnum.SlashResidue or "__slash_residue"
  lu.assertEquals(p1:getMark(residue .. "-turn"), 1)

  local probe
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p1.cardUsedHistory["slash"] = { 1, 1, 1, 1 }
    local card = room():printCard("hanjin__slash", Card.Spade, 9)
    room():obtainCard(p1, card, false, fk.ReasonJustMove)
    probe = card.id
    -- 通常额度已用完，但狂骨的回合次数+1使【杀】仍可使用。
    lu.assertTrue(p1:canUse(card))
  end)
  inRoom(function() p1.hp = 3 end)
  revoke(p1, KUANGGU)
  lu.assertEquals(p1:getMark(residue .. "-turn"), 1)
  -- 失去狂骨后已建立的次数加成仍生效。
  inRoom(function()
    lu.assertTrue(p1:canUse(Fk:getCardById(probe)))
    room():setPlayerMark(p1, residue .. "-turn", 0)
    lu.assertNotIsTrue(p1:canUse(Fk:getCardById(probe)))
  end)
end

function Testhanjin_shu_effects:testKanpoRecordsJinkCancellation()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p3, KANPO)
  clearCards(p1)
  clearCards(p3)
  local slash = give(p1, "hanjin__slash", Card.Spade, 6)
  local jink = give(p3, "hanjin__jink", Card.Heart, 7)
  setPlayPhase(p1)
  FkTest.setNextReplies(p3, { FkTest.ReplyCard(Fk:getCardById(jink)) })
  use(p1, Fk:getCardById(slash), { p3 })
  lu.assertEquals(p3.hp, p3.maxHp)
  lu.assertTrue(p3:getMark("hanjin__skill_shu011_3-cancelled-turn") > 0)

  local viewed = false
  local oldView = room().viewCards
  local oldInvoke = room().askToSkillInvoke
  room().askToSkillInvoke = function(self, player, params)
    if params.skill_name == KANPO then return true end
    return oldInvoke(self, player, params)
  end
  room().viewCards = function(self, player, params)
    viewed = true
    return oldView(self, player, params)
  end
  inRoom(function()
    room().current = p1
    room().logic:trigger(fk.TurnEnd, p1, {})
  end)
  room().viewCards = oldView
  room().askToSkillInvoke = oldInvoke
  lu.assertTrue(viewed)
end

function Testhanjin_shu_effects:testKanpoViewAsAndEndTurnViewAfterRealNullification()
  local p1, p2, p3 = p(1), p(2), p(3)
  grant(p3, KANPO)
  clearCards(p2)
  clearCards(p3)
  inRoom(function() p2.hp = p2.maxHp end)
  local dismantle = give(p1, "hanjin__dismantlement", Card.Club, 3)
  give(p2, "hanjin__jink", Card.Heart, 4)
  local black = give(p3, "hanjin__jink", Card.Spade, 5)
  setPlayPhase(p1)

  local skill = Fk.skills[KANPO]
  local converted = skill:viewAs(p3, { black })
  lu.assertEquals(converted.name, "hanjin__nullification")
  lu.assertFalse(skill:enabledAtResponse(p3, true))
  lu.assertTrue(skill:enabledAtResponse(p3, false))

  FkTest.setNextReplies(p3, { {
    card = { skill = KANPO, subcards = { black } },
    targets = {},
  }, "1" })
  inRoom(function()
    room():useCard(UseCardData:new {
      from = p1, tos = { p2 }, card = Fk:getCardById(dismantle), extra_data = {},
    })
  end)
  lu.assertEquals(#p2:getCardIds("h"), 1) -- 无懈成功，过河拆桥未结算
  lu.assertTrue(p3:getMark("hanjin__skill_shu011_3-cancelled-turn") > 0)

  local viewed
  local asked = false
  local oldView = room().viewCards
  local oldInvoke = room().askToSkillInvoke
  room().askToSkillInvoke = function(self, player, params)
    if params.skill_name == KANPO then
      asked = true
      return true
    end
    return oldInvoke(self, player, params)
  end
  room().viewCards = function(self, player, params)
    viewed = { player = player, cards = table.simpleClone(params.cards or {}) }
    return oldView(self, player, params)
  end
  inRoom(function()
    room().current = p1
    room().logic:trigger(fk.TurnEnd, p1, {})
  end)
  room().viewCards = oldView
  room().askToSkillInvoke = oldInvoke
  lu.assertTrue(asked)
  lu.assertNotNil(viewed)
  lu.assertIs(viewed.player, p3)
  lu.assertEquals(viewed.cards, p1:getCardIds("h"))
end

function Testhanjin_shu_effects:testShushenEachPointAndFullHpNoRecoverOption()
  local p1, p2 = p(1), p(2)
  grant(p1, SHUSHEN)
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p1.hp = 1; p2.hp = p2.maxHp end)
  local drawChoice = "#hanjin__skill_shu016_1-draw"
  local choiceCount = 0
  local sawRecover = false
  FkTest.setNextReplies(p1, { "1", "1" })
  skill_test.withSkillRequests(room(), SHUSHEN, {
    askToChoosePlayers = function(self, player, params) return { p2 } end,
    askToChoice = function(self, player, params)
      choiceCount = choiceCount + 1
      for _, c in ipairs(params.choices) do
        if c == "#hanjin__skill_shu016_1-recover" then sawRecover = true end
      end
      return drawChoice
    end,
  }, function()
    inRoom(function() room():recover { who = p1, num = 2, recoverBy = p1, skillName = "test" } end)
  end)
  lu.assertEquals(choiceCount, 2)
  lu.assertFalse(sawRecover)
  lu.assertEquals(#p1:getCardIds("h"), 2)
  lu.assertEquals(#p2:getCardIds("h"), 2)
end

function Testhanjin_shu_effects:testShenzhiDiscardsAllAndComparesWithHp()
  local p1 = p(1)
  grant(p1, SHENZHI)
  clearCards(p1)
  inRoom(function() p1.hp = 3; p1.maxHp = 4 end)
  give(p1, "hanjin__jink", Card.Spade, 1)
  give(p1, "hanjin__jink", Card.Spade, 2)
  FkTest.setNextReplies(p1, { "1" })
  inRoom(function()
    room().logic:trigger(fk.EventPhaseStart, p1, PhaseData:new {
      who = p1, reason = "game_rule", phase = Player.Start,
    })
  end)
  lu.assertEquals(#p1:getCardIds("h"), 0)
  lu.assertEquals(p1.hp, 3) -- 2 张 < 3 体力，不回复

  -- 3 张手牌、体力 2：弃 3 >= 2，回复 1。
  inRoom(function() p1.hp = 2 end)
  give(p1, "hanjin__jink", Card.Spade, 3)
  give(p1, "hanjin__jink", Card.Spade, 4)
  give(p1, "hanjin__jink", Card.Spade, 5)
  FkTest.setNextReplies(p1, { "1" })
  inRoom(function()
    room().logic:trigger(fk.EventPhaseStart, p1, PhaseData:new {
      who = p1, reason = "game_rule", phase = Player.Start,
    })
  end)
  lu.assertEquals(p1.hp, 3)
end


function Testhanjin_shu_effects:testKuangguStillResolvesAfterKillingTarget()
  local from, victim = p(1), p(2)
  for _, player in ipairs(room().players) do clearCards(player) end
  grant(from, KUANGGU)
  inRoom(function()
    -- 保留敌对角色，避免击杀后先行结束整局而中断后续伤害结算。
    skill_test.installDualGenerals(room(), p(8), {
      main = "hanjin_test__wei_1", deputy = "hanjin_test__wei_2", kingdom = "wei",
    })
    room().current = from
    victim.hp = 1
  end)
  local invoked = 0
  local oldPeach = room().askToPeach
  room().askToPeach = function() return nil end
  skill_test.withSkillRequests(room(), KUANGGU, {
    askToSkillInvoke = function() invoked = invoked + 1; return true end,
    askToChoice = function() return "#hanjin__skill_shu009_1-draw" end,
  }, function()
    inRoom(function() room():damage {from = from, to = victim, damage = 1, skillName = "test"} end)
  end)
  room().askToPeach = oldPeach
  lu.assertTrue(victim.dead)
  lu.assertEquals(invoked, 1)
  lu.assertEquals(#from:getCardIds("h"), 1)
end

return { name = "hanjin_shu_effects" }
