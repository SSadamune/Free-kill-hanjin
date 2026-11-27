local support = __dofile("../../../tests/support/hegemony.lua")
local skillTest = __dofile("../../../tests/support/skill_test.lua")
local Adaptation = require "packages.qiao.pkg.qiao_mode.rules.adaptation"

Testqiao_robot_ai = { setup = support.initQiaoRoom, tearDown = support.clearRoom }

local function scenario(fn)
  local ok, err
  FkTest.runInRoom(function()
    local room = FkTest.room
    local player, enemy, ally, unknown = table.unpack(room.players)
    skillTest.installBlankGenerals(room, { "wei", "shu", "wei", "wu", "wu", "qun", "han", "jin" })
    room:setPlayerProperty(unknown, "kingdom", "unknown")
    room:setPlayerProperty(player, "phase", Player.Play)
    room.current = player
    local hand = player:getCardIds("h")
    if #hand > 0 then room:throwCard(hand, "test", player, player) end
    ok, err = xpcall(fn, debug.traceback, room, player, enemy, ally, unknown)
  end)
  assert(ok, err or "Robot scenario did not reach its assertions")
end

local function give(room, player, name, number, suit)
  local card = room:printCard(name, suit or Card.Heart, number or 5)
  room:obtainCard(player, card, true)
  return card
end

local function reply(player, command, data)
  local ai = player.ai
  ai.command, ai.data = command, data
  return ai:makeReply()
end

local function diplomacyTable(room, player, enemy, ally, unknown)
  local otherEnemy, lastEnemy, weaker, hidden = table.unpack(room.players, 5)
  for _, target in ipairs(room.players) do
    local cards = target:getCardIds("h")
    if #cards > 0 then room:throwCard(cards, "test", target, target) end
  end
  for _, opponent in ipairs({ enemy, otherEnemy, lastEnemy }) do
    room:setPlayerProperty(opponent, "kingdom", "shu")
    room:setPlayerProperty(opponent, "hp", 4)
    room:setPlayerProperty(opponent, "shield", 2)
  end
  room:setPlayerProperty(player, "hp", 4)
  room:setPlayerProperty(ally, "hp", 1)
  room:setPlayerProperty(weaker, "kingdom", "qun")
  room:setPlayerProperty(weaker, "hp", 1)
  room:setPlayerProperty(unknown, "hp", 1)
  room:setPlayerProperty(hidden, "kingdom", "unknown")
  return weaker, otherEnemy, lastEnemy
end

function Testqiao_robot_ai:testFactionWeightPrioritizesStrongerOpponentAndRecalculates()
  scenario(function(room, player, enemy, ally, unknown)
    local weaker, otherEnemy, lastEnemy = diplomacyTable(room, player, enemy, ally, unknown)
    give(room, player, "qiao__duel")
    lu.assertTrue(player.ai:attitude(enemy) < -0.4)
    lu.assertTrue(player.ai:attitude(weaker) > 0)
    lu.assertEquals(player.ai:attitude(ally), 1)
    lu.assertEquals(player.ai:attitude(unknown), 0)
    lu.assertTrue(player.ai:isEnemy(weaker))
    lu.assertEquals(reply(player, "PlayCard", {}).targets, { enemy.id })

    -- Once Shu no longer dominates, the wounded opponent is back on top.
    room:setPlayerProperty(otherEnemy, "kingdom", "unknown")
    room:setPlayerProperty(lastEnemy, "kingdom", "unknown")
    lu.assertEquals(player.ai:attitude(weaker), -0.4)
    lu.assertEquals(reply(player, "PlayCard", {}).targets, { weaker.id })
  end)
end

function Testqiao_robot_ai:testFactionWeightAppliesToDisruptionAndInteractiveSkill()
  scenario(function(room, player, enemy, ally, unknown)
    local weaker = diplomacyTable(room, player, enemy, ally, unknown)
    player.serverplayer:setState(fk.Player_Robot)
    give(room, enemy, "qiao__peach")
    for _ = 1, 4 do give(room, weaker, "qiao__jink") end
    give(room, player, "qiao__dismantlement")
    lu.assertEquals(reply(player, "PlayCard", {}).targets, { enemy.id })
    local picked = room:askToChoosePlayers(player, {
      min_num = 1, max_num = 1, targets = { weaker, enemy, ally, unknown },
      skill_name = "qiao__skill_shu005_2", prompt = "#qiao__skill_shu005_2-target", cancelable = true,
    })
    lu.assertEquals(table.map(picked, Util.IdMapper), { enemy.id })
    local sole = room:askToChoosePlayers(player, {
      min_num = 1, max_num = 1, targets = { weaker, ally, unknown },
      skill_name = "qiao__skill_shu005_2", prompt = "#qiao__skill_shu005_2-target", cancelable = true,
    })
    lu.assertEquals(table.map(sole, Util.IdMapper), { weaker.id })
  end)
end

function Testqiao_robot_ai:testBefriendAttackingHelpsTemporaryAllyWithoutPeachRescue()
  scenario(function(room, player, enemy, ally, unknown)
    local weaker = diplomacyTable(room, player, enemy, ally, unknown)
    player.serverplayer:setState(fk.Player_Robot)
    local befriend = give(room, player, "qiao__befriend_attacking")
    local action = reply(player, "PlayCard", {})
    lu.assertEquals(action.card, befriend.id)
    lu.assertEquals(action.targets, { weaker.id })
    room:useCard(room:handleUseCardReply(player, action))
    lu.assertEquals(player:getHandcardNum(), 3)
    lu.assertEquals(weaker:getHandcardNum(), 1)
    lu.assertEquals(enemy:getHandcardNum(), 0)

    give(room, player, "qiao__peach")
    room:setPlayerProperty(weaker, "hp", 0)
    room:setPlayerProperty(ally, "hp", 0)
    local function askForPeach(target)
      return room:askToUseCard(player, {
        skill_name = "peach", pattern = "peach", prompt = "#AskForPeaches:" .. target.id,
        cancelable = true, extra_data = { fix_targets = { target.id } },
      })
    end
    lu.assertTrue(player.ai:attitude(weaker) > 0)
    lu.assertNil(askForPeach(weaker))
    lu.assertNotNil(askForPeach(ally))
  end)
