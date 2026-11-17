-- EM(QUN010) 张角君主版：数据、旗计数/大势力修正静态验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_lord_qun"
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testqiao_em_qun010_zhangjiao = {
  setup = function() support.initQiaoRoom() end,
  tearDown = support.clearRoom,
}

function Testqiao_em_qun010_zhangjiao:testDataFragment()
  local general = DATA.generals[1]
  lu.assertEquals(general.id, "qiao_heg__em_qun010")
  lu.assertEquals(DATA.skillCount, 3)
  lu.assertNotNil(Fk.generals["qiao_heg__em_qun010"], "正式将池尚未合入 EM(QUN010)")
  lu.assertEquals(DATA.versions[1].normal, "qiao_heg__qun010")
  lu.assertEquals(Fk:translate("qiao_em_qun010_tianbing"), "天兵", "天兵旗状态栏实际显示键应本地化")
end

function Testqiao_em_qun010_zhangjiao:testTianbingCountAndLargePowerOverlay()
  local lord = p(1)
  inRoom(function()
    local ids = FkTest.room:getNCards(3)
    P.add(lord, ids, P.BANNER_SKILL)
    lu.assertEquals(P.count(lord), 3)
    local qun = P.kingdomCount(FkTest.room, "qun")
    lu.assertTrue(qun >= 3)
    lu.assertTrue(P.largeCount(FkTest.room) >= qun)
  end)
end

function Testqiao_em_qun010_zhangjiao:testWendaoDoesNotSearchHand()
  local me = p(1)
  local skill = assert(Fk.skills["qiao__skill_em_qun010_3"])
  inRoom(function()
    FkTest.room:handleAddLoseSkills(me, skill.name, nil, false, true)
    local red = FkTest.room:printCard("qiao__jink", Card.Heart, 2)
    local peace = FkTest.room:printCard("qiao__peace_spell", Card.Heart, 3)
    FkTest.room:obtainCard(me, red, false, fk.ReasonJustMove)
    FkTest.room:obtainCard(me, peace, false, fk.ReasonJustMove)
    me.phase = Player.Play
    lu.assertFalse(skill:canUse(me), "手牌中的太平要术不是合法问道对象")
    FkTest.room:moveCardTo(peace, Card.DiscardPile, nil, fk.ReasonJustMove,
      "test", nil, true, me)
    lu.assertTrue(skill:canUse(me), "弃牌堆中的太平要术是合法问道对象")
  end)
end

function Testqiao_em_qun010_zhangjiao:testWuxinRealPileChangesAndBigKingdomTies()
 local room=FkTest.room
 local fixture=__dofile("../../../tests/support/skill_test.lua")
 local owner=p(1)
 inRoom(function()
  fixture.installBlankGenerals(room,{"qun","qun","qun","wei","wei","wei","shu","shu"})
  room:handleAddLoseSkills(owner,"qiao__skill_em_qun010_2",nil,false,true)
 end)
 local seen,ids={},nil
 fixture.withSkillRequests(room,"qiao__skill_em_qun010_2",{
  askToSkillInvoke=function() return true end,
  askToGuanxing=function(self,who,params)
   table.insert(seen,#params.cards)
   return {top=params.cards,bottom={}}
  end,
 },function()
  inRoom(function()
   ids=room:getNCards(2)
   P.add(owner,ids)
   P.remove(owner,{ids[1]})
   P.remove(owner,{ids[2]})
  end)
 end)
 lu.assertEquals(seen,{5,6},"增加和减至0各卜算，减少未归0不触发；并列大势力人数累计")
 lu.assertEquals(P.physicalCounts(room).qun,3)
end

return { name = "qiao_em_qun010_zhangjiao" }
