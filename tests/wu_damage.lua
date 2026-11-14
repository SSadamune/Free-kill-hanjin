-- WU 标准包：伤害、拼点与翼从定向验收文件。
-- 规则依据：rules/standard-generals.md 吴区与翼从表、rules/generals/wu013-zhoutai.md、
-- rulebook 相关事件条文；本文件只覆盖本轮核心行为，未接入 tests/all.lua。
--   python scripts/test.py --file tests/wu_damage.lua --timeout 180
local support = __dofile("../../../tests/support/hegemony.lua")

local KUROU = "hanjin__skill_wu004_1"
local ZHAXIANG = "hanjin__skill_wu004_2"
local TIANXIANG = "hanjin__skill_wu011_1"
local HONGYAN = "hanjin__skill_wu011_2"
local TIANYI = "hanjin__skill_wu012_1"
local HANZHAN = "hanjin__skill_wu012_2"
local BUQU = "hanjin__skill_wu013_1"
local FENJI = "hanjin__skill_wu013_2"
local HAOSHI = "hanjin__skill_wu014_1"
local DIMENG = "hanjin__skill_wu014_2"
local JINFANJUN = "hanjin__retinue_skill_jinfanjun"
local QUAXIAO = "hanjin__retinue_skill_quaxiaojiang"

local TURN_EFFECTS = "hanjin__wu_turn_effects"
local DIMENG_EXPIRY = "hanjin__wu_dimeng_expiry"
local ZHAXIANG_TIMES = "hanjin_wu004_zhaxiang_times-turn"
local TIANYI_WIN = "hanjin_wu012_tianyi_win-turn"
local TIANYI_LOSE = "hanjin_wu012_tianyi_lose-turn"
local DIMENG_GRANTED = "hanjin_wu_dimeng_granted"
local TIANXIANG_OPT_DAMAGE = "#hanjin__skill_wu011_1-damage"
local TIANXIANG_OPT_LOSEHP = "#hanjin__skill_wu011_1-losehp"

local DEFAULT_KINGDOMS = { "wu", "wu", "wu", "wu", "wu", "wu", "wu", "wu" }

Testhanjin_wu_damage = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(n) return FkTest.room.players[n] end

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

local function setHand(room, player, specs)
  clearCards(room, player, "he")
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

