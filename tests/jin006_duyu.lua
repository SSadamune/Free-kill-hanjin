-- JIN006 杜预：三陈/破竹/武库的静态阶段验收。
-- 数据片段尚未合入中央将池；这里按正式技能 id 和独立数据片段验证。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local U = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_jin"

local SANCHEN = "qiao__skill_jin006_1"
local WUKU = "qiao__skill_jin006_3"
local HISTORY = "#qiao_zhen_shi_jin_history"

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

Testqiao_jin006_duyu = {
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

function Testqiao_jin006_duyu:testDataFragment()
  lu.assertEquals(DATA.generalCount, 2)
  lu.assertEquals(DATA.skillCount, 5)
  local duyu
  for _, general in ipairs(DATA.generals) do
    if general.id == "qiao_heg__jin006" then duyu = general end
  end
  lu.assertNotNil(duyu)
  lu.assertNotNil(Fk.generals["qiao_heg__jin006"], "正式将池尚未合入 JIN006")
  lu.assertEquals(duyu.mainHpAdjust, -1)
  lu.assertEquals(duyu.skills[2].tags[1], "MainPlace")
  lu.assertEquals(duyu.skills[3].tags[1], "DeputyPlace")
end

function Testqiao_jin006_duyu:testSanChenPhaseRestoreAndTargetLedger()
  local me, target = p(1), p(2)
  inRoom(function()
    FkTest.room:handleAddLoseSkills(me, SANCHEN, nil, false, true)
    lu.assertEquals(U.sanChenRemaining(me), 1)
    U.consumeSanChen(me)
    U.markSanChenTarget(me, target)
    lu.assertEquals(U.sanChenRemaining(me), 0)
    lu.assertTrue(U.sanChenTargeted(me, target))
    U.restoreSanChen(me)
    lu.assertEquals(U.sanChenRemaining(me), 1)
    lu.assertEquals(U.sanChenRestored(me), 1)
    lu.assertTrue(U.sanChenTargeted(me, target), "复原不清除本回合已选目标")
    U.resetPhase(me)
    lu.assertEquals(U.sanChenRemaining(me), 1)
    lu.assertEquals(U.sanChenRestored(me), 0)
    lu.assertTrue(U.sanChenTargeted(me, target))
    U.resetTurn(me)
    lu.assertFalse(U.sanChenTargeted(me, target))
  end)
end

function Testqiao_jin006_duyu:testSanChenDrawDiscardRestoreMainFlow()
  local me, target = p(1), p(2)
  local ids = {}
  inRoom(function()
    FkTest.room:handleAddLoseSkills(me, SANCHEN, nil, false, true)
    for _, name in ipairs({ "slash", "duel", "qinggang_sword" }) do
      local card = FkTest.room:printCard(name, Card.Spade, 1)
      FkTest.room:obtainCard(target, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
    skill_test.withSkillRequests(FkTest.room, SANCHEN, {
      askToDiscard = function(self, player, params)
        FkTest.room:throwCard(ids, SANCHEN, player, player)
        return ids
      end,
      askToChoice = function() return "restore" end,
    }, function()
      Fk.skills[SANCHEN]:onUse(FkTest.room, { from = me, tos = { target } })
    end)
    lu.assertEquals(U.sanChenRestored(me), 1, "实际弃足三类各异后复原")
    lu.assertEquals(U.sanChenRemaining(me), 1, "复原后本阶段再次可用")
    lu.assertFalse(target:getCardIds("h")[1] == nil)
  end)
end

function Testqiao_jin006_duyu:testWuKuUsesPublicHistoryAndResponseBoundary()
  local me = p(1)
  inRoom(function()
    FkTest.room:addSkill(Fk.skills[HISTORY])
    FkTest.room.logic:trigger(fk.AfterCardUseDeclared, me, { card = Fk:cloneCard("slash") })
    lu.assertEquals(U.lastUse(me), "slash")
    lu.assertEquals(U.history(me)[1], "slash")

    FkTest.room:handleAddLoseSkills(me, WUKU, nil, false, true)
    local treasure = FkTest.room:printCard("qiao__bronze_sparrow", Card.Spade, 1)
    FkTest.room:obtainCard(me, treasure, false, fk.ReasonJustMove)
    local skill = Fk.skills[WUKU]
    local card = skill:viewAs(me, { treasure.id })
    lu.assertNotNil(card)
    lu.assertEquals(card.name, "slash")
    lu.assertTrue(skill:enabledAtResponse(me, false), "需要“使用”闪/无懈的窗口可转化")
    lu.assertFalse(skill:enabledAtResponse(me, true), "纯打出窗口不提供")
  end)
end

function Testqiao_jin006_duyu:testWuKuReadsRealUseDeclaredAndStillAllowsResponseUse()
  local me, target = p(1), p(2)
  local slash = give(me, "qiao__slash", Card.Spade, 2)
  local treasure = give(me, "qiao__bronze_sparrow", Card.Heart, 3)
  inRoom(function()
    FkTest.room:addSkill(Fk.skills[HISTORY])
    FkTest.room.current = me
    me.phase = Player.Play
    FkTest.room:useCard {
      from = me, tos = { target }, card = Fk:getCardById(slash),
    }
    FkTest.room:handleAddLoseSkills(me, WUKU, nil, false, true)
    lu.assertEquals(U.lastUse(me), "slash", "真实使用后公开历史应记录上一张牌")
    local skill = Fk.skills[WUKU]
    local card = skill:viewAs(me, { treasure })
    lu.assertNotNil(card)
    lu.assertEquals(card.name, "slash")
    lu.assertTrue(skill:enabledAtResponse(me, false), "需要使用的响应窗口仍可转化")
    lu.assertFalse(skill:enabledAtResponse(me, true), "纯打出窗口不提供")
  end)
end

return { name = "qiao_jin006_duyu" }
