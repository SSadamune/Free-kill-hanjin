-- QUN081 徐荣：剽戮、杀绝定向验收。
-- 规则依据：docs/rules/generals/qun081-xurong.md。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local XURONG = "qiao_heg__qun081"
local PIAOLU = "qiao__skill_qun081_1"
local SHAJUE = "qiao__skill_qun081_2"
local SIDE_SELF = "qiao__skill_qun081_1-self"

local ZHEN_SHI = require "packages.qiao.pkg.qiao_generals.data.zhen_shi"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function clearCards(player)
  local ids = player:getCardIds("he")
  if #ids > 0 then
    FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
      "test", nil, false)
  end
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = FkTest.room:printCard(name, suit or Card.Spade, number or 7)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function prepare()
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
      "qun", "qun", "qun", "qun", "qun", "qun", "qun", "qun",
    })
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], {
      main = XURONG,
      deputy = "qiao_test__qun_2",
      kingdom = "qun",
    })
  end)
  return room
end

Testqiao_qun081_xurong = {
  setup = prepare,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_qun081_xurong:testFormalRegistration()
  local pack = assert(Fk.packages.qiao_zhenshi)
  local entry = assert(table.find(ZHEN_SHI.generals, function(data)
    return data.id == XURONG
  end), "missing Xu Rong data entry")
  lu.assertEquals(entry.number, "QUN081")
  local general = assert(Fk.generals[XURONG])
  lu.assertIs(general.package, pack)
  lu.assertEquals(general.trueName, "徐荣")
  lu.assertEquals(general.kingdom, "qun")
  lu.assertEquals(general.maxHp, 4)
  lu.assertEquals(general.gender, General.Male)
  lu.assertTrue(table.contains(general:getSkillNameList(), PIAOLU))
  lu.assertTrue(table.contains(general:getSkillNameList(), SHAJUE))
  inRoom(function()
    lu.assertTrue(Fk:canUseGeneral(XURONG))
  end)
end

function Testqiao_qun081_xurong:testPiaoluOnlyChosenTargetAndSelfMount()
  local room, player, target = FkTest.room, p(1), p(2)
  local mount = give(player, "qiao__jueying", Card.Spade, 5)
  local treasure = give(target, "qiao__bronze_sparrow", Card.Heart, 6)
  local slash = give(player, "qiao__slash", Card.Spade, 7)
  inRoom(function()
    room:moveCardIntoEquip(player, mount, "test", true, player)
    room:moveCardIntoEquip(target, treasure, "test", true, target)
    room.current = player
    player.phase = Player.Play
    room:setBanner("RoundCount", 1)
  end)

  skill_test.withSkillRequests(room, PIAOLU, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == PIAOLU then return true end
      return original(self, who, params)
    end,
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name ~= PIAOLU then return original(self, who, params) end
      lu.assertTrue(table.contains(params.targets, target))
      return { target }
    end,
    askToChoice = function(self, who, params, original)
      if params.skill_name ~= PIAOLU then return original(self, who, params) end
      return SIDE_SELF
    end,
    askToChooseCard = function(self, who, params, original)
      if params.skill_name ~= PIAOLU then return original(self, who, params) end
      lu.assertIs(params.target, player)
      return mount
    end,
  }, function()
    inRoom(function()
      room:useCard(UseCardData:new {
        from = player, tos = { target }, card = Fk:getCardById(slash), extra_data = {},
      })
    end)
  end)

  lu.assertEquals(room:getCardArea(mount), Card.DiscardPile)
  lu.assertEquals(target.hp, target.maxHp - 2) -- 基础1 + 本次对该目标+1。
  lu.assertTrue(table.contains(target:getCardIds(Player.Equip), treasure))
end

function Testqiao_qun081_xurong:testShajueObtainsActualDyingDamageCard()
  local room, player, source = FkTest.room, p(1), p(2)
  inRoom(function()
    player.hp = 1
    room.current = source
  end)
  local peach1 = give(player, "qiao__peach", Card.Heart, 2)
  local peach2 = give(player, "qiao__peach", Card.Diamond, 4)
  local slash = give(source, "qiao__slash", Card.Spade, 3)
  inRoom(function()
    room:moveCardTo({ slash }, Card.Processing, nil, fk.ReasonUse,
      "test", nil, true)
  end)
  FkTest.setNextReplies(player, {
    FkTest.ReplyCard(Fk:getCardById(peach1)),
    FkTest.ReplyCard(Fk:getCardById(peach2)),
  })

  skill_test.withSkillRequests(room, SHAJUE, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == SHAJUE then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:damage {
        from = source, to = player, damage = 2,
        card = Fk:getCardById(slash), skillName = "test",
      }
    end)
  end)

  lu.assertTrue(player:isAlive(), "Xu Rong should survive after using the peach")
  lu.assertTrue(table.contains(player:getCardIds(Player.Hand), slash),
    "dying damage card should be in Xu Rong's hand")
end

return { name = "qiao_qun081_xurong" }
