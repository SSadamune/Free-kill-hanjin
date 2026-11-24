-- SHU021 糜夫人：闺秀、勇决及所授存嗣主流程。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local MIFUREN = "qiao_heg__shu021"
local GUIXIU = "qiao__skill_shu021_1"
local YONGJUE = "qiao__skill_shu021_2"
local CUNSI = "qiao__skill_shu021_3"

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
--- 只在已运行的房间协同程内调用，不得再嵌套 inRoom。
local function clear(player)
  local ids = player:getCardIds("he")
  if #ids > 0 then
    FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
      "test", nil, false)
  end
end

Testqiao_shu021_mifuren = {
  setup = function()
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
        "shu", "shu", "shu", "shu", "qun", "qun", "qun", "qun",
      })
      skill_test.installDualGenerals(room, room.players[1], {
        main = MIFUREN, deputy = "qiao_test__shu_2", kingdom = "shu",
      })
      for _, player in ipairs(room.players) do clear(player) end
      room:setBanner("RoundCount", 1)
    end)
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_shu021_mifuren:testFormalRegistrationAndGuixiuReveal()
  local room, player = FkTest.room, p(1)
  inRoom(function()
    player:hideGeneral(false)
    local before = #player:getCardIds("h")
    player:revealGeneral(false)
    lu.assertEquals(#player:getCardIds("h"), before + 2, "糜夫人将牌明置后摸2")
  end)
  lu.assertNotNil(Fk.generals[MIFUREN])
  lu.assertTrue(table.contains(Fk.generals[MIFUREN]:getSkillNameList(), GUIXIU))
  lu.assertTrue(table.contains(Fk.generals[MIFUREN]:getSkillNameList(), YONGJUE))
  inRoom(function() lu.assertTrue(Fk:canUseGeneral(MIFUREN)) end)
end

function Testqiao_shu021_mifuren:testGuixiuFinishDrawsWhenUnhurt()
  local player = p(1)
  inRoom(function()
    player.hp = player.maxHp
    local before = #player:getCardIds("h")
    player.room.logic:trigger(fk.EventPhaseStart, player, PhaseData:new {
      who = player, reason = "game_rule", phase = Player.Finish,
    })
    lu.assertEquals(#player:getCardIds("h"), before + 2, "结束阶段未受伤摸2")
  end)
end

function Testqiao_shu021_mifuren:testYongjueRemovesCardGrantsCompanionAndCunsi()
  local room, player, target = FkTest.room, p(1), p(2)
  inRoom(function()
    require("packages.hegemony.util").addHegMark(target, "companion")
    room.current = player
    player.phase = Player.Play
  end)
  local companionBefore = target:getMark("@!!companion")
  local pendingBefore = target:getMark("CompanionEffect")
  skill_test.withSkillRequests(room, YONGJUE, {
    askToChoosePlayers = function(self, who, params, original)
      if params.skill_name == YONGJUE then return { target } end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      local skill = Fk.skills[YONGJUE]
      lu.assertTrue(skill:canUse(player))
      room:useSkill(player, skill, function()
        skill:onUse(room, { from = player, tos = { target } })
      end, { from = player, tos = { target } })
    end)
  end)
  local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
  lu.assertNotEquals(Exchange.actualGeneral(player, false), MIFUREN,
    "勇决应移除糜夫人将牌（允许自动转翼从）")
  lu.assertEquals(target:getMark("@!!companion"), companionBefore + 1)
  lu.assertEquals(target:getMark("CompanionEffect"), pendingBefore)
  lu.assertTrue(target:hasSkill("companion_skill&"))
  lu.assertTrue(target:hasSkill(CUNSI))
end

function Testqiao_shu021_mifuren:testCunsiSlashInsideTurnAndPeachOutsideTurn()
  local room, player, source = FkTest.room, p(1), p(2)
  inRoom(function()
    room:handleAddLoseSkills(player, CUNSI, nil, false, true)
    player:revealGeneral(false)
    lu.assertTrue(player:hasSkill(CUNSI))
  end)
  local slash = give(player, "qiao__slash", Card.Spade, 2)
  skill_test.withSkillRequests(room, CUNSI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == CUNSI then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room.current = player
      player.phase = Player.Play
      room:useCard { from = player, tos = { source }, card = Fk:getCardById(slash) }
    end)
  end)
  lu.assertTrue(table.contains(player:getCardIds("h"), slash),
    "回合内使用杀后获得该杀；area=" .. tostring(room:getCardArea(slash)))

  local peach = give(player, "qiao__peach", Card.Heart, 3)
  skill_test.withSkillRequests(room, CUNSI, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == CUNSI then return true end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room.current = source
      room:useCard { from = player, tos = { player }, card = Fk:getCardById(peach) }
    end)
  end)
  lu.assertTrue(table.contains(player:getCardIds("h"), peach), "回合外使用桃后获得该桃")