end

function Testqiao_robot_ai:testAllianceExchangesOnlyCheapMarkedCardWithTemporaryAlly()
  scenario(function(room, player, enemy, ally, unknown)
    local weaker, otherEnemy, lastEnemy = diplomacyTable(room, player, enemy, ally, unknown)
    local peach = give(room, player, "qiao__peach", 3, Card.Diamond)
    local cheap = give(room, player, "qiao__lure_tiger", 10, Card.Diamond)
    local duel = give(room, player, "qiao__duel")
    room:setCardMark(peach, "@@alliance-public", 1)
    room:setCardMark(cheap, "@@alliance-public", 1)

    -- With no cooperation, normal actions have priority over the exchange.
    room:setPlayerProperty(otherEnemy, "kingdom", "unknown")
    room:setPlayerProperty(lastEnemy, "kingdom", "unknown")
    lu.assertEquals(reply(player, "PlayCard", {}).card, duel.id)
    room:setPlayerProperty(otherEnemy, "kingdom", "shu")
    room:setPlayerProperty(lastEnemy, "kingdom", "shu")

    local action = reply(player, "PlayCard", {})
    lu.assertEquals(action.card.skill, "qiao__alliance")
    lu.assertEquals(action.card.subcards, { cheap.id })
    lu.assertEquals(action.targets, { weaker.id })
    room:handleUseCardReply(player, action)
    lu.assertEquals(room:getCardOwner(cheap.id).id, weaker.id)
    lu.assertEquals(room:getCardOwner(peach.id).id, player.id)
    lu.assertEquals(player:getHandcardNum(), 3)
  end)
end

function Testqiao_robot_ai:testAllianceFallsBackToLowValueOnlyWhenAllRecipientsAreEnemies()
  scenario(function(room, player, enemy, ally, unknown)
    local _, otherEnemy, lastEnemy = diplomacyTable(room, player, enemy, ally, unknown)
    room:setPlayerProperty(otherEnemy, "kingdom", "unknown")
    room:setPlayerProperty(lastEnemy, "kingdom", "unknown")
    local peach = give(room, player, "qiao__peach", 3, Card.Diamond)
    room:setCardMark(peach, "@@alliance-public", 1)
    lu.assertEquals(reply(player, "PlayCard", {}), "__cancel")
    local cheap = give(room, player, "qiao__lure_tiger", 10, Card.Diamond)
    room:setCardMark(cheap, "@@alliance-public", 1)
    local action = reply(player, "PlayCard", {})
    lu.assertEquals(action.card.skill, "qiao__alliance")
    lu.assertEquals(action.card.subcards, { cheap.id })
    lu.assertTrue(player.ai:isEnemy(room:getPlayerById(action.targets[1])))
  end)
end

