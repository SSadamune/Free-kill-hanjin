-- 于吉：重复花色收牌、真实取消唯一目标及失技清理。
local support = __dofile("../../../tests/support/hegemony.lua")
local fixture = __dofile("../../../tests/support/skill_test.lua")
local SKILL, PILE = "qiao__skill_qun011_1", "qiao_yuji_sorcery"
local function inRoom(fn) FkTest.runInRoom(fn) end
Testqiao_yuji = {
  setup = function()
    local room = support.initQiaoRoom()
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
function Testqiao_yuji:testSameSuitAcceptedAndLossClearsPile()
  local room = FkTest.room
  local me, target = room.players[1], room.players[2]
  local cards = {}
  inRoom(function()
    for i=1,2 do
      local card=room:printCard("qiao__jink",Card.Heart,i)
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
function Testqiao_yuji:testCancelsRealSingleTargetSlash()
  local room=FkTest.room
  local me,target,enemy=room.players[1],room.players[2],room.players[5]
  local token,slash
  inRoom(function()
    token=room:printCard("qiao__jink",Card.Club,2).id
    room:obtainCard(me, token, false, fk.ReasonJustMove)
    slash=room:printCard("qiao__slash",Card.Spade,3)
    room:obtainCard(enemy,slash,false,fk.ReasonJustMove)
  end)
  fixture.withSkillRequests(room, SKILL, {
    askToCards = function() return { token } end,
  }, function()
    inRoom(function() room:damage { from = enemy, to = target, damage = 1 } end)
  end)
  lu.assertEquals(me:getPile(PILE), { token })
  local before=target.hp
  fixture.withSkillRequests(room,SKILL,{
    askToCards=function() return {token} end,
  },function()
    inRoom(function() room:useCard{from=enemy,tos={target},card=slash} end)
  end)
  lu.assertEquals(target.hp,before)
  lu.assertEquals(room:getCardArea(token),Card.DiscardPile)
end
local function makeTwoQianhuanSources()
  local room, owner, other = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  local general, grant = "qiao_heg__qun011", "qiao__skill_qun012_2"
  local printed, granted
  inRoom(function()
    room:handleAddLoseSkills(owner, "-" .. SKILL, nil, false, true)
    fixture.installDualGenerals(room, owner, { main = general, deputy = "qiao_test__qun_2", kingdom = "qun" })
    owner:addSkill(SKILL, grant)
    printed = room:printCard("qiao__peach", Card.Heart, 3).id
    granted = room:printCard("qiao__jink", Card.Club, 4).id
    room:obtainCard(owner, printed, false, fk.ReasonJustMove)
    room:obtainCard(owner, granted, false, fk.ReasonJustMove)
  end)
  local asked = 0
  fixture.withSkillRequests(room, SKILL, {
    askToChoice = function() return general end,
    askToCards = function()
      asked = asked + 1
      return { asked == 1 and printed or granted }
    end,
  }, function()
    inRoom(function() room:damage { from = room.players[5], to = other, damage = 1 } end)
  end)
  lu.assertEquals(asked, 2)
  lu.assertEquals(owner:getPile(PILE), { printed, granted })
  return room, owner, other, grant, printed, granted
end

function Testqiao_yuji:testExchangeMovesOnlyPrintedQianhuan()
  local room, owner, other, grant, printed, granted = makeTwoQianhuanSources()
  local exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  inRoom(function()
    assert(exchange.exchange(room, { player = owner, isDeputy = false }, { player = other, isDeputy = false }))
  end)
  lu.assertEquals(other:getPile(PILE), { printed })
  lu.assertEquals(owner:getPile(PILE), { granted })
  inRoom(function() room:handleAddLoseSkills(owner, "-" .. SKILL, grant) end)
  lu.assertEquals(room:getCardArea(granted), Card.DiscardPile)
  lu.assertEquals(other:getPile(PILE), { printed })
end

function Testqiao_yuji:testCardAndDirectQianhuanRemainIndependent()
  local room, owner, _, grant, printed, granted = makeTwoQianhuanSources()
  inRoom(function()
    room:invalidateSkill(owner, SKILL)
    lu.assertEquals(owner:getPile(PILE), { printed, granted })
    room:validateSkill(owner, SKILL)
    owner:hideGeneral(false)
    lu.assertEquals(owner:getPile(PILE), { printed, granted })
    owner:revealGeneral(false)
    local loss = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"
    assert(loss.loseCardSkill(room, owner, false, SKILL))
  end)
  lu.assertEquals(owner:getPile(PILE), { granted })
  lu.assertEquals(room:getCardArea(printed), Card.DiscardPile)
  inRoom(function() room:handleAddLoseSkills(owner, "-" .. SKILL, grant) end)
  lu.assertEquals(room:getCardArea(granted), Card.DiscardPile)
end

return {name="qiao_yuji"}
