-- HAN008 伏皇后：惴恐、求援。定向验收文件。
-- 规则依据：rules/generals/han008-fuhuanghou.md、rulebook/events/use-card.md、
-- rulebook/events/damage.md、rules/extra-targets.md。
-- 本文件尚未执行；由基础组统一运行：
--   python scripts/test.py --file tests/han008_fuhuanghou.lua --timeout 120
local support = __dofile("../../../tests/support/hegemony.lua")

local CK = "hanjin__skill_han008_1"
local QY = "hanjin__skill_han008_2"
local OPTION_YES = "#hanjin__skill_han008_1-yes"

local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }
local probeSerial = 0

Testhanjin_han008 = {}

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

local function installTestSkill(room, name, effects)
  local skel = fk.CreateSkill { name = name }
  for _, spec in ipairs(effects) do
    skel:addEffect(spec[1], spec[2])
  end
  local skill = skel:createSkill()
  Fk.skills[name] = skill
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
    room:changeHero(p, "hanjin__han008", true, false, false, false, false)
    room:changeHero(p, "hanjin_test__han_2", true, true, false, false, false)
    p.kingdom = "han"
    room:setPlayerProperty(p, "kingdom", "han")
    room:setPlayerMark(p, "__heg_general", "hanjin__han008")
    room:setPlayerMark(p, "__heg_deputy", "hanjin_test__han_2")
    room:setPlayerMark(p, "__heg_kingdom", "han")
    room:setPlayerMark(p, "__heg_wild", 0)
    for _, q in ipairs(room.players) do q.hp = q.maxHp end
  end)
end

local function setQiuYuanSeats(room)
  inRoom(function()
    local attacker, queen = room.players[1], room.players[2]
    attacker:revealGeneral(false, true)
    attacker:revealGeneral(true, true)
    room:changeHero(attacker, "hanjin_test__han_1", true, false, false, false, false)
    room:changeHero(attacker, "hanjin_test__han_2", true, true, false, false, false)
    room:setPlayerMark(attacker, "__heg_general", "hanjin_test__han_1")
    room:setPlayerMark(attacker, "__heg_deputy", "hanjin_test__han_2")

    queen:revealGeneral(false, true)
    queen:revealGeneral(true, true)
    room:changeHero(queen, "hanjin__han008", true, false, false, false, false)
    room:changeHero(queen, "hanjin_test__han_2", true, true, false, false, false)
    queen.kingdom = "han"
    room:setPlayerProperty(queen, "kingdom", "han")
    room:setPlayerMark(queen, "__heg_general", "hanjin__han008")
    room:setPlayerMark(queen, "__heg_deputy", "hanjin_test__han_2")
    room:setPlayerMark(queen, "__heg_kingdom", "han")
    for _, q in ipairs(room.players) do q.hp = q.maxHp end
  end)
end

local function prepare()
  local room = support.initHanjinRoom()
  initializeGenerals(room)
  setP1(room)
  return room
end

Testhanjin_han008.setup = function() prepare() end
Testhanjin_han008.tearDown = support.clearRoom

-- 惴恐 ---------------------------------------------------------------------

function Testhanjin_han008:testChuikongWinPreventsTargetDamage()
  local room = FkTest.room
  inRoom(function() p1().hp = p1().maxHp - 1 end)
  local p1card = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 10 } })[1]
  local p2card = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 3 } })[1]
  setHand(room, p3(), {})
  inRoom(function()
    p3().maxHp = 20
    p3().hp = 20
  end)

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChooseCards({ p1card }),
  })
  FkTest.setNextReplies(p2(), {
    FkTest.ReplyChooseCards({ p2card }),
  })
  local data = PhaseData:new { who = p2(), phase = Player.Start, reason = "game_rule" }
  inRoom(function() GameEvent.Phase:create(data):exec() end)

  lu.assertEquals(p1():usedSkillTimes(CK, Player.HistoryGame), 1)
  inRoom(function()
    room:damage { from = p2(), to = p3(), damage = 1, skillName = "test" }
  end)
  lu.assertEquals(p3().hp, 20)
end

function Testhanjin_han008:testChuikongTieAllowsTargetVirtualSlash()
  local room = FkTest.room
  inRoom(function() p1().hp = p1().maxHp - 1 end)
  local p1card = setHand(room, p1(), { { "hanjin__slash", Card.Spade, 7 } })[1]
  local p2card = setHand(room, p2(), { { "hanjin__jink", Card.Heart, 7 } })[1]

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChooseCards({ p1card }),
    "", -- 拒绝随后由 p2 视为使用的【杀】触发的求援
  })
  FkTest.setNextReplies(p2(), {
    FkTest.ReplyChooseCards({ p2card }),
    { OPTION_YES },
  })
  local hp = p1().hp
  local data = PhaseData:new { who = p2(), phase = Player.Start, reason = "game_rule" }
  inRoom(function() GameEvent.Phase:create(data):exec() end)

  lu.assertEquals(p1().hp, hp - 1)
  lu.assertEquals(p1():usedSkillTimes(CK, Player.HistoryGame), 1)
end

-- 求援 ---------------------------------------------------------------------

function Testhanjin_han008:testQiuyuanAddsPriorityTargetKeepsEventsAndCancelsRest()
  local room = FkTest.room
  setQiuYuanSeats(room)
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local p3card = setHand(room, p3(), { { "hanjin__jink", Card.Heart, 2 } })[1]
  inRoom(function()
    p2().maxHp = 20
    p2().hp = 20
  end)

  local seenSpecified, seenConfirmed, firstAtEffect
  probeSerial = probeSerial + 1
  installTestSkill(room, "#hanjin_han008_target_probe_" .. probeSerial, {
    { fk.TargetSpecified, {
      global = true,
      -- 指定目标后的 target 是使用者，当前目标在 data.to。
      can_refresh = function(self, event, target, player, data)
        return data.to == p3()
      end,
      on_refresh = function() seenSpecified = true end,
    } },
    { fk.TargetConfirmed, {
      global = true,
      can_refresh = function(self, event, target) return target == p3() end,
      on_refresh = function() seenConfirmed = true end,
    } },
    { fk.PreCardEffect, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        return firstAtEffect == nil and data.card ~= nil and data.card.trueName == "slash"
          and data.use ~= nil
          and data.use.hanjin_skill_han008_2_priority ~= nil
      end,
      on_refresh = function(self, event, target, player, data)
        firstAtEffect = data.to
      end,
    } },
  })

  FkTest.setNextReplies(p2(), {
    "1",
    FkTest.ReplyChoosePlayer({ p3() }),
  })
  FkTest.setNextReplies(p3(), {
    FkTest.ReplyCard(Fk:getCardById(p3card)),
  })
  inRoom(function()
    room:useCard { from = p1(), tos = { p2() }, card = Fk:cloneCard("hanjin__slash") }
  end)

  lu.assertTrue(seenSpecified)
  lu.assertTrue(seenConfirmed)
  lu.assertIs(firstAtEffect, p3())
  lu.assertEquals(p2().hp, 20)
  lu.assertEquals(p2():usedSkillTimes(QY, Player.HistoryGame), 1)
end

return { name = "hanjin_han008" }
