-- WU 标准包：伤害、拼点与翼从定向验收文件。
-- 规则依据：docs/rules/standard-generals.md 吴区与翼从表、docs/rules/generals/wu013-zhoutai.md、
-- rulebook 相关事件条文；本文件只覆盖本轮核心行为，未接入 tests/all.lua。
--   python scripts/test.py --file tests/wu_damage.lua --timeout 180
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")

local KUROU = "qiao__skill_wu004_1"
local ZHAXIANG = "qiao__skill_wu004_2"
local TIANXIANG = "qiao__skill_wu011_1"
local HONGYAN = "qiao__skill_wu011_2"
local TIANYI = "qiao__skill_wu012_1"
local HANZHAN = "qiao__skill_wu012_2"
local BUQU = "qiao__skill_wu013_1"
local FENJI = "qiao__skill_wu013_2"
local HAOSHI = "qiao__skill_wu014_1"
local DIMENG = "qiao__skill_wu014_2"
local JINFANJUN = "qiao__retinue_skill_jinfanjun"
local QUAXIAO = "qiao__retinue_skill_quaxiaojiang"

local TURN_EFFECTS = "qiao__wu_turn_effects"
local DIMENG_EXPIRY = "qiao__wu_dimeng_expiry"
local ZHAXIANG_TIMES = "qiao_wu004_zhaxiang_times-turn"
local TIANYI_WIN = "qiao_wu012_tianyi_win-turn"
local TIANYI_LOSE = "qiao_wu012_tianyi_lose-turn"
local DIMENG_GRANTED = "qiao_wu_dimeng_granted"
local TIANXIANG_OPT_DAMAGE = "#qiao__skill_wu011_1-damage"
local TIANXIANG_OPT_LOSEHP = "#qiao__skill_wu011_1-losehp"

local DEFAULT_KINGDOMS = { "wu", "wu", "wu", "wu", "wu", "wu", "wu", "wu" }

Testqiao_wu_damage = {}

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

--- 取当前房间中指定汉晋牌位的实体牌，保留该牌位自己的 extra_data。
-- 洗牌或初始手牌可能已把它发到其他角色手里，所以不限定仍在牌堆。
local function roomCardAtSlot(room, player, slot)
  local id
  inRoom(function()
    local card = table.find(Fk.cards, function(candidate)
      local area = room:getCardArea(candidate.id)
      return candidate.extra_data ~= nil
        and candidate.extra_data.qiao_slot == slot
        and area ~= Card.Unknown and area ~= Card.Void
    end)
    assert(card ~= nil, "房间中缺少汉晋牌位 " .. slot)
    id = card.id
    room:obtainCard(player, card, false, fk.ReasonJustMove)
  end)
  return id
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
    total = total + (sk:getResidueNum(player, Fk.skills["qiao__inert"],
      Player.HistoryPhase, card, nil) or 0)
  end
  return total
end

local function targetModExtra(room, player, card)
  local total = 0
  for _, sk in ipairs(room.status_skills[TargetModSkill] or {}) do
    total = total + (sk:getExtraTargetNum(player, Fk.skills["qiao__inert"], card) or 0)
  end
  return total
end

