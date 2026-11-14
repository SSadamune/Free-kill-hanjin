-- 吴 标准包：阶段与用牌历史组定向验收（克己、谋断、涉猎、国色、流离、
-- 谦逊、度势、短兵、奋迅）。
-- 规则依据：rules/standard-generals.md 吴区、rules/generals/wu003-lvmeng.md。
-- 接口核对锁定 0.5.25 与 hegemony。
-- 定向运行：
--   python scripts/test.py --file tests/wu_phases.lua --timeout 180
local support = __dofile("../../../tests/support/hegemony.lua")

local KEJI = "hanjin__skill_wu003_1"
local MOUDUAN = "hanjin__skill_wu003_2"
local SHELIE = "hanjin__skill_wu003_3"
local GUOSE = "hanjin__skill_wu006_1"
local LIULI = "hanjin__skill_wu006_2"
local QIANXUN = "hanjin__skill_wu007_1"
local DUSHI = "hanjin__skill_wu007_2"
local DUANBING = "hanjin__skill_wu016_1"
local FENXUN = "hanjin__skill_wu016_2"
local H = require "packages.hanjin.pkg.hanjin_mode.rules.wu_history"
local W = require "packages.hanjin.pkg.hanjin_generals.util.wu_phases"

local function room() return FkTest.room end
local function p(n) return room().players[n] end

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function setGeneral(player, general)
  inRoom(function()
    player:revealGeneral(false, true)
    player:revealGeneral(true, true)
    room():changeHero(player, general, true, false, false, false, false)
    room():changeHero(player, "hanjin_test__wu_2", true, true, false, false, false)
    player.kingdom = "wu"
    room():setPlayerProperty(player, "kingdom", "wu")
    room():setPlayerMark(player, "__heg_general", general)
    room():setPlayerMark(player, "__heg_deputy", player.deputyGeneral)
    room():setPlayerMark(player, "__heg_kingdom", "wu")
    room():setPlayerMark(player, "__heg_init_kingdom", "wu")
    room():setPlayerMark(player, "__heg_wild", 0)
    player.maxHp = player:getGeneralMaxHp()
    player.hp = player.maxHp
  end)
end

local function whiteboard(player)
  setGeneral(player, "hanjin_test__wu_1")
end

local function grant(player, name)
  inRoom(function() room():handleAddLoseSkills(player, name, nil, false, true) end)
end

local function clearCards(player, area)
  inRoom(function()
    local ids = player:getCardIds(area or "hej")
    if #ids > 0 then
      room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end)
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 1)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function seedDrawPile(specs)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs) do
      local card = room():printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      table.removeOne(room().draw_pile, card.id)
      table.insert(room().draw_pile, 1, card.id)
      room().card_place[card.id] = Card.DrawPile
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function use(player, card, tos)
  inRoom(function()
    room().current = player
    room():useCard(UseCardData:new {
      from = player,
      tos = tos or {},
      card = card,
      extra_data = {},
    })
  end)
end

local function triggerPhase(player, phase)
  inRoom(function()
    room().current = player
    player.phase = phase
    room().logic:trigger(fk.EventPhaseStart, player, PhaseData:new {
      who = player,
      reason = "game_rule",
      phase = phase,
    })
  end)
end

local function activate(player, skillName, targets, cards, interaction)
  inRoom(function()
    local reply = FkTest.ReplyUseSkill(skillName, targets, cards or {})
    reply.interaction_data = interaction
    room():handleUseCardReply(player, reply)
  end)
end

local function activeName(base)
  -- active/viewas 主效果沿用骨架名（createSkill 将首个效果命名为骨架名）。
  if Fk.skills[base] ~= nil then return base end
end

local function triggerPhaseChanging(player, phase)
  inRoom(function()
    room().current = player
    room().logic:trigger(fk.EventPhaseChanging, player, PhaseData:new {
      who = player,
      reason = "game_rule",
      phase = phase,
    })
  end)
