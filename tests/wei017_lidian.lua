-- WEI017 李典：恂恂、忘隙定向验收。
-- 规则依据：docs/rules/generals/wei017-lidian.md。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local LIDIAN = "qiao_heg__wei017"
local XUNXUN = "qiao__skill_wei017_1"
local WANGXI = "qiao__skill_wei017_2"
local BLANK_DEPUTY = "qiao_test__wei_2"

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
      "wei", "wei", "wei", "wei", "wei", "wei", "wei", "wei",
    })
    for _, player in ipairs(room.players) do clearCards(player) end
    skill_test.installDualGenerals(room, room.players[1], {
      main = LIDIAN,
      deputy = BLANK_DEPUTY,
      kingdom = "wei",
    })
  end)
  return room
end

Testqiao_wei017_lidian = {
  setup = prepare,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

local function revoke(player, name)
  inRoom(function()
    player.room:handleAddLoseSkills(player, "-" .. name, nil, false, true)
  end)
end

function Testqiao_wei017_lidian:testFormalRegistration()
  local pack = assert(Fk.packages.qiao_zhenshi)
  local entry = assert(table.find(ZHEN_SHI.generals, function(data)
    return data.id == LIDIAN
  end), "missing Li Dian data entry")
  lu.assertEquals(entry.number, "WEI017")
  local general = assert(Fk.generals[LIDIAN])
  lu.assertIs(general.package, pack)
  lu.assertEquals(general.trueName, "李典")
  lu.assertEquals(general.kingdom, "wei")
  lu.assertEquals(general.maxHp, 3)
  lu.assertEquals(general.gender, General.Male)
  lu.assertTrue(general:isCompanionWith(Fk.generals["qiao_heg__wei016"]))
  lu.assertTrue(table.contains(general:getSkillNameList(), XUNXUN))
  lu.assertTrue(table.contains(general:getSkillNameList(), WANGXI))
  lu.assertNotEquals(general, Fk.generals["ld__lidian"])
  inRoom(function()
    lu.assertTrue(Fk:canUseGeneral(LIDIAN))
  end)
end

function Testqiao_wei017_lidian:testXunxunOwnTurnFourCardsExactlyTwoBottom()
  local room, player = FkTest.room, p(1)
  local invoked, calls = 0, {}

  -- 出牌阶段再摸一张：同一回合第二次摸牌不得再次触发恂恂。
  local probe = fk.CreateSkill { name = "#qiao_wei017_draw_probe" }
  probe:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, who, data)
      return target == player and who == player and data.phase == Player.Play
    end,
    on_refresh = function()
      player:drawCards(1, "test")
    end,
  })
  inRoom(function() room:addSkill(probe:createSkill()) end)

  skill_test.withSkillRequests(room, XUNXUN, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == XUNXUN then
        invoked = invoked + 1
        return true
      end
      return original(self, who, params)
    end,
    askToGuanxing = function(self, who, params, original)
      if params.skill_name ~= XUNXUN then
        return original(self, who, params)
      end
      lu.assertIs(who, player)
      table.insert(calls, {
        count = #params.cards,
        top = params.top_limit,
        bottom = params.bottom_limit,
        cards = table.simpleClone(params.cards),
      })
      return {
        top = { params.cards[1], params.cards[2] },
        bottom = { params.cards[3], params.cards[4] },
      }
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", {
        Player.Draw, Player.Play,
      })):exec()
    end)
  end)

  lu.assertEquals(invoked, 1)
  lu.assertEquals(#calls, 1)
  lu.assertEquals(calls[1].count, 4)
  lu.assertEquals(calls[1].top, { 2, 2 })
  lu.assertEquals(calls[1].bottom, { 2, 2 })
  lu.assertEquals(#player:getCardIds(Player.Hand), 3)
end

function Testqiao_wei017_lidian:testXunxunOutsideTurnTwoCardsNoBottomLimit()
  local room, player, current = FkTest.room, p(1), p(2)
  local invoked, calls = 0, {}

  local probe = fk.CreateSkill { name = "#qiao_wei017_outside_probe" }
  probe:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, who, data)
      return target == current and who == current and data.phase == Player.Play
    end,
    on_refresh = function()
      room.current = current
      player:drawCards(1, "test")
    end,
  })
  inRoom(function() room:addSkill(probe:createSkill()) end)

  skill_test.withSkillRequests(room, XUNXUN, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == XUNXUN then
        invoked = invoked + 1
        return true
      end
      return original(self, who, params)
    end,
    askToGuanxing = function(self, who, params, original)
      if params.skill_name ~= XUNXUN then
        return original(self, who, params)
      end
      table.insert(calls, {
        count = #params.cards,
        top = params.top_limit,
        bottom = params.bottom_limit,
        cards = table.simpleClone(params.cards),
      })
      return { top = { params.cards[1] }, bottom = { params.cards[2] } }
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(current, "game_rule", {
        Player.Play,
      })):exec()
    end)
  end)

  lu.assertEquals(invoked, 1)
  lu.assertEquals(#calls, 1)
  lu.assertEquals(calls[1].count, 2)
  lu.assertNil(calls[1].top)
  lu.assertNil(calls[1].bottom)
  lu.assertEquals(#player:getCardIds(Player.Hand), 1)
end

function Testqiao_wei017_lidian:testXunxunSeesDrawBeforeLateAcquire()
  local room, player = FkTest.room, p(1)
  revoke(player, XUNXUN)

  local invoked, calls = 0, 0
  local probe = fk.CreateSkill { name = "#qiao_wei017_late_probe" }
  probe:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, who, data)
      return target == player and who == player and data.phase == Player.Play
    end,
    on_refresh = function()
      room:handleAddLoseSkills(player, XUNXUN, nil, false, true)
      player:drawCards(1, "test")
    end,
  })
  inRoom(function() room:addSkill(probe:createSkill()) end)

  skill_test.withSkillRequests(room, XUNXUN, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == XUNXUN then
        invoked = invoked + 1
        return true
      end
      return original(self, who, params)
    end,
    askToGuanxing = function(self, who, params, original)
      if params.skill_name == XUNXUN then
        calls = calls + 1
        return { top = params.cards, bottom = {} }
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      GameEvent.Turn:create(TurnData:new(player, "game_rule", {
        Player.Draw, Player.Play,
      })):exec()
    end)
  end)

  lu.assertEquals(invoked, 0)
  lu.assertEquals(calls, 0)
  lu.assertEquals(#player:getCardIds(Player.Hand), 3)
end

function Testqiao_wei017_lidian:testWangxiOncePerDamageEventNotPerPoint()
  local room, player, other = FkTest.room, p(1), p(2)
  revoke(player, XUNXUN)

  local invoked = 0
  local function runDamage(from, to, damage)
    skill_test.withSkillRequests(room, WANGXI, {
      askToSkillInvoke = function(self, who, params, original)
        if params.skill_name == WANGXI then
          invoked = invoked + 1
          return true
        end
        return original(self, who, params)
      end,
    }, function()
      inRoom(function()
        room:damage { from = from, to = to, damage = damage, skillName = "test" }
      end)
    end)
  end

  -- 一次2点伤害仍只触发一次，双方各摸1。
  runDamage(player, other, 2)
  lu.assertEquals(invoked, 1)
  lu.assertEquals(#player:getCardIds(Player.Hand), 1)
  lu.assertEquals(#other:getCardIds(Player.Hand), 1)

  -- 李典受到其他角色伤害的分支。
  runDamage(other, player, 1)
  lu.assertEquals(invoked, 2)
  lu.assertEquals(#player:getCardIds(Player.Hand), 2)
  lu.assertEquals(#other:getCardIds(Player.Hand), 2)
end

return { name = "qiao_wei017_lidian" }