local function addEquip(room, player, name, suit, number)
  local id
  inRoom(function()
    local card = room:printCard(name, suit or Card.Spade, number or 2)
    room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

local function seedDrawPile(room, specs)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room:printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      table.removeOne(room.draw_pile, card.id)
      table.insert(room.draw_pile, 1, card.id)
      room.card_place[card.id] = Card.DrawPile
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function grant(player, skillName)
  inRoom(function()
    player.room:handleAddLoseSkills(player, skillName, nil, false, true)
  end)
end

local function activate(room, player, skillName, targets, cards)
  inRoom(function()
    room:handleUseCardReply(player, FkTest.ReplyUseSkill(skillName, targets, cards or {}))
  end)
end

local function turnEnd(room, player)
  inRoom(function()
    room.logic:trigger(fk.TurnEnd, player, TurnData:new(player, "game_rule", { Player.Start }))
  end)
end

--- 客户端可用性：真实 ClientPlayer（无 room 字段）+ Fk:currentRoom 回退。
local function asClient(room, fn)
  local ClientPlayer = require "ltk.client.clientplayer"
  local clients = {}
  for _, original in ipairs(room.players) do
    local copy = ClientPlayer:new(original._splayer)
    for key, value in pairs(original) do
      if key ~= "room" and key ~= "class" and key ~= "serverplayer" then copy[key] = value end
    end
    table.insert(clients, copy)
  end
  for index, player in ipairs(clients) do player.next = clients[index % #clients + 1] end
  local clientRoom = setmetatable(
    { players = clients, alive_players = clients, current = clients[1] },
    { __index = room })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = pcall(fn, clients, clientRoom)
  Fk.currentRoom = originalRoom
  if not ok then error(err) end
end

--- 静态目标修正技能的实际返回值之和（用于验证失去来源技能后仍生效）。
local function targetModResidue(room, player, card)
  local total = 0
  for _, sk in ipairs(room.status_skills[TargetModSkill] or {}) do
    total = total + (sk:getResidueNum(player, Fk.skills["hanjin__inert"],
      Player.HistoryPhase, card, nil) or 0)
  end
  return total
end

local function targetModExtra(room, player, card)
  local total = 0
  for _, sk in ipairs(room.status_skills[TargetModSkill] or {}) do
    total = total + (sk:getExtraTargetNum(player, Fk.skills["hanjin__inert"], card) or 0)
  end
  return total
end

local function initializeGenerals(room)
  inRoom(function()
    for i, pl in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i] or "wu"
      pl:revealGeneral(false, true)
      pl:revealGeneral(true, true)
      room:changeHero(pl, "hanjin_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(pl, "hanjin_test__" .. kingdom .. "_1", true, false, false, false, false)
      pl.kingdom = kingdom
      room:setPlayerProperty(pl, "kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_general", pl.general)
      room:setPlayerMark(pl, "__heg_deputy", pl.deputyGeneral)
      room:setPlayerMark(pl, "__heg_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_init_kingdom", kingdom)
      room:setPlayerMark(pl, "__heg_wild", 0)
      pl.maxHp = pl:getGeneralMaxHp()
      pl.hp = pl.maxHp
    end
  end)
end

local function prepare()
  local room = support.initHanjinRoom()
  initializeGenerals(room)
  return room
end

Testhanjin_wu_damage.setup = function() prepare() end
Testhanjin_wu_damage.tearDown = support.clearRoom

-- 苦肉/诈降：失去体力触发诈降，随后可交牌 -------------------------------
function Testhanjin_wu_damage:testKurouLosesHpTriggersZhaxiangAndGivesCard()
  local room = FkTest.room
  local mine = setHand(room, p(1), { { "hanjin__peach", Card.Heart, 2 } })[1]
  setHand(room, p(2), {})
  grant(p(1), KUROU)
  grant(p(1), ZHAXIANG)
  local hp = p(1).hp

  FkTest.setNextReplies(p(1), { FkTest.ReplyChoosePlayer({ p(2) }), mine })
  activate(room, p(1), KUROU, {}, {})

  lu.assertEquals(p(1).hp, hp - 1)
  lu.assertTrue(table.contains(p(2):getCardIds(Player.Hand), mine))
  -- 原手牌交给目标；诈降摸三张仍留在自己手里。
  lu.assertEquals(#p(1):getCardIds(Player.Hand), 3)
  lu.assertEquals(p(1):usedSkillTimes(ZHAXIANG, Player.HistoryGame), 1)
end

-- 诈降：多次失去体力累计次数；失去技能后本回合效果仍由静态技能提供
function Testhanjin_wu_damage:testZhaxiangStackAndEffectSurviveSkillLoss()
  local room = FkTest.room
  grant(p(1), ZHAXIANG)
  lu.assertTrue(room:hasSkill(TURN_EFFECTS))

  inRoom(function()
    room:loseHp(p(1), 1, "test")
    room:loseHp(p(1), 1, "test")
  end)
  lu.assertEquals(p(1):getMark(ZHAXIANG_TIMES), 2)
  local slash = Fk:cloneCard("hanjin__slash")
  lu.assertTrue(targetModResidue(room, p(1), slash) >= 2)

  inRoom(function()
    room:handleAddLoseSkills(p(1), "-" .. ZHAXIANG, nil, false, true)
  end)
  lu.assertFalse(p(1):hasSkill(ZHAXIANG))
  lu.assertTrue(room:hasSkill(TURN_EFFECTS))
  lu.assertEquals(p(1):getMark(ZHAXIANG_TIMES), 2)
  lu.assertTrue(targetModResidue(room, p(1), slash) >= 2)
end

-- 诈降：真实已用一张杀后，HistoryPhase 次数增益使下一张杀仍可用
function Testhanjin_wu_damage:testZhaxiangAdditionalSlashAfterRealUse()
  local room = FkTest.room
  grant(p(1), ZHAXIANG)
  local ids = setHand(room, p(1), {
    { "hanjin__slash", Card.Spade, 2 },
    { "hanjin__slash", Card.Heart, 3 },
  })
  setHand(room, p(2), {})
  inRoom(function() room:loseHp(p(1), 1, "test") end)

  FkTest.setNextReplies(p(2), { "__cancel" })
  inRoom(function()
    room:useCard { from = p(1), tos = { p(2) }, card = Fk:getCardById(ids[1]) }
  end)

  inRoom(function()
    local card = Fk:getCardById(ids[2])
    local slashSkill = card:getSkill(p(1))
    lu.assertTrue(slashSkill:canUse(p(1), card))
  end)
end

-- 天香分支1：防止原伤害，来源对目标造成1点伤害，目标摸已损失体力值张牌
function Testhanjin_wu_damage:testTianxiangPreventsAndSourceDamages()
  local room = FkTest.room
  local heart = setHand(room, p(1), { { "hanjin__peach", Card.Heart, 2 } })[1]
  clearCards(room, p(3), "he")
  inRoom(function() p(3).hp = 2 end)
  grant(p(1), TIANXIANG)
  local hp1, hp3 = p(1).hp, p(3).hp

  FkTest.setNextReplies(p(1), {
    "1",
    FkTest.ReplyChooseCards({ heart }),
    FkTest.ReplyChoosePlayer({ p(3) }),
    { TIANXIANG_OPT_DAMAGE },
  })
  inRoom(function()
    room:damage { from = p(2), to = p(1), damage = 1 }
  end)

  lu.assertEquals(p(1):usedSkillTimes(TIANXIANG, Player.HistoryGame), 1)
  lu.assertEquals(p(1).hp, hp1)
  lu.assertEquals(p(3).hp, hp3 - 1)
  lu.assertEquals(#p(3):getCardIds(Player.Hand), 3)
end

-- 天香分支2：防止原伤害，目标失去1点体力，然后获得被弃置的牌
function Testhanjin_wu_damage:testTianxiangPreventsThenTargetLosesHpAndObtainsCard()
  local room = FkTest.room
  local heart = setHand(room, p(1), { { "hanjin__jink", Card.Heart, 3 } })[1]
  clearCards(room, p(4), "he")
  inRoom(function() p(4).hp = p(4).maxHp end)
  grant(p(1), TIANXIANG)
  local hp1, hp4 = p(1).hp, p(4).hp

  FkTest.setNextReplies(p(1), {
    "1",
    FkTest.ReplyChooseCards({ heart }),
    FkTest.ReplyChoosePlayer({ p(4) }),
    { TIANXIANG_OPT_LOSEHP },
  })
  inRoom(function()
    room:damage { from = p(2), to = p(1), damage = 1 }
  end)

  lu.assertEquals(p(1):usedSkillTimes(TIANXIANG, Player.HistoryGame), 1)
  lu.assertEquals(p(1).hp, hp1)
  lu.assertEquals(p(4).hp, hp4 - 1)
  lu.assertTrue(table.contains(p(4):getCardIds(Player.Hand), heart))
end

-- 红颜：黑桃手牌、装备和判定牌视为红桃 ------------------------------------
function Testhanjin_wu_damage:testHongyanSpadeHandEquipAndJudge()
  local room = FkTest.room
  grant(p(1), HONGYAN)
  local hand = setHand(room, p(1), { { "hanjin__peach", Card.Spade, 4 } })[1]
  local equip = addEquip(room, p(1), "hanjin__chixiao_sword", Card.Spade, 5)
  lu.assertEquals(Fk:getCardById(hand).suit, Card.Heart)
  lu.assertEquals(Fk:getCardById(equip).suit, Card.Heart)

  local judgeIds = seedDrawPile(room, { { "hanjin__jink", Card.Spade, 6 } })
  local judge = { who = p(1), reason = "test", pattern = "." }
  inRoom(function() room:judge(judge) end)
  lu.assertEquals(judge.card.suit, Card.Heart)
  lu.assertEquals(judge.card.id, judgeIds[1])
end

-- 天义赢：乐成拼点、酣战取回最大杀，并建立本回合胜利标记 ---------------
function Testhanjin_wu_damage:testTianyiWinAndHanzhanTakesSlash()
  local room = FkTest.room
  local slash = setHand(room, p(1), {
    { "hanjin__slash", Card.Spade, 13 },
    { "hanjin__peach", Card.Heart, 2 },
  })[1]
  local other = setHand(room, p(2), { { "hanjin__jink", Card.Heart, 1 } })[1]
  grant(p(1), TIANYI)
  grant(p(1), HANZHAN)

  FkTest.setNextReplies(p(1), { FkTest.ReplyChooseCards({ slash }), "1" })
  FkTest.setNextReplies(p(2), { FkTest.ReplyChooseCards({ other }) })
  activate(room, p(1), TIANYI, { p(2) }, {})

  lu.assertEquals(p(1):getMark(TIANYI_WIN), 1)
  lu.assertEquals(p(1):getMark(TIANYI_LOSE), 0)
  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), slash))
  lu.assertEquals(p(1):usedSkillTimes(HANZHAN, Player.HistoryGame), 1)
end

-- 天义：赢后失去技能，静态回合效果仍提供加目标/加次数/无距离
function Testhanjin_wu_damage:testTianyiWinEffectSurvivesSkillLoss()
  local room = FkTest.room
  local slash = setHand(room, p(1), { { "hanjin__slash", Card.Spade, 13 } })[1]
  local other = setHand(room, p(2), { { "hanjin__jink", Card.Heart, 1 } })[1]
  grant(p(1), TIANYI)

  FkTest.setNextReplies(p(1), { FkTest.ReplyChooseCards({ slash }) })
  FkTest.setNextReplies(p(2), { FkTest.ReplyChooseCards({ other }) })
  activate(room, p(1), TIANYI, { p(2) }, {})
  lu.assertTrue(room:hasSkill(TURN_EFFECTS))

  inRoom(function()
    room:handleAddLoseSkills(p(1), "-" .. TIANYI, nil, false, true)
  end)
  lu.assertFalse(p(1):hasSkill(TIANYI))
  lu.assertEquals(p(1):getMark(TIANYI_WIN), 1)
  local card = Fk:cloneCard("hanjin__slash")
  lu.assertTrue(targetModExtra(room, p(1), card) >= 1)
  lu.assertTrue(targetModResidue(room, p(1), card) >= 1)
end

-- 酣战：点数最大的【杀】并列时全部取得，不自行限“一张”
function Testhanjin_wu_damage:testHanzhanTakesAllTiedHighestSlash()
  local room = FkTest.room
  local mine = setHand(room, p(1), { { "hanjin__slash", Card.Spade, 13 } })[1]
  local theirs = setHand(room, p(2), { { "hanjin__slash", Card.Heart, 13 } })[1]
  grant(p(1), TIANYI)
  grant(p(1), HANZHAN)

  FkTest.setNextReplies(p(1), { FkTest.ReplyChooseCards({ mine }), "1" })
  FkTest.setNextReplies(p(2), { FkTest.ReplyChooseCards({ theirs }) })
  activate(room, p(1), TIANYI, { p(2) }, {})

  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), mine))
  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), theirs))
  lu.assertEquals(p(1):usedSkillTimes(HANZHAN, Player.HistoryGame), 1)