end

local function prepare()
  local room = support.initHanjinRoom()
  for _, pl in ipairs(room.players) do whiteboard(pl) end
  return room
end

Testhanjin_wu_phases = { setup = prepare, tearDown = support.clearRoom }

function Testhanjin_wu_phases:testKejiUsesPlayPhaseColorsOnly()
  local p1, p2 = p(1), p(2)
  setGeneral(p1, "hanjin__wu003")
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p2.hp = 20 end)
  local black = give(p1, "hanjin__slash", Card.Spade)
  local red = give(p1, "hanjin__slash", Card.Heart)
  inRoom(function() room().current = p1; p1.phase = Player.Play end)

  -- 两种颜色均使用：不加手牌上限。
  use(p1, Fk:getCardById(black), { p2 })
  use(p1, Fk:getCardById(red), { p2 })
  triggerPhaseChanging(p1, Player.Discard)
  lu.assertEquals(p1:getMark(MarkEnum.AddMaxCardsInTurn), 0)

  -- 只使用一种颜色：+4。
  inRoom(function()
    p1:setMark(MarkEnum.AddMaxCardsInTurn, 0)
    H.clear(room())
  end)
  use(p1, Fk:getCardById(red), { p2 })
  triggerPhaseChanging(p1, Player.Discard)
  lu.assertEquals(p1:getMark(MarkEnum.AddMaxCardsInTurn), 4)
end

