-- Copy this file to tests/<general>_<skill>.lua, then:
--   1. rename Testhanjin_skill_template (including its setup/tearDown
--      assignments) to a unique test class name;
--   2. rename the returned descriptor `name = "hanjin_skill_template"` too;
--   3. add the basename to the default national-war suite list in tests/all.lua.
-- Reusing either name lets a later file overwrite this suite silently.
-- The template itself is not loaded by all.lua and intentionally contains no
-- placeholder tests that could pass without exercising the skill.
local support = __dofile("../../../tests/support/hegemony.lua")
local skill = __dofile("../../../tests/support/skill_test.lua")

-- TODO: replace with the generals and skill under test.
local MAIN = "hanjin__han001"
local DEPUTY = "hanjin_test__han_2"
local SKILL = "hanjin__skill_han001_1"

Testhanjin_skill_template = {}
Testhanjin_skill_template.tearDown = support.clearRoom

Testhanjin_skill_template.setup = function()
  -- Explicit HanJin room with real request replies.
  local room = support.initHanjinRoom()
  FkTest.runInRoom(function()
    -- Deterministic seats: clear the random opening pair first, then install
    -- the known main/deputy used by this example.
    skill.installBlankGenerals(room, "han")
    skill.installDualGenerals(room, room.players[1], {
      main = MAIN,
      deputy = DEPUTY,
      kingdom = "han",
    })
  end)
end

-- TODO: exercise the real skill flow, not only installation. Trigger SKILL
-- through its actual request/reply entry and assert an observable result such
-- as card movement, hp/maxHp, marks, used times or event data. Prefer the
-- official FkTest reply queue so the real request handlers consume replies:
--
-- function Testhanjin_skill_template:testMainFlow()
--   local room, p = FkTest.room, FkTest.room.players[1]
--   FkTest.setNextReplies(p, { "1" })
--   FkTest.runInRoom(function()
--     -- ... trigger the real skill flow ...
--   end)
--   lu.assertEquals(...)
-- end
--
-- Use withSkillRequests only for special inputs the queue cannot express,
-- such as a forced choice or card selection; wrap only the affected requests:
--   skill.withSkillRequests(room, SKILL, {
--     askToChoice = function(self, player, params) return "#..." end,
--   }, function()
--     FkTest.runInRoom(function() ... end)
--   end)

return { name = "hanjin_skill_template" }
