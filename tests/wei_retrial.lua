-- WEI002 司马懿 · 鹰视：真实 room:judge → responseCard → changeJudge 集成。
-- 输入类请求（是否发动、选哪张牌）用测试桩，其余判定与打出流程均为真实实现。
local support = __dofile("../../../tests/support/hegemony.lua")

local SKILL = "hanjin__skill_wei002_2"

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
    local card = room():printCard(name, suit or Card.Heart, number or 2)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

Testhanjin_wei_retrial = { setup = support.initHanjinRoom, tearDown = support.clearRoom }

function Testhanjin_wei_retrial:testRealJudgeCompletesWithRespondedCard()
  local p1, p2 = p(1), p(2)
  grant(p2, SKILL)
  clearHand(p2)
  local chosen = give(p2, "slash", Card.Heart, 2)

  local oldInvoke, oldAsk = room().askToSkillInvoke, room().askToCards
  room().askToSkillInvoke = function() return true end
  room().askToCards = function() return { chosen } end

  local judge = { who = p1, reason = "hanjin_test_judge", pattern = "." }
  local ok, err = pcall(function() inRoom(function() room():judge(judge) end) end)
  room().askToSkillInvoke, room().askToCards = oldInvoke, oldAsk
  assert(ok, err)

  -- 真实判定完成：改判后的牌成为最终判定牌（真实 responseCard + changeJudge）。
  lu.assertNotNil(judge.card)
  lu.assertEquals(judge.card.id, chosen)
  lu.assertFalse(table.contains(p2:getCardIds("h"), chosen))
end

function Testhanjin_wei_retrial:testProhibitedCardCannotBePlayed()
  local p1, p2 = p(1), p(2)
  grant(p2, SKILL)
  clearHand(p2)
  local chosen = give(p2, "slash", Card.Heart, 2)
  local oldProhibit = p2.prohibitResponse
  p2.prohibitResponse = function() return true end

  local oldInvoke, oldAsk = room().askToSkillInvoke, room().askToCards
  room().askToSkillInvoke = function() return true end
  room().askToCards = function() return { chosen } end
  local judge = { who = p1, reason = "hanjin_test_judge", pattern = "." }
  local ok, err = pcall(function() inRoom(function() room():judge(judge) end) end)
  p2.prohibitResponse = oldProhibit
  room().askToSkillInvoke, room().askToCards = oldInvoke, oldAsk
  assert(ok, err)
  lu.assertNotEquals(judge.card and judge.card.id, chosen)
  lu.assertTrue(table.contains(p2:getCardIds("h"), chosen))
end

return { name = "hanjin_wei_retrial" }
