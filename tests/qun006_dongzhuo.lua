-- QUN006 董卓：横征、暴凌及所授崩坏定向验收。
-- 规则依据：docs/rules/generals/qun006-dongzhuo.md。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"

local DONGZHUO = "qiao_heg__qun006"
local HENGZHENG = "qiao__skill_qun006_1"
local BAOLING = "qiao__skill_qun006_2"
local BENG = "qiao__skill_qun006_3"
local LOSE_HP = "qiao__skill_qun006_3-lose-hp"
local LOSE_MAX = "qiao__skill_qun006_3-lose-max"

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
      qiao_faction_ban_enabled = false,
    },
  }
  inRoom(function()
    skill_test.installBlankGenerals(room, {
      "qun", "qun", "qun", "qun", "wei", "wei", "wei", "wei",
    })
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], {
      main = DONGZHUO,
      deputy = "qiao_test__qun_2",
      kingdom = "qun",
    })
  end)
  return room
end

Testqiao_qun006_dongzhuo = {
  setup = prepare,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_qun006_dongzhuo:testFormalRegistration()
  local pack = assert(Fk.packages.qiao_zhenshi)
  local entry = assert(table.find(ZHEN_SHI.generals, function(data)
    return data.id == DONGZHUO
  end), "missing Dong Zhuo data entry")
  lu.assertEquals(entry.number, "QUN006")
  local general = assert(Fk.generals[DONGZHUO])
  lu.assertIs(general.package, pack)
  lu.assertEquals(general.trueName, "董卓")
  lu.assertEquals(general.kingdom, "qun")
  lu.assertEquals(general.maxHp, 4)
  lu.assertEquals(general.gender, General.Male)
  lu.assertTrue(table.contains(general:getSkillNameList(), HENGZHENG))
  lu.assertTrue(table.contains(general:getSkillNameList(), BAOLING))
  inRoom(function()
    lu.assertTrue(Fk:canUseGeneral(DONGZHUO))
  end)
end

function Testqiao_qun006_dongzhuo:testHengzhengOneFromEachThenNormalDraw()
  local room, player = FkTest.room, p(1)
  inRoom(function()
    player.hp = 1
    room.current = player
    player.phase = Player.Start
  end)
  local secondCard = give(p(2), "qiao__jink", Card.Heart, 2)
  local thirdCard = give(p(3), "qiao__slash", Card.Spade, 3)

  skill_test.withSkillRequests(room, HENGZHENG, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == HENGZHENG then return true end
      return original(self, who, params)
    end,
    askToChooseCard = function(self, who, params, original)
      if params.skill_name ~= HENGZHENG then return original(self, who, params) end
      lu.assertIs(who, player)
      local ids = params.target:getCardIds("hej")
      return ids[1]
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", {
        Player.Start, Player.Draw,
      })):exec()
    end)
  end)

  lu.assertTrue(table.contains(player:getCardIds(Player.Hand), secondCard))
  lu.assertTrue(table.contains(player:getCardIds(Player.Hand), thirdCard))
  lu.assertEquals(#player:getCardIds(Player.Hand), 4) -- 获得2 + 正常摸2。
end

function Testqiao_qun006_dongzhuo:testBaolingRemovesDeputyOnlyOnce()
  local room, player = FkTest.room, p(1)
  local oldDeputy = player.deputyGeneral
  inRoom(function()
    player.hp = 1
    room.current = player
    player.phase = Player.Play
    room.logic:trigger(fk.EventPhaseEnd, player, PhaseData:new {
      who = player, reason = "game_rule", phase = Player.Play,
    })
  end)
  local deputy = player.deputyGeneral
  lu.assertFalse(player.dead, "暴凌结算时角色不应死亡")
  lu.assertNotEquals(deputy, oldDeputy, "旧副将武将牌应离开")
  lu.assertTrue(Commander.isSoldier(deputy),
    "当前副将应为士兵/统领转翼从；实际=" .. tostring(deputy))
  lu.assertEquals(player.maxHp, 7)
  lu.assertEquals(player.hp, 4)
  lu.assertTrue(player:hasSkill(BENG))

  inRoom(function()
    room.logic:trigger(fk.EventPhaseEnd, player, PhaseData:new {
      who = player, reason = "game_rule", phase = Player.Play,
    })
  end)
  lu.assertEquals(player.maxHp, 7)
end

function Testqiao_qun006_dongzhuo:testBengChoosesOneWithoutExtraDrawPhase()
  local room, player, other = FkTest.room, p(1), p(2)
  inRoom(function()
    room:handleAddLoseSkills(player, BENG, nil, false, true)
    player.hp = 3
    other.hp = 1
  end)

  local asked = {}
  for _, choice in ipairs({ LOSE_MAX, LOSE_HP }) do
    skill_test.withSkillRequests(room, BENG, {
      askToChoice = function(_, _, params)
        lu.assertEquals(params.choices, { LOSE_MAX, LOSE_HP })
        lu.assertFalse(params.cancelable)
        table.insert(asked, choice)
        return choice
      end,
    }, function()
      inRoom(function()
        GameEvent.Turn:create(TurnData:new(player, "game_rule", { Player.Finish })):exec()
      end)
    end)
  end
  lu.assertEquals(asked, { LOSE_MAX, LOSE_HP })
  lu.assertEquals(player.hp, 2)
  lu.assertEquals(player.maxHp, 3)
  lu.assertEquals(#player:getCardIds(Player.Hand), 0)
end

function Testqiao_qun006_dongzhuo:testBaolingRejectsExistingRetinueDeputy()
  local room, player = FkTest.room, p(1)
  inRoom(function()
    local wing = "qiao_test__retinue_alpha"
    lu.assertTrue(Fk.generals[wing] ~= nil)
    room:setPlayerProperty(player, "deputyGeneral", wing)
    room:setPlayerMark(player, "__heg_deputy", wing)
    player.hp = 1
    room.current = player
    player.phase = Player.Play
    room.logic:trigger(fk.EventPhaseEnd, player, PhaseData:new {
      who = player, reason = "game_rule", phase = Player.Play,
    })
  end)
  lu.assertEquals(player.maxHp, 4)
  lu.assertEquals(player.hp, 1)
  lu.assertFalse(player:hasSkill(BENG))
end

return { name = "qiao_qun006_dongzhuo" }