local function initializeGenerals(room)
  inRoom(function()
    for i, pl in ipairs(room.players) do
      local kingdom = DEFAULT_KINGDOMS[i] or "wu"
      pl:revealGeneral(false, true)
      pl:revealGeneral(true, true)
      room:changeHero(pl, "qiao_test__" .. kingdom .. "_2", true, true, false, false, false)
      room:changeHero(pl, "qiao_test__" .. kingdom .. "_1", true, false, false, false, false)
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
  local room = support.initQiaoRoom()
  initializeGenerals(room)
  return room
end

Testqiao_wu_damage.setup = function() prepare() end
Testqiao_wu_damage.tearDown = support.clearRoom

-- 黄盖先失去体力并由诈降摸牌，随后可以把新摸到的牌交给目标。
function Testqiao_wu_damage:testKurouGivesCardAlreadyDrawnByZhaxiang()
  local room, huangGai, recipient = FkTest.room, p(1), p(2)
  local old = setHand(room, huangGai, { { "qiao__peach", Card.Heart, 2 } })[1]
  setHand(room, recipient, {})
  local drawn = seedDrawPile(room, {
    { "qiao__jink", Card.Spade, 3 },
    { "qiao__jink", Card.Club, 4 },
    { "qiao__jink", Card.Diamond, 5 },
  })
  inRoom(function()
    skill_test.installDualGenerals(room, huangGai, {
      main = "qiao_heg__wu004", deputy = "qiao_test__wu_2", kingdom = "wu",
    })
    room.current, huangGai.phase = huangGai, Player.Play
  end)
  lu.assertTrue(huangGai:hasSkill(KUROU))
  lu.assertTrue(huangGai:hasSkill(ZHAXIANG))
  client_room.run(room, function(clients)
    local handler = require("ltk.core.request_type.play_card"):new(clients[1])
    handler:setup()
    handler:selectSkill(KUROU, { selected = true })
    lu.assertTrue(handler:feasible())
    lu.assertFalse(handler:cardValidity(old))
    lu.assertFalse(handler:targetValidity(recipient.id))
    handler:_finish()
  end)

  local hp, requests = huangGai.hp, 0
  local ask = room.askToUseActiveSkill
  room.askToUseActiveSkill = function(self, who, params)
    if params.skill_name == "ex__choose_skill" and params.extra_data.skillName == KUROU then
      requests = requests + 1
      lu.assertEquals(huangGai.hp, hp - 1)
      lu.assertEquals(huangGai:usedSkillTimes(ZHAXIANG, Player.HistoryGame), 1)
      lu.assertItemsEquals(huangGai:getCardIds("h"), { old, drawn[1], drawn[2], drawn[3] })
      local reply = client_room.confirmSelection(room, who, params, { drawn[1] }, { recipient })
      FkTest.setNextReplies(who, { reply })
    end
    return ask(self, who, params)
  end
  local ok, err = pcall(activate, room, huangGai, KUROU, {}, {})
  room.askToUseActiveSkill = ask
  assert(ok, err)
  lu.assertEquals(requests, 1)
  lu.assertItemsEquals(huangGai:getCardIds("h"), { old, drawn[2], drawn[3] })
  lu.assertEquals(recipient:getCardIds("h"), { drawn[1] })
end

-- 诈降：多次失去体力累计次数；失去技能后本回合效果仍由静态技能提供
function Testqiao_wu_damage:testZhaxiangStackAndEffectSurviveSkillLoss()
  local room = FkTest.room
  grant(p(1), ZHAXIANG)
  lu.assertTrue(room:hasSkill(TURN_EFFECTS))

  inRoom(function()
    room:loseHp(p(1), 1, "test")
    room:loseHp(p(1), 1, "test")
  end)
  lu.assertEquals(p(1):getMark(ZHAXIANG_TIMES), 2)
  local slash = Fk:cloneCard("qiao__slash")
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
function Testqiao_wu_damage:testZhaxiangAdditionalSlashAfterRealUse()
  local room = FkTest.room
  grant(p(1), ZHAXIANG)
  local ids = setHand(room, p(1), {
    { "qiao__slash", Card.Spade, 2 },
    { "qiao__slash", Card.Heart, 3 },
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
function Testqiao_wu_damage:testTianxiangPreventsAndSourceDamages()
  local room = FkTest.room
  local heart = setHand(room, p(1), { { "qiao__peach", Card.Heart, 2 } })[1]
  clearCards(room, p(3), "he")
  inRoom(function() p(3).hp = 2 end)
  grant(p(1), TIANXIANG)
  local hp1, hp3 = p(1).hp, p(3).hp

  FkTest.setNextReplies(p(1), {
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
function Testqiao_wu_damage:testTianxiangPreventsThenTargetLosesHpAndObtainsCard()
  local room = FkTest.room
  local heart = setHand(room, p(1), { { "qiao__jink", Card.Heart, 3 } })[1]
  clearCards(room, p(4), "he")
  inRoom(function() p(4).hp = p(4).maxHp end)
  grant(p(1), TIANXIANG)
  local hp1, hp4 = p(1).hp, p(4).hp

  FkTest.setNextReplies(p(1), {
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

function Testqiao_wu_damage:testTianxiangCanDeclineWhenOnlyOneHeartIsAvailable()
  local room = FkTest.room
  local heart = setHand(room, p(1), { { "qiao__peach", Card.Heart, 2 } })[1]
  grant(p(1), TIANXIANG)
  local hp = p(1).hp
  FkTest.setNextReplies(p(1), { "" })
  inRoom(function()
    room:damage { from = p(2), to = p(1), damage = 1 }
  end)
  lu.assertEquals(p(1):usedSkillTimes(TIANXIANG, Player.HistoryGame), 0)
  lu.assertEquals(p(1).hp, hp - 1)
  lu.assertEquals(room:getCardArea(heart), Card.PlayerHand)
end

-- 红颜：黑桃手牌、装备和判定牌视为红桃 ------------------------------------
function Testqiao_wu_damage:testHongyanSpadeHandEquipAndJudge()
  local room = FkTest.room
  grant(p(1), HONGYAN)
  local hand = setHand(room, p(1), { { "qiao__peach", Card.Spade, 4 } })[1]
  local equip = addEquip(room, p(1), "qiao__chixiao_sword", Card.Spade, 5)
  lu.assertEquals(Fk:getCardById(hand).suit, Card.Heart)
  lu.assertEquals(Fk:getCardById(equip).suit, Card.Heart)
  client_room.run(room, function(clients, client)
    local viewer = require "packages.freekill-core.ltk.client.util"
    client:filterCard(hand, clients[1])
    lu.assertEquals(viewer:getCardData(hand, true).suit, "spade")
    lu.assertEquals(Fk:getCardById(hand).suit, Card.Heart)
  end)

  local judgeIds = seedDrawPile(room, { { "qiao__jink", Card.Spade, 6 } })
  local judge = { who = p(1), reason = "test", pattern = "." }
  inRoom(function() room:judge(judge) end)
  lu.assertEquals(judge.card.suit, Card.Heart)
  lu.assertEquals(judge.card.id, judgeIds[1])
end

-- 红颜：真实黑桃9雷【杀】经正常回包使用，锁视牌保留原包与逐实体元数据，
-- 原实体不变，并完成音效、移动、雷伤害和弃牌。
function Testqiao_wu_damage:testHongyanRealThunderSlashKeepsEntityAndResolves()
  local room = FkTest.room
  grant(p(1), HONGYAN)
  clearCards(room, p(1), "he")
  setHand(room, p(2), {})
  inRoom(function()
    room.current = p(1)
    p(1).phase = Player.Play
  end)

  local id = roomCardAtSlot(room, p(1), "shibei/S/9")
  local raw = Fk:getCardById(id, true)
  local rawExtra = raw.extra_data
  lu.assertNotNil(rawExtra)
  lu.assertEquals(raw.suit, Card.Spade)
  lu.assertEquals(raw.color, Card.Black)
  lu.assertEquals(rawExtra.qiao_slot, "shibei/S/9")
  lu.assertEquals(#rawExtra.qiao_adaptation, 1)
  local hp = p(2).hp

  local damages, handled = {}, {}
  inRoom(function()
    local probe = fk.CreateSkill { name = "#qiao_test_wu_hongyan_damage" }
    probe:addEffect(fk.Damage, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        return handled[event.id] ~= true and data.to == p(2)
      end,
      on_refresh = function(self, event, target, player, data)
        handled[event.id] = true
        table.insert(damages, {
          from = data.from and data.from.id,
          to = data.to and data.to.id,
          damage = data.damage,
          nature = data.damageType,
          card = data.card and data.card.id,
          suit = data.card and data.card.suit,
          package = data.card and data.card.package and data.card.package.name,
        })
      end,
    })
    room:addSkill(probe:createSkill())
  end)

  FkTest.setNextReplies(p(1), { FkTest.ReplyCard(Fk:getCardById(id), { p(2) }) })
  FkTest.setNextReplies(p(2), { "__cancel" })

  local sounds, used = {}, nil
  local originalSound = room.broadcastPlaySound
  room.broadcastPlaySound = function(self, path)
    table.insert(sounds, path)
    return originalSound(self, path)
  end
  local ok, err = pcall(function()
    inRoom(function()
      used = room:askToUseCard(p(1), { pattern = ".", cancelable = true })
      lu.assertNotNil(used)
      lu.assertEquals(used.card.id, id)
      room:useCard(used)
    end)
  end)
  room.broadcastPlaySound = originalSound
  if not ok then error(err) end

  local filtered = used.card
  lu.assertEquals(filtered.suit, Card.Heart)
  lu.assertEquals(filtered.color, Card.Red)
  lu.assertIs(filtered.package, Fk.packages.qiao_cards)
  lu.assertEquals(filtered.skill.name, "qiao__thunder_slash_skill")
  lu.assertNotIs(filtered.extra_data, rawExtra)
  lu.assertEquals(filtered.extra_data.qiao_slot, "shibei/S/9")
  lu.assertEquals(filtered.extra_data.qiao_package, "qiao_cards")
  lu.assertEquals(filtered.extra_data.qiao_adaptation[1].condition, "gujun")
  lu.assertEquals(filtered.extra_data.qiao_adaptation[1].effect, "ignore_times")

  lu.assertNotNil(table.find(sounds, function(path)
    return path ~= nil
      and path:find("/packages/qiao/", 1, true) ~= nil
      and path:find("qiao__thunder__slash", 1, true) ~= nil
  end), "实际用牌音效应按原实体所属包播放")

  lu.assertEquals(#damages, 1)
  lu.assertEquals(damages[1].from, p(1).id)
  lu.assertEquals(damages[1].to, p(2).id)
  lu.assertEquals(damages[1].damage, 1)
  lu.assertEquals(damages[1].nature, fk.ThunderDamage)
  lu.assertEquals(damages[1].card, id)
  lu.assertEquals(damages[1].suit, Card.Heart)
  lu.assertEquals(damages[1].package, "qiao_cards")
  lu.assertEquals(p(2).hp, hp - 1)

  lu.assertEquals(room:getCardArea(id), Card.DiscardPile)
  lu.assertTrue(table.contains(room.discard_pile, id))
  lu.assertIs(Fk:getCardById(id, true), raw)
  lu.assertIs(raw.extra_data, rawExtra)
  lu.assertEquals(raw.suit, Card.Spade)
  lu.assertEquals(raw.color, Card.Black)
  lu.assertEquals(rawExtra.qiao_slot, "shibei/S/9")
  lu.assertEquals(#rawExtra.qiao_adaptation, 1)
end

-- 天义赢：乐成拼点、酣战取回最大杀，并建立本回合胜利标记 ---------------
function Testqiao_wu_damage:testTianyiWinAndHanzhanTakesSlash()
  local room = FkTest.room
  local slash = setHand(room, p(1), {
    { "qiao__slash", Card.Spade, 13 },
    { "qiao__peach", Card.Heart, 2 },
  })[1]
  local other = setHand(room, p(2), { { "qiao__jink", Card.Heart, 1 } })[1]
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
function Testqiao_wu_damage:testTianyiWinEffectSurvivesSkillLoss()
  local room = FkTest.room
  local slash = setHand(room, p(1), { { "qiao__slash", Card.Spade, 13 } })[1]
  local other = setHand(room, p(2), { { "qiao__jink", Card.Heart, 1 } })[1]
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
  local card = Fk:cloneCard("qiao__slash")
  lu.assertTrue(targetModExtra(room, p(1), card) >= 1)
  lu.assertTrue(targetModResidue(room, p(1), card) >= 1)
end

-- 酣战：点数最大的【杀】并列时全部取得，不自行限“一张”
function Testqiao_wu_damage:testHanzhanTakesAllTiedHighestSlash()
  local room = FkTest.room
  local mine = setHand(room, p(1), { { "qiao__slash", Card.Spade, 13 } })[1]
  local theirs = setHand(room, p(2), { { "qiao__slash", Card.Heart, 13 } })[1]
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
function Testqiao_wu_damage:testTianyiCanUseOnClientWithoutRoom()
  local room = FkTest.room
  setHand(room, p(1), { { "qiao__peach", Card.Heart, 4 } })
  setHand(room, p(2), { { "qiao__jink", Card.Heart, 5 } })
  grant(p(1), TIANYI)

  asClient(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    lu.assertTrue(Fk.skills[TIANYI]:canUse(me))
  end)
end

-- 天义没赢：平局也按没赢处理，本回合禁止使用杀 --------------------------
function Testqiao_wu_damage:testTianyiDrawCountsAsLoseAndProhibitsSlash()
  local room = FkTest.room
  local mine = setHand(room, p(1), { { "qiao__peach", Card.Heart, 7 } })[1]
  local other = setHand(room, p(2), { { "qiao__jink", Card.Heart, 7 } })[1]
  grant(p(1), TIANYI)

  FkTest.setNextReplies(p(1), { FkTest.ReplyChooseCards({ mine }) })
  FkTest.setNextReplies(p(2), { FkTest.ReplyChooseCards({ other }) })
  activate(room, p(1), TIANYI, { p(2) }, {})

  lu.assertEquals(p(1):getMark(TIANYI_WIN), 0)
  lu.assertEquals(p(1):getMark(TIANYI_LOSE), 1)
  inRoom(function()
    lu.assertTrue(p(1):prohibitUse(Fk:cloneCard("qiao__slash")))
  end)
end

-- 不屈：真实濒死摸X、置创；无须移去则回复至1 ------------------------------
function Testqiao_wu_damage:testBuquDrawsPlacesAndRecoversWhenNoDuplicate()
  local room = FkTest.room
  grant(p(1), BUQU)
  setHand(room, p(1), { { "qiao__peach", Card.Heart, 8 } })
  local drawn = seedDrawPile(room, { { "qiao__jink", Card.Diamond, 9 } })[1]
  inRoom(function() p(1).hp = 0 end)

  FkTest.setNextReplies(p(1), { FkTest.ReplyChooseCards({ drawn }) })
  inRoom(function() room:enterDying { who = p(1) } end)

  lu.assertEquals(p(1).hp, 1)
  lu.assertEquals(#p(1):getPile("创"), 1)
  lu.assertTrue(table.contains(p(1):getCardIds(Player.Hand), drawn) == false)
end

-- 不屈：同花色重复时移去一张，不回复体力 --------------------------------
function Testqiao_wu_damage:testBuquRemovesDuplicateSuitWithoutRecover()
  local room = FkTest.room
  grant(p(1), BUQU)
  setHand(room, p(1), {})
  local old = seedDrawPile(room, { { "qiao__peach", Card.Heart, 10 } })[1]
  inRoom(function()
    room:moveCardTo({ old }, Card.PlayerSpecial, p(1), fk.ReasonPut, "test", "创", true, p(1))
  end)
  local drawn = seedDrawPile(room, { { "qiao__jink", Card.Heart, 11 } })[1]
  inRoom(function() p(1).hp = 1 end)

  FkTest.setNextReplies(p(1), { FkTest.ReplyChooseCards({ old }) })
  inRoom(function() room:enterDying { who = p(1) } end)

  lu.assertEquals(#p(1):getPile("创"), 1)
  lu.assertTrue(table.contains(p(1):getPile("创"), old))
  lu.assertEquals(room:getCardArea(drawn), Card.DiscardPile)
  lu.assertEquals(p(1).hp, 1)
end

-- 不屈：可以选择装备区的牌作为“创”
function Testqiao_wu_damage:testBuquMayPlaceEquipmentCard()
  local room = FkTest.room
  grant(p(1), BUQU)
  setHand(room, p(1), {})
  local equip = addEquip(room, p(1), "qiao__chixiao_sword", Card.Spade, 7)
  seedDrawPile(room, { { "qiao__jink", Card.Diamond, 12 } })
  inRoom(function() p(1).hp = 1 end)

  FkTest.setNextReplies(p(1), { FkTest.ReplyChooseCards({ equip }) })
  inRoom(function() room:enterDying { who = p(1) } end)

  lu.assertTrue(table.contains(p(1):getPile("创"), equip))
  lu.assertFalse(table.contains(p(1):getCardIds(Player.Equip), equip))
  lu.assertEquals(p(1).hp, 1)
end

-- 不屈：同花色多张由玩家选择保留哪一张，而不是固定保留最早
function Testqiao_wu_damage:testBuquChoosesWhichDuplicateToKeep()
  local room = FkTest.room
  grant(p(1), BUQU)
  setHand(room, p(1), {})
  local old1 = seedDrawPile(room, { { "qiao__peach", Card.Heart, 13 } })[1]
  local old2 = seedDrawPile(room, { { "qiao__jink", Card.Heart, 1 } })[1]
  inRoom(function()
    room:moveCardTo({ old1 }, Card.PlayerSpecial, p(1), fk.ReasonPut, "test", "创", true, p(1))
    room:moveCardTo({ old2 }, Card.PlayerSpecial, p(1), fk.ReasonPut, "test", "创", true, p(1))
  end)
  local drawn = seedDrawPile(room, { { "qiao__peach", Card.Heart, 2 } })[1]
  inRoom(function() p(1).hp = 1 end)

  FkTest.setNextReplies(p(1), { FkTest.ReplyChooseCards({ old2 }) })
  inRoom(function() room:enterDying { who = p(1) } end)

  local pile = p(1):getPile("创")
  lu.assertEquals(#pile, 1)
  lu.assertTrue(table.contains(pile, old2))
  lu.assertEquals(room:getCardArea(old1), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(drawn), Card.DiscardPile)
end

-- 奋激：本回合真实失去所有手牌的角色摸两张，周泰失去1点体力 ------------
function Testqiao_wu_damage:testFenjiUsesRealEmptyHandHistory()
  local room = FkTest.room
  grant(p(1), FENJI)
  local victim = setHand(room, p(3), { { "qiao__peach", Card.Heart, 12 } })[1]
  local hp = p(1).hp

  inRoom(function() room:throwCard({ victim }, "test", p(3), p(3)) end)
  FkTest.setNextReplies(p(1), { "1", FkTest.ReplyChoosePlayer({ p(3) }) })
  turnEnd(room, p(1))

  lu.assertEquals(#p(3):getCardIds(Player.Hand), 2)
  lu.assertEquals(p(1).hp, hp - 1)
end

-- 好施：实际多摸两张后按半数交给手牌最少的角色 --------------------------
function Testqiao_wu_damage:testHaoshiDrawsTwoThenGivesHalf()
  local room = FkTest.room
  grant(p(1), HAOSHI)
  local start = setHand(room, p(1), {
    { "qiao__peach", Card.Heart, 2 },
    { "qiao__jink", Card.Diamond, 3 },
  })
  setHand(room, p(2), {})
  setHand(room, p(3), { { "qiao__slash", Card.Spade, 4 } })
  local drawn = seedDrawPile(room, {
    { "qiao__peach", Card.Heart, 5 },
    { "qiao__jink", Card.Diamond, 6 },
    { "qiao__slash", Card.Spade, 7 },
    { "qiao__peach", Card.Heart, 8 },
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
function Testqiao_wu_damage:testHaoshiGiveSurvivesSkillLossBeforeAfterDraw()
  local room = FkTest.room
  grant(p(1), HAOSHI)
  local start = setHand(room, p(1), {
    { "qiao__peach", Card.Heart, 2 },
    { "qiao__jink", Card.Diamond, 3 },
  })
  setHand(room, p(2), {})
  setHand(room, p(3), { { "qiao__slash", Card.Spade, 4 } })
  local drawn = seedDrawPile(room, {
    { "qiao__peach", Card.Heart, 5 },
    { "qiao__jink", Card.Diamond, 6 },
    { "qiao__slash", Card.Spade, 7 },
    { "qiao__peach", Card.Heart, 8 },
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
function Testqiao_wu_damage:testDimengSwapsHandsAndGrantsHaoshiUntilTargetTurnEnd()
  local room = FkTest.room
  grant(p(1), DIMENG)
  local cost = setHand(room, p(1), {
    { "qiao__peach", Card.Heart, 2 },
    { "qiao__jink", Card.Diamond, 3 },
  })
  setHand(room, p(2), {
    { "qiao__slash", Card.Spade, 4 },
    { "qiao__slash", Card.Spade, 5 },
    { "qiao__slash", Card.Spade, 6 },
    { "qiao__slash", Card.Spade, 7 },
    { "qiao__slash", Card.Spade, 8 },
  })
  setHand(room, p(3), {
    { "qiao__peach", Card.Heart, 9 },
    { "qiao__peach", Card.Heart, 10 },
    { "qiao__peach", Card.Heart, 11 },
  })

  FkTest.setNextReplies(p(1), { "1" })
  activate(room, p(1), DIMENG, { p(2), p(3) }, cost)

  lu.assertEquals(#p(2):getCardIds(Player.Hand), 3)
  lu.assertEquals(#p(3):getCardIds(Player.Hand), 5)
  lu.assertTrue(p(2):hasSkill(HAOSHI))
  lu.assertTrue(room:hasSkill(DIMENG_EXPIRY))
  lu.assertEquals(p(2):getMark(DIMENG_GRANTED), 1)

  -- 追加另一来源；addSkill 即使已拥有同名技能也会记录 derivative source。
  inRoom(function()
    p(2):addSkill(Fk.skills[HAOSHI], "qiao__skill_wu005_1")
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
    room:handleAddLoseSkills(p(2), "-" .. HAOSHI, "qiao__skill_wu005_1", false, true)
  end)
  lu.assertFalse(p(2):hasSkill(HAOSHI))
end

-- 缔盟：ClientPlayer 无 room 时可安全计算；手牌数相等不能支付零张弃置
function Testqiao_wu_damage:testDimengClientCanUseAndRejectsZeroDiff()
  local room = FkTest.room
  grant(p(1), DIMENG)
  local cost = setHand(room, p(1), {
    { "qiao__peach", Card.Heart, 2 },
    { "qiao__jink", Card.Diamond, 3 },
  })
  for i = 2, 8 do
    setHand(room, p(i), {
      { "qiao__slash", Card.Spade, 4 },
      { "qiao__jink", Card.Heart, 5 },
    })
  end

  asClient(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    -- 所有其他角色手牌数相等，差为 0，不能支付“弃置零张牌”的消耗。
    lu.assertFalse(Fk.skills[DIMENG]:canUse(me))
  end)

  setHand(room, p(2), {
    { "qiao__slash", Card.Spade, 4 },
    { "qiao__slash", Card.Spade, 5 },
    { "qiao__slash", Card.Spade, 6 },
    { "qiao__slash", Card.Spade, 7 },
    { "qiao__slash", Card.Spade, 8 },
  })
  setHand(room, p(3), {
    { "qiao__peach", Card.Heart, 9 },
    { "qiao__peach", Card.Heart, 10 },
    { "qiao__peach", Card.Heart, 11 },
  })
  asClient(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room)
    local handler = require("ltk.core.request_type.play_card"):new(me)
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity(DIMENG))
    handler:selectSkill(DIMENG, { selected = true })
    lu.assertTrue(handler:targetValidity(clients[2].id))
    handler:selectTarget(clients[2].id, { selected = true })
    lu.assertTrue(handler:targetValidity(clients[3].id))
    handler:selectTarget(clients[3].id, { selected = true })
    lu.assertFalse(handler:feasible())
    for _, id in ipairs(cost) do
      lu.assertTrue(handler:cardValidity(id))
      handler:selectCard(id, { selected = true })
    end
    lu.assertTrue(handler:feasible())
    handler:_finish()
  end)
end

-- 锦帆军：弃置他人牌后按颜色弃牌并摸两张，颜色次数记录 ------------------
function Testqiao_wu_damage:testJinfanjunDiscardsColorThenDraws()
  local room = FkTest.room
  grant(p(1), JINFANJUN)
  local cost = setHand(room, p(1), { { "qiao__jink", Card.Heart, 2 } })[1]
  local victim = setHand(room, p(2), { { "qiao__slash", Card.Diamond, 3 } })[1]

  FkTest.setNextReplies(p(1), { FkTest.ReplyDiscard({ cost }) })
  inRoom(function() room:throwCard({ victim }, "test", p(2), p(1)) end)

  lu.assertEquals(room:getCardArea(victim), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(cost), Card.DiscardPile)
  lu.assertEquals(#p(1):getCardIds(Player.Hand), 2)
  lu.assertEquals(p(1):getMark("qiao__retinue_skill_jinfanjun_red-turn"), 1)
  lu.assertEquals(p(1):getMark("qiao__retinue_skill_jinfanjun_black-turn"), 0)
end

-- 曲阿小将：相邻两次用牌目标不完全相同，重合目标各受1点伤害 ------------
function Testqiao_wu_damage:testQuaxiaoDamagesOverlappingTargets()
  local room = FkTest.room
  grant(p(1), QUAXIAO)
  local cards = setHand(room, p(1), {
    { "qiao__slash", Card.Spade, 1 },
    { "qiao__slash", Card.Heart, 2 },
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

function Testqiao_wu_damage:testFenjiRetainsHistoryBeforeAcquisitionAndAfterRefill()
  local room, owner, to = FkTest.room, p(1), p(3)
  local last = setHand(room, to, { { "qiao__peach", Card.Heart, 12 } })[1]
  inRoom(function()
    room:throwCard({ last }, "test", to, to)
    to:drawCards(1)
  end)
  grant(owner, FENJI)
  local hp = owner.hp
  FkTest.setNextReplies(owner, { "1", FkTest.ReplyChoosePlayer({ to }) })
  turnEnd(room, owner)
  lu.assertEquals(to:getHandcardNum(), 3)
  lu.assertEquals(owner.hp, hp - 1)
end

function Testqiao_wu_damage:testDiscardMarksAskBelowAtAndAboveHandLimit()
  local room, player = FkTest.room, p(1)
  local H = require "packages.hegemony.util"
  local requests = __dofile("../../../tests/support/skill_test.lua")
  inRoom(function() room:setCurrent(player); player.phase = Player.Discard end)
  for _, mark in ipairs({ "yinyangfish", "wild" }) do
    local skillName = mark .. "_skill&"
    for _, offset in ipairs({ -1, 0, 1 }) do
      local specs = {}
      inRoom(function() room:setPlayerMark(player, MarkEnum.AddMaxCardsInTurn, 0) end)
      local limit = player:getMaxCards()
      for _ = 1, limit + offset do table.insert(specs, { "qiao__jink" }) end
      setHand(room, player, specs)
      inRoom(function() H.addHegMark(player, mark, 1) end)
      local count = player:getMark("@!!" .. mark)
      local asked = 0
      requests.withSkillRequests(room, skillName, {
        askToSkillInvoke = function() asked = asked + 1; return asked == 2 end,
      }, function()
        for i = 1, 2 do
          inRoom(function() room.logic:trigger(fk.EventPhaseStart, player, { phase = Player.Discard }) end)
          lu.assertEquals(asked, i)
          lu.assertEquals(player:getMark("@!!" .. mark), i == 1 and count or count - 1)
          lu.assertEquals(player:getMaxCards(), i == 1 and limit or limit + 2)
        end
      end)
    end
  end
end

return { name = "qiao_wu_damage" }
