-- 蜀势力第六批：铁骑。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local TIEQI = "qiao__skill_shu006_2"
local DEFAULT_KINGDOMS = { "shu", "shu", "shu", "shu", "shu", "shu", "shu", "shu" }
local function room() return FkTest.room end
local function p(n) return room().players[n] end
local function inRoom(fn) local r; FkTest.runInRoom(function() r = fn() end); return r end
local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end
local function clearCards(player)
  inRoom(function()
    local ids = player:getCardIds("hej")
    if #ids > 0 then room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false) end
  end)
end
local function prepare()
  Fk.currentResponsePattern = nil
  local r = support.initQiaoRoom()
  inRoom(function() skill_test.installBlankGenerals(r, DEFAULT_KINGDOMS) end)
  return r
end
local function teardown() Fk.currentResponsePattern = nil; support.clearRoom() end

Testqiao_shu_tieqi = { setup = prepare, tearDown = teardown }

local function setupFighters()
  local p1, p2 = p(1), p(2)
  inRoom(function()
    skill_test.installDualGenerals(room(), p1, { main = "qiao_heg__shu006", deputy = "qiao_heg__shu002", kingdom = "shu" })
    skill_test.installDualGenerals(room(), p2, { main = "qiao_heg__shu014", deputy = "qiao_heg__shu001", kingdom = "shu" })
  end)
  return p1, p2
end

function Testqiao_shu_tieqi:testTieqiInvalidatesSelectedPositionAndAllowsJinkAfterFullDiscard()
  local p1, p2 = setupFighters()
  clearCards(p1)
  clearCards(p2)
  local slash = give(p1, "qiao__slash", Card.Spade, 8)
  local heart1 = give(p2, "qiao__jink", Card.Heart, 3)
  local heart2 = give(p2, "qiao__peach", Card.Heart, 4)
  local spadeJink = give(p2, "qiao__jink", Card.Spade, 5)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p2.hp = p2.maxHp
    room():moveCardTo(room():printCard("qiao__jink", Card.Heart, 6), Card.DrawPile)
  end)
  local options
  FkTest.setRoomBreakpoint(p1, "AskForOptions", function(data)
    if data[5] == TIEQI then options = table.simpleClone(data[1]) end
    return false
  end)
  FkTest.setNextReplies(p1, { { "#qiao__skill_shu006_2-main" } })
  FkTest.setNextReplies(p2, { FkTest.ReplyCard(Fk:getCardById(spadeJink)) })
  skill_test.withSkillRequests(room(), TIEQI, {
    askToSkillInvoke = function() error("铁骑应直接询问武将牌位置") end,
    askToDiscard = function(self, player, params, original)
      if params.skill_name == TIEQI then
        lu.assertTrue(params.skip)
        return { heart1, heart2 }
      end
      return original(self, player, params)
    end,
  }, function()
    inRoom(function()
      room():useCard(UseCardData:new {
        from = p1, tos = { p2 }, card = Fk:getCardById(slash), extra_data = {},
      })
    end)
  end)
  lu.assertEquals(options, { "#qiao__skill_shu006_2-main", "#qiao__skill_shu006_2-deputy" })
  lu.assertEquals(p2.hp, p2.maxHp) -- 弃干净后仍可用黑桃闪响应
  lu.assertFalse(p2:hasSkill("qiao__skill_shu014_2")) -- 主将再起失效
  lu.assertTrue(p2:hasSkill("qiao__skill_shu014_1")) -- 锁定祸首不受影响
  lu.assertTrue(p2:hasSkill("qiao__skill_shu001_1")) -- 未选副将不受影响
end

function Testqiao_shu_tieqi:testTieqiHiddenDeputySelectedAndStillInvalidAfterReveal()
  local p1, p2 = setupFighters()
  clearCards(p1)
  clearCards(p2)
  local slash = give(p1, "qiao__slash", Card.Spade, 8)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p2.deputyGeneral = "anjiang"
    room():setPlayerMark(p2, "__heg_deputy", "qiao_heg__shu001")
    room():moveCardTo(room():printCard("qiao__jink", Card.Heart, 6), Card.DrawPile)
  end)
  FkTest.setNextReplies(p1, { TIEQI })
  skill_test.withSkillRequests(room(), TIEQI, {
    askToSkillInvoke = function() error("铁骑应直接询问武将牌位置") end,
    askToOptions = function(self, player, params, original)
      if params.skill_name == TIEQI then return { "#qiao__skill_shu006_2-deputy" } end
      return original(self, player, params)
    end,
    askToDiscard = function(self, player, params, original)
      if params.skill_name == TIEQI then return {} end
      return original(self, player, params)
    end,
  }, function()
    inRoom(function()
      room():useCard(UseCardData:new { from = p1, tos = { p2 }, card = Fk:getCardById(slash), extra_data = {} })
    end)
  end)
  lu.assertFalse(p2:hasSkill("qiao__skill_shu001_1")) -- 暗副将被选后失效
  lu.assertTrue(p2:hasSkill("qiao__skill_shu014_1")) -- 主将锁定不受影响
  -- 后续明置仍依据同一位置记录失效。
  inRoom(function() p2.deputyGeneral = "qiao_heg__shu001" end)
  lu.assertFalse(p2:hasSkill("qiao__skill_shu001_1"))
end

function Testqiao_shu_tieqi:testTieqiNoMatchingCardCannotRespond()
  local p1, p2 = setupFighters()
  clearCards(p1)
  clearCards(p2)
  local slash = give(p1, "qiao__slash", Card.Spade, 8)
  local spadeJink = give(p2, "qiao__jink", Card.Spade, 5)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p2.hp = p2.maxHp
    room():moveCardTo(room():printCard("qiao__jink", Card.Heart, 6), Card.DrawPile)
  end)
  FkTest.setNextReplies(p1, { TIEQI })
  FkTest.setNextReplies(p2, { FkTest.ReplyCard(Fk:getCardById(spadeJink)) })
  skill_test.withSkillRequests(room(), TIEQI, {
    askToSkillInvoke = function() error("铁骑应直接询问武将牌位置") end,
    askToOptions = function(self, player, params, original)
      if params.skill_name == TIEQI then return { "#qiao__skill_shu006_2-main" } end
      return original(self, player, params)
    end,
  }, function()
    inRoom(function()
      room():useCard(UseCardData:new { from = p1, tos = { p2 }, card = Fk:getCardById(slash), extra_data = {} })
    end)
  end)
  lu.assertEquals(p2.hp, p2.maxHp - 1) -- 无同花色手牌，不能支付，不能闪
end

return { name = "qiao_shu_tieqi" }
