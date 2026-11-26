-- 蜀势力第四批：祸首、再起、巨象、烈刃。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")

local HUOSHOU = "qiao__skill_shu014_1"
local ZAIQI = "qiao__skill_shu014_2"
local JUXIANG = "qiao__skill_shu015_1"
local LIEHEN = "qiao__skill_shu015_2"
local NANMAN = "qiao__savage_assault"

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

Testqiao_shu_savage = { setup = prepare, tearDown = teardown }

function Testqiao_shu_savage:testHuoshouNanmanSourceAndImmunity()
  local p1, p2, p3 = p(1), p(2), p(3)
  inRoom(function()
    skill_test.installDualGenerals(room(), p1, { main = "qiao_heg__shu014", deputy = "qiao_heg__shu002", kingdom = "shu" })
  end)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  local nanman = give(p2, NANMAN, Card.Club, 7)
  inRoom(function() p1.hp = p1.maxHp; p3.hp = p3.maxHp end)
  local sources = {}
  local oldDamage = room().damage
  room().damage = function(self, data)
    local ok = oldDamage(self, data)
    table.insert(sources, data.from)
    return ok
  end
  inRoom(function()
    room():useCard(UseCardData:new {
      from = p2, tos = { p1, p3 }, card = Fk:getCardById(nanman), extra_data = {},
    })
  end)
  room().damage = oldDamage
  lu.assertEquals(p1.hp, p1.maxHp) -- 南蛮对祸首无效
  lu.assertEquals(p3.hp, p3.maxHp - 1)
  lu.assertEquals(#sources, 1)
  lu.assertIs(sources[1], p1) -- 伤害来源为祸首，而不是使用者 p2
end

function Testqiao_shu_savage:testZaiqiRedDiscardChoices()
  local p1, p2, p3 = p(1), p(2), p(3)
  inRoom(function()
    skill_test.installDualGenerals(room(), p1, { main = "qiao_heg__shu014", deputy = "qiao_heg__shu002", kingdom = "shu" })
  end)
  for _, q in ipairs({ p1, p2, p3 }) do clearCards(q) end
  local red1 = give(p3, "qiao__jink", Card.Heart, 4)
  local red2 = give(p3, "qiao__peach", Card.Diamond, 5)
  inRoom(function()
    room().current = p1
    room():setPlayerMark(p1, "qiao__shu_red_discard-turn", 0)
    room():throwCard({ red1 }, "test", p3, p3)
    room():throwCard({ red2 }, "test", p3, p3)
    p1.hp = 2
    p1.phase = Player.Discard
  end)
  local oldChoose, oldChoice = room().askToChoosePlayers, room().askToChoice
  FkTest.setNextReplies(p1, { ZAIQI, "1" })
  local hp1, hand1, hand2 = p1.hp, #p1:getCardIds("h"), #p2:getCardIds("h")
  skill_test.withSkillRequests(room(), ZAIQI, {
    askToChoosePlayers = function(self, player, params, original)
      return { p1, p2 }
    end,
    askToChoice = function(self, player, params, original)
      if player == p2 then return "#qiao__skill_shu014_2-recover:" .. p1.id end
      return "#qiao__skill_shu014_2-draw"
    end,
  }, function()
    inRoom(function()
      room().logic:trigger(fk.EventPhaseEnd, p1, PhaseData:new { who = p1, reason = "game_rule", phase = Player.Discard })
    end)
  end)
  lu.assertEquals(p1.hp, hp1 + 1) -- p2 选择令孟获回复
  lu.assertEquals(#p1:getCardIds("h"), hand1 + 1) -- p1 自己选择摸牌
  lu.assertEquals(#p2:getCardIds("h"), hand2) -- p2 选择回复，不摸牌
end

function Testqiao_shu_savage:testJuxiangTakesNanmanAfterWholeResolution()
  local p1, p2, p3 = p(1), p(2), p(3)
  inRoom(function()
    skill_test.installDualGenerals(room(), p1, { main = "qiao_heg__shu015", deputy = "qiao_heg__shu002", kingdom = "shu" })
  end)
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  local nanman = give(p2, NANMAN, Card.Club, 7)
  inRoom(function() p1.hp = p1.maxHp; p3.hp = p3.maxHp end)
  inRoom(function()
    room():useCard(UseCardData:new {
      from = p2, tos = { p1, p3 }, card = Fk:getCardById(nanman), extra_data = {},
    })
  end)
  lu.assertEquals(p1.hp, p1.maxHp)
  lu.assertTrue(table.contains(p1:getCardIds("h"), nanman))
end

function Testqiao_shu_savage:testLiehenPindianWinGainsCard()
  local p1, p2 = p(1), p(2)
  inRoom(function()
    skill_test.installDualGenerals(room(), p1, { main = "qiao_heg__shu015", deputy = "qiao_heg__shu002", kingdom = "shu" })
  end)
  clearCards(p1)
  clearCards(p2)
  local slash = give(p1, "qiao__slash", Card.Spade, 8)
  give(p1, "qiao__jink", Card.Heart, 9)
  give(p2, "qiao__jink", Card.Heart, 10)
  inRoom(function() room().current = p1; p1.phase = Player.Play; p2.hp = p2.maxHp end)
  local oldPindian = p1.pindian
  p1.pindian = function() return { results = { [p2] = { winner = p1 } } } end
  local cardPrompt
  local choose = room().askToChooseCards
  room().askToChooseCards = function(self, player, params)
    if params.skill_name == LIEHEN then cardPrompt = params.prompt end
    return choose(self, player, params)
  end
  FkTest.setNextReplies(p1, { "1" })
  local before = #p2:getCardIds("he")
  inRoom(function()
    room():useCard(UseCardData:new { from = p1, tos = { p2 }, card = Fk:getCardById(slash), extra_data = {} })
  end)
  p1.pindian = oldPindian
  room().askToChooseCards = choose
  local key, source = table.unpack(cardPrompt:split(":"))
  lu.assertEquals(tonumber(source), p2.id)
  lu.assertEquals(Fk:translate(key, "zh_CN"), "烈刃：选择 %src 的一张牌获得")
  lu.assertEquals(p2.hp, p2.maxHp - 1)
  lu.assertEquals(#p2:getCardIds("he"), before - 1)
  lu.assertTrue(#p1:getCardIds("he") >= 2)
end

function Testqiao_shu_savage:testLiehenDoesNotPromptIfEitherHandIsEmpty()
  local p1, p2 = p(1), p(2)
  inRoom(function()
    skill_test.installDualGenerals(room(), p1, { main = "qiao_heg__shu015", deputy = "qiao_heg__shu002", kingdom = "shu" })
  end)
  clearCards(p1)
  clearCards(p2)
  local promptCount = 0
  local ask = room().askToSkillInvoke
  room().askToSkillInvoke = function(self, player, params)
    if params.skill_name == LIEHEN then promptCount = promptCount + 1 end
    return ask(self, player, params)
  end
  local cases = { p1, p2 }
  for _, holding in ipairs(cases) do
    clearCards(p1)
    clearCards(p2)
    give(holding, "qiao__jink", Card.Heart, 9)
    inRoom(function()
      room().current = p1
      p1.phase = Player.Play
      p2.hp = p2.maxHp
      room():useCard(UseCardData:new {
        from = p1, tos = { p2 }, card = Fk:cloneCard("qiao__slash"), extra_data = {},
      })
    end)
    lu.assertEquals(p2.hp, p2.maxHp - 1)
  end
  room().askToSkillInvoke = ask
  lu.assertEquals(promptCount, 0)
end

return { name = "qiao_shu_savage" }
