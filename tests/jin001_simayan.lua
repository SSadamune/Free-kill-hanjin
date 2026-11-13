-- JIN001 司马炎：垂统、兴图。默认国战套件用例。
-- 规则依据：rules/generals/jin001-simayan.md 第 2、3 节、
-- rules/equipment-movement.md、rules/adaptation.md、rules/card-use-targets.md。
local support = __dofile("../../../tests/support/hegemony.lua")

local CT = "hanjin__skill_jin001_1"
local XT = "hanjin__skill_jin001_2"
local AUX = "#hanjin__skill_jin001_2_active"
local OPTION_EQUIP = "hanjin__skill_jin001_2-option_equip"
local OPTION_DRAW = "hanjin__skill_jin001_2-option_draw"
local TRACK_TAG = "hanjin_jin001_2_adaptation_used"

--- Resolve the HanJin API only after the engine has loaded packages; a
--- top-level require here would initialize the mode package before postLoad.
local function adaptation()
  return require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
end

local DEFAULT_KINGDOMS = { "han", "han", "wei", "wei", "shu", "shu", "wei", "han" }

Testhanjin_jin001 = {}

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function clearCards(room, player, area)
  local ids = player:getCardIds(area or "he")
  if #ids > 0 then
    inRoom(function()
      room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end)
  end
end

--- Replace a player's hand (and optionally equipment) with printed cards.
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

local function addEquip(room, player, name, suit, number)
  local id
  inRoom(function()
    local card = room:printCard(name, suit or Card.Spade, number or 1)
    room:moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, false)
    id = card.id
  end)
  return id
end

local function grant(player, skillName)
  inRoom(function()
    player.room:handleAddLoseSkills(player, skillName, nil, false, true)
  end)
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
    end
    room:changeHero(room.players[1], "hanjin__jin001", true, false, false, false, false)
    room:setPlayerMark(room.players[1], "__heg_general", "hanjin__jin001")
    room.players[1].kingdom = "jin"
    room:setPlayerProperty(room.players[1], "kingdom", "jin")
    room:setPlayerMark(room.players[1], "__heg_kingdom", "jin")
    for _, p in ipairs(room.players) do p.hp = p.maxHp end
  end)
end

local function installJinDeputy(room)
  inRoom(function()
    local p = room.players[1]
    room:changeHero(p, "hanjin_test__han_1", true, false, false, false, false)
    room:changeHero(p, "hanjin__jin001", true, true, false, false, false)
    room:setPlayerMark(p, "__heg_general", "hanjin_test__han_1")
    room:setPlayerMark(p, "__heg_deputy", "hanjin__jin001")
  end)
end

local function prepare()
  initializeGenerals(support.initHanjinRoom())
  return FkTest.room
end

Testhanjin_jin001.setup = function()
  prepare()
end
Testhanjin_jin001.tearDown = support.clearRoom

local function p1() return FkTest.room.players[1] end
local function p2() return FkTest.room.players[2] end
local function p3() return FkTest.room.players[3] end

local function clearAllHands(room)
  for _, p in ipairs(room.players) do setHand(room, p, {}) end
end

local function enterDying(room, who)
  inRoom(function()
    who.hp = 1
    room:enterDying { who = who }
  end)
end

local function turnStart(room, player)
  inRoom(function() room.logic:trigger(fk.PreTurnStart, player, {}) end)
end

local function turnEnd(room, player)
  inRoom(function() room.logic:trigger(fk.TurnEnd, player, {}) end)
end

local function useAdaptation(room, from, to)
  local card = Fk:cloneCard("hanjin_test__blank_basic")
  adaptation().setCardEntries(card, { { condition = "gujun", effect = "draw" } })
  inRoom(function()
    room:useCard { from = from, tos = { to }, card = card }
  end)
end

local function useOrdinary(room, from, to)
  local card = Fk:cloneCard("hanjin_test__blank_basic")
  inRoom(function()
    room:useCard { from = from, tos = { to }, card = card }
  end)
end

--- 纯“打出”一张带应变条目的实体牌，不经过使用牌事件。
local function pureRespond(room, from)
  local id = addHand(room, from, { { "hanjin_test__blank_basic" } })[1]
  local card = Fk:getCardById(id)
  adaptation().setCardEntries(card, { { condition = "gujun", effect = "draw" } })
  inRoom(function()
    room:responseCard { from = from, card = card }
  end)
end