end

-- 天义：真实 ClientPlayer 没有 room 字段时 canUse 仍能安全取得当前房间
function Testhanjin_wu_damage:testTianyiCanUseOnClientWithoutRoom()
  local room = FkTest.room
  setHand(room, p(1), { { "hanjin__peach", Card.Heart, 4 } })
  setHand(room, p(2), { { "hanjin__jink", Card.Heart, 5 } })
  grant(p(1), TIANYI)

  asClient(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    lu.assertTrue(Fk.skills[TIANYI]:canUse(me))
  end)
end

-- 天义没赢：平局也按没赢处理，本回合禁止使用杀 --------------------------
function Testhanjin_wu_damage:testTianyiDrawCountsAsLoseAndProhibitsSlash()
  local room = FkTest.room
  local mine = setHand(room, p(1), { { "hanjin__peach", Card.Heart, 7 } })[1]
  local other = setHand(room, p(2), { { "hanjin__jink", Card.Heart, 7 } })[1]
  grant(p(1), TIANYI)

  FkTest.setNextReplies(p(1), { FkTest.ReplyChooseCards({ mine }) })
  FkTest.setNextReplies(p(2), { FkTest.ReplyChooseCards({ other }) })
  activate(room, p(1), TIANYI, { p(2) }, {})

  lu.assertEquals(p(1):getMark(TIANYI_WIN), 0)
  lu.assertEquals(p(1):getMark(TIANYI_LOSE), 1)
  inRoom(function()
    lu.assertTrue(p(1):prohibitUse(Fk:cloneCard("hanjin__slash")))
  end)
