-- WU010 孙策：激昂、鹰扬、魂殇定向验收。
-- 规则依据：docs/rules/generals/wu010-sunce.md。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local H = require "packages.hegemony.util"

local SUNCE = "qiao_heg__wu010"
local JIANG = "qiao__skill_wu010_1"
local YINGYANG = "qiao__skill_wu010_2"
local HUNSHANG = "qiao__skill_wu010_3"
local YINGHUN = "qiao__skill_wu009_1"
local YINGZI = "qiao__skill_wu005_1"
local DISABLED = "qiao__skill_wu010_1-disabled-turn"
local PLUS = "qiao__skill_wu010_2-plus3"

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
      "wu", "wu", "wu", "wu", "wu", "wu", "wu", "wu",
    })
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], {
      main = "qiao_test__wu_1",
      deputy = SUNCE,
      kingdom = "wu",
    })
  end)
  return room
end

Testqiao_wu010_sunce = {
  setup = prepare,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_wu010_sunce:testFormalRegistration()
  local pack = assert(Fk.packages.qiao_zhenshi)
  local entry = assert(table.find(ZHEN_SHI.generals, function(data)
    return data.id == SUNCE
  end), "missing Sun Ce data entry")
  lu.assertEquals(entry.number, "WU010")
  local general = assert(Fk.generals[SUNCE])
  lu.assertIs(general.package, pack)
  lu.assertEquals(general.trueName, "孙策")
  lu.assertEquals(general.kingdom, "wu")
  lu.assertEquals(general.maxHp, 4)
  lu.assertEquals(general.gender, General.Male)
  lu.assertEquals(general.deputyMaxHpAdjustedValue, -1)
  lu.assertTrue(general:isCompanionWith(Fk.generals["qiao_heg__wu005"]))
  lu.assertTrue(general:isCompanionWith(Fk.generals["qiao_heg__wu012"]))
  lu.assertTrue(general:isCompanionWith(Fk.generals["qiao_heg__wu006"]))
  for _, name in ipairs({ JIANG, YINGYANG, HUNSHANG }) do
    lu.assertTrue(table.contains(general:getSkillNameList(), name))
  end
  inRoom(function()
    lu.assertTrue(Fk:canUseGeneral(SUNCE))
  end)
end

function Testqiao_wu010_sunce:testJiangNormalVirtualThenConvertedDisables()
  local room, player, target = FkTest.room, p(1), p(2)
  local material = give(player, "qiao__jink", Card.Heart, 2)
  local invoked, captured = 0, {}

  local function useVirtual(converted)
    local card
    if converted then
      card = Fk:cloneCard("qiao__slash", Card.Heart, 7, nil, { material })
    else
      card = Fk:cloneCard("qiao__slash", Card.Heart, 7)
    end
    room:useCard(UseCardData:new {
      from = player, tos = { target }, card = card, extra_data = {},
    })
  end

  local probe = fk.CreateSkill { name = "#qiao_wu010_jiang_probe" }
  probe:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, who, data)
      return who == player and data.phase == Player.Play
    end,
    on_refresh = function()
      -- 纯虚拟、无实体子牌：不属于转化牌，只摸1，不失效。
      useVirtual(false)
      captured.afterNormal = invoked
      captured.disabledAfterNormal = player:getMark(DISABLED) > 0

      -- 有实体子牌的转化牌：摸2并令本回合激昂失效。
      useVirtual(true)
      captured.afterConverted = invoked
      captured.disabledAfterConverted = player:getMark(DISABLED) > 0

      -- 已失效后本回合不再触发。
      useVirtual(false)
      captured.afterThird = invoked
    end,
  })
  inRoom(function() room:addSkill(probe:createSkill()) end)

  skill_test.withSkillRequests(room, JIANG, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == JIANG then
        invoked = invoked + 1
        return true
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", {
        Player.Play,
      })):exec()
    end)
  end)

  lu.assertEquals(captured.afterNormal, 1)
  lu.assertFalse(captured.disabledAfterNormal)
  lu.assertEquals(captured.afterConverted, 2)
  lu.assertTrue(captured.disabledAfterConverted)
  lu.assertEquals(captured.afterThird, 2)
end

local function checkJiangOnHalberdSlash(user, first, extra, accept)
  local room, sunce = FkTest.room, p(1)
  local halberd = give(user, "qiao__halberd")
  local slash = give(user, "qiao__slash", Card.Heart, 7)
  local hp1, hp2 = first.hp, extra.hp
  local prompts = 0
  inRoom(function()
    room:setCurrent(user)
    room:setPlayerProperty(first, "kingdom", "wei")
    room:moveCardTo(halberd, Card.PlayerEquip, user, fk.ReasonPut, "test", nil, true)
  end)
  FkTest.setNextReplies(user, {
    FkTest.ReplyCard(Fk:getCardById(slash), { first }),
    FkTest.ReplyUseSkill("#qiao__halberd_active", { extra }),
  })
  skill_test.withSkillRequests(room, JIANG, {
    askToSkillInvoke = function(self, who, params, original)
      lu.assertIs(who, sunce)
      prompts = prompts + 1
      FkTest.setNextReplies(who, { accept and "1" or "__cancel" })
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(user, "game_rule", { Player.Play })):exec()
    end)
  end)
  lu.assertEquals({ first.hp, extra.hp }, { hp1 - 1, hp2 - 1 })
  lu.assertEquals(prompts, 1)
  lu.assertEquals(sunce:getHandcardNum(), accept and 1 or 0)
