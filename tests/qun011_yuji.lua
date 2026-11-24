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

function Testqiao_yuji:testRevokingParentDiscardsOnlyItsQianhuanCards()
  local room, owner, _, parent, printed, granted = makeTwoQianhuanSources()
  inRoom(function()
    room:handleAddLoseSkills(owner, parent, nil, false, true)
    room:handleAddLoseSkills(owner, "-" .. parent, nil, false, true)
  end)
  lu.assertEquals(owner:getPile(PILE), { printed })
  lu.assertEquals(room:getCardArea(granted), Card.DiscardPile)
  lu.assertTrue(owner:hasSkill(SKILL))
end

function Testqiao_yuji:testWithdrawingDirectGrantWhileYujiIsHidden()
  local room, owner, donor = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  local exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  local markers = require "packages.qiao.pkg.qiao_mode.rules.marker_cards"
  inRoom(function()
    fixture.installDualGenerals(room, donor, {
      main = "qiao_heg__qun011", deputy = "qiao_test__qun_2", kingdom = "qun",
    })
    assert(exchange.exchange(room, { player = owner, isDeputy = false }, { player = donor, isDeputy = false }))
    owner:hideGeneral(false)
  end)
  lu.assertNotNil(owner.derivative_skills[Fk.skills[markers.DIRECT]])
  inRoom(function() room:handleAddLoseSkills(owner, "-" .. SKILL, nil, false, true) end)
  lu.assertNil(owner.derivative_skills[Fk.skills[markers.DIRECT]])
  inRoom(function() owner:revealGeneral(false) end)
  lu.assertTrue(owner:hasSkill(SKILL))
end

local function checkIndependentGrants(prepare, removePrinted)
  local room, owner, ally = FkTest.room, FkTest.room.players[1], FkTest.room.players[3]
  local general = "qiao_heg__qun011"
  local ids = {}
  inRoom(function()
    prepare(room, owner, general)
    for value = 1, 3 do
      ids[value] = room:printCard("qiao__jink", Card.Heart, value).id
    end
    room:obtainCard(owner, ids, false, fk.ReasonJustMove)
  end)
  local asked = 0
  fixture.withSkillRequests(room, SKILL, {
    askToChoice = function() return general end,
    askToCards = function() asked = asked + 1; return { ids[asked] } end,
  }, function()
    inRoom(function() room:damage { from = room.players[5], to = ally, damage = 1 } end)
    lu.assertEquals(owner:getPile(PILE), { ids[1], ids[2] })
    inRoom(function() removePrinted(room, owner) end)
    lu.assertEquals(room:getCardArea(ids[1]), Card.DiscardPile)
    lu.assertEquals(owner:getPile(PILE), { ids[2] })
    inRoom(function() room:damage { from = room.players[5], to = ally, damage = 1 } end)
  end)
  lu.assertEquals(asked, 3)
  lu.assertEquals(owner:getPile(PILE), { ids[2], ids[3] })
  inRoom(function() room:handleAddLoseSkills(owner, "-" .. SKILL, nil, false, true) end)
  lu.assertFalse(owner:hasSkill(SKILL))
  lu.assertEquals(room:getCardArea(ids[2]), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(ids[3]), Card.DiscardPile)
end

local function receiveYuji(room, owner, general)
  local donor = room.players[2]
  local exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  fixture.installDualGenerals(room, donor, { main = general, deputy = "qiao_test__qun_2", kingdom = "qun" })
  assert(exchange.exchange(room, { player = owner, isDeputy = false }, { player = donor, isDeputy = false }))
end

local function removeYuji(room, owner)
  require("packages.hegemony.util").removeGeneral(owner, false)
  lu.assertNotEquals(owner.general, "qiao_heg__qun011")
end

function Testqiao_yuji:testUninvokedDirectGrantSurvivesReceivingAndLosingPrintedSkill()
  checkIndependentGrants(receiveYuji, function(room, owner)
    assert(require("packages.qiao.pkg.qiao_mode.rules.qun_duanchang").loseCardSkill(room, owner, false, SKILL))
  end)
end

function Testqiao_yuji:testRemovingYujiKeepsEarlierDirectGrant()
  checkIndependentGrants(receiveYuji, removeYuji)
end

local function showYujiFirst(room, owner, general)
  room:handleAddLoseSkills(owner, "-" .. SKILL, nil, false, true)
  fixture.installDualGenerals(room, owner, { main = general, deputy = "qiao_test__qun_2", kingdom = "qun" })
end

function Testqiao_yuji:testRoomGrantsQianhuanAfterShowingYuji()
  checkIndependentGrants(function(room, owner, general)
    showYujiFirst(room, owner, general)
    room:handleAddLoseSkills(owner, SKILL, nil, false, true)
  end, removeYuji)
end

function Testqiao_yuji:testPlayerGrantsQianhuanAfterShowingYuji()
  checkIndependentGrants(function(room, owner, general)
    showYujiFirst(room, owner, general)
    owner:addSkill(SKILL)
    owner:addSkill(SKILL)
  end, removeYuji)
end

return {name="qiao_yuji"}
