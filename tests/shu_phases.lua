-- 蜀势力阶段与濒死：观星、空城、涅槃、放权。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local GUANXING = "hanjin__skill_shu004_1"
local KONGCHENG = "hanjin__skill_shu004_2"
local NIEPAN = "hanjin__skill_shu010_2"
local FANGQUAN = "hanjin__skill_shu013_2"
local DEFAULT_KINGDOMS = { "shu", "shu", "shu", "shu", "shu", "shu", "shu", "shu" }

local function room() return FkTest.room end
local function p(n) return room().players[n] end
local function inRoom(fn) local r; FkTest.runInRoom(function() r = fn() end); return r end
local function grant(player, name) inRoom(function() player.room:handleAddLoseSkills(player, name, nil, false, true) end) end
local function revoke(player, name) inRoom(function() player.room:handleAddLoseSkills(player, "-" .. name, nil, false, true) end) end

local function clearCards(player)
  inRoom(function()
    local ids = player:getCardIds("hej")
    if #ids > 0 then room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false) end
  end)
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function setPlayPhase(player)
  inRoom(function() room().current = player; player.phase = Player.Play; room():setBanner("RoundCount", 1) end)
end

local function prepare()
  Fk.currentResponsePattern = nil
  local r = support.initHanjinRoom()
  inRoom(function() skill_test.installBlankGenerals(r, DEFAULT_KINGDOMS) end)
  return r
end

local function teardown()
  Fk.currentResponsePattern = nil
  support.clearRoom()
end

Testhanjin_shu_phases = { setup = prepare, tearDown = teardown }

function Testhanjin_shu_phases:testGuanxingAllBottomSchedulesFinishAndSurvivesLoss()
  local p1 = p(1)
  grant(p1, GUANXING)
  clearCards(p1)
  local calls = 0
  local old = room().askToGuanxing
  room().askToGuanxing = function(self, who, params)
    calls = calls + 1
    return { {}, params.cards }
  end
  FkTest.setNextReplies(p1, { "1" })
  inRoom(function()
    p1.phase = Player.Start
    room().logic:trigger(fk.EventPhaseStart, p1, PhaseData:new { who = p1, reason = "game_rule", phase = Player.Start })
  end)
  lu.assertEquals(calls, 1)
  lu.assertEquals(p1:getMark("hanjin__skill_shu004_1_finish-turn"), 1)
  revoke(p1, GUANXING)
  inRoom(function()
    p1.phase = Player.Finish
    room().logic:trigger(fk.EventPhaseStart, p1, PhaseData:new { who = p1, reason = "game_rule", phase = Player.Finish })
  end)
  room().askToGuanxing = old
  lu.assertEquals(calls, 2)
  lu.assertEquals(p1:getMark("hanjin__skill_shu004_1_finish-turn"), 0)
end

function Testhanjin_shu_phases:testKongchengNullifiesSlashUntilDrawNotObtain()
  local p1, p2 = p(1), p(2)
  inRoom(function()
    skill_test.installDualGenerals(room(), p1, { main = "hanjin__shu004", deputy = "hanjin__shu002", kingdom = "shu" })
  end)
  clearCards(p1)
  clearCards(p2)
  local junk = give(p1, "hanjin__jink", Card.Heart, 3)
  setPlayPhase(p1)
  FkTest.setNextReplies(p1, { "1" })
  inRoom(function() room():throwCard({ junk }, "test", p1, p1) end)
  lu.assertEquals(p1:getMark("hanjin__skill_shu004_2_kong"), 1)
  give(p1, "hanjin__peach", Card.Heart, 4)
  lu.assertEquals(p1:getMark("hanjin__skill_shu004_2_kong"), 1)
  inRoom(function() p1.hp = p1.maxHp end)
  local slash = give(p2, "hanjin__slash", Card.Spade, 8)
  setPlayPhase(p2)
  inRoom(function()
    room():useCard(UseCardData:new { from = p2, tos = { p1 }, card = Fk:getCardById(slash), extra_data = {} })
  end)
  lu.assertEquals(p1.hp, p1.maxHp)
  inRoom(function() room():drawCards(p1, 1, "test") end)
  lu.assertEquals(p1:getMark("hanjin__skill_shu004_2_kong"), 0)
end

function Testhanjin_shu_phases:testNiepanResetsDrawsAndRecovers()
  local p1 = p(1)
  grant(p1, NIEPAN)
  clearCards(p1)
  give(p1, "hanjin__jink", Card.Heart, 3)
  inRoom(function()
    p1.hp = 1
    p1.faceup = false
    p1.chained = true
    local equip = room():printCard("hanjin__eight_diagram", Card.Spade, 2)
    room():moveCardIntoEquip(p1, equip.id, "test", true, p1)
  end)
  -- 触发排序请求先要技能 ID，随后才是技能 invoke 的 "1"。
  FkTest.setNextReplies(p1, { NIEPAN, "1" })
  local oldPeach = room().askToPeach
  room().askToPeach = function() return nil end
  inRoom(function() room():loseHp(p1, 1, "test") end)
  room().askToPeach = oldPeach
  lu.assertEquals(p1.hp, 3)
  lu.assertTrue(p1.faceup)
  lu.assertFalse(p1.chained)
  lu.assertEquals(#p1:getCardIds("h"), 3)
  lu.assertEquals(#p1:getCardIds("e"), 0)
end

-- 跳过出牌阶段后，失去技能也保留回合末授予额外回合的机会。
function Testhanjin_shu_phases:testFangquanSkipsPlayAndPaysForExtraTurn()
  local p1, p2 = p(1), p(2)
  grant(p1, FANGQUAN)
  clearCards(p1)
  local hand = give(p1, "hanjin__jink", Card.Heart, 3)
  inRoom(function() room().current = p1; p1.phase = Player.Play end)
  local data = PhaseData:new { who = p1, reason = "game_rule", phase = Player.Play }
  skill_test.withSkillRequests(room(), FANGQUAN, {
    askToSkillInvoke = function() return true end,
  }, function()
    inRoom(function() room().logic:trigger(fk.EventPhaseChanging, p1, data) end)
  end)
  lu.assertTrue(data.skipped)
  lu.assertEquals(p1:getMark("hanjin__skill_shu013_2_turn-turn"), 1)
  revoke(p1, FANGQUAN)
  skill_test.withSkillRequests(room(), FANGQUAN, {
    askToChoosePlayers = function() return { p2 } end,
    askToDiscard = function(self, who, params)
      room():throwCard({hand}, FANGQUAN, who, who)
      return {hand}
    end,
  }, function()
    inRoom(function() room().logic:trigger(fk.TurnEnd, p1, TurnData:new(p1, "game_rule", {Player.Start})) end)
  end)
  lu.assertEquals(#p1:getCardIds("h"), 0)
  lu.assertEquals(#room().extra_turn_list, 1)
  lu.assertIs(room().extra_turn_list[1].who, p2)
  room().extra_turn_list = {} -- 清理已验收的待执行回合，避免夹具结束时启动正常回合。
end

return { name = "hanjin_shu_phases" }
