-- WU020 徐盛：疑城延迟弃牌、破军移出/回合末回归真实主流程。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local XUSHENG = "qiao_heg__wu020"
local YICHENG = "qiao__skill_wu020_1"
local POJUN = "qiao__skill_wu020_2"
local DELAY = "qiao__skill_wu020_1-delay"

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
--- 必须只在外层 inRoom 的房间协同程内调用，禁止嵌套。
local function clear(player)
  local ids = player:getCardIds("he")
  if #ids > 0 then
    FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove,
      "test", nil, false)
  end
end

Testqiao_wu020_xusheng = {
  setup = function()
    Fk.currentResponsePattern = nil
    local room = support.initQiaoRoom()
    inRoom(function()
      skill_test.installBlankGenerals(room, {
        "wu", "wu", "wu", "wu", "qun", "qun", "qun", "qun",
      })
      for _, player in ipairs(room.players) do clear(player) end
      room:handleAddLoseSkills(room.players[1], YICHENG, nil, false, false)
      room:handleAddLoseSkills(room.players[1], POJUN, nil, false, false)
      lu.assertTrue(room.players[1]:hasSkill(YICHENG))
      lu.assertTrue(room.players[1]:hasSkill(POJUN))
      room:setBanner("RoundCount", 1)
    end)
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_wu020_xusheng:testYichengDrawsThenDelayedDiscard()
  local room, player, ally, source = FkTest.room, p(1), p(2), p(3)
  local slash = give(source, "qiao__slash", Card.Spade, 2)
  local spare = give(ally, "qiao__slash", Card.Heart, 3)
  inRoom(function()
    room.current = source
    player:revealGeneral(false)
  end)
  skill_test.withSkillRequests(room, YICHENG, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == YICHENG then return true end
      return original(self, who, params)
    end,
    askToChoice = function(self, who, params, original)
      if params.skill_name == YICHENG then return DELAY end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:useCard { from = source, tos = { ally }, card = Fk:getCardById(slash) }
    end)
  end)
  lu.assertTrue(table.contains(ally:getCardIds("h"), spare))
  skill_test.withSkillRequests(room, "qiao__wu020_yicheng_rule", {
    askToDiscard = function(self, who, params, original)
      if params.skill_name == "qiao__wu020_yicheng_rule" then
        self:throwCard({ spare }, "qiao__wu020_yicheng_rule", who, who)
        return { spare }
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.TurnEnd, source, TurnData:new(source, "game_rule", { Player.Start }))
    end)
  end)
  lu.assertFalse(table.contains(ally:getCardIds("h"), spare))
end

function Testqiao_wu020_xusheng:testPojunRemovesCardsAndReturnsAtTurnEnd()
  local room, player, target = FkTest.room, p(1), p(2)
  local slash = give(player, "qiao__slash", Card.Spade, 2)
  local first = give(target, "qiao__jink", Card.Heart, 3)
  local second = give(target, "qiao__jink", Card.Club, 4)
  inRoom(function()
    room.current = player
    player.phase = Player.Play
    player:revealGeneral(false)
  end)
  skill_test.withSkillRequests(room, POJUN, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == POJUN then return true end
      return original(self, who, params)
    end,
    askToChooseCards = function(self, who, params, original)
      if params.skill_name == POJUN then return { first, second } end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:useCard { from = player, tos = { target }, card = Fk:getCardById(slash) }
    end)
  end)
  lu.assertEquals(room:getCardArea(first), Card.Void)
  lu.assertEquals(room:getCardArea(second), Card.Void)
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, player, TurnData:new(player, "game_rule", { Player.Start }))
  end)
  lu.assertEquals(room:getCardArea(first), Card.PlayerHand)
  lu.assertEquals(room:getCardArea(second), Card.PlayerHand)
end

return { name = "qiao_wu020_xusheng" }
