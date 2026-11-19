-- 象兵/周仓的同名多实例登记与直接来源 fallback 静态验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testqiao_retinue_multi_instance_card_finish = {
  setup = function()
    local room = support.initQiaoRoom()
    inRoom(function() skill_test.installBlankGenerals(room, "han") end)
  end,
  tearDown = support.clearRoom,
}

function Testqiao_retinue_multi_instance_card_finish:testXiangbingAndZhoucangCounts()
  local me, donor = p(1), p(2)
  inRoom(function()
    R.grant(me, {
      general = "qiao_heg__retinue_xiangbing",
      skill = "qiao__retinue_skill_xiangbing",
      origin = "shared", shared_from = donor.id,
    })
    R.grant(me, {
      general = "qiao_heg__retinue_xiangbing",
      skill = "qiao__retinue_skill_xiangbing",
      origin = "shared", shared_from = donor.id,
    })
    R.grant(me, {
      general = "qiao_heg__retinue_zhoucang",
      skill = "qiao__retinue_skill_zhoucang",
      origin = "shared", shared_from = donor.id,
    })
    lu.assertEquals(R.countForSkill(me, "qiao__retinue_skill_xiangbing"), 2)
    lu.assertEquals(R.countForSkill(me, "qiao__retinue_skill_zhoucang"), 1)
    lu.assertTrue(me:hasSkill("qiao__retinue_skill_xiangbing"))
    lu.assertTrue(me:hasSkill("qiao__retinue_skill_zhoucang"))
  end)
end

function Testqiao_retinue_multi_instance_card_finish:testDirectSkillWithoutInstanceRemainsOne()
  local me = p(3)
  inRoom(function()
    FkTest.room:handleAddLoseSkills(me, "qiao__retinue_skill_xiangbing", nil, false, true)
    lu.assertEquals(R.countForSkill(me, "qiao__retinue_skill_xiangbing"), 0)
    lu.assertTrue(me:hasSkill("qiao__retinue_skill_xiangbing"),
      "直接来源仍应保留原始触发一次")
  end)
end

return { name = "qiao_retinue_multi_instance_card_finish" }