end

function Testqiao_wu010_sunce:testJiangDrawsOnceForExpandedSlash()
  checkJiangOnHalberdSlash(p(1), p(2), p(3), true)
end

function Testqiao_wu010_sunce:testJiangDeclineSkipsLaterTarget()
  checkJiangOnHalberdSlash(p(1), p(2), p(3), false)
end

function Testqiao_wu010_sunce:testJiangStillDrawsAsLaterTarget()
  checkJiangOnHalberdSlash(p(2), p(3), p(1), true)
end

function Testqiao_wu010_sunce:testYingyangChangesOwnPindianNumber()
  local room, player, other = FkTest.room, p(1), p(2)
  local own = give(player, "qiao__slash", Card.Spade, 5)
  local theirs = give(other, "qiao__jink", Card.Heart, 10)

  FkTest.setNextReplies(player, { FkTest.ReplyChooseCards({ own }) })
  FkTest.setNextReplies(other, { FkTest.ReplyChooseCards({ theirs }) })
  local data
  skill_test.withSkillRequests(room, YINGYANG, {
    askToChoice = function(self, who, params, original)
      if params.skill_name == YINGYANG then return PLUS end
      return original(self, who, params)
    end,
  }, function()
    data = inRoom(function() return player:pindian({ other }, "test") end)
  end)

  lu.assertEquals(data.fromCard.number, 8)
end

function Testqiao_wu010_sunce:testHunshangGrantsAndCleanupKeepsOriginalYingzi()
  local room, player = FkTest.room, p(1)
  inRoom(function()
    player.hp = 1
    room:handleAddLoseSkills(player, YINGZI, nil, false, true)
  end)

  local invoked, captured = 0, {}
  local probe = fk.CreateSkill { name = "#qiao_wu010_hunshang_probe" }
  probe:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, who, data)
      return who == player and data.phase == Player.Play
    end,
    on_refresh = function()
      captured.yinghun = player:hasSkill(YINGHUN)
      captured.yingzi = player:hasSkill(YINGZI)
      H.removeGeneral(player, true)
      captured.lostHunshang = not player:hasSkill(HUNSHANG)
      captured.stillYinghun = player:hasSkill(YINGHUN)
      captured.stillYingzi = player:hasSkill(YINGZI)
    end,
  })
  inRoom(function() room:addSkill(probe:createSkill()) end)

  skill_test.withSkillRequests(room, HUNSHANG, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == HUNSHANG then
        invoked = invoked + 1
        return true
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", {
        Player.Start, Player.Play,
      })):exec()
    end)
  end)

  lu.assertEquals(invoked, 1)
  lu.assertTrue(captured.yinghun)
  lu.assertTrue(captured.yingzi)
  lu.assertTrue(captured.lostHunshang)
  lu.assertTrue(captured.stillYinghun)
  lu.assertTrue(captured.stillYingzi)
  lu.assertFalse(player:hasSkill(YINGHUN))
  lu.assertTrue(player:hasSkill(YINGZI))
end

function Testqiao_wu010_sunce:testHunshangOutlivesOtherYingziSource()
  local room, me = FkTest.room, FkTest.room.players[1]
  local H = require "packages.hegemony.util"
  local hun, ying = "qiao__skill_wu010_3", "qiao__skill_wu005_1"
  local asked, beforeRemoval, afterRemoval, afterEnd = 0
  local watcher = fk.CreateSkill{ name = "#qiao_test_hunshang_yingzi" }
  watcher:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == me and player == me and data.phase == Player.Play
    end,
    on_refresh = function()
      beforeRemoval = me:hasSkill(ying)
      H.removeGeneral(me, false)
      afterRemoval = me:hasSkill(ying)
    end,
  })
  skill_test.withSkillRequests(room, hun, { askToSkillInvoke = function() asked = asked + 1; return true end }, function()
    inRoom(function()
      skill_test.installDualGenerals(room, me, { main = "qiao_heg__wu005", deputy = "qiao_heg__wu010", kingdom = "wu" })
      me.hp = 1
      room:addSkill(watcher:createSkill())
      GameEvent.Turn:create(TurnData:new(me, "game_rule", { Player.Start, Player.Play })):exec()
      afterEnd = me:hasSkill(ying)
    end)
  end)
  lu.assertEquals({ asked, beforeRemoval, afterRemoval, afterEnd }, { 1, true, true, false })
end

return { name = "qiao_wu010_sunce" }