function Testqiao_robot_ai:testTemporaryAllyReceivesAidOnlyForHighValueWaterAttack()
  scenario(function(room, player, enemy, ally, unknown)
    local weaker = diplomacyTable(room, player, enemy, ally, unknown)
    player.serverplayer:setState(fk.Player_Robot)
    local cheap = give(room, player, "qiao__lure_tiger")
    local expensive = give(room, player, "qiao__foresight")
    local gear = give(room, enemy, "qiao__blade")
    room:moveCardTo(gear, Card.PlayerEquip, enemy, fk.ReasonPut)
    local card = give(room, weaker, "qiao__drowning")
    Adaptation.setCardEntries(card, { { condition = "zhuzhan", effect = "execute_both" } })

    local function probe()
      local use = UseCardData:new { from = weaker, tos = { enemy }, card = card, extra_data = {} }
      Adaptation.prepare(room, use)
      Adaptation.resolve(room, use)
      return Adaptation.hasEffect(use, "execute_both") == true
    end
    lu.assertTrue(player.ai:attitude(weaker) > 0)
    lu.assertFalse(probe()) -- One weapon and a healthy target do not justify this reserve.
    room:setPlayerProperty(enemy, "hp", 1)
    room:setPlayerProperty(enemy, "shield", 0)
    room:setPlayerProperty(enemy, "chained", true)
    room:setPlayerProperty(ally, "chained", true)
    lu.assertFalse(probe())
    lu.assertEquals(room:getCardOwner(cheap.id).id, player.id)
    room:setPlayerProperty(ally, "chained", false)

    room:useCard { from = weaker, tos = { enemy }, card = card }
    lu.assertEquals(room:getCardArea(cheap.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(gear.id), Card.DiscardPile)
    lu.assertEquals(room:getCardOwner(expensive.id).id, player.id)
    lu.assertEquals(enemy.hp, 0)
  end)
end

function Testqiao_robot_ai:testTemporaryAidForDamageBoostUsesCheapCardAndCommonEnemy()
  scenario(function(room, player, enemy, ally, unknown)
    local weaker = diplomacyTable(room, player, enemy, ally, unknown)
    player.serverplayer:setState(fk.Player_Robot)
    local cheap = give(room, player, "qiao__slash")
    local other = give(room, player, "qiao__slash")
    local peach = give(room, player, "qiao__peach")
    room:setPlayerProperty(enemy, "hp", 2)
    room:setPlayerProperty(enemy, "shield", 0)
    local function probe(target)
      local card = Fk:cloneCard("qiao__fire__slash")
      Adaptation.setCardEntries(card, { { condition = "zhuzhan", effect = "damage" } })
      local use = UseCardData:new { from = weaker, tos = { target }, card = card, extra_data = {} }
      Adaptation.prepare(room, use)
      Adaptation.resolve(room, use)
      return use.additionalDamage or 0
    end
    lu.assertEquals(probe(ally), 0)
    lu.assertEquals(probe(enemy), 1)
    lu.assertEquals(player:getHandcardNum(), 2)
    lu.assertTrue(room:getCardArea(cheap.id) == Card.DiscardPile or room:getCardArea(other.id) == Card.DiscardPile)
    lu.assertEquals(room:getCardOwner(peach.id).id, player.id)
    lu.assertEquals(probe(enemy), 0) -- The remaining Slash and Peach cost too much.
  end)
end

function Testqiao_robot_ai:testHiddenRobotUsesItsOwnFactionOnlyForTacticalKnowledge()
  scenario(function(room, player, enemy, ally, unknown)
    local weaker = diplomacyTable(room, player, enemy, ally, unknown)
    room:setPlayerProperty(player, "kingdom", "unknown")
    give(room, player, "qiao__befriend_attacking")
    local cheap = give(room, player, "qiao__lure_tiger", 10, Card.Diamond)
    room:setCardMark(cheap, "@@alliance-public", 1)
    lu.assertTrue(player.ai:isEnemy(enemy))
    lu.assertFalse(player.ai:isFriend(ally))
    lu.assertFalse(player.ai:isEnemy(ally))
    lu.assertTrue(player.ai:attitude(weaker) > 0)
    lu.assertEquals(reply(player, "PlayCard", {}), "__cancel")

    local duel = give(room, player, "qiao__duel")
    local action = reply(player, "PlayCard", {})
    lu.assertEquals(action.card, duel.id)
    lu.assertEquals(action.targets, { enemy.id })
  end)
end

function Testqiao_robot_ai:testHumanSeatsWinCloseAttackAndSupportChoices()
  scenario(function(room, player, enemy, ally, unknown)
    local otherEnemy, otherAlly = table.unpack(room.players, 5)
    for _, target in ipairs(room.players) do
      local cards = target:getCardIds("h")
      if #cards > 0 then room:throwCard(cards, "test", target, target) end
      if target ~= player and target ~= enemy and target ~= ally then
        room:setPlayerProperty(target, "kingdom", "unknown")
      end
    end
    room:setPlayerProperty(otherEnemy, "kingdom", "shu")
    room:setPlayerProperty(otherAlly, "kingdom", "wei")
    room:setPlayerProperty(otherEnemy, "hp", enemy.hp)
    room:setPlayerProperty(otherAlly, "maxHp", ally.maxHp)
    player.serverplayer:setState(fk.Player_Robot)
    enemy.serverplayer:setState(fk.Player_Robot)
    ally.serverplayer:setState(fk.Player_Robot)
    otherEnemy.serverplayer:setState(fk.Player_Online)
    otherAlly.serverplayer:setState(fk.Player_Trust)
    unknown.serverplayer:setState(fk.Player_Online)
    give(room, player, "qiao__duel")
    lu.assertEquals(reply(player, "PlayCard", {}).targets, { otherEnemy.id })
    room:setPlayerProperty(enemy, "hp", otherEnemy.hp - 1)
    lu.assertEquals(reply(player, "PlayCard", {}).targets, { enemy.id })

    local chosen = room:askToChoosePlayers(player, {
      min_num = 1, max_num = 1, targets = { ally, otherAlly, otherEnemy, unknown },
      skill_name = "qiao__skill_han015_3", prompt = "#qiao__skill_han015_3-target", cancelable = true,
    })
    lu.assertEquals(table.map(chosen, Util.IdMapper), { otherAlly.id })
  end)
end

function Testqiao_robot_ai:testWildPlayersShareAGroupOnlyWithPublicCountry()
  scenario(function(room, player, enemy)
    for _, target in ipairs({ player, enemy }) do
      room:setPlayerProperty(target, "kingdom", "wild")
      room:setPlayerProperty(target, "role", "heg_qin")
      room:setPlayerProperty(target, "role_shown", false)
    end
    lu.assertFalse(player.ai:isFriend(enemy))
    lu.assertTrue(player.ai:isEnemy(enemy))
    room:setPlayerProperty(player, "role_shown", true)
    room:setPlayerProperty(enemy, "role_shown", true)
    lu.assertTrue(player.ai:isFriend(enemy))
    lu.assertFalse(player.ai:isEnemy(enemy))
  end)
end

function Testqiao_robot_ai:testDecisionDeadlineCancelsStuckReplyAndNextRequestWorks()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    local card = give(room, player, "qiao__foresight")
    local ai = player.ai
    local previousHook, previousMask, previousCount = debug.gethook()
    local originalHandler = room.current_request_handler
    ai.handlePlayCard = function() while true do end end

    local req = Request:new(player, "PlayCard")
    req.timeout = 1
    local started = os.getms()
    local answer = req:getResult(player)
    local elapsed = os.getms() - started
    ai.handlePlayCard = nil

    lu.assertEquals(answer, "")
    lu.assertTrue(elapsed >= 10000000 and elapsed < 30000000, tostring(elapsed))
    lu.assertNil(ai.handler)
    lu.assertTrue(room.current_request_handler == originalHandler)
    local hook, mask, count = debug.gethook()
    lu.assertTrue(hook == previousHook)
    lu.assertEquals(mask, previousMask)
    lu.assertEquals(count, previousCount)
    lu.assertEquals(room:getCardOwner(card.id).id, player.id)

    local nextRequest = Request:new(player, "PlayCard")
    lu.assertEquals(nextRequest:getResult(player).card, card.id)
  end)
end

function Testqiao_robot_ai:testForesightThroughPlayCard()
  scenario(function(room, player)
    local card = give(room, player, "qiao__foresight")
    local answer = reply(player, "PlayCard", {})
    lu.assertEquals(answer.card, card.id)
    local use = room:handleUseCardReply(player, answer)
    lu.assertNotNil(use)
    room:useCard(use)
    lu.assertEquals(player:getHandcardNum(), 2)
  end)
end

function Testqiao_robot_ai:testAttackOnlyConfirmedEnemy()
  scenario(function(room, player, enemy, ally, unknown)
    for _, target in ipairs(room.players) do
      if target ~= player and target ~= enemy and target ~= ally then
        room:setPlayerProperty(target, "kingdom", "unknown")
      end
    end
    give(room, player, "qiao__unexpectation")
    room:setPlayerProperty(ally, "hp", 1)
    room:setPlayerProperty(unknown, "hp", 1)
    lu.assertEquals(reply(player, "PlayCard", {}).targets, { enemy.id })
    room:setPlayerProperty(enemy, "kingdom", "unknown")
    lu.assertEquals(reply(player, "PlayCard", {}), "__cancel")
  end)
end

