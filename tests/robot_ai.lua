local support = __dofile("../../../tests/support/hegemony.lua")
local skillTest = __dofile("../../../tests/support/skill_test.lua")

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

return { name = "qiao_robot_ai" }