end

function Testqiao_shu021_mifuren:testGuixiuIndependentWindowsInOneTurn()
  local room, owner = FkTest.room, p(1)
  local gains = {}
  local skel = fk.CreateSkill { name = "#test_guixiu_repeat_windows" }
  skel:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == owner and player == owner and (data.phase == Player.Start or data.phase == Player.Draw)
    end,
    on_refresh = function()
      local hand = owner:getHandcardNum()
      owner:hideGeneral(false)
      owner:revealGeneral(false)
      table.insert(gains, owner:getHandcardNum() - hand)
    end,
  })
  local helper = skel:createSkill()
  Fk.skills[helper.name] = helper
  inRoom(function()
    room:addSkill(helper)
    GameEvent.Turn:create(TurnData:new(owner, "game_rule", { Player.Start, Player.Draw })):exec()
  end)
  lu.assertEquals(gains, { 2, 2 })
end

function Testqiao_shu021_mifuren:testGuixiuSurvivesHidingBeforeReward()
  local room, owner = FkTest.room, p(1)
  inRoom(function() owner:hideGeneral(false) end)
  local skel = fk.CreateSkill { name = "#test_guixiu_hide_at_reveal" }
  skel:addEffect(fk.GeneralShown, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == owner and player == owner and data.m == MIFUREN
    end,
    on_refresh = function() owner:hideGeneral(false) end,
  })
  local helper = skel:createSkill()
  Fk.skills[helper.name] = helper
  local hand = owner:getHandcardNum()
  inRoom(function() room:addSkill(helper); owner:revealGeneral(false) end)
  lu.assertEquals(owner.general, "anjiang")
  lu.assertEquals(owner:getHandcardNum(), hand + 2)
end

local function revealInsideOneSkill(killBeforeExit)
  local room, owner = FkTest.room, p(1)
  local gained
  local skel = fk.CreateSkill { name = "#test_guixiu_deferred_" .. tostring(killBeforeExit) }
  skel:addEffect(fk.EventPhaseStart, {
    global = true,
    can_trigger = function(self, event, target, player, data)
      return target == owner and player == owner and data.phase == Player.Start
    end,
    on_cost = Util.TrueFunc,
    on_use = function()
      local hand = owner:getHandcardNum()
      owner:hideGeneral(false)
      owner:revealGeneral(false)
      owner:hideGeneral(false)
      owner:revealGeneral(false)
      owner:hideGeneral(false)
      gained = owner:getHandcardNum() - hand
      if killBeforeExit then room:killPlayer { who = owner } end
    end,
  })
  local helper = skel:createSkill()
  Fk.skills[helper.name] = helper
  local hand = owner:getHandcardNum()
  inRoom(function()
    room:addSkill(helper)
    GameEvent.Turn:create(TurnData:new(owner, "game_rule", { Player.Start })):exec()
  end)
  lu.assertEquals(gained, 0)
  if killBeforeExit then
    lu.assertTrue(owner.dead)
    lu.assertEquals(owner:getHandcardNum(), 0)
  else
    lu.assertEquals(owner:getHandcardNum(), hand + 2)
  end
end

function Testqiao_shu021_mifuren:testRepeatedRevealWithinOneWindowPaysOnce()
  revealInsideOneSkill(false)
end

function Testqiao_shu021_mifuren:testDeathBeforeRevealWindowSkipsDraw()
  revealInsideOneSkill(true)
end

function Testqiao_shu021_mifuren:testCombinedRevealPaysOnlyForActuallyHiddenMifuren()
  local room, owner = FkTest.room, p(1)
  local gains = {}
  local skel = fk.CreateSkill { name = "#test_guixiu_combined" }
  skel:addEffect(fk.EventPhaseStart, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == owner and player == owner and data.phase == Player.Start
    end,
    on_refresh = function()
      owner:hideGeneral(true)
      local before = owner:getHandcardNum()
      owner:revealGenerals()
      table.insert(gains, owner:getHandcardNum() - before)
      owner:hideGeneral(false)
      owner:hideGeneral(true)
      before = owner:getHandcardNum()
      owner:revealGenerals()
      table.insert(gains, owner:getHandcardNum() - before)
    end,
  })
  local helper = skel:createSkill()
  Fk.skills[helper.name] = helper
  inRoom(function()
    room:addSkill(helper)
    GameEvent.Turn:create(TurnData:new(owner, "game_rule", { Player.Start })):exec()
  end)
  lu.assertEquals(gains, { 0, 2 })
end

return { name = "qiao_shu021_mifuren" }
