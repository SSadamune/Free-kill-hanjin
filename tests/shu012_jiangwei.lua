-- SHU012 姜维：挑衅、天覆、承志真实主流程验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local H = require "packages.hegemony.util"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local JIANGWEI = "qiao_heg__shu012"
local TIAOXIN = "qiao__skill_shu012_1"
local TIANFU = "qiao__skill_shu012_2"
local TIANFU_RULE = "qiao__skill_shu012_2_rule"
local CHENGZHI = "qiao__skill_shu012_3"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = FkTest.room:printCard(name, suit or Card.Spade, number or 7)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

Testqiao_shu012_jiangwei = {
  setup = function()
    Fk.currentResponsePattern = nil
    local room = support.createRoom {
      mode = "qiao_heg_mode",
      realSelection = true,
      settings = {
        qiao_candidate_kingdoms = { "han", "wei", "shu", "wu", "qun", "jin" },
        qiao_kingdom_limit = 6,
      },
    }
    inRoom(function()
      skill_test.installBlankGenerals(room, {
        "shu", "shu", "shu", "shu", "qun", "qun", "qun", "qun",
      })
      skill_test.installDualGenerals(room, room.players[1], {
        main = JIANGWEI, deputy = "qiao_test__shu_2", kingdom = "shu",
      })
      room.players[1]:revealGeneral(false)
      room.current = room.players[1]
    end)
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_shu012_jiangwei:testFormalRegistration()
  local general = assert(Fk.generals[JIANGWEI])
  lu.assertEquals(general.trueName, "姜维")
  lu.assertEquals(general.maxHp, 4)
  lu.assertEquals(general.kingdom, "shu")
  lu.assertTrue(general:isCompanionWith(Fk.generals["qiao_heg__shu004"]))
  for _, name in ipairs({ TIAOXIN, TIANFU, CHENGZHI }) do
    lu.assertTrue(table.contains(general:getSkillNameList(), name))
  end
  lu.assertEquals(Exchange.actualGeneral(p(1), false), JIANGWEI)
end

function Testqiao_shu012_jiangwei:testTianfuRuleReadsActualFormation()
  local first, second, outsider = p(1), p(2), p(5)
  inRoom(function()
    FkTest.room:addSkill(Fk.skills[TIANFU_RULE])
    lu.assertTrue(H.inFormationRelation(first, first), "夹具应形成真实队列")
    -- 基线必须来自非队列者回合，不能从已生效值再镜像加2。
    FkTest.room.current = outsider
    local base = second:getAttackRange()
    FkTest.room.current = second
    lu.assertEquals(second:getAttackRange(), base + 2, "队列者回合全场攻击范围+2")
  end)
end

function Testqiao_shu012_jiangwei:testChengzhiMainSourceBaseline()
  local player = p(1)
  inRoom(function()
    FkTest.room:changeHero(player, "qiao_heg__shu004", false, false, false, false, false)
    FkTest.room:setPlayerMark(player, "__heg_general", "qiao_heg__shu004")
    lu.assertTrue(Fk.generals["qiao_heg__shu004"]:getSkillNameList()[1] == "qiao__skill_shu004_1")
    lu.assertTrue(table.contains(Fk.generals["qiao_heg__shu004"]:getSkillNameList(),
      "qiao__skill_shu004_1"))
  end)
end

function Testqiao_shu012_jiangwei:testTiaoxinRealSlashOnJiangwei()
  local room, player, target = FkTest.room, p(1), p(2)
  local slash = give(target, "qiao__slash", Card.Spade, 2)
  inRoom(function()
    room.current = player
    player.phase = Player.Play
  end)
  -- 走真实 C.askToUseCard / Room:askToUseCard 请求；只提供目标的
  -- AskForUseCard 回复，不替换请求方法。
  FkTest.setNextReplies(target, { { card = slash, targets = { player.id } } })
  inRoom(function()
    Fk.skills[TIAOXIN]:onUse(room, { from = player, tos = { target } })
  end)
  lu.assertEquals(player.hp, player.maxHp - 1, "目标实际对姜维使用杀并造成伤害")
  lu.assertTrue(table.contains(target:getCardIds("he"), slash) == false)
end

function Testqiao_shu012_jiangwei:testTiaoxinCancelDiscardsTargetCard()
  local room, player, target = FkTest.room, p(1), p(2)
  local jink = give(target, "qiao__jink", Card.Heart, 3)
  inRoom(function()
    room.current = player
    player.phase = Player.Play
  end)
  FkTest.setNextReplies(target, { "" })
  local original = room.askToChooseCard
  local ok, err = pcall(function()
    room.askToChooseCard = function() return jink end
    inRoom(function()
      Fk.skills[TIAOXIN]:onUse(room, { from = player, tos = { target } })
    end)
  end)
  room.askToChooseCard = original
  if not ok then error(err, 0) end
  lu.assertFalse(table.contains(target:getCardIds("he"), jink),
    "挑衅取消使用杀后应实际弃置目标一张牌")
end

function Testqiao_shu012_jiangwei:testChengzhiReallyAddsTwoGuanxingCards()
  local room,player=FkTest.room,p(2)
  lu.assertTrue(table.contains(Fk.generals[JIANGWEI]:getSkillNameList(), CHENGZHI),
    "姜维印刷技能应含承志")
  inRoom(function()
    -- 先副将姜维、后实际换主将为诸葛亮，复现承志先授予观星再切换印刷来源。
    skill_test.installDualGenerals(room,player,{
      main="qiao_test__shu_1",deputy=JIANGWEI,kingdom="shu",
    })
    room:changeHero(player, "qiao_heg__shu004", false, false, false, false, false)
    room:setPlayerMark(player, "__heg_general", "qiao_heg__shu004")
    player.maxHp = player:getGeneralMaxHp()
    player:revealGeneral(false)
    room.current=player
    player.phase=Player.Start
    lu.assertEquals(player.deputyGeneral,JIANGWEI)
    lu.assertTrue(player:hasSkill(CHENGZHI, true, true), "承志应随副将安装")
    lu.assertTrue(player:hasSkill("qiao__skill_shu004_1"), "换主将后应恢复印刷观星")
    lu.assertEquals(player:getMark("qiao__skill_shu012_3-guanxing-bonus"),1)
  end)
  local seen
  skill_test.withSkillRequests(room,"qiao__skill_shu004_1",{
    askToSkillInvoke=function() return true end,
    askToGuanxing=function(self,who,params)
      seen=#params.cards
      return {top=params.cards,bottom={}}
    end,
  },function()
    inRoom(function() room.logic:trigger(fk.EventPhaseStart,player,PhaseData:new{who=player,phase=Player.Start}) end)
  end)
  lu.assertEquals(seen,7)
  inRoom(function()
    room:handleAddLoseSkills(player,"-"..CHENGZHI,nil,false,true)
    lu.assertEquals(player:getMark("qiao__skill_shu012_3-guanxing-bonus"),0)
    lu.assertTrue(player:hasSkill("qiao__skill_shu004_1"),"失承志不应失主将观星")
  end)
end

return { name = "qiao_shu012_jiangwei" }