--- 在真实回合的 TurnStart 时机使用一张牌，随后由真实 TurnEnd 检查兴图。
local function installTurnStartCard(room, from, to, entries)
  local fired = false
  local skel = fk.CreateSkill { name = "#hanjin_jin001_turnstart_probe" }
  skel:addEffect(fk.TurnStart, {
    global = true,
    can_refresh = function(self, event, target, player)
      return not fired and target == player and player == from
    end,
    on_refresh = function(self, event, target, player)
      fired = true
      local card = Fk:cloneCard("hanjin_test__blank_basic")
      entries = entries or { { condition = "gujun", effect = "draw" } }
      adaptation().setCardEntries(card, entries)
      from.room:useCard { from = from, tos = { to }, card = card }
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)
end

local function installUseProbe(room, uses)  local skel = fk.CreateSkill { name = "#hanjin_jin001_peach_probe" }
  skel:addEffect(fk.CardUsing, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == player and data.card ~= nil and data.card.trueName == "peach"
    end,
    on_refresh = function(self, event, target, player, data)
      table.insert(uses, {
        from = data.from,
        tos = table.simpleClone(data.tos or {}),
        card = data.card,
      })
    end,
  })
  inRoom(function() room:addSkill(skel:createSkill()) end)
end

-- 垂统 ---------------------------------------------------------------------

function Testhanjin_jin001:testCT01MovesIntoEmptyCorrespondingSlotNotHand()
  local room = FkTest.room
  clearAllHands(room)
  local equip = addEquip(room, p2(), "jueying")
  FkTest.setNextReplies(p1(), { "1", equip })
  enterDying(room, p2())
  lu.assertTrue(table.contains(p1():getCardIds("e"), equip))
  lu.assertFalse(table.contains(p2():getCardIds("e"), equip))
  lu.assertEquals(room:getCardArea(equip), Card.PlayerEquip)
  lu.assertEquals(#p1():getCardIds("h"), 0)
  lu.assertEquals(p1():usedSkillTimes(CT, Player.HistoryGame), 1)
end

function Testhanjin_jin001:testCT02DeputySourceAndHiddenSourceReveal()
  local room = FkTest.room
  clearAllHands(room)
  installJinDeputy(room)
  local equip = addEquip(room, p2(), "jueying")
  FkTest.setNextReplies(p1(), { "1", equip })
  enterDying(room, p2())
  lu.assertTrue(table.contains(p1():getCardIds("e"), equip))

  -- 暗置的副将来源：预亮后发动，SkillEffect 应明置实际提供技能的武将牌。
  inRoom(function()
    p1():hideGeneral(true)
    p1():prelightSkill(Fk.skills[CT], true)
  end)
  lu.assertTrue(p1():isFakeSkill(CT))
  local hiddenEquip = addEquip(room, p2(), "qinggang_sword")
  FkTest.setNextReplies(p1(), { "1", hiddenEquip })
  enterDying(room, p2())
  lu.assertEquals(p1().deputyGeneral, "hanjin__jin001")
  lu.assertFalse(p1():isFakeSkill(CT))
  lu.assertTrue(table.contains(p1():getCardIds("e"), hiddenEquip))
end

function Testhanjin_jin001:testCT03OccupiedOrSealedSlotAndNoCardDoNotMove()
  local room = FkTest.room
  clearAllHands(room)
  local owned = addEquip(room, p1(), "jueying")
  local moving = addEquip(room, p2(), "jueying")
  FkTest.setNextReplies(p1(), { "" })
  enterDying(room, p2())
  lu.assertTrue(table.contains(p2():getCardIds("e"), moving))
  lu.assertTrue(table.contains(p1():getCardIds("e"), owned))
  lu.assertEquals(p1():usedSkillTimes(CT, Player.HistoryGame), 0)

  -- 同栏已废除：即使没有装备，也不能移入该栏。
  clearCards(room, p1(), "e")
  inRoom(function() room:abortPlayerArea(p1(), Player.DefensiveRideSlot) end)
  FkTest.setNextReplies(p1(), { "" })
  enterDying(room, p2())
  lu.assertTrue(table.contains(p2():getCardIds("e"), moving))
  lu.assertEquals(#p1():getCardIds("e"), 0)
  lu.assertEquals(p1():usedSkillTimes(CT, Player.HistoryGame), 0)

  -- 无牌或取消发动：均不移动。
  clearCards(room, p2(), "e")
  FkTest.setNextReplies(p1(), { "" })
  enterDying(room, p2())
  lu.assertEquals(#p2():getCardIds("e"), 0)
  clearCards(room, p1(), "e")
  local cancelled = addEquip(room, p2(), "jueying")
  FkTest.setNextReplies(p1(), { "" })
  enterDying(room, p2())
  lu.assertTrue(table.contains(p2():getCardIds("e"), cancelled))
  lu.assertEquals(p1():usedSkillTimes(CT, Player.HistoryGame), 0)

  -- 自己进入濒死不发动；不能把自己装备区的牌移给自己。
  local own = addEquip(room, p1(), "qinggang_sword")
  inRoom(function() p1().hp = 1 end)
  FkTest.setNextReplies(p1(), { "" })
  inRoom(function() room:enterDying { who = p1() } end)
  lu.assertTrue(table.contains(p1():getCardIds("e"), own))
  lu.assertEquals(p1():usedSkillTimes(CT, Player.HistoryGame), 0)
end

function Testhanjin_jin001:testCT04DyingEventOffersOnceNotPerPeachRequest()
  local room = FkTest.room
  clearAllHands(room)
  local equip = addEquip(room, p2(), "jueying")
  -- hp 0 会进入求桃流程；垂统只在 EnterDying 提供一次机会。
  for _, p in ipairs(room.players) do FkTest.setNextReplies(p, { "" }) end
  FkTest.cleanNextReplies(p1())
  FkTest.setNextReplies(p1(), { "1", equip })
  inRoom(function()
    p2().hp = 0
    room:enterDying { who = p2() }
  end)
  lu.assertEquals(p1():usedSkillTimes(CT, Player.HistoryGame), 1)
  lu.assertTrue(table.contains(p1():getCardIds("e"), equip))
end

-- 兴图 ---------------------------------------------------------------------

function Testhanjin_jin001:testXT01NoAdaptationUseNoTrigger()
  local room = FkTest.room
  clearAllHands(room)
  turnStart(room, p1())
  FkTest.setNextReplies(p1(), { "" })
  turnEnd(room, p1())
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 0)

  turnStart(room, p1())
  useOrdinary(room, p2(), p3())
  FkTest.setNextReplies(p1(), { "" })
  turnEnd(room, p1())
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 0)

  -- 纯打出带应变条目的牌不属于使用，不计入本回合事实。
  turnStart(room, p1())
  pureRespond(room, p2())
  FkTest.setNextReplies(p1(), { "" })
  turnEnd(room, p1())
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 0)
end

