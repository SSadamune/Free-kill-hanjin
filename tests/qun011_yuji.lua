-- 于吉：重复花色收牌、真实取消唯一目标及失技清理。
local support = __dofile("../../../tests/support/hegemony.lua")
local fixture = __dofile("../../../tests/support/skill_test.lua")
local SKILL, PILE = "hanjin__skill_qun011_1", "hanjin_yuji_sorcery"
local function inRoom(fn) FkTest.runInRoom(fn) end
Testhanjin_yuji = {
  setup = function()
    local room = support.initHanjinRoom()
    inRoom(function()
      fixture.installBlankGenerals(room, {"qun","qun","qun","qun","wei","wei","wei","wei"})
      room:handleAddLoseSkills(room.players[1], SKILL, nil, false, true)
      for _, p in ipairs(room.players) do
        local ids = p:getCardIds("he")
        if #ids > 0 then room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false) end
      end
    end)
  end,
  tearDown = support.clearRoom,
}
function Testhanjin_yuji:testSameSuitAcceptedAndLossClearsPile()
  local room = FkTest.room
  local me, target = room.players[1], room.players[2]
  local cards = {}
  inRoom(function()
    for i=1,2 do
      local card=room:printCard("hanjin__jink",Card.Heart,i)
      room:obtainCard(me,card,false,fk.ReasonJustMove)
      table.insert(cards,card.id)
    end
  end)
  local n=0
  fixture.withSkillRequests(room, SKILL, {
    askToCards=function() n=n+1; return {cards[n]} end,
  },function()
    inRoom(function()
      room:damage{from=room.players[5],to=target,damage=1}
      room:damage{from=room.players[5],to=target,damage=1}
    end)
  end)
  lu.assertEquals(n,2)
  lu.assertEquals(#me:getPile(PILE),2)
  inRoom(function() room:handleAddLoseSkills(me,"-"..SKILL,nil,false,true) end)
  lu.assertEquals(#me:getPile(PILE),0)
  for _,id in ipairs(cards) do lu.assertEquals(room:getCardArea(id),Card.DiscardPile) end
end
function Testhanjin_yuji:testCancelsRealSingleTargetSlash()
  local room=FkTest.room
  local me,target,enemy=room.players[1],room.players[2],room.players[5]
  local token,slash
  inRoom(function()
    token=room:printCard("hanjin__jink",Card.Club,2).id
    me:addToPile(PILE,{token},true,SKILL)
    slash=room:printCard("hanjin__slash",Card.Spade,3)
    room:obtainCard(enemy,slash,false,fk.ReasonJustMove)
  end)
  local before=target.hp
  fixture.withSkillRequests(room,SKILL,{
    askToCards=function() return {token} end,
  },function()
    inRoom(function() room:useCard{from=enemy,tos={target},card=slash} end)
  end)
  lu.assertEquals(target.hp,before)
  lu.assertEquals(room:getCardArea(token),Card.DiscardPile)
end
return {name="hanjin_yuji"}