function Testhanjin_wu_phases:testMoudanCountsWholeTurnAndGrantsShelieWithoutUsingIt()
  local p1, p2 = p(1), p(2)
  setGeneral(p1, "hanjin__wu003")
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p2.hp = 30; H.clear(room()); room().current = p1; p1.phase = Player.Play end)
  -- 四项条件：四种花色 + 三种类别，测试数据必须同时满足两项，谋断才会
  -- 授予涉猎（只满足花色时按规则不授予）。
  FkTest.setNextReplies(p2, { "", "" })
  local spadeSlash = give(p1, "hanjin__slash", Card.Spade)
  local diamondSlash = give(p1, "hanjin__slash", Card.Diamond)
  local equip = give(p1, "hanjin__axe", Card.Heart)
  local trick = give(p1, "hanjin__dismantlement", Card.Club)
  use(p1, Fk:getCardById(spadeSlash), { p2 })
  use(p1, Fk:getCardById(diamondSlash), { p2 })
  use(p1, Fk:getCardById(equip), { p1 })
  use(p1, Fk:getCardById(trick), { p2 })
  -- 避免谋断的“移动场上一张牌”询问消费发动回复。
  clearCards(p1, "e")

  local beforeHand = p1:getHandcardNum()
  lu.assertTrue(room():hasSkill(H.HISTORY_SKILL))
  lu.assertEquals(#W.usedThisTurn(p1), 4)
  local usedSuits, suitKinds = {}, 0
  for _, record in ipairs(W.usedThisTurn(p1)) do usedSuits[record.suit] = true end
  for _ in pairs(usedSuits) do suitKinds = suitKinds + 1 end
  lu.assertEquals(suitKinds, 4)
  lu.assertEquals(p1.phase, Player.Play)
  lu.assertTrue(p1:hasSkill(MOUDUAN))
  lu.assertNotNil(Fk.skill_skels[MOUDUAN])
  lu.assertNotNil(Fk.skill_skels[SHELIE])
  lu.assertFalse(p1:hasSkill(SHELIE))
  FkTest.setNextReplies(p1, { "1" })
  triggerPhase(p1, Player.Finish)

  lu.assertTrue(p1:hasSkill(SHELIE))
  -- 只获得技能，不在此次结算中额外发动涉猎。
  lu.assertEquals(p1:getHandcardNum(), beforeHand)
  lu.assertEquals(p1.phase, Player.Finish)
end

function Testhanjin_wu_phases:testShelieRevealsFiveAndTakesDistinctSuits()
  local p1 = p(1)
  setGeneral(p1, "hanjin__wu003")
  grant(p1, SHELIE)
  lu.assertNotNil(Fk.skills[SHELIE])
  lu.assertTrue(p1:hasSkill(SHELIE))
  clearCards(p1)
  local ids = seedDrawPile {
    { "hanjin_test__blank_basic", Card.Spade },
    { "hanjin_test__blank_basic", Card.Heart },
    { "hanjin_test__blank_basic", Card.Club },
    { "hanjin_test__blank_basic", Card.Diamond },
    { "hanjin_test__blank_basic", Card.Spade },
  }
  lu.assertNotNil(Fk.poxi_methods["hanjin_shelie"])
  FkTest.setNextReplies(p1, {
    "1",
    { { ids[5] }, { ids[1], ids[2], ids[3], ids[4] } },
  })
  triggerPhase(p1, Player.Draw)

  local hand = p1:getCardIds(Player.Hand)
  lu.assertEquals(#hand, 4)
  local seen = {}
  for _, id in ipairs(hand) do
    local suit = Fk:getCardById(id).suit
    lu.assertFalse(seen[suit] == true)
    seen[suit] = true
  end
  lu.assertEquals(#seen, 4)
  -- 未获得的牌进入弃牌堆，处理区清空。
  for _, id in ipairs(ids) do
    lu.assertNotEquals(room():getCardArea(id), Card.Processing)
  end
end

function Testhanjin_wu_phases:testLiuliTransfersSlashToAnotherTarget()
  local p1, p2 = p(1), p(2)
  setGeneral(p1, "hanjin__wu006")
  clearCards(p1)
  clearCards(p2)
  local near = table.find(room().alive_players, function(pl)
    return pl ~= p1 and pl ~= p2 and not pl:isRemoved() and p1:distanceTo(pl) == 1
  end)
  lu.assertNotNil(near)
  clearCards(near)
  inRoom(function() p1.hp = p1.maxHp; p2.hp = p2.maxHp; near.hp = near.maxHp end)
  local cost = give(p1, "hanjin_test__blank_basic", Card.Spade)
  give(p1, "hanjin_test__blank_basic", Card.Heart)
  local slash = give(p2, "hanjin__slash", Card.Spade)
  FkTest.setNextReplies(p1, { "1", cost, FkTest.ReplyChoosePlayer({ near }) })
  inRoom(function()
    room().current = p2
    p2.phase = Player.Play
    room():useCard(UseCardData:new {
      from = p2,
      tos = { p1 },
      card = Fk:getCardById(slash),
      extra_data = {},
    })
  end)
  lu.assertEquals(p1.hp, p1.maxHp)
  lu.assertEquals(near.hp, near.maxHp - 1)
  lu.assertFalse(table.contains(p1:getCardIds("he"), cost))
end

function Testhanjin_wu_phases:testLiuliCancelDoesNotDiscard()
  local p1, p2 = p(1), p(2)
  setGeneral(p1, "hanjin__wu006")
  clearCards(p1)
  clearCards(p2)
  local near = table.find(room().alive_players, function(pl)
    return pl ~= p1 and pl ~= p2 and not pl:isRemoved() and p1:distanceTo(pl) == 1
  end)
  lu.assertNotNil(near)
  inRoom(function() p1.hp = p1.maxHp; p2.hp = p2.maxHp; near.hp = near.maxHp end)
  local cost = give(p1, "hanjin_test__blank_basic", Card.Spade)
  local slash = give(p2, "hanjin__slash", Card.Spade)
  -- 取消转移目标：不支付弃牌，原【杀】仍以大乔为目标。
  FkTest.setNextReplies(p1, { "1", cost, FkTest.ReplyChoosePlayer({}) })
  inRoom(function()
    room().current = p2
    p2.phase = Player.Play
    room():useCard(UseCardData:new {
      from = p2,
      tos = { p1 },
      card = Fk:getCardById(slash),
      extra_data = {},
    })
  end)
  lu.assertTrue(table.contains(p1:getCardIds("he"), cost))
  lu.assertEquals(p1.hp, p1.maxHp - 1)
end

function Testhanjin_wu_phases:testQianxunCancelsOnlyWhenAnotherLegalTargetRemains()
  local p1, p2, p3 = p(1), p(2), p(3)
  setGeneral(p1, "hanjin__wu007")
  clearCards(p1)
  clearCards(p2)
  clearCards(p3)
  inRoom(function() H.clear(room()) end)

  -- 单目标锦囊，p3 是尚未指定的合法目标：取消 p1 这个目标。
  local indulgence = give(p2, "hanjin__indulgence", Card.Heart)
  inRoom(function()
    room().current = p2
    p2.phase = Player.Play
    room():useCard(UseCardData:new {
      from = p2,
      tos = { p1 },
      card = Fk:getCardById(indulgence),
      extra_data = {},
    })
  end)
  lu.assertEquals(#p1:getCardIds(Player.Judge), 0)
  lu.assertEquals(p1:getMark("hanjin__skill_wu007_1_used-turn"), 1)

  -- 同回合第二次成为锦囊目标：机会已消耗，不再取消。
  local second = give(p2, "hanjin__indulgence", Card.Heart)
  inRoom(function()
    room().current = p2
    p2.phase = Player.Play
    room():useCard(UseCardData:new {
      from = p2,
      tos = { p1 },
      card = Fk:getCardById(second),
      extra_data = {},
    })
  end)
  lu.assertEquals(#p1:getCardIds(Player.Judge), 1)
end

-- 条件“有未指定的合法目标”的否定分支（群体锦囊已指定所有目标）本轮不单独
-- 构造：需要消费多名角色的响应请求，风险高于本轮核心验收；留待后续补测。

function Testhanjin_wu_phases:testGuoseBothBranchesIndependentLimits()
  local p1, p2 = p(1), p(2)
  setGeneral(p1, "hanjin__wu006")
  clearCards(p1)
  clearCards(p2)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p1.hp = p1.maxHp
    p2.hp = p2.maxHp
  end)
  local guoseActive = activeName(GUOSE)
  lu.assertNotNil(guoseActive)

  -- 分支 1：方片当【乐不思蜀】，然后摸一张。
  local diamond = give(p1, "hanjin_test__blank_basic", Card.Diamond)
  local before = p1:getHandcardNum()
  activate(p1, guoseActive, { p2 }, { diamond }, "hanjin__skill_wu006_1-use")
  lu.assertEquals(p2:getCardIds(Player.Judge)[1] ~= nil, true)
  lu.assertEquals(p1:getMark("hanjin__skill_wu006_1_use-phase"), 1)
  lu.assertEquals(p1:getMark("hanjin__skill_wu006_1_discard-phase"), 0)
  lu.assertEquals(p1:getHandcardNum(), before)

  -- 已用分支不能再次发动：新方片不应再产生第二张【乐不思蜀】。
  local extra = give(p1, "hanjin_test__blank_basic", Card.Diamond)
  activate(p1, guoseActive, { p2 }, { extra }, "hanjin__skill_wu006_1-use")
  lu.assertEquals(#p2:getCardIds(Player.Judge), 1)
  lu.assertEquals(p1:getMark("hanjin__skill_wu006_1_use-phase"), 1)

  -- 分支 2：弃方片 + 场上延时锦囊，然后摸一张；分支 1 已限次不影响本分支。
  local second = give(p1, "hanjin_test__blank_basic", Card.Diamond)
  local before2 = p1:getHandcardNum()
  activate(p1, guoseActive, { p2 }, { second }, "hanjin__skill_wu006_1-discard")
  lu.assertEquals(#p2:getCardIds(Player.Judge), 0)
  lu.assertEquals(p1:getMark("hanjin__skill_wu006_1_discard-phase"), 1)
  lu.assertEquals(p1:getHandcardNum(), before2)
end

function Testhanjin_wu_phases:testDuanbingExtraTargetAndExtraJink()
  local p1, p2 = p(1), p(2)
  setGeneral(p1, "hanjin__wu016")
  clearCards(p1)
  clearCards(p2)
  local near = table.find(room().alive_players, function(pl)
    return pl ~= p1 and pl ~= p2 and not pl:isRemoved() and p1:distanceTo(pl) == 1
  end)
  lu.assertNotNil(near)
  clearCards(near)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p1.hp = p1.maxHp
    p2.hp = p2.maxHp
    near.hp = near.maxHp
  end)
  local slash = give(p1, "hanjin__slash", Card.Spade)
  -- 第一段：原目标 p2 不在距离 1；短兵额外加入距离 1 的 near。两者都无【闪】。
  FkTest.setNextReplies(p1, { FkTest.ReplyChoosePlayer({ near }) })
  FkTest.setNextReplies(p2, { "" })
  FkTest.setNextReplies(near, { "" })
  inRoom(function()
    room():useCard(UseCardData:new {
      from = p1,
      tos = { p2 },
      card = Fk:getCardById(slash),
      extra_data = {},
    })
  end)
  lu.assertEquals(p2.hp, p2.maxHp - 1)
  lu.assertEquals(near.hp, near.maxHp - 1)

  -- 额外【闪】数需求本轮未通过：对距离 1 的目标使用一张【杀】，目标一张【闪】
  -- 仍抵消成功；怀疑 fixedResponseTimesList 未传播到 CardEffectData，待下轮核对。
end

function Testhanjin_wu_phases:testFenxunDistancePersistsAfterLosingSkill()
  local p1, p3 = p(1), p(3)
  setGeneral(p1, "hanjin__wu016")
  clearCards(p1)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    p1.hp = p1.maxHp
    p3.hp = p3.maxHp
  end)
  local fenxunActive = activeName(FENXUN)
  lu.assertNotNil(fenxunActive)
  local before = p1:distanceTo(p3)
  lu.assertTrue(before > 1)
  local cost = give(p1, "hanjin_test__blank_basic", Card.Spade)
  activate(p1, fenxunActive, { p3 }, { cost })
  lu.assertEquals(p1:getMark(H.FENXUN_MARK), p3.id)
  lu.assertEquals(p1:distanceTo(p3), 1)
  lu.assertEquals(p3:distanceTo(p1), 1)

  -- 失去奋迅后，模式级距离技能仍按本回合标记保持为 1。
  inRoom(function()
    room():handleAddLoseSkills(p1, "-" .. FENXUN, nil, false, true)
  end)
  lu.assertFalse(p1:hasSkill(FENXUN))
  lu.assertEquals(p1:distanceTo(p3), 1)
  lu.assertEquals(p3:distanceTo(p1), 1)
end

function Testhanjin_wu_phases:testDushiPublicDiscardSuitsAndClientFilter()
  local p1 = p(1)
  setGeneral(p1, "hanjin__wu007")
  clearCards(p1)
  inRoom(function() H.clear(room()) end)
  local heart = give(p1, "hanjin_test__blank_basic", Card.Heart)
  inRoom(function() room():throwCard({ heart }, "test", p1, p1) end)
  lu.assertTrue(H.hasSuit(p1, Card.Heart))

  -- 公开标记到真实 ClientPlayer；度势筛选读同一份数据。
  local cp = ClientInstance:getPlayerById(p1.id)
  lu.assertNotNil(cp)
  lu.assertTrue(H.hasSuit(cp, Card.Heart))
  local spade = give(p1, "hanjin_test__blank_basic", Card.Spade)
  local active = Fk.skills[activeName(DUSHI)]
  lu.assertNotNil(active)
  lu.assertFalse(active:cardFilter(cp, heart, {}, {}))
  lu.assertTrue(active:cardFilter(cp, spade, {}, {}))

  -- X 取【火烧连营】当前目标数；默认无队列关系时下家一名。
  local Heg = require "packages.hegemony.util"
  local prev = p1:getNextAlive()
  local expected = table.filter(room().alive_players, function(pl)
    return pl == prev or Heg.inFormationRelation(prev, pl)
  end)
  local skel = Fk.skill_skels[DUSHI]
  lu.assertNotNil(skel and skel.burningTargetsFor)
  lu.assertEquals(#expected, #skel.burningTargetsFor(p1))
  lu.assertTrue(#expected > 0)
end

-- 度势主效果真实用牌回归：不直接断言计算器，而是执行 after_use 的实际
-- 【火烧连营】转化用牌。小势力角色选 p1；X 由火烧连营目标规则计算。
function Testhanjin_wu_phases:testDushiBurningCampsRealUse()
  local p1 = p(1)
  setGeneral(p1, "hanjin__wu007")
  for i = 2, #room().players do
    local pl = room().players[i]
    inRoom(function()
      pl.kingdom = "wei"
      room():setPlayerProperty(pl, "kingdom", "wei")
      room():setPlayerMark(pl, "__heg_kingdom", "wei")
    end)
  end
  clearCards(p1)
  inRoom(function() H.clear(room()) end)
  for _, suit in ipairs({ Card.Spade, Card.Heart, Card.Club, Card.Diamond }) do
    local id = give(p1, "hanjin_test__blank_basic", suit)
    inRoom(function() room():throwCard({ id }, "test", p1, p1) end)
  end
  lu.assertTrue(H.allSuits(p1))

  local skel = Fk.skill_skels[DUSHI]
  lu.assertNotNil(skel and skel.burningTargetsFor)
  local targets = skel.burningTargetsFor(p1)
  lu.assertTrue(#targets > 0)
  local red = {}
  for _ = 1, #targets do
    table.insert(red, give(p1, "hanjin_test__blank_basic", Card.Heart))
  end
  local active = Fk.skills[activeName(DUSHI)]
  lu.assertNotNil(active)
  FkTest.setNextReplies(p1, {
    FkTest.ReplyChoosePlayer({ p1 }),
    red,
  })
  local before = targets[1].hp
  inRoom(function()
    active:afterUse(p1, { card = Fk:cloneCard("hanjin__await_exhausted") })
  end)
  lu.assertTrue(targets[1].hp < before)
end

-- 失败回归：短兵应使距离 1 的目标需要两张【闪】。当前仅一张【闪】仍抵消成功，
-- 保留此用例供整合轮定位，不删除、不以弱断言替代。
function Testhanjin_wu_phases:testDuanbingDistanceOneTargetNeedsTwoJinks()
  local p1, p2 = p(1), p(2)
  setGeneral(p1, "hanjin__wu016")
  clearCards(p1)
  clearCards(p2)
  local near = table.find(room().alive_players, function(pl)
    return pl ~= p1 and pl ~= p2 and not pl:isRemoved() and p1:distanceTo(pl) == 1
  end)
  lu.assertNotNil(near)
  clearCards(near)
  inRoom(function()
    room().current = p1
    p1.phase = Player.Play
    near.hp = near.maxHp
  end)
  local slash = give(p1, "hanjin__slash", Card.Spade)
  local jink = give(near, "hanjin__jink", Card.Heart)
  FkTest.setNextReplies(near, { { card = jink }, "" })
  inRoom(function()
    room():useCard(UseCardData:new {
      from = p1,
      tos = { near },
      card = Fk:getCardById(slash),
      extra_data = {},
    })
  end)
  lu.assertEquals(near.hp, near.maxHp - 1)
end

return { name = "hanjin_wu_phases" }