function Testhanjin_jin001:testXT02OtherRoleUseBeforeSkillAcquiredCountsAtTurnEnd()
  local room = FkTest.room
  clearAllHands(room)
  -- 先用测试武将，确保用牌事实发生在 p1 尚未获得兴图之前。
  inRoom(function()
    room:changeHero(p1(), "hanjin_test__han_2", true, false, false, false, false)
    room:setPlayerMark(p1(), "__heg_general", "hanjin_test__han_2")
  end)
  lu.assertFalse(p1():hasSkill(XT))
  turnStart(room, p1())
  useAdaptation(room, p2(), p3())
  lu.assertEquals(room:getTag(TRACK_TAG), true)
  grant(p1(), XT)
  lu.assertTrue(p1():hasSkill(XT))
  local before = #p1():getCardIds("h")
  FkTest.setNextReplies(p1(), { { OPTION_DRAW } })
  turnEnd(room, p1())
  lu.assertEquals(#p1():getCardIds("h"), before + 1)
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 1)
end

function Testhanjin_jin001:testXT03AnyRolesTurnEndAndNextTurnCleanup()
  local room = FkTest.room
  clearAllHands(room)
  turnStart(room, p2())
  useAdaptation(room, p3(), p1())
  local before = #p1():getCardIds("h")
  FkTest.setNextReplies(p1(), { { OPTION_DRAW } })
  turnEnd(room, p2())
  lu.assertEquals(#p1():getCardIds("h"), before + 1)
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 1)

  -- 下一回合清理上一回合的用牌事实；本轮没有新用牌时不发动。
  turnStart(room, p1())
  lu.assertEquals(room:getTag(TRACK_TAG), false)
  FkTest.setNextReplies(p1(), { "" })
  turnEnd(room, p1())
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 1)
end