function Testqiao_robot_ai:testRemovalDoesNotHitAllyOrUnknown()
  scenario(function(room, player, enemy, ally, unknown)
    for _, target in ipairs(room.players) do
      if target ~= player and target ~= enemy and target ~= ally then
        room:setPlayerProperty(target, "kingdom", "unknown")
      end
    end
    give(room, player, "qiao__chasing_near")
    lu.assertEquals(reply(player, "PlayCard", {}).targets, { enemy.id })
    room:setPlayerProperty(enemy, "kingdom", "unknown")
    lu.assertEquals(reply(player, "PlayCard", {}), "__cancel")
  end)
end

function Testqiao_robot_ai:testRobotInvokesBiyueInRoom()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__skill_qun003_2", nil, false, true)
    room:setPlayerProperty(player, "phase", Player.Finish)
    room.logic:trigger(fk.EventPhaseStart, player, { phase = Player.Finish })
    lu.assertEquals(player:getHandcardNum(), 2)
  end)
end

function Testqiao_robot_ai:testAxePaysOnlyLowCostForFinishingAttack()
  scenario(function(room, player, enemy, ally)
    player.serverplayer:setState(fk.Player_Robot)
    local cheap = give(room, player, "qiao__lightning")
    local otherCheap = give(room, player, "qiao__lure_tiger")
    give(room, player, "qiao__peach")
    room:setPlayerProperty(enemy, "hp", 1)
    room:setPlayerProperty(ally, "hp", 1)
    local function choose(target)
      return room:askToDiscard(player, {
        min_num = 2, max_num = 2, cancelable = true, skip = true,
        skill_name = "qiao__axe_skill", prompt = "#axe-invoke::" .. target.id,
      })
    end
    lu.assertEquals(#choose(ally), 0)
    lu.assertItemsEquals(choose(enemy), { cheap.id, otherCheap.id })
    room:throwCard(otherCheap, "test", player, player)
    lu.assertEquals(#choose(enemy), 0)
  end)
end

function Testqiao_robot_ai:testMandatoryDiscardPreservesSavingCard()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    local peach = give(room, player, "qiao__peach")
    local cheap = give(room, player, "qiao__lightning")
    local cards = room:askToDiscard(player, {
      min_num = 1, max_num = 2, cancelable = false, skill_name = "phase_discard",
    })
    lu.assertEquals(cards, { cheap.id })
    lu.assertEquals(player:getCardIds("h"), { peach.id })
  end)
end

function Testqiao_robot_ai:testSupportSpendsOnlyCheapMatchingCardForAlly()
  scenario(function(room, player, enemy, ally)
    player.serverplayer:setState(fk.Player_Robot)
    local function settle(from, target)
      local card = Fk:cloneCard("qiao__chasing_near")
      Adaptation.setCardEntries(card, { { condition = "zhuzhan", effect = "execute_both" } })
      local use = UseCardData:new { from = from, tos = { target }, card = card, extra_data = {} }
      Adaptation.prepare(room, use)
      Adaptation.resolve(room, use)
      return not not Adaptation.hasEffect(use, "execute_both")
    end
    local peach = give(room, player, "qiao__peach")
    local expensive = give(room, player, "qiao__foresight")
    local cheap = give(room, player, "qiao__lightning")
    lu.assertFalse(settle(enemy, ally))
    lu.assertEquals(room:getCardArea(cheap.id), Card.PlayerHand)
    lu.assertTrue(settle(ally, enemy))
    lu.assertEquals(room:getCardArea(cheap.id), Card.DiscardPile)
    lu.assertFalse(settle(ally, enemy))
    lu.assertItemsEquals(player:getCardIds("h"), { peach.id, expensive.id })
  end)
end

function Testqiao_robot_ai:testRealPlayCardRequestUsesZhiheng()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__skill_wu001_1", nil, false, true)
    local cheap = give(room, player, "qiao__lightning")
    local req = Request:new(player, "PlayCard")
    local response = req:getResult(player)
    lu.assertEquals(response.card.skill, "qiao__skill_wu001_1")
    lu.assertEquals(response.card.subcards, { cheap.id })
    room:handleUseCardReply(player, response)
    lu.assertEquals(room:getCardArea(cheap.id), Card.DiscardPile)
    lu.assertEquals(player:getHandcardNum(), 2)
  end)
end

function Testqiao_robot_ai:testExtraSlashRespectsRestrictedTargets()
  scenario(function(room, player, enemy, ally)
    player.serverplayer:setState(fk.Player_Robot)
    local slash = give(room, player, "qiao__slash")
    local function ask(target)
      return room:askToUseCard(player, {
        skill_name = "slash", pattern = "slash", prompt = "#test-slash",
        extra_data = { exclusive_targets = { target.id }, bypass_distances = true },
        cancelable = true,
      })
    end
    lu.assertNil(ask(ally))
    local answer = ask(enemy)
    lu.assertNotNil(answer)
    lu.assertEquals(answer.card.id, slash.id)
    lu.assertEquals(answer.tos[1].id, enemy.id)
  end)
end

function Testqiao_robot_ai:testAdaptationAddsAnEnemyThroughCardUse()
  scenario(function(room, player, enemy, ally, anotherEnemy)
    player.serverplayer:setState(fk.Player_Robot)
    room:setPlayerProperty(player, "hp", 1)
    for index = 5, #room.players do room:setPlayerProperty(room.players[index], "kingdom", "unknown") end
    room:setPlayerProperty(anotherEnemy, "kingdom", "shu")
    local card = give(room, player, "qiao__unexpectation")
    Adaptation.setCardEntries(card, { { condition = "canqu", effect = "add_target" } })
    local use = room:handleUseCardReply(player, reply(player, "PlayCard", {}))
    lu.assertNotNil(use)
    room:useCard(use)
    lu.assertItemsEquals(table.map(use.tos, Util.IdMapper), { enemy.id, anotherEnemy.id })
    lu.assertFalse(table.contains(use.tos, ally))
  end)
end

