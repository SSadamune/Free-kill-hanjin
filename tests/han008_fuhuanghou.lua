-- HAN008 伏皇后：惴恐、求援。定向验收文件。
-- 规则依据：docs/rules/generals/han008-fuhuanghou.md、rulebook/events/use-card.md、
-- rulebook/events/damage.md、docs/rules/extra-targets.md。
-- 本文件为定向验收；由基础组统一运行：
--   python scripts/test.py --file tests/han008_fuhuanghou.lua --timeout 120
local support = __dofile("../../../tests/support/hegemony.lua")

local CK = "qiao__skill_han008_1"
local QY = "qiao__skill_han008_2"
local OPTION_YES = "#qiao__skill_han008_1-yes"

local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }
local probeSerial = 0

Testqiao_han008 = {}

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
      room:changeHero(p, "qiao_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(p, "qiao_test__" .. kingdom .. "_1", true, false, false, false, false)
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
    room:changeHero(p, "qiao_heg__han008", true, false, false, false, false)
    room:changeHero(p, "qiao_test__han_2", true, true, false, false, false)
    p.kingdom = "han"
    room:setPlayerProperty(p, "kingdom", "han")
    room:setPlayerMark(p, "__heg_general", "qiao_heg__han008")
    room:setPlayerMark(p, "__heg_deputy", "qiao_test__han_2")
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
    room:changeHero(attacker, "qiao_test__han_1", true, false, false, false, false)
    room:changeHero(attacker, "qiao_test__han_2", true, true, false, false, false)
    room:setPlayerMark(attacker, "__heg_general", "qiao_test__han_1")
    room:setPlayerMark(attacker, "__heg_deputy", "qiao_test__han_2")

    queen:revealGeneral(false, true)
    queen:revealGeneral(true, true)
    room:changeHero(queen, "qiao_heg__han008", true, false, false, false, false)
    room:changeHero(queen, "qiao_test__han_2", true, true, false, false, false)
    queen.kingdom = "han"
    room:setPlayerProperty(queen, "kingdom", "han")
    room:setPlayerMark(queen, "__heg_general", "qiao_heg__han008")
    room:setPlayerMark(queen, "__heg_deputy", "qiao_test__han_2")
    room:setPlayerMark(queen, "__heg_kingdom", "han")
    for _, q in ipairs(room.players) do q.hp = q.maxHp end
  end)
end

local function prepare()
  local room = support.initQiaoRoom()
  initializeGenerals(room)
  setP1(room)
  return room
end

Testqiao_han008.setup = function() prepare() end
Testqiao_han008.tearDown = support.clearRoom

-- 惴恐 ---------------------------------------------------------------------

function Testqiao_han008:testChuikongWinPreventsTargetDamage()
  local room = FkTest.room
  inRoom(function() p1().hp = p1().maxHp - 1 end)
  local p1card = setHand(room, p1(), { { "qiao__slash", Card.Spade, 10 } })[1]
  local p2card = setHand(room, p2(), { { "qiao__jink", Card.Heart, 3 } })[1]
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
  local mark = "@@qiao__skill_han008_1_no_damage-turn"
  lu.assertEquals(p2():getMark(mark), 1)
  lu.assertEquals(Fk:translate(mark), "惴恐")
  inRoom(function()
    room:damage { from = p2(), to = p3(), damage = 1, skillName = "test" }
  end)
  lu.assertEquals(p3().hp, 20)
end

function Testqiao_han008:testChuikongTieAllowsTargetVirtualSlash()
  local room = FkTest.room
  inRoom(function() p1().hp = p1().maxHp - 1 end)
  local p1card = setHand(room, p1(), { { "qiao__slash", Card.Spade, 7 } })[1]
  local p2card = setHand(room, p2(), { { "qiao__jink", Card.Heart, 7 } })[1]

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