function Testhanjin_jin001:testXT03bRealTurnPreTurnStartClearsFact()
  local room = FkTest.room
  clearAllHands(room)
  installTurnStartCard(room, p2(), p3())
  local before = #p1():getCardIds("h")
  FkTest.setNextReplies(p1(), { { OPTION_DRAW } })
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p2(), "game_rule", { Player.Play })):exec()
  end)
  lu.assertEquals(#p1():getCardIds("h"), before + 1)
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 1)

  -- 第二个真实回合没有用应变牌；PreTurnStart 必须清空上一回合事实。
  before = #p1():getCardIds("h")
  FkTest.setNextReplies(p1(), {})
  inRoom(function()
    GameEvent.Turn:create(TurnData:new(p2(), "game_rule", { Player.Play })):exec()
  end)
  lu.assertEquals(#p1():getCardIds("h"), before)
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 1)
end

function Testhanjin_jin001:testXT04DrawOptionAndDecline()
  local room = FkTest.room
  clearAllHands(room)
  turnStart(room, p2())
  useAdaptation(room, p2(), p3())
  local before = #p1():getCardIds("h")
  FkTest.setNextReplies(p1(), { { OPTION_DRAW } })
  turnEnd(room, p2())
  lu.assertEquals(#p1():getCardIds("h"), before + 1)
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 1)

  turnStart(room, p2())
  useAdaptation(room, p2(), p3())
  before = #p1():getCardIds("h")
  FkTest.setNextReplies(p1(), { "" })
  turnEnd(room, p2())
  lu.assertEquals(#p1():getCardIds("h"), before)
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 1)
end

function Testhanjin_jin001:testXT04bCancelDoesNotRevealOrCount()
  local room = FkTest.room
  clearAllHands(room)
  inRoom(function()
    p1():hideGeneral(false)
    p1():prelightSkill(Fk.skills[XT], true)
  end)
  lu.assertTrue(p1():isFakeSkill(XT))
  turnStart(room, p2())
  useAdaptation(room, p2(), p3())
  FkTest.setNextReplies(p1(), { "" })
  turnEnd(room, p2())
  lu.assertEquals(p1().general, "anjiang")
  lu.assertTrue(p1():isFakeSkill(XT))
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 0)
end

function Testhanjin_jin001:testXT05PeachFromHandUsesRealCardAndHealsOther()
  local room = FkTest.room
  clearAllHands(room)
  local equip = addHand(room, p1(), { { "jueying" } })[1]
  inRoom(function()
    p2().hp = p2().maxHp - 1
  end)
  p2().hp = p2().maxHp - 1
  turnStart(room, p2())
  useAdaptation(room, p2(), p3())
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), {
    { OPTION_EQUIP }, FkTest.ReplyUseSkill(AUX, { p2() }, { equip }),
  })
  turnEnd(room, p2())
  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].from, p1())
  lu.assertIs(uses[1].tos[1], p2())
  lu.assertEquals(uses[1].card.trueName, "peach")
  lu.assertEquals(uses[1].card.skillName, XT)
  lu.assertEquals(uses[1].card.subcards, { equip })
  lu.assertEquals(p2().hp, p2().maxHp)
  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 1)
end

