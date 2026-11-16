-- Default national-war suite for the reusable skill fixtures in
-- tests/support/skill_test.lua.
local support = __dofile("../../../tests/support/hegemony.lua")
local skill = __dofile("../../../tests/support/skill_test.lua")

Testhanjin_test_support = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

Testhanjin_test_support.setup = function()
  support.initHanjinRoom()
end
Testhanjin_test_support.tearDown = support.clearRoom

function Testhanjin_test_support:testInstallDualGeneralsSetsMarksAndHp()
  local room = FkTest.room
  inRoom(function()
    local p = room.players[1]
    skill.installDualGenerals(room, p, {
      main = "hanjin_test__wei_1",
      deputy = "hanjin_test__wei_2",
      kingdom = "wei",
    })
    lu.assertEquals(p.general, "hanjin_test__wei_1")
    lu.assertEquals(p.deputyGeneral, "hanjin_test__wei_2")
    lu.assertEquals(p.kingdom, "wei")
    lu.assertEquals(p:getMark("__heg_general"), "hanjin_test__wei_1")
    lu.assertEquals(p:getMark("__heg_deputy"), "hanjin_test__wei_2")
    lu.assertEquals(p:getMark("__heg_kingdom"), "wei")
    lu.assertEquals(p:getMark("__heg_init_kingdom"), "wei")
    lu.assertEquals(p:getMark("__heg_wild"), 0)
    lu.assertEquals(p.maxHp, 4)
    lu.assertEquals(p.hp, p.maxHp)
  end)
end

function Testhanjin_test_support:testInstallDualGeneralsClearsOldSkillSources()
  local room = FkTest.room
  inRoom(function()
    local p = room.players[1]
    skill.installDualGenerals(room, p, {
      main = "hanjin__han004",
      deputy = "hanjin_test__han_2",
      kingdom = "han",
    })
    local oldSkills = Fk.generals["hanjin__han004"]:getSkillNameList(true)
    local installed = false
    for _, name in ipairs(oldSkills) do
      if p:hasSkill(name) then installed = true end
    end
    lu.assertTrue(installed, "fixture did not install the old main general's skills")

    skill.installDualGenerals(room, p, {
      main = "hanjin_test__han_1",
      deputy = "hanjin_test__han_2",
      kingdom = "han",
    })
    for _, name in ipairs(oldSkills) do
      lu.assertFalse(p:hasSkill(name), "old skill source survived: " .. name)
    end
  end)
end

function Testhanjin_test_support:testInstallBlankGeneralsClearsHiddenGeneralSource()
  local room = FkTest.room
  inRoom(function()
    local p = room.players[1]
    skill.installDualGenerals(room, p, {
      main = "hanjin__han001",
      deputy = "hanjin_test__han_2",
      kingdom = "han",
    })
    -- Real engine hide path: keep the old main general as the hidden source,
    -- turn the visible general into anjiang, and leave the fake skill plus the
    -- wild marker that the original fixture bug failed to clear.
    p:hideGeneral(false)
    p:prelightSkill(Fk.skills["hanjin__skill_han001_1"], true)
    room:setPlayerMark(p, "__heg_wild", 1)

    lu.assertEquals(p.general, "anjiang")
    lu.assertEquals(p:getMark("__heg_general"), "hanjin__han001")
    lu.assertEquals(p:getMark("__heg_wild"), 1)
    lu.assertTrue(p:isFakeSkill("hanjin__skill_han001_1"),
      "hidden general left no fake skill source to clean")

    skill.installBlankGenerals(room, "han")

    lu.assertEquals(p.general, "hanjin_test__han_1")
    lu.assertEquals(p.deputyGeneral, "hanjin_test__han_2")
    lu.assertFalse(p:isFakeSkill("hanjin__skill_han001_1"))
    lu.assertFalse(p:hasSkill("hanjin__skill_han001_1"))
    lu.assertEquals(p:getMark("__heg_general"), "hanjin_test__han_1")
    lu.assertEquals(p:getMark("__heg_wild"), 0)
    lu.assertEquals(p.maxHp, 4)
    lu.assertEquals(p.hp, 4)
  end)
end

function Testhanjin_test_support:testInstallDualGeneralsRequiresRoomContext()
  local room = FkTest.room
  local ok, err = pcall(function()
    skill.installDualGenerals(room, room.players[1], {
      main = "hanjin_test__han_1",
      deputy = "hanjin_test__han_2",
      kingdom = "han",
    })
  end)
  lu.assertFalse(ok)
  lu.assertStrContains(tostring(err), "FkTest.runInRoom")
end

function Testhanjin_test_support:testWithSkillRequestsDelegatesAndRestores()
  local room = FkTest.room
  local p = room.players[1]
  local originalChoice, originalDiscard = room.askToChoice, room.askToDiscard
  local delegated = {}
  room.askToChoice = function(self, player, params)
    delegated[#delegated + 1] = params.skill_name
    return "delegated:" .. tostring(params.skill_name)
  end
  local stub = room.askToChoice

  local ok, err = pcall(function()
    skill.withSkillRequests(room, "target_skill", {
      askToChoice = function(self, player, params)
        return "override:" .. params.skill_name
      end,
      askToDiscard = function(self, player, params)
        error("handler failure", 0)
      end,
    }, function()
      lu.assertEquals(room:askToChoice(p, { skill_name = "target_skill" }), "override:target_skill")
      lu.assertEquals(room:askToChoice(p, { skill_name = "AskForKingdom" }), "delegated:AskForKingdom")
      lu.assertEquals(#delegated, 1)
      room:askToDiscard(p, { skill_name = "target_skill" })
    end)
  end)

  local restoredChoice = room.askToChoice
  room.askToChoice = originalChoice
  lu.assertFalse(ok)
  lu.assertStrContains(tostring(err), "handler failure")
  lu.assertIs(restoredChoice, stub)
  lu.assertIs(room.askToDiscard, originalDiscard)
end

function Testhanjin_test_support:testWithSkillRequestsRestoresWhenBodyFails()
  local room = FkTest.room
  local originalChoice, originalDiscard = room.askToChoice, room.askToDiscard
  local ok, err = pcall(function()
    skill.withSkillRequests(room, "target_skill", {
      askToChoice = function() return nil end,
      askToDiscard = function() return nil end,
    }, function()
      error("body failure", 0)
    end)
  end)
  lu.assertFalse(ok)
  lu.assertStrContains(tostring(err), "body failure")
  lu.assertIs(room.askToChoice, originalChoice)
  lu.assertIs(room.askToDiscard, originalDiscard)
end

return { name = "hanjin_test_support" }