function Testqiao_robot_ai:testRecastWhenNoneOfTheNormalTargetsAreUseful()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    local card = give(room, player, "qiao__iron_chain")
    local req = Request:new(player, "PlayCard")
    local answer = req:getResult(player)
    lu.assertEquals(answer.card, card.id)
    lu.assertEquals(answer.special_skill, "recast")
    room:handleUseCardReply(player, answer)
    lu.assertEquals(room:getCardArea(card.id), Card.DiscardPile)
    lu.assertEquals(player:getHandcardNum(), 1)
  end)
end

function Testqiao_robot_ai:testEightDiagramForUseAndResponse()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    local armor = give(room, player, "qiao__eight_diagram")
    room:moveCardTo(armor, Card.PlayerEquip, player, fk.ReasonPut)
    for _, method in ipairs({ "askToUseCard", "askToResponse" }) do
      room:moveCardTo(room:printCard("qiao__slash", Card.Heart, 3), Card.DrawPile)
      local result = room[method](room, player, { skill_name = "jink", pattern = "jink", cancelable = true })
      lu.assertNotNil(result, method)
      lu.assertEquals(result.card.name, "qiao__jink")
      lu.assertEquals(result.card.skillName, "qiao__eight_diagram_skill")
    end
  end)
end

function Testqiao_robot_ai:testJinfanPaysCheapMatchingCardAndDrawsTwo()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__retinue_skill_jinfanjun", nil, false, true)
    local peach = give(room, player, "qiao__peach")
    local cheap = give(room, player, "qiao__lightning")
    local discarded = give(room, player, "qiao__slash")
    room:throwCard(discarded, "test", player, player)
    lu.assertEquals(room:getCardArea(cheap.id), Card.DiscardPile)
    lu.assertEquals(room:getCardOwner(peach.id).id, player.id)
    lu.assertEquals(player:getHandcardNum(), 3)
  end)
end

function Testqiao_robot_ai:testQuaxiaoRequiresAllOverlappingTargetsToBeEnemies()
  scenario(function(room, player, enemy, ally)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__retinue_skill_quaxiaojiang", nil, false, true)
    local function use(targets)
      room:useCard { from = player, tos = targets, card = Fk:cloneCard("qiao__iron_chain") }
    end
    local allyHp, enemyHp = ally.hp, enemy.hp
    use({ ally })
    use({ ally, enemy })
    lu.assertEquals(ally.hp, allyHp)
    use({ enemy })
    lu.assertEquals(enemy.hp, enemyHp - 1)
  end)
end

function Testqiao_robot_ai:testNiujinUsesSafeCardInActualFreeUseWindow()
  scenario(function(room, player, _, ally)
    player.serverplayer:setState(fk.Player_Robot)
    local name = "qiao__retinue_skill_niujin"
    room:handleAddLoseSkills(player, name, nil, false, true)
    local card = give(room, player, "qiao__foresight")
    room.logic:trigger(fk.TurnEnd, ally, {})
    lu.assertEquals(room:getCardArea(card.id), Card.DiscardPile)
    lu.assertTrue(player:usedSkillTimes(name, Player.HistoryGame) > 0)
  end)
end

function Testqiao_robot_ai:testVenomSavesGeneralWhenEnemyIsNotDying()
  scenario(function(room, player, enemy)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__skill_han019_2", nil, false, true)
    room:setPlayerProperty(enemy, "hp", 1)
    room:recover { who = enemy, num = 1 }
    lu.assertEquals(enemy.hp, 2)
    room:setPlayerProperty(enemy, "hp", 0)
    room:recover { who = enemy, num = 1 }
    lu.assertEquals(enemy.hp, 0)
  end)
end

function Testqiao_robot_ai:testYimieKeepsLimitedUseUntilDamageIsLethal()
  scenario(function(room, player, enemy)
    player.serverplayer:setState(fk.Player_Robot)
    local name = "qiao__skill_jin002_2"
    room:handleAddLoseSkills(player, name, nil, false, true)
    room:setPlayerProperty(player, "hp", 1)
    room:setPlayerProperty(enemy, "hp", 3)
    room:damage { from = player, to = enemy, damage = 1 }
    lu.assertEquals(enemy.hp, 2)
    lu.assertEquals(player:usedSkillTimes(name, Player.HistoryGame), 0)
    room:damage { from = player, to = enemy, damage = 1 }
    lu.assertEquals(enemy.hp, 0)
    lu.assertEquals(player:usedSkillTimes(name, Player.HistoryGame), 1)
  end)
end

function Testqiao_robot_ai:testLizhanDrawsForWoundedAllyOnly()
  scenario(function(room, player, enemy, ally, unknown)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__skill_wei011_2", nil, false, true)
    room:setPlayerProperty(player, "phase", Player.Finish)
    for _, target in ipairs({ enemy, ally, unknown }) do room:setPlayerProperty(target, "hp", 1) end
    local allyHand, enemyHand, unknownHand = ally:getHandcardNum(), enemy:getHandcardNum(), unknown:getHandcardNum()
    room.logic:trigger(fk.EventPhaseStart, player, { phase = Player.Finish })
    lu.assertEquals(ally:getHandcardNum(), allyHand + 1)
    lu.assertEquals(enemy:getHandcardNum(), enemyHand)
    lu.assertEquals(unknown:getHandcardNum(), unknownHand)
  end)
end

function Testqiao_robot_ai:testJizhiInvokesThroughDefaultPrompt()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__skill_shu007_1", nil, false, true)
    local card = give(room, player, "qiao__foresight")
    room:useCard { from = player, tos = { player }, card = card }
    lu.assertEquals(player:getHandcardNum(), 3)
  end)
end

