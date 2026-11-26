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

local function give(room, player, name)
  local card = room:printCard(name, Card.Heart, 5)
  room:obtainCard(player, card, true)
  return card
end

local function reply(player, command, data)
  local ai = player.ai
  ai.command, ai.data = command, data
  return ai:makeReply()
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

return { name = "qiao_robot_ai" }
