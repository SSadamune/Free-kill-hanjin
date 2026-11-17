-- 武将牌后天技能台账：授予、承志来源、暗置失效、交换随牌。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local G = require "packages.hanjin.pkg.hanjin_mode.rules.general_card_skills"
local Exchange = require "packages.hanjin.pkg.hanjin_mode.rules.general_exchange"

local GUANXING = "hanjin__skill_shu004_1"
local BONUS = "hanjin__skill_shu012_3-guanxing-bonus"
local MAIN = "hanjin__shu001"
local JIANGWEI = "hanjin__shu012"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testhanjin_general_card_skills = {
  setup = function()
    Fk.currentResponsePattern = nil
    local room = support.initHanjinRoom()
    inRoom(function()
      skill_test.installBlankGenerals(room, {
        "shu", "shu", "shu", "shu", "qun", "qun", "qun", "qun",
      })
      skill_test.installDualGenerals(room, room.players[1], {
        main = MAIN, deputy = JIANGWEI, kingdom = "shu",
      })
      skill_test.installDualGenerals(room, room.players[2], {
        main = "hanjin__shu003", deputy = "hanjin_test__shu_2", kingdom = "shu",
      })
      room.players[1]:revealGeneral(false)
      room.players[1]:revealGeneral(true)
      room.players[2]:revealGeneral(false)
      room.players[2]:revealGeneral(true)
    end)
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testhanjin_general_card_skills:testGrantToMainCardThenChengzhiBonus()
  local player = p(1)
  local main = player.general
  inRoom(function()
    lu.assertFalse(Exchange.cardProvidesSkill(FkTest.room, main, GUANXING))
    G.grant(FkTest.room, main, GUANXING)
    lu.assertTrue(Exchange.cardProvidesSkill(FkTest.room, main, GUANXING))
    lu.assertEquals(Exchange.skillOwner(player, GUANXING), main)
    lu.assertTrue(player:hasSkill(GUANXING))
    lu.assertEquals(player:getMark(BONUS), 1)
  end)
end

function Testhanjin_general_card_skills:testHideMainStopsCardSkillAndBonus()
  local player = p(1)
  local main = player.general
  inRoom(function()
    G.grant(FkTest.room, main, GUANXING)
    player:hideGeneral(false)
    lu.assertFalse(player:hasShownSkill(GUANXING))
    lu.assertEquals(Exchange.skillOwner(player, GUANXING),main,"暗置不删除将牌的技能归属")
    lu.assertEquals(player:getMark(BONUS), 1,"主将仍拥有观星，暗置仅改变技能可发动状态")
    player:revealGeneral(false)
    lu.assertTrue(Exchange.cardProvidesSkill(FkTest.room, main, GUANXING))
    lu.assertEquals(Exchange.skillOwner(player, GUANXING), main)
  end)
end

function Testhanjin_general_card_skills:testSkillFollowsCardOnExchange()
  local first, second = p(1), p(2)
  local main = first.general
  inRoom(function()
    G.grant(FkTest.room, main, GUANXING)
    local context = Exchange.exchange(FkTest.room,
      { player = first, isDeputy = false },
      { player = second, isDeputy = false })
    lu.assertNotNil(context)
    lu.assertEquals(Exchange.actualGeneral(second, false), main)
    lu.assertTrue(Exchange.cardProvidesSkill(FkTest.room, main, GUANXING))
    lu.assertTrue(second:hasSkill(GUANXING))
    lu.assertEquals(Exchange.skillOwner(second, GUANXING), main)
    lu.assertNotEquals(Exchange.actualGeneral(first, false), main)
    lu.assertFalse(Exchange.skillOwner(first, GUANXING) == main)
  end)
end

function Testhanjin_general_card_skills:testHiddenAcquiredSkillRevealsItsOwnCard()
 local room,player=FkTest.room,p(2)
 local main=player.general
 inRoom(function()
  G.grant(room,main,GUANXING)
  player:hideGeneral(false)
  lu.assertTrue(player:isFakeSkill(GUANXING))
  lu.assertFalse(player:hasSkill(GUANXING))
  player:prelightSkill(GUANXING,true)
  player.phase=Player.Start
 end)
 local seen=0
 skill_test.withSkillRequests(room,GUANXING,{
  askToSkillInvoke=function() return true end,
  askToGuanxing=function(self,who,params) seen=#params.cards;return {top=params.cards,bottom={}} end,
 },function()
  inRoom(function() room.logic:trigger(fk.EventPhaseStart,player,PhaseData:new{who=player,phase=Player.Start}) end)
 end)
 lu.assertEquals(seen,5)
 lu.assertEquals(player.general,main,"发动后天牌技须明置实际所属将牌")
end
function Testhanjin_general_card_skills:testRemovalStopsCardSourceAndRevokeKeepsExternalSource()
 local room,player=FkTest.room,p(2)
 local main=player.general
 inRoom(function()
  G.grant(room,main,GUANXING)
  lu.assertFalse(table.contains(Fk.generals[main]:getSkillNameList(true),GUANXING),"不能污染全局将牌")
  local H=require "packages.hegemony.util"
  H.removeGeneral(player,false)
  lu.assertFalse(player:hasSkill(GUANXING),"移除将牌后停止该牌提供的技能")
  room:handleAddLoseSkills(player,GUANXING,nil,false,true)
  G.revoke(room,main,GUANXING)
  lu.assertTrue(player:hasSkill(GUANXING),"撤回将牌来源不得删除角色独立来源")
 end)
end
function Testhanjin_general_card_skills:testGrantedSkillLeavesOldHolderWithoutChengzhi()
 local room,first,second=FkTest.room,p(2),p(3)
 inRoom(function()
  local name=first.general
  G.grant(room,name,GUANXING)
  lu.assertTrue(first:hasSkill(GUANXING))
  lu.assertNotNil(Exchange.exchange(room,{player=first,isDeputy=false},{player=second,isDeputy=false}))
  lu.assertFalse(first:hasSkill(GUANXING))
  lu.assertTrue(second:hasSkill(GUANXING))
  G.revoke(room,name,GUANXING)
  lu.assertFalse(second:hasSkill(GUANXING),"最后一个将牌台账记录撤回后也必须失去技能")
 end)
end

function Testhanjin_general_card_skills:testAcquiredCardSkillCanBeLostAndStaysLostAfterReveal()
 local room,player=FkTest.room,p(2)
 local main=player.general
 inRoom(function()
  G.grant(room,main,GUANXING)
  local Choices=require "packages.hanjin.pkg.hanjin_generals.util.jin_sources"
  local offered=0
  for _,entry in ipairs(Choices.choices(player)) do
   if entry.skill==GUANXING then
    offered=offered+1
    lu.assertEquals(entry.general,main)
   end
  end
  lu.assertEquals(offered,1,"将牌后天技能不重复列为角色派生来源")
  local Lost=require "packages.hanjin.pkg.hanjin_mode.rules.qun_duanchang"
  lu.assertTrue(Lost.loseCardSkill(room,player,false,GUANXING))
  lu.assertFalse(player:hasSkill(GUANXING))
  player:hideGeneral(false)
  player:revealGeneral(false)
  lu.assertFalse(player:hasSkill(GUANXING))
  lu.assertFalse(Exchange.cardProvidesSkill(room,main,GUANXING))
 end)
end

return { name = "hanjin_general_card_skills" }