function Testqiao_robot_ai:testCiweiPaysForAnAllyButLeavesOtherTargetsInPlace()
  scenario(function(room, player, enemy, ally, unknown)
    player.serverplayer:setState(fk.Player_Robot)
    local name = "qiao__skill_jin012_1"
    room:handleAddLoseSkills(player, name, nil, false, true)
    local cheap = give(room, player, "qiao__lightning")
    local armor = give(room, enemy, "qiao__eight_diagram")
    local attack = give(room, enemy, "qiao__archery_attack")
    local allyHp, unknownHp = ally.hp, unknown.hp
    local probe = fk.CreateSkill { name = "#qiao_robot_ciwei_turn_probe" }
    probe:addEffect(fk.TurnStart, {
      global = true,
      can_refresh = function(_, _, target, owner) return target == enemy and owner == enemy end,
      on_refresh = function()
        room:setCurrent(enemy)
        room:useCard { from = enemy, tos = { enemy }, card = armor }
        room:useCard { from = enemy, tos = { ally, unknown }, card = attack }
      end,
    })
    room:addSkill(probe:createSkill())
    GameEvent.Turn:create(TurnData:new(enemy, "game_rule", { Player.Play })):exec()
    lu.assertEquals(room:getCardArea(cheap.id), Card.DiscardPile)
    lu.assertEquals(ally.hp, allyHp)
    lu.assertEquals(unknown.hp, unknownHp - 1)
  end)
end

function Testqiao_robot_ai:testKurouRequiresEffectiveZhaxiangAndSafeHp()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    local kurou, zhaxiang = "qiao__skill_wu004_1", "qiao__skill_wu004_2"
    room:handleAddLoseSkills(player, kurou, nil, false, true)
    room:setPlayerProperty(player, "hp", 3)
    lu.assertEquals(reply(player, "PlayCard", {}), "__cancel")
    room:handleAddLoseSkills(player, zhaxiang, nil, false, true)
    room:setPlayerProperty(player, "hp", 2)
    lu.assertEquals(reply(player, "PlayCard", {}), "__cancel")
    room:setPlayerProperty(player, "hp", 3)
    local req = Request:new(player, "PlayCard")
    local answer = req:getResult(player)
    lu.assertEquals(answer.card.skill, kurou)
    room:handleUseCardReply(player, answer)
    lu.assertEquals(player.hp, 2)
    lu.assertEquals(player:getHandcardNum(), 3)
    lu.assertEquals(player:getMark("qiao_wu004_zhaxiang_times-turn"), 1)
  end)
end

function Testqiao_robot_ai:testQiangxiChoosesSpareWeaponForLethalDamage()
  scenario(function(room, player, enemy)
    player.serverplayer:setState(fk.Player_Robot)
    local name = "qiao__skill_wei012_1"
    room:handleAddLoseSkills(player, name, nil, false, true)
    local weapon = give(room, player, "qiao__axe")
    room:moveCardTo(weapon, Card.PlayerEquip, player, fk.ReasonPut)
    local spare = give(room, player, "qiao__crossbow")
    room:setPlayerProperty(enemy, "hp", 1)
    local hp = player.hp
    local answer = reply(player, "PlayCard", {})
    lu.assertEquals(answer.card.skill, name)
    lu.assertEquals(answer.interaction_data, "#qiao__skill_wei012_1-discard")
    lu.assertEquals(answer.targets, { enemy.id })
    room:handleUseCardReply(player, answer)
    lu.assertEquals(player.hp, hp)
    lu.assertEquals(enemy.hp, 0)
    lu.assertEquals(room:getCardArea(spare.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(weapon.id), Card.PlayerEquip)
  end)
end

function Testqiao_robot_ai:testMinsiFindsCheapExactSumAndProtectsPeach()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    local name = "qiao__skill_han007_1"
    room:handleAddLoseSkills(player, name, nil, false, true)
    room:setPlayerProperty(player, "hp", player.maxHp)
    local peach = give(room, player, "qiao__peach", 13)
    local a = give(room, player, "qiao__lightning", 6)
    local b = give(room, player, "qiao__lure_tiger", 7)
    local answer = reply(player, "PlayCard", {})
    lu.assertEquals(answer.card.skill, name)
    lu.assertItemsEquals(answer.card.subcards, { a.id, b.id })
    room:handleUseCardReply(player, answer)
    lu.assertEquals(player:getHandcardNum(), 5)
    lu.assertEquals(room:getCardOwner(peach.id).id, player.id)
  end)
end

function Testqiao_robot_ai:testYinghunTargetsAllyWithDrawOption()
  scenario(function(room, player, enemy, ally)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__skill_wu009_1", nil, false, true)
    room:setPlayerProperty(player, "phase", Player.Start)
    room:setPlayerProperty(player, "hp", player.maxHp - 2)
    local allyHand, enemyHand = ally:getHandcardNum(), enemy:getHandcardNum()
    room.logic:trigger(fk.EventPhaseStart, player, { phase = Player.Start })
    lu.assertEquals(ally:getHandcardNum(), allyHand + 1)
    lu.assertEquals(enemy:getHandcardNum(), enemyHand)
  end)
end

function Testqiao_robot_ai:testQingguoUsesCheapBlackCardForBothJinkRequests()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    local name = "qiao__skill_wei007_1"
    room:handleAddLoseSkills(player, name, nil, false, true)
    local cost = give(room, player, "qiao__lightning", 5, Card.Spade)
    for _, method in ipairs({ "askToUseCard", "askToResponse" }) do
      local answer = room[method](room, player, { pattern = "jink", skill_name = "jink", cancelable = true })
      lu.assertNotNil(answer, method)
      lu.assertEquals(answer.card.name, "qiao__jink")
      lu.assertEquals(answer.card.subcards, { cost.id })
    end
  end)
end

