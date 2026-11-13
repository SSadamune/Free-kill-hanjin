-- HAN017 刘繇：戡难、逆拒。定向验收文件。
-- 规则依据：rules/generals/han017-liuyao.md、rulebook/events/pindian.md、
-- rulebook/terms/description-terms/and.md。
-- 本文件尚未执行；由基础组统一运行：
--   python scripts/test.py --file tests/han017_liuyao.lua --timeout 120
local support = __dofile("../../../tests/support/hegemony.lua")

local QN = "hanjin__skill_han017_1"
local NJ = "hanjin__skill_han017_2"

local USED_TARGETS = "hanjin__skill_han017_1-given_targets-phase"
local LOCK = "hanjin__skill_han017_1-locked-turn"
local NEXT_SLASH = "hanjin_skill_han017_1_next_slash_damage-turn"
local BONUS = "hanjin__skill_han017_2-bonus-turn"
local OPTION_TAKE = "#hanjin__skill_han017_1-take"

local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }
local probeSerial = 0

Testhanjin_han017 = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end
local function p4() return FkTest.room.players[4] end
local function p5() return FkTest.room.players[5] end
local function p6() return FkTest.room.players[6] end
local function p7() return FkTest.room.players[7] end
local function p8() return FkTest.room.players[8] end

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

local function setHand(room, player, specs, area)
  clearCards(room, player, area or "he")
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room:obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function addHand(room, player, specs)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room:obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function installUseProbe(room, uses)
  probeSerial = probeSerial + 1
  local key = "__hanjin_han017_use_probe_" .. probeSerial
  local skel = fk.CreateSkill { name = "#hanjin_han017_use_probe_" .. probeSerial }
  skel:addEffect(fk.CardUseFinished, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return type(data) == "table" and not data[key]
        and data.card ~= nil and data.card.trueName == "slash"
    end,
    on_refresh = function(self, event, target, player, data)
      data[key] = true
      table.insert(uses, {
        from = data.from,
        tos = table.simpleClone(data.tos or {}),
        additionalDamage = data.additionalDamage or 0,
      })
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room:addSkill(skill) end)
end

