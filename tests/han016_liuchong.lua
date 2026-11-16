-- HAN016A 刘宠：劲弩、威屯。定向验收文件。
-- 规则依据：rules/generals/han016a-liuchong.md。
-- 本文件尚未执行；由基础组统一运行：
--   python scripts/test.py --file tests/han016_liuchong.lua --timeout 120
local support = __dofile("../../../tests/support/hegemony.lua")

local JN = "hanjin__skill_han016_1"
local WT = "hanjin__skill_han016_2"

local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }
local probeSerial = 0

Testhanjin_han016 = {}

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
    room:changeHero(p, "hanjin__han016", true, false, false, false, false)
    room:changeHero(p, "hanjin_test__han_2", true, true, false, false, false)
    p.kingdom = "han"
    room:setPlayerProperty(p, "kingdom", "han")
    room:setPlayerMark(p, "__heg_general", "hanjin__han016")
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

Testhanjin_han016.setup = function() prepare() end
Testhanjin_han016.tearDown = support.clearRoom

local function installUseProbe(room, uses)
  probeSerial = probeSerial + 1
  local key = "__hanjin_han016_use_probe_" .. probeSerial
  local skel = fk.CreateSkill { name = "#hanjin_han016_use_probe_" .. probeSerial }
  skel:addEffect(fk.CardUseFinished, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return type(data) == "table" and not data[key] and data.card ~= nil
    end,
    on_refresh = function(self, event, target, player, data)
      data[key] = true
      table.insert(uses, {
        name = data.card.name,
        trueName = data.card.trueName,
        skillName = data.card.skillName,
        extraUse = data.extraUse == true,
        tos = table.simpleClone(data.tos or {}),
      })
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room:addSkill(skill) end)
end

--- 在出牌阶段第一个空闲时点按顺序真实使用若干牌，然后结束该阶段。
local function installPhaseSequence(room, names)
  if #names == 0 then return end
  probeSerial = probeSerial + 1
  local flag = "__hanjin_han016_sequence_" .. probeSerial
  local skel = fk.CreateSkill { name = "#hanjin_han016_sequence_" .. probeSerial }
  skel:addEffect(fk.BeforePlayCard, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == p1() and type(data) == "table" and not data[flag]
    end,
    on_refresh = function(self, event, target, player, data)
      data[flag] = true
      for _, name in ipairs(names) do
        local tos = (name == "hanjin__peach") and { p1() } or { p2() }
        room:useCard { from = p1(), tos = tos, card = Fk:cloneCard(name) }
      end
    end,
  })
  local skill = skel:createSkill()
  Fk.skills[skel.name] = skill
  inRoom(function() room:addSkill(skill) end)
end

--- 运行一个只有出牌阶段的真实回合；phase_end 由劲弩在阶段结束时触发。
local function runPlayTurn(room, replies)
  FkTest.setNextReplies(p1(), replies)
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p1(), "game_rule", { Player.Play })):exec()
  end)
end

-- 劲弩 ---------------------------------------------------------------------

function Testhanjin_han016:testJinnuZeroCardsDoesNotTrigger()
  local room = FkTest.room
  setHand(room, p1(), { { "hanjin__jink", Card.Heart, 2 } })
  setHand(room, p2(), {})
  setHand(room, p5(), {})
  local uses = {}
  installUseProbe(room, uses)

  runPlayTurn(room, { "" })
  lu.assertEquals(p1():usedSkillTimes(JN, Player.HistoryGame), 0)
  lu.assertEquals(#uses, 0)
end

function Testhanjin_han016:testJinnuAllSlashTriggersOneDistanceFreeSlash()
  local room = FkTest.room
  setHand(room, p1(), { { "hanjin__jink", Card.Heart, 2 } })
  setHand(room, p2(), {})
  setHand(room, p5(), {})
  inRoom(function()
    p2().maxHp = 20
    p2().hp = 20
  end)
  local uses = {}
  installUseProbe(room, uses)
  installPhaseSequence(room, { "hanjin__slash", "hanjin__slash" })

  runPlayTurn(room, {
    "",
    "1",
    FkTest.ReplyChoosePlayer({ p5() }),
  })

  lu.assertEquals(p1():usedSkillTimes(JN, Player.HistoryGame), 1)
  -- 序列中的普通杀都指向 p2；指向 p5 的唯一一次就是用劲弩产生的无距离杀。
  local jinnu = table.filter(uses, function(use) return use.tos[1] == p5() end)
  lu.assertEquals(#jinnu, 1)
  lu.assertIs(jinnu[1].tos[1], p5())
  lu.assertTrue(p1():distanceTo(p5()) > 1)
end

function Testhanjin_han016:testJinnuLastTwoNonSlashTriggers()
  local room = FkTest.room
  setHand(room, p1(), { { "hanjin__jink", Card.Heart, 2 } })
  setHand(room, p2(), {})
  setHand(room, p5(), {})
  inRoom(function() p1().hp = 4 end)
  local uses = {}
  installUseProbe(room, uses)
  installPhaseSequence(room, {
    "hanjin__slash",
    "hanjin__peach",
    "hanjin__peach",
  })

  runPlayTurn(room, {
    "",
    "1",
    FkTest.ReplyChoosePlayer({ p5() }),
  })

  lu.assertEquals(p1():usedSkillTimes(JN, Player.HistoryGame), 1)
  local jinnu = table.filter(uses, function(use) return use.tos[1] == p5() end)
  lu.assertEquals(#jinnu, 1)
  lu.assertIs(jinnu[1].tos[1], p5())
end

-- 威屯 ---------------------------------------------------------------------

function Testhanjin_han016:testWeitunTiedMostHandsSkipsDiscardAndUsesSameGroup()
  local room = FkTest.room
  setHand(room, p1(), {
    { "hanjin__slash" }, { "hanjin__jink" },
    { "hanjin__peach" }, { "hanjin__duel" },
  })
  setHand(room, p2(), {
    { "hanjin__slash" }, { "hanjin__jink" },
    { "hanjin__peach" }, { "hanjin__duel" },
  })
  setHand(room, p3(), {})
  local uses = {}
  installUseProbe(room, uses)

  FkTest.setNextReplies(p1(), {
    "1",
    FkTest.ReplyChoosePlayer({ p1(), p2() }),
  })
  local data = PhaseData:new { who = p1(), phase = Player.Discard, reason = "game_rule" }
  inRoom(function() GameEvent.Phase:create(data):exec() end)

  lu.assertTrue(data.skipped)
  -- 五谷丰登已实装：这组两名目标各从明出的牌中取得一张，所以手牌由
  -- 4 变为 5；弃牌阶段本身确实被跳过（没有额外弃牌）。
  lu.assertEquals(#p1():getCardIds("h"), 5)
  lu.assertEquals(p1():usedSkillTimes(WT, Player.HistoryGame), 1)
  lu.assertEquals(#uses, 2)
  lu.assertEquals(uses[1].name, "hanjin__god_salvation")
  lu.assertEquals(uses[2].name, "hanjin__amazing_grace")
  for _, use in ipairs(uses) do
    lu.assertEquals(#use.tos, 2)
    lu.assertIs(use.tos[1], p1())
    lu.assertIs(use.tos[2], p2())
  end
end

return { name = "hanjin_han016" }