function Testqiao_robot_ai:testQixiTargetsAnEnemyWithCheapBlackMaterial()
  scenario(function(room, player, enemy)
    player.serverplayer:setState(fk.Player_Robot)
    for index = 3, #room.players do room:setPlayerProperty(room.players[index], "kingdom", "unknown") end
    local name = "qiao__skill_wu002_1"
    room:handleAddLoseSkills(player, name, nil, false, true)
    local cost = give(room, player, "qiao__lightning", 5, Card.Spade)
    local armor = give(room, enemy, "qiao__eight_diagram")
    room:moveCardTo(armor, Card.PlayerEquip, enemy, fk.ReasonPut)
    local answer = reply(player, "PlayCard", {})
    lu.assertEquals(answer.card.skill, name)
    lu.assertEquals(answer.card.subcards, { cost.id })
    lu.assertEquals(answer.targets, { enemy.id })
    room:handleUseCardReply(player, answer)
    lu.assertEquals(room:getCardArea(armor.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(cost.id), Card.DiscardPile)
  end)
end

function Testqiao_robot_ai:testYingshiOnlyChangesUnfavorableAllyJudgment()
  scenario(function(room, player, _, ally)
    player.serverplayer:setState(fk.Player_Robot)
    local name = "qiao__skill_wei002_2"
    room:handleAddLoseSkills(player, name, nil, false, true)
    local cost = give(room, player, "qiao__lightning")
    local function judge(suit)
      room:moveCardTo(room:printCard("qiao__slash", suit, 3), Card.DrawPile)
      room:judge { who = ally, reason = "indulgence_skill", pattern = ".|.|^heart" }
    end
    judge(Card.Heart)
    lu.assertEquals(room:getCardOwner(cost.id).id, player.id)
    judge(Card.Spade)
    lu.assertEquals(room:getCardArea(cost.id), Card.DiscardPile)
  end)
end

function Testqiao_robot_ai:testLeijiAndGuidaoChangePublicJudgmentForEnemy()
  scenario(function(room, player, enemy)
    player.serverplayer:setState(fk.Player_Robot)
    for index = 3, #room.players do room:setPlayerProperty(room.players[index], "kingdom", "unknown") end
    room:handleAddLoseSkills(player, "qiao__skill_qun010_1|qiao__skill_qun010_2", nil, false, true)
    local cost = give(room, player, "qiao__lightning", 5, Card.Spade)
    local jink = give(room, player, "qiao__jink")
    local first = room:printCard("qiao__slash", Card.Heart, 3)
    room:moveCardTo(first, Card.DrawPile)
    local hp = enemy.hp
    room:responseCard { from = player, card = jink }
    lu.assertEquals(enemy.hp, hp - 2)
    lu.assertEquals(room:getCardArea(cost.id), Card.DiscardPile)
    lu.assertEquals(room:getCardOwner(first.id).id, player.id)
  end)
end

function Testqiao_robot_ai:testGuidaoKeepsLeijiRecoveryAtOneHp()
  scenario(function(room, player, enemy)
    player.serverplayer:setState(fk.Player_Robot)
    for index = 3, #room.players do room:setPlayerProperty(room.players[index], "kingdom", "unknown") end
    room:handleAddLoseSkills(player, "qiao__skill_qun010_1|qiao__skill_qun010_2", nil, false, true)
    room:setPlayerProperty(player, "hp", 1)
    room:setPlayerProperty(enemy, "hp", 2)
    local cost = give(room, player, "qiao__lightning", 5, Card.Spade)
    local jink = give(room, player, "qiao__jink")
    room:moveCardTo(room:printCard("qiao__slash", Card.Club, 3), Card.DrawPile)
    room:responseCard { from = player, card = jink }
    lu.assertEquals(player.hp, 2)
    lu.assertEquals(enemy.hp, 1)
    lu.assertEquals(room:getCardOwner(cost.id).id, player.id)
  end)
end

function Testqiao_robot_ai:testShebianMovesOnlyBeneficialBoardCards()
  scenario(function(room, player, enemy, ally)
    player.serverplayer:setState(fk.Player_Robot)
    for index = 4, #room.players do room:setPlayerProperty(room.players[index], "kingdom", "unknown") end
    local name = "qiao__skill_wei008_2"
    room:handleAddLoseSkills(player, name, nil, false, true)
    local weapon = give(room, ally, "qiao__blade")
    room:moveCardTo(weapon, Card.PlayerEquip, ally, fk.ReasonPut)
    room:loseHp(player, 1, "test")
    lu.assertEquals(player:usedSkillTimes(name, Player.HistoryGame), 0)
    lu.assertEquals(room:getCardOwner(weapon.id).id, ally.id)
    local armor = give(room, enemy, "qiao__eight_diagram")
    room:moveCardTo(armor, Card.PlayerEquip, enemy, fk.ReasonPut)
    local delayed = give(room, ally, "qiao__indulgence")
    room:moveCardTo(delayed, Card.PlayerJudge, ally, fk.ReasonPut)
    room:loseHp(player, 1, "test")
    lu.assertEquals(room:getCardOwner(delayed.id).id, enemy.id)
    lu.assertEquals(room:getCardOwner(armor.id).id, enemy.id)
    room:loseHp(player, 1, "test")
    lu.assertTrue(player.ai:isFriend(room:getCardOwner(armor.id)))
    lu.assertEquals(room:getCardOwner(delayed.id).id, enemy.id)
  end)
end

function Testqiao_robot_ai:testQiaobianPaysCheapCardToSkipHarmfulJudgment()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__skill_wei009_1", nil, false, true)
    local cost = give(room, player, "qiao__lightning")
    local function checkJudge()
      local data = PhaseData:new { who = player, reason = "game_rule", phase = Player.Judge }
      room.logic:trigger(fk.EventPhaseChanging, player, data)
      return data.skipped == true
    end
    lu.assertFalse(checkJudge())
    lu.assertEquals(room:getCardOwner(cost.id).id, player.id)
    local delayed = give(room, player, "qiao__indulgence")
    room:moveCardTo(delayed, Card.PlayerJudge, player, fk.ReasonPut)
    lu.assertTrue(checkJudge())
    lu.assertEquals(room:getCardArea(cost.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(delayed.id), Card.PlayerJudge)
  end)
end

function Testqiao_robot_ai:testFenjiValuesZhaxiangFromActualHpLoss()
  scenario(function(room, player, _, ally)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__skill_wu013_2", nil, false, true)
    local history = require "packages.qiao.pkg.qiao_mode.rules.wu_history"
    for _, target in ipairs(room.players) do room:setPlayerMark(target, history.LOST_HAND, 0) end
    local old = ally:getCardIds("h")
    if #old > 0 then room:throwCard(old, "test", ally, ally) end
    local cost = give(room, ally, "qiao__jink")
    room:throwCard(cost.id, "test", ally, ally)
    lu.assertEquals(ally:getMark(history.LOST_HAND), 1)
    room:setPlayerProperty(player, "hp", 3)
    local hp = player.hp
    room.logic:trigger(fk.TurnEnd, ally, {})
    lu.assertEquals(player.hp, hp)
    lu.assertEquals(ally:getHandcardNum(), 0)
    room:handleAddLoseSkills(player, "qiao__skill_wu004_2", nil, false, true)
    room.logic:trigger(fk.TurnEnd, ally, {})
    lu.assertEquals(ally:getHandcardNum(), 2)
    lu.assertEquals(player.hp, hp - 1)
    lu.assertEquals(player:getHandcardNum(), 3)
  end)
end

function Testqiao_robot_ai:testShelieTakesBestCardOfEachPublicSuit()
  scenario(function(room, player)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__skill_wu003_3", nil, false, true)
    local peach = room:printCard("qiao__peach", Card.Heart, 3)
    local heart = room:printCard("qiao__jink", Card.Heart, 2)
    local club = room:printCard("qiao__jink", Card.Club, 2)
    local spade = room:printCard("qiao__slash", Card.Spade, 3)
    local diamond = room:printCard("qiao__slash", Card.Diamond, 4)
    room:moveCardTo({ peach.id, heart.id, club.id, spade.id, diamond.id }, Card.DrawPile)
    room:setPlayerProperty(player, "phase", Player.Draw)
    room.logic:trigger(fk.EventPhaseStart, player, { phase = Player.Draw })
    lu.assertItemsEquals(player:getCardIds("h"), { peach.id, club.id, spade.id, diamond.id })
    lu.assertEquals(room:getCardArea(heart.id), Card.DiscardPile)
  end)
end

function Testqiao_robot_ai:testCangjiProtectsEquipmentOnlyFromEnemyDiscard()
  scenario(function(room, player, enemy)
    player.serverplayer:setState(fk.Player_Robot)
    local name = "qiao__skill_shu007_2"
    room:handleAddLoseSkills(player, name, nil, false, true)
    local armor = give(room, player, "qiao__eight_diagram")
    room:moveCardTo(armor, Card.PlayerEquip, player, fk.ReasonPut)
    room:throwCard(armor.id, "test", player, player)
    lu.assertEquals(room:getCardArea(armor.id), Card.DiscardPile)
    room:moveCardTo(armor, Card.PlayerEquip, player, fk.ReasonPut)
    room:throwCard(armor.id, "test", player, enemy)
    lu.assertEquals(room:getCardArea(armor.id), Card.PlayerEquip)
    lu.assertEquals(player:usedSkillTimes(name, Player.HistoryGame), 1)
  end)
end

function Testqiao_robot_ai:testLuoyiPaysOnlyForReachableEnemyAndPlayPhase()
  scenario(function(room, player, enemy)
    player.serverplayer:setState(fk.Player_Robot)
    for index = 3, #room.players do room:setPlayerProperty(room.players[index], "kingdom", "unknown") end
    room:handleAddLoseSkills(player, "qiao__skill_wei005_1", nil, false, true)
    local cost = give(room, player, "qiao__lightning")
    give(room, player, "qiao__duel")
    local hand = enemy:getCardIds("h")
    if #hand > 0 then room:throwCard(hand, "test", enemy, enemy) end
    room:setPlayerProperty(enemy, "hp", 2)
    for _ = 1, 4 do room:moveCardTo(room:printCard("qiao__jink", Card.Heart, 3), Card.DrawPile) end
    GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Draw })):exec()
    lu.assertEquals(room:getCardOwner(cost.id).id, player.id)
    lu.assertEquals(enemy.hp, 2)
    GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Draw, Player.Play })):exec()
    lu.assertEquals(room:getCardArea(cost.id), Card.DiscardPile)
    lu.assertEquals(enemy.hp, 0)
  end)
