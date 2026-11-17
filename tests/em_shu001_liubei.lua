-- EM(SHU001) 君刘备：静态数据/技能骨架验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_lord_shu"

local LORD = "qiao_heg__em_shu001"
local ZHANGWU = "qiao__skill_em_shu001_1"
local TIANYI = "qiao__skill_em_shu001_2"
local JIZHAO = "qiao__skill_em_shu001_3"
local FLAG = "qiao__skill_em_shu001_flag"

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

Testqiao_em_shu001_liubei = {
  setup = function()
    Fk.currentResponsePattern = nil
    local room = support.initQiaoRoom()
    inRoom(function()
      skill_test.installBlankGenerals(room, {
        "shu", "shu", "shu", "shu", "qun", "qun", "qun", "qun",
      })
      room.current = room.players[1]
      room.players[1]:revealGeneral(false)
    end)
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_em_shu001_liubei:testStaticFragment()
  lu.assertEquals(DATA.generalCount, 1)
  lu.assertEquals(DATA.skillCount, 3)
  lu.assertEquals(DATA.kingdoms[1], "shu")
  local general = assert(DATA.generals[1])
  lu.assertEquals(general.id, LORD)
  lu.assertEquals(general.number, "EM(SHU001)")
  lu.assertTrue(general.is_lord)
  lu.assertEquals(general.lord_kingdoms[1], "shu")
  lu.assertEquals(#DATA.versions, 1)
  lu.assertEquals(DATA.versions[1].normal, "qiao_heg__shu001")
  lu.assertEquals(DATA.versions[1].lord, LORD)
end

function Testqiao_em_shu001_liubei:testSkillsAndDragonPhoenixIdentity()
  for _, name in ipairs({ ZHANGWU, TIANYI, JIZHAO, FLAG }) do
    lu.assertNotNil(Fk.skills[name], "missing skill skeleton: " .. name)
  end
  local card = assert(Fk.all_card_types["qiao__dragon_phoenix"])
  lu.assertEquals(card.type, Card.TypeEquip)
  lu.assertEquals(card.display_name or Fk:translate(card.name), "飞龙夺凤")
end

function Testqiao_em_shu001_liubei:testTianyiSplitsOnlyDragonPhoenixMove()
  local room, lord, other = FkTest.room, p(1), p(2)
  local dragon = give(other, "qiao__dragon_phoenix", Card.Spade, 2)
  local jink = give(other, "qiao__jink", Card.Heart, 3)
  inRoom(function()
    room:handleAddLoseSkills(lord, TIANYI, nil, false, true)
    room:moveCards {
      from = other, ids = { dragon, jink }, toArea = Card.DiscardPile,
      moveReason = fk.ReasonJustMove, moveVisible = true,
    }
  end)
  lu.assertEquals(room:getCardArea(dragon), Card.PlayerHand)
  lu.assertIs(room:getCardOwner(dragon), lord)
  lu.assertEquals(room:getCardArea(jink), Card.DiscardPile)
end

function Testqiao_em_shu001_liubei:testFlagGivesTwoCardsAndTemporarySkill()
  local room, lord, other = FkTest.room, p(1), p(2)
  local first = give(other, "qiao__jink", Card.Heart, 2)
  local second = give(other, "qiao__jink", Card.Club, 3)
  inRoom(function()
    room:handleAddLoseSkills(lord, ZHANGWU, nil, false, true)
    room:handleAddLoseSkills(other, FLAG, nil, false, true)
    lu.assertTrue(other:hasSkill(FLAG))
  end)
  skill_test.withSkillRequests(room, FLAG, {
    askToChoice = function(self, who, params, original)
      if params.skill_name == FLAG then return "qiao__skill_shu002_1" end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      Fk.skills[FLAG]:onUse(room, {
        from = other, cards = { first, second }, tos = {},
      })
    end)
  end)
  lu.assertTrue(table.contains(lord:getCardIds("h"), first))
  lu.assertTrue(table.contains(lord:getCardIds("h"), second))
  lu.assertTrue(other:hasSkill("qiao__skill_shu002_1"))
end

return { name = "qiao_em_shu001_liubei" }
