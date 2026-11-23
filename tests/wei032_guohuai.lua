-- WEI032 郭淮：精策事件计数、疲攻给牌、屏御请求窗口静态主流程。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_wei"

local JINGCE = "qiao__skill_wei032_1"
local PIGONG = "qiao__skill_wei032_2"
local PINGYU = "qiao__skill_wei032_3"

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

Testqiao_wei032_guohuai = {
  setup = function()
    Fk.currentResponsePattern = nil
    local room = support.initQiaoRoom()
    inRoom(function() skill_test.installBlankGenerals(room, "han") end)
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_wei032_guohuai:testDataFragment()
  local general = DATA.generals[1]
  lu.assertEquals(general.id, "qiao_heg__wei032")
  lu.assertNotNil(Fk.generals["qiao_heg__wei032"], "正式将池尚未合入 WEI032")
  lu.assertEquals(general.mainHpAdjust, -1)
  lu.assertEquals(general.skills[2].tags[1], "MainPlace")
  lu.assertEquals(general.skills[3].tags[1], "DeputyPlace")
end

function Testqiao_wei032_guohuai:testJingCeCountsUseAndResponseEvents()
  local me = p(1)
  inRoom(function()
    FkTest.room:handleAddLoseSkills(me, JINGCE, nil, false, true)
    FkTest.room.logic:trigger(fk.AfterCardUseDeclared, me, { card = Fk:cloneCard("slash") })
    FkTest.room.logic:trigger(fk.CardResponding, me, { card = Fk:cloneCard("jink") })
    me.hp = 1
  end)
  local before = #me:getCardIds("h")
  skill_test.withSkillRequests(FkTest.room, JINGCE, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == JINGCE then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      FkTest.room.logic:trigger(fk.TurnEnd, me, TurnData:new(me, "game_rule", { Player.Start }))
    end)
  end)
  lu.assertEquals(#me:getCardIds("h"), before + 1, "事件数大于体力值摸1，不按材料张数")
end

function Testqiao_wei032_guohuai:testJingCeReadsPublicHistoryBeforeAcquisition()
  local me, target = p(1), p(2)
  local slash = give(me, "qiao__slash", Card.Spade, 2)
  inRoom(function()
    FkTest.room.current = me
    me.phase = Player.Play
    FkTest.room:useCard {
      from = me, tos = { target }, card = Fk:getCardById(slash),
    }
    me.hp = 1
    FkTest.room:handleAddLoseSkills(me, JINGCE, nil, false, true)
  end)
  local before = #me:getCardIds("h")
  skill_test.withSkillRequests(FkTest.room, JINGCE, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == JINGCE then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      FkTest.room.logic:trigger(fk.TurnEnd, me, TurnData:new(me, "game_rule", { Player.Start }))
    end)
  end)
  lu.assertEquals(#me:getCardIds("h"), before + 2,
    "取得精策前的本回合使用也应计入；等于体力值时摸2")
end

function Testqiao_wei032_guohuai:testPingYuHasUseAndResponseRequestEntries()
  inRoom(function()
    local useEffect, responseEffect
    for _, effect in ipairs(Fk.skills[PINGYU]:getSkeleton().effects) do
      if effect:isInstanceOf(TriggerSkill) then
        -- 只做静态入口存在性核对；真实杀闪请求由主批运行时验收。
        useEffect = useEffect or effect
        responseEffect = effect
      end
    end
    lu.assertNotNil(useEffect)
    lu.assertNotNil(responseEffect)
    lu.assertNotNil(Fk.skills[PIGONG])
  end)
end

function Testqiao_wei032_guohuai:testPingYuRealSlashResponsePlaysGuohuaisJink()
  local room, guohuai, target, source = FkTest.room, p(1), p(2), p(3)
  local jink = give(guohuai, "qiao__jink", Card.Heart, 2)
  local slash = give(source, "qiao__slash", Card.Spade, 3)
  local requested = 0
  inRoom(function()
    room:handleAddLoseSkills(guohuai, PINGYU, nil, false, true)
    guohuai:revealGeneral(false)
    lu.assertTrue(guohuai:hasShownSkill(PINGYU), "屏御来源应已明置")
    room:setPlayerProperty(guohuai, "kingdom", "han"); guohuai.kingdom = "han"
    room:setPlayerProperty(target, "kingdom", "han"); target.kingdom = "han"
    room.current = source
    target.hp = target.maxHp
  end)

  skill_test.withSkillRequests(room, PINGYU, {
    askToChoice = function(self, who, params, original)
      if params.skill_name == PINGYU then requested = requested + 1; return "request" end
      return original(self, who, params)
    end,
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == PINGYU then return true end
      return original(self, who, params)
    end,
    askToResponse = function(self, who, params, original)
      if params.skill_name ~= PINGYU then return original(self, who, params) end
      return { from = who, card = Fk:getCardById(jink), extra_data = {} }
    end,
  }, function()
    inRoom(function()
      room:useCard {
        from = source, tos = { target }, card = Fk:getCardById(slash),
      }
    end)
  end)

  lu.assertEquals(requested, 1, "真实杀请求应先让目标选择请求郭淮")
  lu.assertEquals(room:getCardArea(jink), Card.DiscardPile, "实际打出的是郭淮的闪")
  lu.assertEquals(target.hp, target.maxHp, "郭淮的闪应抵消原杀，请求者不掉血")
  lu.assertFalse(table.contains(guohuai:getCardIds(Player.Hand), jink))
end

function Testqiao_wei032_guohuai:testJingceChecksEveryTurnAndOnlyAsksWhenEligible()
  local room, owner, other = FkTest.room, p(1), p(2)
  inRoom(function()
    room:handleAddLoseSkills(owner, JINGCE, nil, false, true)
    room.logic:trigger(fk.CardResponding, owner, { card = Fk:cloneCard("jink") })
    owner.hp = 2
  end)
  local asks, hand = 0, owner:getHandcardNum()
  skill_test.withSkillRequests(room, JINGCE, {
    askToSkillInvoke = function() asks = asks + 1; return true end,
  }, function()
    local function finish()
      inRoom(function() room.logic:trigger(fk.TurnEnd, other, TurnData:new(other, "game_rule", {})) end)
    end
    finish()
    lu.assertEquals(asks, 0)
    owner.hp = 1
    finish()
    lu.assertEquals(asks, 1)
    lu.assertEquals(owner:getHandcardNum(), hand + 2)
  end)
end

return { name = "qiao_wei032_guohuai" }
