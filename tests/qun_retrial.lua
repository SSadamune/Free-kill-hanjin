-- QUN010 张角 · 鬼道：真实 room:judge → responseCard → changeJudge(exchange) 集成。
-- 输入类请求（是否发动、选哪张牌）使用测试桩，判定与打出流程均为真实实现。
-- 本文件已加入 tests/all.lua，纳入默认国战套件。
local support = __dofile("../../../tests/support/hegemony.lua")

local SKILL = "qiao__skill_qun010_2"
local DEFAULT_KINGDOMS = { "qun", "qun", "wei", "wei", "shu", "shu", "wu", "wu" }

local function room() return FkTest.room end
local function p(n) return room().players[n] end

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function grant(player, name)
  inRoom(function() player.room:handleAddLoseSkills(player, name, nil, false, true) end)
end

local function clearHand(player)
  inRoom(function()
    local ids = player:getCardIds("he")
    if #ids > 0 then
      room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end)
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 2)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

--- 把一张牌放在牌堆顶，作为本次判定的原判定牌。
local function seedJudgeCard(name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Heart, number or 9)
    table.removeOne(room().draw_pile, card.id)
    table.insert(room().draw_pile, 1, card.id)
    room().card_place[card.id] = Card.DrawPile
    id = card.id
  end)
  return id
end

local function runJudge(who)
  local judge = { who = who, reason = "qiao_test_judge", pattern = "." }
  local ok, err = pcall(function() inRoom(function() room():judge(judge) end) end)
  assert(ok, err)
  return judge
end

Testqiao_qun_retrial = { tearDown = support.clearRoom }

Testqiao_qun_retrial.setup = function()
  local r = support.initQiaoRoom()
  inRoom(function()
    local skill_test = __dofile("../../../tests/support/skill_test.lua")
    skill_test.installBlankGenerals(r, DEFAULT_KINGDOMS)
  end)
end

function Testqiao_qun_retrial:testGuidaoBlackCardReplacesAndObtainsOldJudge()
  local p1, p2 = p(1), p(2)
  grant(p2, SKILL)
  clearHand(p2)
  local chosen = give(p2, "qiao__slash", Card.Spade, 2)
  local original = seedJudgeCard("qiao__jink", Card.Heart, 9)

  local oldInvoke, oldAsk = room().askToSkillInvoke, room().askToCards
  room().askToSkillInvoke = function() return true end
  room().askToCards = function() return { chosen } end
  local ok, judge = pcall(function() return runJudge(p1) end)
  room().askToSkillInvoke, room().askToCards = oldInvoke, oldAsk
  assert(ok, judge)

  lu.assertNotNil(judge and judge.card or nil)
  lu.assertEquals(judge.card.id, chosen)
  -- 打出的黑色牌离开手牌；原判定牌因 exchange=true 归张角所有。
  lu.assertFalse(table.contains(p2:getCardIds("h"), chosen))
  lu.assertTrue(table.contains(p2:getCardIds("h"), original))
end

function Testqiao_qun_retrial:testGuidaoRedCardCannotReplace()
  local p1, p2 = p(1), p(2)
  grant(p2, SKILL)
  clearHand(p2)
  local chosen = give(p2, "qiao__slash", Card.Heart, 2)
  local original = seedJudgeCard("qiao__jink", Card.Spade, 9)

  local invoked = 0
  local oldInvoke, oldAsk = room().askToSkillInvoke, room().askToCards
  room().askToSkillInvoke = function() invoked = invoked + 1; return true end
  room().askToCards = function() return { chosen } end
  local ok, judge = pcall(function() return runJudge(p1) end)
  room().askToSkillInvoke, room().askToCards = oldInvoke, oldAsk
  assert(ok, judge)

  lu.assertEquals(invoked, 0)
  lu.assertEquals(judge.card.id, original)
  lu.assertTrue(table.contains(p2:getCardIds("h"), chosen))
end

return { name = "qiao_qun_retrial" }