end

function Testqiao_robot_ai:testXingtuSparesArmorAndHealsAllyWithSpareEquipment()
  scenario(function(room, player, enemy, ally)
    player.serverplayer:setState(fk.Player_Robot)
    room:handleAddLoseSkills(player, "qiao__skill_jin001_2", nil, false, true)
    local armor = give(room, player, "qiao__eight_diagram")
    room:moveCardTo(armor, Card.PlayerEquip, player, fk.ReasonPut)
    room:setPlayerProperty(ally, "hp", 1)
    local first = give(room, enemy, "qiao__foresight")
    Adaptation.setCardEntries(first, { { condition = "canqu", effect = "add_target" } })
    room:useCard { from = enemy, tos = { enemy }, card = first }
    room:moveCardTo(room:printCard("qiao__jink", Card.Heart, 3), Card.DrawPile)
    room.logic:trigger(fk.TurnEnd, enemy, {})
    lu.assertEquals(player:getHandcardNum(), 1)
    lu.assertEquals(ally.hp, 1)
    local spare = give(room, player, "qiao__breastplate")
    room.logic:trigger(fk.TurnEnd, enemy, {})
    lu.assertEquals(ally.hp, 2)
    lu.assertEquals(room:getCardArea(armor.id), Card.PlayerEquip)
    lu.assertEquals(room:getCardArea(spare.id), Card.DiscardPile)
  end)
end

function Testqiao_robot_ai:testChuitongChoosesEnemyArmorAtDyingEvent()
  scenario(function(room, player, enemy, ally)
    player.serverplayer:setState(fk.Player_Robot)
    local name = "qiao__skill_jin001_1"
    room:handleAddLoseSkills(player, name, nil, false, true)
    local friendlyArmor = give(room, ally, "qiao__eight_diagram")
    room:moveCardTo(friendlyArmor, Card.PlayerEquip, ally, fk.ReasonPut)
    room:enterDying { who = ally }
    lu.assertEquals(room:getCardOwner(friendlyArmor.id).id, ally.id)
    lu.assertEquals(player:usedSkillTimes(name, Player.HistoryGame), 0)
    local weapon = give(room, enemy, "qiao__blade")
    local armor = give(room, enemy, "qiao__eight_diagram")
    room:moveCardTo(weapon, Card.PlayerEquip, enemy, fk.ReasonPut)
    room:moveCardTo(armor, Card.PlayerEquip, enemy, fk.ReasonPut)
    room:enterDying { who = enemy }
    lu.assertEquals(room:getCardOwner(armor.id).id, player.id)
    lu.assertEquals(room:getCardOwner(weapon.id).id, enemy.id)
  end)
end

return { name = "qiao_robot_ai" }
