-- 西凉精骑/腹心死士/黄巾雷使：同名多实例授技与直接来源登记回归。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local R = require "packages.hanjin.pkg.hanjin_generals.util.retinue_instances"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testhanjin_retinue_multi_instance_remaining = {
  setup = function()
    local room = support.initHanjinRoom()
    inRoom(function() skill_test.installBlankGenerals(room, "han") end)
  end,
  tearDown = support.clearRoom,
}

function Testhanjin_retinue_multi_instance_remaining:testThreeSkillsHaveIndependentInstances()
  local me, donor = p(1), p(2)
  inRoom(function()
    for _, spec in ipairs({
      { "hanjin__retinue_xiliang_jingqi", "hanjin__retinue_skill_xiliang_jingqi" },
      { "hanjin__retinue_fuxin_sishi", "hanjin__retinue_skill_fuxin_sishi" },
      { "hanjin__retinue_huangjin_leishi", "hanjin__retinue_skill_huangjin_leishi" },
    }) do
      R.grant(me, { general = spec[1], skill = spec[2], origin = "shared", shared_from = donor.id })
      R.grant(me, { general = spec[1], skill = spec[2], origin = "shared", shared_from = donor.id })
      lu.assertEquals(R.countForSkill(me, spec[2]), 2)
      lu.assertTrue(me:hasSkill(spec[2]))
    end
  end)
end

function Testhanjin_retinue_multi_instance_remaining:testDirectSkillWithoutInstanceHasOneFallback()
  local me = p(3)
  inRoom(function()
    FkTest.room:handleAddLoseSkills(me, "hanjin__retinue_skill_huangjin_leishi", nil, false, true)
    lu.assertEquals(R.countForSkill(me, "hanjin__retinue_skill_huangjin_leishi"), 0)
    lu.assertTrue(me:hasSkill("hanjin__retinue_skill_huangjin_leishi"))
  end)
end

return { name = "hanjin_retinue_multi_instance_remaining" }
