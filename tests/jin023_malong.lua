-- JIN023 马隆：数据片段、锋械/锥形注册与总戎目标组静态入口。
-- 真实装备交换、杀响应与围攻伤害验证。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_jin2"


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

return { name = "qiao_jin023_malong" }
