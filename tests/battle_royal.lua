local support = __dofile("../../../tests/support/hegemony.lua")
__dofile("../../../tests/support/only_as_content.lua")
local O = require "packages.hanjin.pkg.hanjin_mode.rules.only_as"
local BattleRoyal = require "packages.hanjin.pkg.hanjin_mode.rules.battle_royal"
local H = require "packages.hegemony.util"
local Variants = require "packages.hanjin.pkg.hanjin_mode.rules.variants"

local function setup()
  Fk.currentResponsePattern = nil
  return support.initHanjinRoom()
end

local function teardown()
  Fk.currentResponsePattern = nil
  support.clearRoom()
end

Testhanjin_battle_royal = { setup = setup, tearDown = teardown }

local function room() return FkTest.room end
local function run(fn) FkTest.runInRoom(fn) end

local function give(player, name, suit, number)
  local card
  run(function()
    card = room():printCard(name, suit, number)
    room():obtainCard(player, card, true)
  end)
  return card
end

local function sourceDefs(player)
  local defs = {}
  local mark = player:getMark(O.SOURCE_MARK)
  if type(mark) == "table" then
    for _, rec in ipairs(mark) do defs[rec.def] = (defs[rec.def] or 0) + 1 end
  end
  return defs
end

local function hasUpstreamStatus()
  local upstream = false
  for _, list in pairs(room().status_skills or {}) do
    for _, skill in ipairs(list) do
      local skeleton = skill:getSkeleton()
      if skeleton and table.contains(BattleRoyal.UPSTREAM_SKILLS, skeleton.name) then
        upstream = true
      end
    end
  end
  return upstream
end

local function setMode(key, value)
  room().settings._mode = room().settings._mode or {}
  room().settings._mode[key] = value
  room().settings[key] = value
end

function Testhanjin_battle_royal:testUpstreamCallPathIsTakenOverAndIdempotent()
  local player = room().players[1]
  setMode("old_battle_royal", true)
  run(function()
    -- 模拟其它技能直接调用上游入口。汉晋开关关闭时 H 会选择普通鏖战。
    H.enterBattleRoyalMode(room())
  end)
  lu.assertTrue(room():getTag("BattleRoyalMode"))
  lu.assertEquals(room():getBanner("@[:]BattleRoyalDummy"), "BattleRoyalMode")
  lu.assertFalse(player:hasSkill("battle_royal&", true, true))
  lu.assertFalse(player:hasSkill("new_battle_royal&", true, true))
  lu.assertFalse(hasUpstreamStatus())
  lu.assertNotNil(Fk.skills["#hanjin_only_as_rule"])
  lu.assertNotNil(Fk.skills[O.SKILL])
  lu.assertTrue(table.contains(room().logic.skills, "#hanjin_only_as_rule"))
  lu.assertTrue(player:hasSkill(O.SKILL, true, true))
  lu.assertTrue(table.contains(player.player_skills, Fk.skills[O.SKILL]))
  lu.assertTrue(sourceDefs(player)["battle_royal"] == 1)
  lu.assertFalse(table.contains(room().logic.skills, BattleRoyal.EVENT_SKILL))

  -- 重复进入幂等：同一玩家不会重复登记来源，事件技能也不会重复。
  local before = sourceDefs(player)["battle_royal"]
  run(function() BattleRoyal.enter(room()) end)
  run(function() BattleRoyal.enter(room()) end)
  lu.assertEquals(sourceDefs(player)["battle_royal"], before)
end

function Testhanjin_battle_royal:testUpstreamCallPathWithWolvesOnKeepsEventsOnly()
  local player = room().players[1]
  setMode(Variants.key, true)
  run(function()
    Variants.apply(room())
    H.enterBattleRoyalMode(room())
  end)
  lu.assertTrue(table.contains(room().logic.skills, BattleRoyal.EVENT_SKILL))
  lu.assertFalse(player:hasSkill("new_battle_royal&", true, true))
  lu.assertFalse(player:hasSkill("battle_royal&", true, true))
  lu.assertEquals(sourceDefs(player)["battle_royal"], 1)
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  local targets = O.availableTargets(room(), player, peach.id, "use")
  lu.assertTrue(table.contains(targets, "hanjin__slash"))
  lu.assertTrue(table.contains(targets, "hanjin__jink"))
  lu.assertFalse(table.contains(targets, "hanjin__analeptic"))
end

function Testhanjin_battle_royal:testWolvesOnKeepsHistoricalEventsButUsesSlashJink()
  local player = room().players[1]
  setMode(Variants.key, true)
  run(function() BattleRoyal.enter(room()) end)
  lu.assertTrue(Variants.enabled(room()))
  lu.assertTrue(table.contains(room().logic.skills, BattleRoyal.EVENT_SKILL))
  lu.assertFalse(player:hasSkill("battle_royal&", true, true))
  lu.assertFalse(player:hasSkill("new_battle_royal&", true, true))
  local peach = give(player, "hanjin__peach", Card.Heart, 4)
  local targets = O.availableTargets(room(), player, peach.id, "use")
  lu.assertTrue(table.contains(targets, "hanjin__slash"))
  lu.assertTrue(table.contains(targets, "hanjin__jink"))
  lu.assertFalse(table.contains(targets, "hanjin__analeptic"))
  lu.assertTrue(O.isForbidden(player, peach))
end

function Testhanjin_battle_royal:testWolvesOffDoesNotAddHistoricalEvents()
  setMode(Variants.key, false)
  run(function() BattleRoyal.enter(room()) end)
  lu.assertFalse(Variants.enabled(room()))
  lu.assertFalse(table.contains(room().logic.skills, BattleRoyal.EVENT_SKILL))
end

function Testhanjin_battle_royal:testEntryConditionAndTriggerPriority()
  local players = room().players
  local savedAlive = room().alive_players
  lu.assertFalse(BattleRoyal.shouldEnter(room()))
  run(function()
    room().alive_players = { players[1], players[2], players[3], players[4] }
    local kingdoms = { "wei", "shu", "wu", "qun" }
    for i = 1, 4 do room():setPlayerProperty(players[i], "kingdom", kingdoms[i]) end
  end)
  lu.assertTrue(BattleRoyal.shouldEnter(room()))

  local foundPriority = false
  for _, skill in ipairs(room().logic.skill_table[fk.BeforeTurnStart] or {}) do
    if skill.name == "#hanjin_battle_royal_rule" and skill.priority == 10 then
      foundPriority = true
    end
  end
  lu.assertTrue(foundPriority)
  run(function()
    BattleRoyal.onTurnStart(room())
    room().alive_players = savedAlive
  end)
  lu.assertTrue(room():getTag("BattleRoyalMode"))
  lu.assertTrue(sourceDefs(players[1])["battle_royal"] == 1)
end

return { name = "hanjin_battle_royal" }