function Testhanjin_jin001:testXT06PeachFromEquipmentOnUnwoundedTargetStillOneUse()
  local room = FkTest.room
  clearAllHands(room)
  local equip = addEquip(room, p1(), "jueying")
  inRoom(function() p2().hp = p2().maxHp end)
  turnStart(room, p2())
  useAdaptation(room, p2(), p3())
  local uses = {}
  installUseProbe(room, uses)
  FkTest.setNextReplies(p1(), {
    { OPTION_EQUIP }, FkTest.ReplyUseSkill(AUX, { p2() }, { equip }),
  })
  turnEnd(room, p2())
  lu.assertEquals(#uses, 1)
  lu.assertIs(uses[1].tos[1], p2())
  lu.assertEquals(uses[1].card.subcards, { equip })
  lu.assertEquals(p2().hp, p2().maxHp)
  lu.assertEquals(room:getCardArea(equip), Card.DiscardPile)
  lu.assertEquals(p1():usedSkillTimes(XT, Player.HistoryGame), 1)
end

function Testhanjin_jin001:testXT07NoEquipmentOnlyDrawOptionAndPeachCancel()
  local room = FkTest.room
  clearAllHands(room)
  setHand(room, p1(), { { "hanjin__slash" } })
  turnStart(room, p2())
  useAdaptation(room, p2(), p3())
  local captured
  local asked = 0
  local original = room.askToChoice
  room.askToChoice = function(self, player, params)
    if params.skill_name == XT then
      asked = asked + 1
      captured = table.simpleClone(params.choices)
    end
    return original(self, player, params)
  end
  local before = #p1():getCardIds("h")
  FkTest.setNextReplies(p1(), { { OPTION_DRAW } })
  turnEnd(room, p2())
  room.askToChoice = original
  lu.assertEquals(asked, 1)
  lu.assertEquals(captured, { OPTION_DRAW })
  lu.assertEquals(#p1():getCardIds("h"), before + 1)

  -- 有合法装备但同时取消选牌：不摸牌、不使用，也不留下移动。
  turnStart(room, p2())
  useAdaptation(room, p2(), p3())
  local equip = addHand(room, p1(), { { "jueying" } })[1]
  local handBefore = #p1():getCardIds("h")
  FkTest.setNextReplies(p1(), { { OPTION_EQUIP }, "" })
  turnEnd(room, p2())
  lu.assertEquals(#p1():getCardIds("h"), handBefore)
  lu.assertEquals(room:getCardArea(equip), Card.PlayerHand)
end

function Testhanjin_jin001:testXT08DeputySource()
  local room = FkTest.room
  clearAllHands(room)
  installJinDeputy(room)
  lu.assertTrue(p1():hasSkill(XT))
  turnStart(room, p2())
  useAdaptation(room, p2(), p3())
  local before = #p1():getCardIds("h")
  FkTest.setNextReplies(p1(), { { OPTION_DRAW } })
  turnEnd(room, p2())
  lu.assertEquals(#p1():getCardIds("h"), before + 1)
end
function Testhanjin_jin001:testHGDefaultSuiteAndRoomIsolation()
  lu.assertTrue(table.contains(Fk.packages.hanjin_generals.game_modes_whitelist, "hanjin_heg_mode"))
  lu.assertEquals(FkTest.room:getSettings("gameMode"), "hanjin_heg_mode")
  lu.assertNotNil(Fk.skills[CT])
  lu.assertNotNil(Fk.skills[XT])
  lu.assertNotNil(Fk.skills[AUX])
end

function Testhanjin_jin001:testXT09bEightDiagramVirtualJinkHasNoAdaptationEntry()
  local card = Fk:cloneCard("hanjin__jink")
  card.skillName = "hanjin__eight_diagram_skill"
  local use = { from = p1(), tos = {}, card = card }
  lu.assertEquals(#adaptation().getEntries(card, use), 0)
  lu.assertFalse(adaptation().isAdaptationCard(card, use))
end

function Testhanjin_jin001:testXT09RealClientPlayerSelectsEquipmentAndTarget()
  local room = FkTest.room
  clearAllHands(room)
  local equip = addHand(room, p1(), { { "jueying" } })[1]
  local nonEquip = addHand(room, p1(), { { "hanjin__slash" } })[1]
  -- 触发真实的 AskForUseActiveSkill 请求，使客户端拿到实际房间状态。
  FkTest.setNextReplies(p1(), { { OPTION_EQUIP }, FkTest.ReplyUseSkill(AUX, { p2() }, { equip }) })
  turnStart(room, p2())
  useAdaptation(room, p2(), p3())
  FkTest.setRoomBreakpoint(p1(), "AskForUseActiveSkill", function(data)
    return type(data) == "table" and data[1] == AUX
  end)
  turnEnd(room, p2())
  FkTest.runInClient(function()
    local handler = ClientInstance.current_request_handler
    lu.assertNotNil(handler)
    lu.assertEquals(handler.class.name, "HanjinActiveSkill")
    lu.assertEquals(handler.class.super.name, "ReqActiveSkill")
    lu.assertEquals(handler.skill_name, AUX)
    local me = handler.player
    lu.assertEquals(me.class.name, "ClientPlayer")
    lu.assertNil(me.room)
    -- The test backend does not replay this room's move notifications into the
    -- long-lived client instance. Seed only the client's own hand entry; the
    -- request handler, skill filters and target lookup are the real client path.
    me.player_cards[Player.Hand] = { equip }
    lu.assertTrue(handler:cardValidity(equip))
    lu.assertFalse(handler:cardValidity(nonEquip))
    lu.assertTrue(handler:targetValidity(me.id))
  end)
  FkTest.resumeRoom()
end

return { name = "hanjin_jin001" }
