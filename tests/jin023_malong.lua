-- JIN023 马隆：数据片段、锋械/锥形注册与总戎目标组静态入口。
-- 真实装备交换、杀响应与围攻伤害验证。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_jin2"
local EquipmentExchange = require "packages.qiao.pkg.qiao_mode.rules.equipment_exchange"


local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testqiao_jin023_malong = {
  setup = function()
    Fk.currentResponsePattern = nil
    local room = support.initQiaoRoom()
    inRoom(function() skill_test.installBlankGenerals(room, {"han","han","han","han","qun","qun","qun","qun"}) end)
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_jin023_malong:testDataFragment()
  local general = table.find(DATA.generals, function(g) return g.id == "qiao_heg__jin023" end)
  lu.assertNotNil(general)
  lu.assertNotNil(Fk.generals["qiao_heg__jin023"], "正式将池尚未合入 JIN023")
  lu.assertEquals(DATA.commanderCount, 0)
  lu.assertEquals(DATA.skillCount, 4)
  lu.assertEquals(general.skills[2].tags[1], "Compulsory")
end

function Testqiao_jin023_malong:testSkillsRegistered()
  lu.assertNotNil(Fk.skills["qiao__skill_jin023_1"])
  lu.assertNotNil(Fk.skills["qiao__skill_jin023_2"])
end

function Testqiao_jin023_malong:testSharedEquipmentSwapLetsThirdPlayerChooseBothCards()
  local room, chooser, a, b = FkTest.room, p(1), p(2), p(3)
  local reason = "qiao_test_equipment_exchange"
  inRoom(function()
    local mount = room:printCard("qiao__liulongcanjia", Card.Heart, 13).id
    local sword = room:printCard("qiao__qinggang_sword", Card.Spade, 2).id
    local treasure = room:printCard("qiao__bronze_sparrow", Card.Club, 3).id
    local armor = room:printCard("qiao__eight_diagram", Card.Club, 2).id
    room:moveCardIntoEquip(a, mount, reason, false, a)
    room:moveCardIntoEquip(a, sword, reason, false, a)
    room:moveCardIntoEquip(b, treasure, reason, false, b)
    room:moveCardIntoEquip(b, armor, reason, false, b)

    lu.assertTrue(EquipmentExchange.canSwapOneEach(chooser, a, b))
    local asked = {}
    skill_test.withSkillRequests(room, reason, {
      askToChooseCard = function(_, player, params)
        lu.assertIs(player, chooser)
        table.insert(asked, params.target.id)
        local candidates = params.flag.card_data[1][2]
        if params.target == a then
          lu.assertItemsEquals(candidates, { mount, sword })
          return mount
        end
        lu.assertItemsEquals(candidates, { treasure, armor })
        return treasure
      end,
    }, function()
      lu.assertTrue(EquipmentExchange.swapOneEach(room, chooser, a, b, reason))
    end)

    lu.assertEquals(asked, { a.id, b.id })
    lu.assertItemsEquals(a:getCardIds("e"), { sword, treasure })
    lu.assertItemsEquals(b:getCardIds("e"), { armor, mount })
  end)
end

function Testqiao_jin023_malong:testFengxieSwapsAcrossOpenSlotsThenUsesSlash()
  local me, target = p(1), p(2)
  local mine, theirs, targetJink
  inRoom(function()
    FkTest.room:handleAddLoseSkills(me, "qiao__skill_jin023_1", nil, false, true)
    skill_test.installDualGenerals(FkTest.room, target, {
      main = "qiao_test__qun_1", deputy = "qiao_test__qun_2", kingdom = "qun",
    })
    local a = FkTest.room:printCard("qinggang_sword", Card.Spade, 2)
    local b = FkTest.room:printCard("qiao__eight_diagram", Card.Club, 2)
    local jink = FkTest.room:printCard("qiao__jink", Card.Heart, 2)
    FkTest.room:obtainCard(target, jink, false, fk.ReasonJustMove)
    FkTest.room:moveCardTo(a, Card.PlayerEquip, me, fk.ReasonPut, "test", nil, false)
    FkTest.room:moveCardTo(b, Card.PlayerEquip, target, fk.ReasonPut, "test", nil, false)
    mine, theirs = a.id, b.id
    targetJink = jink.id
    me.phase = Player.Play
  end)
  local before = target.hp
  FkTest.setNextReplies(me, { { targets = { target.id } } })
  FkTest.setNextReplies(target, { { card = targetJink } })
  inRoom(function()
    Fk.skills["qiao__skill_jin023_1"]:onUse(FkTest.room, {
      from = me, tos = { me, target },
    })
  end)
  lu.assertEquals(FkTest.room:getCardArea(mine), Card.PlayerEquip)
  lu.assertEquals(FkTest.room:getCardArea(theirs), Card.PlayerEquip)
  lu.assertIs(FkTest.room:getCardOwner(mine), target)
  lu.assertIs(FkTest.room:getCardOwner(theirs), me)
  lu.assertEquals(me:usedCardTimes("slash", Player.HistoryPhase), 0)
  lu.assertEquals(me:getCardIds("e"), { theirs })
  lu.assertEquals(target:getCardIds("e"), { mine })
  lu.assertEquals(FkTest.room:getCardArea(targetJink), Card.DiscardPile,
    "目标用【闪】响应，证明虚拟杀真实进入使用/响应流程")
end

function Testqiao_jin023_malong:testFengxieFitsOccupiedSlotsAndExcludesUserFromQueue()
  local room, me, other, third = FkTest.room, p(1), p(2), p(3)
  local name = "qiao__skill_jin023_1"
  local sword, otherSword, armor
  local chooseCalls, queued = 0, false
  inRoom(function()
    room.current = me
    me.phase = Player.Play
    room:handleAddLoseSkills(me, name, nil, false, true)
    sword = room:printCard("qiao__qinggang_sword", Card.Spade, 2)
    otherSword = room:printCard("qiao__axe", Card.Spade, 3)
    armor = room:printCard("qiao__eight_diagram", Card.Club, 2)
    room:moveCardIntoEquip(me, sword.id, name, false, me)
    room:moveCardIntoEquip(me, armor.id, name, false, me)
    room:moveCardIntoEquip(other, otherSword.id, name, false, me)
    local formation = require("packages.hegemony.util").getFormationRelation(other)
    lu.assertTrue(table.contains(formation, me) and table.contains(formation, third))
    for _, target in ipairs({ other, third }) do
      local hand = target:getCardIds("h")
      if #hand > 0 then room:moveCardTo(hand, Card.DiscardPile, nil, fk.ReasonJustMove) end
      FkTest.setNextReplies(target, { "" })
    end
  end)
  local meHp, otherHp, thirdHp = me.hp, other.hp, third.hp
  skill_test.withSkillRequests(room, name, {
    askToChooseCard = function()
      chooseCalls = chooseCalls + 1
      return armor.id
    end,
    askToChoice = function()
      queued = true
      return "queue"
    end,
  }, function()
    inRoom(function()
      Fk.skills[name]:onUse(room, { from = me, tos = { me, other } })
    end)
  end)
  lu.assertEquals(chooseCalls, 0, "同栏武器是唯一合法组合，防具无需询问")
  lu.assertTrue(queued)
  lu.assertIs(room:getCardOwner(sword.id), other)
  lu.assertIs(room:getCardOwner(otherSword.id), me)
  lu.assertIs(room:getCardOwner(armor.id), me)
  lu.assertEquals(room:getCardArea(armor.id), Card.PlayerEquip)
  lu.assertEquals(me.hp, meHp)
  lu.assertTrue(other.hp < otherHp)
  lu.assertTrue(third.hp < thirdHp)
end

function Testqiao_jin023_malong:testZhuixingAttackAndDefenseInSiege()
  local room=FkTest.room
  inRoom(function()
    skill_test.installBlankGenerals(room,{"wu","wei","wu","wei","wei","wei","wei","wei"})
    local holder,victim=room.players[1],room.players[2]
    local H=require "packages.hegemony.util"
    lu.assertTrue(H.inSiegeRelation(holder,holder,victim))
    room:handleAddLoseSkills(holder,"qiao__skill_jin023_2",nil,false,true)
    local hp=holder.hp
    room:damage{from=victim,to=holder,damage=2,card=Fk:cloneCard("qiao__slash")}
    lu.assertEquals(holder.hp,hp-1,"围攻者受到被围攻者杀伤害-1")
    room:handleAddLoseSkills(holder,"-qiao__skill_jin023_2",nil,false,true)
    room:handleAddLoseSkills(victim,"qiao__skill_jin023_2",nil,false,true)
    holder.hp=holder.maxHp
    hp=holder.hp
    room:damage{from=victim,to=holder,damage=1,card=Fk:cloneCard("qiao__slash")}
    lu.assertEquals(holder.hp,hp-2,"被围攻者对围攻者杀伤害+1")
  end)
end

function Testqiao_jin023_malong:testEquipSlotsAfterJubao()
  local room, me, sun = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  local count, slots
  local feng = "qiao__skill_jin023_1"
  inRoom(function()
    room.current = me
    me.phase = Player.Play
    room:handleAddLoseSkills(me, feng, nil, false, true)
    skill_test.installDualGenerals(room, sun, {
      main = "qiao_heg__em_wu001", deputy = "qiao_test__wu_2", kingdom = "wu",
    })
    local mine = room:printCard("qiao__bronze_sparrow", Card.Spade, 3)
    local pearl = room:printCard("qiao__luminous_pearl", Card.Diamond, 4)
    room:moveCardIntoEquip(me, mine.id, feng, false, me)
    room:moveCardIntoEquip(sun, pearl.id, feng, false, sun)
    lu.assertEquals(#sun:getEquipments(Card.SubtypeTreasure), 1)
    lu.assertFalse(Fk.skills[feng]:targetFilter(me, sun, {me }, {}))
    Fk.skills[feng]:onUse(room, { from = me, tos = { me, sun } })
    local ids = sun:getEquipments(Card.SubtypeTreasure)
    lu.assertTrue(table.contains(ids, pearl.id))
    count, slots = #ids, #sun:getAvailableEquipSlots(Card.SubtypeTreasure)
  end)
  lu.assertEquals(count, slots, "受聚宝保护的宝物须独占原栏位")
end

local function checkSwapAfterRefill(skillName, event, shouldRefill)
  local room, me, other = FkTest.room, p(1), p(2)
  local mine, theirs, replacement
  local occupied = false
  local refill = fk.CreateSkill { name = "#qiao_test_refill_" .. skillName .. tostring(event) }
  refill:addEffect(event, {
    global = true,
    late_refresh = event == fk.BeforeCardsMove,
    can_refresh = function(_, _, _, player, moves)
      return player == me and not occupied and mine and room:getCardArea(mine) == Card.Processing
        and shouldRefill(moves, other, skillName)
    end,
    on_refresh = function()
      occupied = true
      room:moveCardIntoEquip(other, replacement, "test", false, other)
    end,
  })
  inRoom(function()
    room:setCurrent(me)
    me.phase = Player.Play
    room:handleAddLoseSkills(me, skillName, nil, false, true)
    mine = room:printCard("qiao__bronze_sparrow", Card.Spade, 3).id
    theirs = room:printCard("qiao__luminous_pearl", Card.Diamond, 4).id
    replacement = room:printCard("qiao__bronze_sparrow", Card.Club, 5).id
    room:moveCardIntoEquip(me, mine, skillName, false, me)
    room:moveCardIntoEquip(other, theirs, skillName, false, other)
    room:addSkill(refill:createSkill())
    Fk.skills[skillName]:onUse(room, { from = me, tos = { me, other } })
  end)
  lu.assertTrue(occupied)
  lu.assertEquals(other:getEquipments(Card.SubtypeTreasure), { replacement })
  lu.assertEquals(me:getEquipments(Card.SubtypeTreasure), { theirs })
  lu.assertEquals(room:getCardArea(mine), Card.DiscardPile)
end

function Testqiao_jin023_malong:testFengxieRechecksSlotsAfterEquipsLeave()
  checkSwapAfterRefill("qiao__skill_jin023_1", fk.AfterCardsMove, function() return true end)
end

local function isIncomingEquipment(moves, recipient, skillName)
  return table.find(moves, function(move)
    return move.to == recipient and move.toArea == Card.PlayerEquip and move.skillName == skillName
  end) ~= nil
end

function Testqiao_jin023_malong:testFengxieRechecksSlotsAfterIncomingMoveRefresh()
  checkSwapAfterRefill("qiao__skill_jin023_1", fk.BeforeCardsMove, isIncomingEquipment)
end

function Testqiao_jin023_malong:testGanluRechecksSlotsAfterIncomingMoveRefresh()
  checkSwapAfterRefill("qiao__skill_wu024_2", fk.BeforeCardsMove, isIncomingEquipment)
end

function Testqiao_jin023_malong:testFengxieAfterOrdinarySlashLeavesCountUnchanged()
  local room, me, target = FkTest.room, FkTest.room.players[1], FkTest.room.players[2]
  local name = "qiao__skill_jin023_1"
  local before, after, used
  inRoom(function()
    room:setCurrent(me)
    me.phase = Player.Play
    room:handleAddLoseSkills(me, name, nil, false, true)
    local a = room:printCard("qiao__qinggang_sword", Card.Spade, 2)
    local b = room:printCard("qiao__axe", Card.Spade, 3)
    room:moveCardIntoEquip(me, a.id, name, false, me)
    room:moveCardIntoEquip(target, b.id, name, false, target)
    me:addCardUseHistory("slash", 1)
    before = me:usedCardTimes("slash", Player.HistoryPhase)
    local hp = target.hp
    FkTest.setNextReplies(target, { "" })
    Fk.skills[name]:onUse(room, { from = me, tos = { me, target } })
    used = target.hp < hp
    after = me:usedCardTimes("slash", Player.HistoryPhase)
  end)
  lu.assertTrue(used)
  lu.assertEquals(before, 1)
  lu.assertEquals(after, before, "锋械额外用杀不改变普通出杀次数")
end

return { name = "qiao_jin023_malong" }