end

-- 不屈：真实濒死摸X、置创；无须移去则回复至1 ------------------------------
function Testhanjin_wu_damage:testBuquDrawsPlacesAndRecoversWhenNoDuplicate()
  local room = FkTest.room
  grant(p(1), BUQU)
  setHand(room, p(1), { { "hanjin__peach", Card.Heart, 8 } })
  local drawn = seedDrawPile(room, { { "hanjin__jink", Card.Diamond, 9 } })[1]
  inRoom(function() p(1).hp = 0 end)

  FkTest.setNextReplies(p(1), { drawn })
  inRoom(function() room:enterDying { who = p(1) } end)

  lu.assertEquals(p(1).hp, 1)
  lu.assertEquals(#p(1):getPile("创"), 1)
  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), drawn) == false)
end

-- 不屈：同花色重复时移去一张，不回复体力 --------------------------------
function Testhanjin_wu_damage:testBuquRemovesDuplicateSuitWithoutRecover()
  local room = FkTest.room
  grant(p(1), BUQU)
  setHand(room, p(1), {})
  local old = seedDrawPile(room, { { "hanjin__peach", Card.Heart, 10 } })[1]
  inRoom(function()
    room:moveCardTo({ old }, Card.PlayerSpecial, p(1), fk.ReasonPut, "test", "创", true, p(1))
  end)
  local drawn = seedDrawPile(room, { { "hanjin__jink", Card.Heart, 11 } })[1]
  inRoom(function() p(1).hp = 1 end)

  FkTest.setNextReplies(p(1), { drawn, FkTest.ReplyChooseCards({ old }) })
  inRoom(function() room:enterDying { who = p(1) } end)

  lu.assertEquals(#p(1):getPile("创"), 1)
  lu.assertTrue(table.contains(p(1):getPile("创"), old))
  lu.assertEquals(room:getCardArea(drawn), Card.DiscardPile)
  lu.assertEquals(p(1).hp, 1)
end

-- 不屈：可以选择装备区的牌作为“创”
function Testhanjin_wu_damage:testBuquMayPlaceEquipmentCard()
  local room = FkTest.room
  grant(p(1), BUQU)
  setHand(room, p(1), {})
  local equip = addEquip(room, p(1), "hanjin__chixiao_sword", Card.Spade, 7)
  seedDrawPile(room, { { "hanjin__jink", Card.Diamond, 12 } })
  inRoom(function() p(1).hp = 1 end)

  FkTest.setNextReplies(p(1), { equip })
  inRoom(function() room:enterDying { who = p(1) } end)

  lu.assertTrue(table.contains(p(1):getPile("创"), equip))
  lu.assertFalse(table.contains(p(1):getCardIds(Player.Equip), equip))
  lu.assertEquals(p(1).hp, 1)
end

-- 不屈：同花色多张由玩家选择保留哪一张，而不是固定保留最早
function Testhanjin_wu_damage:testBuquChoosesWhichDuplicateToKeep()
  local room = FkTest.room
  grant(p(1), BUQU)
  setHand(room, p(1), {})
  local old1 = seedDrawPile(room, { { "hanjin__peach", Card.Heart, 13 } })[1]
  local old2 = seedDrawPile(room, { { "hanjin__jink", Card.Heart, 1 } })[1]
  inRoom(function()
    room:moveCardTo({ old1 }, Card.PlayerSpecial, p(1), fk.ReasonPut, "test", "创", true, p(1))
    room:moveCardTo({ old2 }, Card.PlayerSpecial, p(1), fk.ReasonPut, "test", "创", true, p(1))
  end)
  local drawn = seedDrawPile(room, { { "hanjin__peach", Card.Heart, 2 } })[1]
  inRoom(function() p(1).hp = 1 end)

  FkTest.setNextReplies(p(1), { drawn, FkTest.ReplyChooseCards({ old2 }) })
  inRoom(function() room:enterDying { who = p(1) } end)

  local pile = p(1):getPile("创")
  lu.assertEquals(#pile, 1)
  lu.assertTrue(table.contains(pile, old2))
  lu.assertEquals(room:getCardArea(old1), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(drawn), Card.DiscardPile)
end

-- 奋激：本回合真实失去所有手牌的角色摸两张，周泰失去1点体力 ------------
function Testhanjin_wu_damage:testFenjiUsesRealEmptyHandHistory()
  local room = FkTest.room
  grant(p(1), FENJI)
  local victim = setHand(room, p(3), { { "hanjin__peach", Card.Heart, 12 } })[1]
  local hp = p(1).hp

  inRoom(function() room:throwCard({ victim }, "test", p(3), p(3)) end)
  FkTest.setNextReplies(p(1), { "1", FkTest.ReplyChoosePlayer({ p(3) }) })
  turnEnd(room, p(1))

  lu.assertEquals(#p(3):getCardIds(Player.Hand), 2)
  lu.assertEquals(p(1).hp, hp - 1)
end

-- 好施：实际多摸两张后按半数交给手牌最少的角色 --------------------------
function Testhanjin_wu_damage:testHaoshiDrawsTwoThenGivesHalf()
  local room = FkTest.room
  grant(p(1), HAOSHI)
  local start = setHand(room, p(1), {
    { "hanjin__peach", Card.Heart, 2 },
    { "hanjin__jink", Card.Diamond, 3 },
  })
  setHand(room, p(2), {})
  setHand(room, p(3), { { "hanjin__slash", Card.Spade, 4 } })
  local drawn = seedDrawPile(room, {
    { "hanjin__peach", Card.Heart, 5 },
    { "hanjin__jink", Card.Diamond, 6 },
    { "hanjin__slash", Card.Spade, 7 },
    { "hanjin__peach", Card.Heart, 8 },
  })
  local give = { start[1], start[2], drawn[4] }

  FkTest.setNextReplies(p(1), {
    "1",
    FkTest.ReplyChoosePlayer({ p(2) }),
    FkTest.ReplyChooseCards(give),
  })
  local data = PhaseData:new { who = p(1), reason = "game_rule", phase = Player.Draw, n = 2 }
  inRoom(function()
    room.logic:trigger(fk.DrawNCards, p(1), data)
    room:drawCards(p(1), data.n, "phase_draw")
    room.logic:trigger(fk.AfterDrawNCards, p(1), data)
  end)

  lu.assertEquals(#p(1):getCardIds(Player.Hand), 3)
  lu.assertEquals(#p(2):getCardIds(Player.Hand), 3)
  for _, id in ipairs(give) do
    lu.assertTrue(table.contains(p(2):getCardIds(Player.Hand), id))
  end
end

-- 好施：摸牌承诺后即使失去好施，既定给牌仍由静态延迟效果完成
function Testhanjin_wu_damage:testHaoshiGiveSurvivesSkillLossBeforeAfterDraw()
  local room = FkTest.room
  grant(p(1), HAOSHI)
  local start = setHand(room, p(1), {
    { "hanjin__peach", Card.Heart, 2 },
    { "hanjin__jink", Card.Diamond, 3 },
  })
  setHand(room, p(2), {})
  setHand(room, p(3), { { "hanjin__slash", Card.Spade, 4 } })
  local drawn = seedDrawPile(room, {
    { "hanjin__peach", Card.Heart, 5 },
    { "hanjin__jink", Card.Diamond, 6 },
    { "hanjin__slash", Card.Spade, 7 },
    { "hanjin__peach", Card.Heart, 8 },
  })
  local give = { start[1], start[2], drawn[4] }

  FkTest.setNextReplies(p(1), {
    "1",
    FkTest.ReplyChoosePlayer({ p(2) }),
    FkTest.ReplyChooseCards(give),
  })
  local data = PhaseData:new { who = p(1), reason = "game_rule", phase = Player.Draw, n = 2 }
  inRoom(function()
    room.logic:trigger(fk.DrawNCards, p(1), data)
    room:handleAddLoseSkills(p(1), "-" .. HAOSHI, nil, false, true)
    room:drawCards(p(1), data.n, "phase_draw")
    room.logic:trigger(fk.AfterDrawNCards, p(1), data)
  end)

  lu.assertFalse(p(1):hasSkill(HAOSHI))
  lu.assertEquals(#p(2):getCardIds(Player.Hand), 3)
  for _, id in ipairs(give) do
    lu.assertTrue(table.contains(p(2):getCardIds(Player.Hand), id))
  end
end

-- 缔盟：真实弃牌、交换手牌，纵横好施到目标回合结束 ----------------------
function Testhanjin_wu_damage:testDimengSwapsHandsAndGrantsHaoshiUntilTargetTurnEnd()
  local room = FkTest.room
  grant(p(1), DIMENG)
  local cost = setHand(room, p(1), {
    { "hanjin__peach", Card.Heart, 2 },
    { "hanjin__jink", Card.Diamond, 3 },
  })
  setHand(room, p(2), {
    { "hanjin__slash", Card.Spade, 4 },
    { "hanjin__slash", Card.Spade, 5 },
    { "hanjin__slash", Card.Spade, 6 },
    { "hanjin__slash", Card.Spade, 7 },
    { "hanjin__slash", Card.Spade, 8 },
  })
  setHand(room, p(3), {
    { "hanjin__peach", Card.Heart, 9 },
    { "hanjin__peach", Card.Heart, 10 },
    { "hanjin__peach", Card.Heart, 11 },
  })

  FkTest.setNextReplies(p(1), { FkTest.ReplyDiscard(cost), "1" })
  activate(room, p(1), DIMENG, { p(2), p(3) }, {})

  lu.assertEquals(#p(2):getCardIds(Player.Hand), 3)
  lu.assertEquals(#p(3):getCardIds(Player.Hand), 5)
  lu.assertTrue(p(2):hasSkill(HAOSHI))
  lu.assertTrue(room:hasSkill(DIMENG_EXPIRY))
  lu.assertEquals(p(2):getMark(DIMENG_GRANTED), 1)

  -- 追加另一来源；addSkill 即使已拥有同名技能也会记录 derivative source。
  inRoom(function()
    p(2):addSkill(Fk.skills[HAOSHI], "hanjin__skill_wu005_1")
  end)

  -- 授予时所在回合（可能是鲁肃的额外回合）结束不清理。
  turnEnd(room, p(1))
  lu.assertTrue(p(2):hasSkill(HAOSHI))
  lu.assertEquals(p(2):getMark(DIMENG_GRANTED), 1)

  -- 目标自己的下一个回合结束：只移除缔盟来源，保留其他来源。
  turnEnd(room, p(2))
  lu.assertEquals(p(2):getMark(DIMENG_GRANTED), 0)
  lu.assertTrue(p(2):hasSkill(HAOSHI))
  inRoom(function()
    room:handleAddLoseSkills(p(2), "-" .. HAOSHI, "hanjin__skill_wu005_1", false, true)
  end)
  lu.assertFalse(p(2):hasSkill(HAOSHI))
end

-- 缔盟：ClientPlayer 无 room 时可安全计算；手牌数相等不能支付零张弃置
function Testhanjin_wu_damage:testDimengClientCanUseAndRejectsZeroDiff()
  local room = FkTest.room
  grant(p(1), DIMENG)
  setHand(room, p(1), {
    { "hanjin__peach", Card.Heart, 2 },
    { "hanjin__jink", Card.Diamond, 3 },
  })
  for i = 2, 8 do
    setHand(room, p(i), {
      { "hanjin__slash", Card.Spade, 4 },
      { "hanjin__jink", Card.Heart, 5 },
    })
  end

  asClient(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    -- 所有其他角色手牌数相等，差为 0，不能支付“弃置零张牌”的消耗。
    lu.assertFalse(Fk.skills[DIMENG]:canUse(me))
  end)

  setHand(room, p(2), {
    { "hanjin__slash", Card.Spade, 4 },
    { "hanjin__slash", Card.Spade, 5 },
    { "hanjin__slash", Card.Spade, 6 },
    { "hanjin__slash", Card.Spade, 7 },
    { "hanjin__slash", Card.Spade, 8 },
  })
  setHand(room, p(3), {
    { "hanjin__peach", Card.Heart, 9 },
    { "hanjin__peach", Card.Heart, 10 },
    { "hanjin__peach", Card.Heart, 11 },
  })
  asClient(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    lu.assertTrue(Fk.skills[DIMENG]:canUse(me))
  end)
end

-- 锦帆军：弃置他人牌后按颜色弃牌并摸两张，颜色次数记录 ------------------
function Testhanjin_wu_damage:testJinfanjunDiscardsColorThenDraws()
  local room = FkTest.room
  grant(p(1), JINFANJUN)
  local cost = setHand(room, p(1), { { "hanjin__jink", Card.Heart, 2 } })[1]
  local victim = setHand(room, p(2), { { "hanjin__slash", Card.Diamond, 3 } })[1]

  FkTest.setNextReplies(p(1), { "1", FkTest.ReplyDiscard({ cost }) })
  inRoom(function() room:throwCard({ victim }, "test", p(2), p(1)) end)

  lu.assertEquals(room:getCardArea(victim), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(cost), Card.DiscardPile)
  lu.assertEquals(#p(1):getCardIds(Player.Hand), 2)
  lu.assertEquals(p(1):getMark("hanjin__retinue_skill_jinfanjun_red-turn"), 1)
  lu.assertEquals(p(1):getMark("hanjin__retinue_skill_jinfanjun_black-turn"), 0)
end

-- 曲阿小将：相邻两次用牌目标不完全相同，重合目标各受1点伤害 ------------
function Testhanjin_wu_damage:testQuaxiaoDamagesOverlappingTargets()
  local room = FkTest.room
  grant(p(1), QUAXIAO)
  local cards = setHand(room, p(1), {
    { "hanjin__slash", Card.Spade, 1 },
    { "hanjin__slash", Card.Heart, 2 },
  })
  local hp = p(3).hp

  FkTest.setNextReplies(p(1), { "1" })
  inRoom(function()
    room:useCard { from = p(1), tos = { p(2), p(3) }, card = Fk:getCardById(cards[1]) }
    room:useCard { from = p(1), tos = { p(3), p(4) }, card = Fk:getCardById(cards[2]) }
  end)

  lu.assertEquals(p(1):usedSkillTimes(QUAXIAO, Player.HistoryGame), 1)
  -- 两张【杀】各造成1点，曲阿重合目标再造成1点。
  lu.assertEquals(p(3).hp, hp - 3)
end

return { name = "hanjin_wu_damage" }
