-- QUN024 张任：正式登记、穿心分支及龙飞共享实例回归。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_qun2"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local L = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_longfei"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testqiao_qun024_zhangren = {
  setup = function()
    local room = support.initQiaoRoom()
    inRoom(function() skill_test.installBlankGenerals(room, {"han","han","han","han","qun","qun","qun","qun"}) end)
  end,
  tearDown = support.clearRoom,
}

function Testqiao_qun024_zhangren:testDataFragment()
  local general = DATA.generals[1]
  lu.assertEquals(general.id, "qiao_heg__qun024")
  lu.assertEquals(DATA.skillCount, 2)
  lu.assertNotNil(Fk.generals["qiao_heg__qun024"], "正式将池尚未合入 QUN024")
end

function Testqiao_qun024_zhangren:testLongfeiSharesOwnInstancesWithoutRecursion()
  local holder, mate = p(1), p(2)
  inRoom(function()
    FkTest.room:handleAddLoseSkills(holder, L.LONG_FEI, nil, false, true)
    local first = R.grant(holder, {
      general = "qiao_heg__retinue_xiyuanjun",
      skill = "qiao__retinue_skill_xiyuanjun",
      origin = "granted",
    })
    local second = R.grant(holder, {
      general = "qiao_heg__retinue_huweijun",
      skill = "qiao__retinue_skill_huweijun",
      origin = "granted",
    })
    lu.assertNotNil(first)
    lu.assertNotNil(second)
    L.ensureRule(FkTest.room)
    L.refresh(FkTest.room)
    lu.assertTrue(mate:hasSkill("qiao__retinue_skill_xiyuanjun"))
    lu.assertTrue(mate:hasSkill("qiao__retinue_skill_huweijun"))
    lu.assertEquals(R.count(mate), 2, "两份共享实例应各算一份")
    for _, instance in ipairs(R.instances(mate)) do
      lu.assertEquals(instance.origin, "shared")
    end
    -- 共享不会再次传播：mate 的队列不能获得 mate 的 shared。
    local third = p(3)
    for _, instance in ipairs(R.instances(third)) do
      lu.assertNotEquals(instance.shared_from, mate.id)
    end
  end)
end

function Testqiao_qun024_zhangren:testChuanxinSoldierMustUseOtherwise()
 local room=FkTest.room
 local me,victim=p(1),p(2)
 inRoom(function()
  room:handleAddLoseSkills(me,"qiao__skill_qun024_1",nil,false,true)
  room:changeHero(victim,"qiao_heg__retinue_xiyuanjun",false,true,false,false,false)
  room:setPlayerMark(victim,"__heg_deputy","qiao_heg__retinue_xiyuanjun")
 end)
 skill_test.withSkillRequests(room,"qiao__skill_qun024_1",{
  askToSkillInvoke=function() return true end,
  askToChoice=function(self,who,params) return params.choices[1] end,
 },function()
  inRoom(function() room:damage{from=me,to=victim,damage=1,card=Fk:cloneCard("qiao__slash")} end)
 end)
 lu.assertEquals(victim.hp,victim.maxHp-2)
 lu.assertEquals(victim.deputyGeneral,"qiao_heg__retinue_xiyuanjun")
 lu.assertEquals(R.count(me),1)
end
function Testqiao_qun024_zhangren:testHiddenDeputyChangesWithoutReveal()
 local room=FkTest.room
 local victim=p(2)
 inRoom(function()
  victim:hideGeneral(true)
  lu.assertEquals(victim.deputyGeneral,"anjiang")
  local Transform=require "packages.qiao.pkg.qiao_generals.util.zhen_shi_chuanxin"
  lu.assertTrue(Transform.replaceDeputy(room,victim,"qiao_heg__retinue_xiyuanjun","test"))
  lu.assertEquals(victim.deputyGeneral,"qiao_heg__retinue_xiyuanjun")
 end)
end

return { name = "qiao_qun024_zhangren" }
