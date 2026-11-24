-- JIN017 王浑：数据片段、遄征移除副将并获得献捷。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_jin2"
local ZONGRONG = "qiao__skill_jin017_1"
local XIANJIE = "qiao__skill_jin017_3"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testqiao_jin017_wanghun = {
  setup = function()
    local room = support.initQiaoRoom()
    inRoom(function() skill_test.installBlankGenerals(room, "han") end)
  end,
  tearDown = support.clearRoom,
}

function Testqiao_jin017_wanghun:testDataFragment()
  local general = table.find(DATA.generals, function(g) return g.id == "qiao_heg__jin017" end)
  lu.assertNotNil(general)
  lu.assertNotNil(Fk.generals["qiao_heg__jin017"], "正式将池尚未合入 JIN017")
  lu.assertEquals(general.skills[2].tags[1], "Limited")
end

function Testqiao_jin017_wanghun:testChuanzhengGrantsXianjie()
  local me = p(1)
  inRoom(function()
    FkTest.room:handleAddLoseSkills(me, "qiao__skill_jin017_2", nil, false, true)
    me.phase = Player.Play
    Fk.skills["qiao__skill_jin017_2"]:onUse(FkTest.room, { from = me })
    lu.assertTrue(me:hasSkill(XIANJIE), "移除副将后获得永久献捷")
  end)
end

function Testqiao_jin017_wanghun:testXianjieChecksHanjinDamageCardCategory()
  local room, me = FkTest.room, p(1)
  local skill = Fk.skills[XIANJIE]
  inRoom(function()
    room:handleAddLoseSkills(me, XIANJIE, nil, false, true)
    local hand = me:getCardIds("he")
    if #hand > 0 then room:moveCardTo(hand, Card.DiscardPile, nil, fk.ReasonJustMove) end
    for _, name in ipairs({ "qiao__slash", "qiao__fire__slash", "qiao__duel" }) do
      local damage = room:printCard(name, Card.Spade, 2)
      room:obtainCard(me, damage, false, fk.ReasonJustMove)
      lu.assertFalse(skill:cardFilter(me, damage.id, {}))
      lu.assertNil(skill:viewAs(me, { damage.id }))
    end
    lu.assertFalse(skill:enabledAtPlay(me))
    for _, name in ipairs({ "qiao__lightning", "qiao__qinggang_sword" }) do
      local material = room:printCard(name, Card.Spade, 3)
      room:obtainCard(me, material, false, fk.ReasonJustMove)
      lu.assertTrue(skill:cardFilter(me, material.id, {}))
      local converted = skill:viewAs(me, { material.id })
      lu.assertEquals(converted.name, "qiao__iron_chain")
      lu.assertEquals(Card:getIdList(converted), { material.id })
    end
    lu.assertTrue(skill:enabledAtPlay(me))
  end)
end

function Testqiao_jin017_wanghun:testZongrongOnlyRelaxesTheHoldersLimitsAgainstChainedTargets()
  local room, holder, other, distant = FkTest.room, p(1), p(2), p(4)
  local ids = {}
  inRoom(function()
    room:handleAddLoseSkills(holder, ZONGRONG, nil, false, true)
    holder.phase = Player.Play
    other.phase = Player.Play
    distant:setChainState(true)
    for i, name in ipairs({ "qiao__slash", "qiao__fire__slash", "qiao__ice__slash" }) do
      local card = room:printCard(name, Card.Spade, i)
      room:obtainCard(holder, card, true, fk.ReasonJustMove)
      ids[#ids + 1] = card.id
    end
    for _, id in ipairs(ids) do
      local card = Fk:getCardById(id)
      lu.assertFalse(card.skill:withinDistanceLimit(other, true, card, distant))
      lu.assertTrue(card.skill:withinDistanceLimit(holder, true, card, distant))
      holder:addCardUseHistory("slash", 1)
      lu.assertTrue(card.skill:withinTimesLimit(holder, Player.HistoryPhase, card, nil, distant))
      lu.assertFalse(card.skill:withinTimesLimit(holder, Player.HistoryPhase, card, nil, other))
    end
  end)
  client_room.run(room, function(clients)
    local req = require("ltk.core.request_type.play_card"):new(clients[1])
    for _, id in ipairs(ids) do
      req.selected_card = Fk:getCardById(id)
      lu.assertTrue(req:cardValidity(id))
      lu.assertTrue(req:targetValidity(clients[4].id))
      lu.assertFalse(req:targetValidity(clients[2].id))
    end
  end)
  inRoom(function()
    room:setPlayerMark(holder, MarkEnum.InvalidSkills, { [ZONGRONG] = true })
    local card = Fk:getCardById(ids[1])
    lu.assertFalse(card.skill:withinDistanceLimit(holder, true, card, distant))
    lu.assertFalse(card.skill:withinTimesLimit(holder, Player.HistoryPhase, card, nil, distant))
  end)
end

return { name = "qiao_jin017_wanghun" }