local function initializeGenerals(room)
  inRoom(function()
    for i, p in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i]
      p:revealGeneral(false, true)
      p:revealGeneral(true, true)
      room:changeHero(p, "hanjin_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(p, "hanjin_test__" .. kingdom .. "_1", true, false, false, false, false)
      p.kingdom = kingdom
      room:setPlayerProperty(p, "kingdom", kingdom)
      room:setPlayerMark(p, "__heg_general", p.general)
      room:setPlayerMark(p, "__heg_deputy", p.deputyGeneral)
      room:setPlayerMark(p, "__heg_kingdom", kingdom)
      room:setPlayerMark(p, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(p, "__heg_wild", 0)
      p.hp = p.maxHp
    end
  end)
end

local function setP1(room)
  inRoom(function()
    local p = room.players[1]
    p:revealGeneral(false, true)
    p:revealGeneral(true, true)
    room:changeHero(p, "hanjin__han017", true, false, false, false, false)
    room:changeHero(p, "hanjin_test__han_2", true, true, false, false, false)
    p.kingdom = "han"
    room:setPlayerProperty(p, "kingdom", "han")
    room:setPlayerMark(p, "__heg_general", "hanjin__han017")
    room:setPlayerMark(p, "__heg_deputy", "hanjin_test__han_2")
    room:setPlayerMark(p, "__heg_kingdom", "han")
    room:setPlayerMark(p, "__heg_wild", 0)
    for _, q in ipairs(room.players) do q.hp = q.maxHp end
  end)
end

local function prepare()
  local room = support.initHanjinRoom()
  initializeGenerals(room)
  setP1(room)
  return room
end

Testhanjin_han017.setup = function() prepare() end
Testhanjin_han017.tearDown = support.clearRoom

local function activate(room, player, targets)
  inRoom(function()
    room:handleUseCardReply(player, FkTest.ReplyUseSkill(QN, targets, {}))
  end)
end

-- 戡难 ---------------------------------------------------------------------

function Testhanjin_han017:testKannanWinObtainsCardLocksAndBuffsNextSlash()
  local room = FkTest.room
  local p1card = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 } })[1]
  local p2card = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  local uses = {}
  installUseProbe(room, uses)

  FkTest.setNextReplies(p1(), {
    FkTest.ReplyChooseCards({ p1card }),
    { OPTION_TAKE },
  })
  FkTest.setNextReplies(p2(), {
    FkTest.ReplyChooseCards({ p2card }),
  })
  activate(room, p1(), { p2() })

  lu.assertTrue(table.contains(p1():getCardIds("h"), p2card))
  lu.assertFalse(table.contains(p2():getCardIds("h"), p2card))
  lu.assertTrue(p1():getMark(LOCK) > 0)
  lu.assertEquals(p1():getMark(NEXT_SLASH), 1)
  lu.assertTrue(table.contains(p1():getTableMark(USED_TARGETS), p2().id))

  setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 } })
  setHand(room, p3(), {})
  inRoom(function()
    p3().maxHp = 20
    p3().hp = 20
  end)
  inRoom(function()
    room:useCard { from = p1(), tos = { p3() }, card = Fk:cloneCard("hanjin__slash") }
  end)
  lu.assertEquals(#uses, 1)
  lu.assertEquals(uses[1].additionalDamage, 1)
  lu.assertEquals(p3().hp, 18)
  lu.assertEquals(p1():getMark(NEXT_SLASH), 0)
end

function Testhanjin_han017:testKannanTargetWinNoLockAndPerCharacterLimit()
  local room = FkTest.room
  local p1card = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 3 } })[1]
  local p2card = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 10 } })[1]

  FkTest.setNextReplies(p1(), { FkTest.ReplyChooseCards({ p1card }) })
  FkTest.setNextReplies(p2(), {
    FkTest.ReplyChooseCards({ p2card }),
    { OPTION_TAKE },
  })
  activate(room, p1(), { p2() })

  lu.assertTrue(table.contains(p2():getCardIds("h"), p1card))
  lu.assertFalse(table.contains(p1():getCardIds("h"), p1card))
  lu.assertEquals(p1():getMark(LOCK), 0)
  lu.assertEquals(p1():getMark(NEXT_SLASH), 1)
  lu.assertTrue(table.contains(p1():getTableMark(USED_TARGETS), p2().id))

  -- 同一角色本阶段不能再选；另一名角色仍可。
  local p1next = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 5 } })[1]
  local p3card = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 2 } })[1]
  local p2Before = #p2():getCardIds("h")
  activate(room, p1(), { p2() })
  lu.assertEquals(#p2():getCardIds("h"), p2Before)
  lu.assertTrue(table.contains(p1():getTableMark(USED_TARGETS), p2().id))

  FkTest.setNextReplies(p1(), { FkTest.ReplyChooseCards({ p1next }), { OPTION_TAKE } })
  FkTest.setNextReplies(p3(), { FkTest.ReplyChooseCards({ p3card }) })
  activate(room, p1(), { p3() })
  lu.assertTrue(p1():getMark(LOCK) > 0)
end

function Testhanjin_han017:testKannanTieHasNoObtainNoBuffNoLock()
  local room = FkTest.room
  local p1card = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 7 } })[1]
  local p2card = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 7 } })[1]

  FkTest.setNextReplies(p1(), { FkTest.ReplyChooseCards({ p1card }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ p2card }) })
  activate(room, p1(), { p2() })

  lu.assertFalse(table.contains(p2():getCardIds("h"), p2card))
  lu.assertEquals(p1():getMark(NEXT_SLASH), 0)
  lu.assertEquals(p1():getMark(LOCK), 0)
  lu.assertEquals(p1():usedSkillTimes(QN, Player.HistoryGame), 1)
end

-- 逆拒 ---------------------------------------------------------------------

function Testhanjin_han017:testNijuAsTargetDrawsThenAccumulates()
  local room = FkTest.room
  local p1card = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 5 },
    { "hanjin__peach", Card.Heart, 2 },
  })[1]
  local p2card = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 10 } })[1]
  local before = #p1():getCardIds("h")

  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ p2card }) })
  FkTest.setNextReplies(p1(), { FkTest.ReplyChooseCards({ p1card }) })
  local pindian = inRoom(function() return p2():pindian({ p1() }, "test") end)

  lu.assertEquals(p1():getMark(BONUS), 3)
  lu.assertEquals(#p1():getCardIds("h"), before)
  -- 已确定的当前结果不被回溯修改。
  lu.assertEquals(pindian.results[p1()].toCard.number, 5)

  -- 下一次拼点 11 + 3 = 13，封顶；平局后继续累计到 6。
  local p1next = setHand(room, p1(), {
    { "hanjin__slash", Card.Spade, 11 },
    { "hanjin__peach", Card.Heart, 2 },
  })[1]
  local p2next = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 13 } })[1]
  local before2 = #p1():getCardIds("h")
  FkTest.setNextReplies(p1(), { FkTest.ReplyChooseCards({ p1next }) })
  FkTest.setNextReplies(p2(), { FkTest.ReplyChooseCards({ p2next }) })
  local nextPindian = inRoom(function() return p1():pindian({ p2() }, "test") end)

  lu.assertEquals(nextPindian.fromCard.number, 13)
  lu.assertNil(nextPindian.results[p2()].winner)
  lu.assertEquals(p1():getMark(BONUS), 6)
  lu.assertEquals(#p1():getCardIds("h"), before2)
end

return { name = "hanjin_han017" }
