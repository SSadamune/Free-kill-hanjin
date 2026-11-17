local support=__dofile("../../../tests/support/hegemony.lua")
local fixture=__dofile("../../../tests/support/skill_test.lua")
local SKILL="qiao__skill_wei023_1"
local function inRoom(fn) FkTest.runInRoom(fn) end
Testqiao_zangba={
 setup=function()
  local room=support.initQiaoRoom()
  inRoom(function()
   fixture.installBlankGenerals(room,{"wei","wei","wei","wei","qun","qun","qun","qun"})
   room:handleAddLoseSkills(room.players[1],SKILL,nil,false,true)
   room.current=room.players[5]
   for _,p in ipairs(room.players) do
    local ids=p:getCardIds("he")
    if #ids>0 then room:moveCardTo(ids,Card.DiscardPile,nil,fk.ReasonJustMove,"test",nil,false) end
   end
  end)
 end,
 tearDown=support.clearRoom,
}
function Testqiao_zangba:testEachDamagePointAndFollowupSurvivesLoss()
 local room=FkTest.room
 local me,current=room.players[1],room.players[5]
 local asks=0
 fixture.withSkillRequests(room,SKILL,{
  askToSkillInvoke=function() asks=asks+1;return true end,
 },function()
  inRoom(function() room:damage{from=current,to=me,damage=2} end)
 end)
 lu.assertEquals(asks,2)
 lu.assertEquals(current:getMark("qiao_hengjiang_penalty-turn"),2)
 lu.assertEquals(#current:getTableMark("qiao_hengjiang_follow-turn"),2)
 inRoom(function()
  room:handleAddLoseSkills(me,"-"..SKILL,nil,false,true)
  current.phase=Player.Discard
  room.logic:trigger(fk.EventPhaseEnd,current,PhaseData:new{who=current,phase=Player.Discard})
 end)
 lu.assertEquals(#me:getCardIds("h"),me.maxHp)
end
return {name="qiao_zangba"}
