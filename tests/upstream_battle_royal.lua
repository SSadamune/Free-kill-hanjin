local support = __dofile("../../../tests/support/hegemony.lua")
local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"
local H = require "packages.hegemony.util"

local function setup()
  Fk.currentResponsePattern = nil
  return support.initRoom()
end

local function teardown()
  Fk.currentResponsePattern = nil
  support.clearRoom()
end

Testhanjin_upstream_battle_royal = { setup = setup, tearDown = teardown }

local function room() return FkTest.room end
local function run(fn) FkTest.runInRoom(fn) end

function Testhanjin_upstream_battle_royal:testOrdinaryRoomKeepsUpstreamOldBattleRoyal()
  local player = room().players[1]
  run(function()
    room().settings._mode = room().settings._mode or {}
    room().settings._mode.old_battle_royal = true
    room().settings.old_battle_royal = true
    H.enterBattleRoyalMode(room())
  end)
  lu.assertTrue(room():getTag("BattleRoyalMode"))
  -- 普通国战房间仍保留上游普通鏖战技能。
  lu.assertTrue(player:hasSkill("battle_royal&", true, true))
  lu.assertFalse(player:hasSkill("new_battle_royal&", true, true))
  lu.assertFalse(player:hasSkill(O.SKILL, true, true))
  lu.assertEquals(player:getMark(O.SOURCE_MARK), 0)

  local handPeach = room():printCard("hanjin__peach", Card.Heart, 4)
  local deckPeach = room():printCard("hanjin__peach", Card.Heart, 5)
  run(function()
    room():obtainCard(player, handPeach, true)
    room():moveCardTo(deckPeach, Card.DrawPile, nil, fk.ReasonPut, nil, nil, true)
  end)
  -- 上游普通鏖战只限制手牌；“只能当”汉晋来源未进入普通房间。
  lu.assertTrue(player:prohibitUse(handPeach))
  lu.assertFalse(player:prohibitUse(deckPeach))
end

function Testhanjin_upstream_battle_royal:testOrdinaryRoomKeepsUpstreamNewBattleRoyalPeachWine()
  local player = room().players[1]
  run(function()
    room().settings._mode = room().settings._mode or {}
    room().settings._mode.old_battle_royal = false
    room().settings.old_battle_royal = false
    H.enterBattleRoyalMode(room())
  end)
  lu.assertTrue(player:hasSkill("new_battle_royal&", true, true))
  lu.assertFalse(player:hasSkill(O.SKILL, true, true))
  lu.assertEquals(player:getMark(O.SOURCE_MARK), 0)
  local peach = room():printCard("hanjin__peach", Card.Heart, 4)
  run(function() room():obtainCard(player, peach, true) end)
  local upstream = Fk.skills["new_battle_royal&"]
  local converted = upstream:viewAs(player, { peach.id })
  lu.assertNotNil(converted)
  lu.assertEquals(converted.trueName, "analeptic")
  lu.assertTrue(table.contains(room().logic.skills, "#new_battle_royal_event&"))
end

return { name = "hanjin_upstream_battle_royal" }