-- 惴恐视为使用的【杀】也走求援：新增目标死亡后，伏皇后仍应受此【杀】伤害。
function Testqiao_han008:testChuikongSlashQiuyuanDeathKeepsRemainingTarget()
  local room = FkTest.room
  inRoom(function() p1().hp = p1().maxHp - 1 end)
  local p1card = setHand(room, p1(), { { "qiao__slash", Card.Spade, 7 } })[1]
  local p2card = setHand(room, p2(), { { "qiao__jink", Card.Heart, 7 } })[1]
  setHand(room, p3(), {})
  inRoom(function() p3().hp = 1 end)

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChooseCards({ p1card }),
    "1",
    FkTest.ReplyChoosePlayer({ p3() }),
  })
  FkTest.setNextReplies(p2(), {
    FkTest.ReplyChooseCards({ p2card }),
    { OPTION_YES },
  })
  FkTest.setNextReplies(p3(), { "" })
  local hp = p1().hp
  local data = PhaseData:new { who = p2(), phase = Player.Start, reason = "game_rule" }
  inRoom(function() GameEvent.Phase:create(data):exec() end)

  lu.assertTrue(p3().dead, "优先目标应死亡")
  lu.assertEquals(p1().hp, hp - 1, "优先目标死亡后伏皇后仍应受此【杀】伤害")
  lu.assertEquals(p1():usedSkillTimes(QY, Player.HistoryGame), 1)
end

function Testqiao_han008:testQiuyuanAddsPriorityTargetKeepsEventsAndCancelsRest()
  local room = FkTest.room
  setQiuYuanSeats(room)
  setHand(room, p1(), {})
  setHand(room, p2(), {})
  local p3card = setHand(room, p3(), { { "qiao__jink", Card.Heart, 2 } })[1]
  inRoom(function()
    p2().maxHp = 20
    p2().hp = 20
  end)

  local seenSpecified, seenConfirmed, firstAtEffect
  probeSerial = probeSerial + 1
  installTestSkill(room, "#qiao_han008_target_probe_" .. probeSerial, {
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
          and data.use.qiao_skill_han008_2_priority ~= nil
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
    room:useCard { from = p1(), tos = { p2() }, card = Fk:cloneCard("qiao__slash") }
  end)

  lu.assertTrue(seenSpecified)
  lu.assertTrue(seenConfirmed)
  lu.assertIs(firstAtEffect, p3())
  lu.assertEquals(p2().hp, 20)
  lu.assertEquals(p2():usedSkillTimes(QY, Player.HistoryGame), 1)
end

-- 优先目标被此【杀】实际击杀不是“抵消”：其余目标仍须结算。用真实
-- room:useCard 建立两名目标，只给新增目标 1 点体力且不提供【闪】。
function Testqiao_han008:testQiuyuanPriorityTargetDeathKeepsSlashOnRemainingTarget()
  local room = FkTest.room
  setQiuYuanSeats(room)
  local slashCard = setHand(room, p1(), { { "qiao__slash", Card.Spade, 10 } })[1]
  setHand(room, p2(), {})
  setHand(room, p3(), {})
  inRoom(function()
    p2().maxHp = 20
    p2().hp = 20
    p3().hp = 1
  end)

  local effectOrder, effectDetail = {}, {}
  probeSerial = probeSerial + 1
  installTestSkill(room, "#qiao_han008_death_probe_" .. probeSerial, {
    { fk.PreCardEffect, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        return data.card ~= nil and data.card.trueName == "slash"
          and data.use ~= nil and data.use.qiao_skill_han008_2_priority ~= nil
      end,
      on_refresh = function(self, event, target, player, data)
        if effectOrder[#effectOrder] ~= data.to then
          table.insert(effectOrder, data.to)
          table.insert(effectDetail, string.format("%s from=%s card=%s tos=%s", tostring(data.to),
            tostring(data.from), tostring(data.card),
            table.concat(table.map(data.use.tos, function(p) return p.id end), ",")))
        end
      end,
    } },
  })

  FkTest.setNextReplies(p2(), {
    "1",
    FkTest.ReplyChoosePlayer({ p3() }),
  })
  FkTest.setNextReplies(p3(), { "" })
  inRoom(function()
    room:useCard { from = p1(), tos = { p2() }, card = Fk:getCardById(slashCard) }
  end)

  lu.assertIs(effectOrder[1], p3(), "新增目标应先结算，死亡分支才与报告一致: " .. table.concat(effectDetail, " | "))
  lu.assertIs(effectOrder[2], p2(), "死亡不等于抵消，其余目标仍应进入效果结算: " .. table.concat(effectDetail, " | "))
  lu.assertTrue(p3().dead, "优先目标应实际死亡，才进入死亡而非抵消分支")
  lu.assertFalse(p2().dead)
  lu.assertEquals(p2().hp, 19, "优先目标死亡后，其余目标仍应受此【杀】伤害")
  lu.assertEquals(p2():usedSkillTimes(QY, Player.HistoryGame), 1)
end

return { name = "qiao_han008" }
