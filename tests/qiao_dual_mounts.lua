-- 六龙骖驾 / 临筱玉舆 双副类别坐骑：占双栏、替换、距离与进出触发。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local SIX = "qiao__liulongcanjia"
local LIN = "qiao__linxiao_yuyu"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testqiao_dual_mounts = {
  setup = function()
    local room = support.initQiaoRoom()
    inRoom(function()
      skill_test.installBlankGenerals(room, { "wei", "jin", "wu", "shu", "qun", "han", "jin", "wei" })
      room.current = room.players[1]
    end)
  end,
  tearDown = support.clearRoom,
}

local function give(player, name, suit, number)
  local card
  inRoom(function()
    card = FkTest.room:printCard(name, suit or Card.Heart, number or 5)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
  end)
  return card
end

function Testqiao_dual_mounts:testSixDragonsReplacesBothMountsAndDistance()
  local room, user, other = FkTest.room, p(1), p(2)
  local offensive, defensive, six
  local beforeForward, beforeBack
  inRoom(function()
    offensive = room:printCard("qiao__chitu", Card.Heart, 5)
    defensive = room:printCard("qiao__jueying", Card.Spade, 5)
    room:moveCardIntoEquip(user, offensive, "test", true, user)
    room:moveCardIntoEquip(user, defensive, "test", true, user)
    six = room:printCard(SIX, Card.Heart, 13)
    room:obtainCard(user, six, false, fk.ReasonJustMove)
    room.current = user
    beforeForward = user:distanceTo(other)
    beforeBack = other:distanceTo(user)
    room:useCard { from = user, tos = { user }, card = Fk:getCardById(six.id) }
  end)
  lu.assertEquals(room:getCardArea(six.id), Card.PlayerEquip)
  lu.assertEquals(room:getCardArea(offensive.id), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(defensive.id), Card.DiscardPile)
  lu.assertEquals(user:distanceTo(other), math.max(1, beforeForward - 1), "持有者到其他角色距离-1")
  lu.assertEquals(other:distanceTo(user), beforeBack + 1, "其他角色到持有者距离+1")
  local extra
  inRoom(function()
    extra = room:printCard("qiao__chitu", Card.Diamond, 9)
    room:obtainCard(user, extra, false, fk.ReasonJustMove)
    room:moveCardTo(extra, Card.PlayerEquip, user, fk.ReasonPutIntoDiscardPile, "test", nil, true, user)
  end)
  lu.assertEquals(room:getCardArea(extra.id), Card.PlayerHand, "持有双坐骑时其他坐骑不能置入")
  lu.assertEquals(room:getCardArea(six.id), Card.PlayerEquip, "六龙骖驾应仍在装备区")
end

function Testqiao_dual_mounts:testLinxiaoEnterReplacesAndRecoversThenLeaveDraws()
  local room, user, current = FkTest.room, p(1), p(2)
  local offensive, defensive, lin
  local hpBefore, handBefore
  inRoom(function()
    offensive = room:printCard("qiao__chitu", Card.Heart, 6)
    defensive = room:printCard("qiao__jueying", Card.Spade, 6)
    room:moveCardIntoEquip(user, offensive, "test", true, user)
    room:moveCardIntoEquip(user, defensive, "test", true, user)
    user.hp = user.maxHp - 1
    lin = room:printCard(LIN, Card.Spade, 5)
    room:obtainCard(user, lin, false, fk.ReasonJustMove)
    room.current = user
    hpBefore = user.hp
    room:useCard { from = user, tos = { user }, card = Fk:getCardById(lin.id) }
  end)
  lu.assertEquals(room:getCardArea(lin.id), Card.PlayerEquip)
  lu.assertEquals(room:getCardArea(offensive.id), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(defensive.id), Card.DiscardPile)
  lu.assertEquals(user.hp, hpBefore + 1, "本次确有坐骑被替换时改为回复1")
  inRoom(function()
    room.current = current
    handBefore = #current:getCardIds("h")
    room:moveCardTo(lin.id, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile, "test", nil, true, user)
  end)
  lu.assertEquals(#current:getCardIds("h"), handBefore + 1, "从装备区置入非装备区后当前回合角色摸1")
end

function Testqiao_dual_mounts:testLinxiaoOnlyOffensiveReplacedFullHpNoDraw()
  local room, user = FkTest.room, p(1)
  local offensive, lin, handBefore
  inRoom(function()
    offensive = room:printCard("qiao__chitu", Card.Heart, 7)
    room:moveCardIntoEquip(user, offensive, "test", true, user)
    lin = room:printCard(LIN, Card.Spade, 5)
    room:obtainCard(user, lin, false, fk.ReasonJustMove)
    user.hp = user.maxHp
    room.current = user
    handBefore = #user:getCardIds("h")
    room:useCard { from = user, tos = { user }, card = Fk:getCardById(lin.id) }
  end)
  lu.assertEquals(room:getCardArea(lin.id), Card.PlayerEquip)
  lu.assertEquals(room:getCardArea(offensive.id), Card.DiscardPile, "仅进攻马也应被清掉")
  lu.assertEquals(user.hp, user.maxHp, "满血替换仍走回复，不改为摸牌")
  lu.assertEquals(#user:getCardIds("h"), handBefore - 1, "满血替换不得改为摸1")
end

return { name = "qiao_dual_mounts" }
