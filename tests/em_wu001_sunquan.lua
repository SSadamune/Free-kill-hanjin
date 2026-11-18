-- EM(WU001) 君孙权：正式升变、旗入口失效、敛资门槛、聚宝宝物保护、
-- 准备阶段临时授技、授予“攻心”与旗第三段的伤害后续。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_lord_wu"
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local History = require "packages.qiao.pkg.qiao_generals.util.han_history"
local ReqPlayCard = require "ltk.core.request_type.play_card"

local LORD = "qiao_heg__em_wu001"
local NORMAL = "qiao_heg__wu001"
local ORDINARY_TREASURE = "qiao__bronze_sparrow"
local GONGXIN = P.GONGXIN
local DISCARD = "#qiao__gongxin-discard"
local ON_TOP = "#qiao__gongxin-top"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

local function ascendLord()
  local room = FkTest.room
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wu", "wu", "wei", "wei", "wei", "wei", "wei", "wei" })
    skill_test.installDualGenerals(room, room.players[1], {
      main = NORMAL, deputy = "qiao_test__wu_2", kingdom = "wu",
    })
    room.current = room.players[1]
    A.ascend(room, room.players[1], LORD, "wu", { kind = "lord" })
  end)
end

--- 记录家：给玩家若干张手牌，并按给定顺序放牌堆顶（最后传入的为最顶）。
local function prepareDrawTop(room, player, cards)
  for i = #cards, 1, -1 do
    table.removeOne(room.draw_pile, cards[i].id)
    table.insert(room.draw_pile, 1, cards[i].id)
  end
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = FkTest.room:printCard(name, suit or Card.Spade, number or 7)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function clearCards(player)
  inRoom(function()
    local ids = player:getCardIds("he")
    if #ids > 0 then
      FkTest.room:moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end)
end

--- 直接往持旗者的旗牌堆放 n 张装备牌（烽火）。
local function putFenghuo(lord, n)
  inRoom(function()
    for i = 1, n do
      local card = FkTest.room:printCard(P.PEARL, Card.Heart, i)
      lord:addToPile(P.PILE, { card.id }, true, P.FLAG)
    end
  end)
end

local function preparePhase(player)
  inRoom(function()
    player.phase = Player.Start
    FkTest.room.logic:trigger(fk.EventPhaseStart, player,
      PhaseData:new { who = player, phase = Player.Start })
  end)
end

--- 真实 ClientPlayer 夹具：复用公共 client_room（禁止访问服务端私有字段）。
local function withClientRoom(current, fn)
  return client_room.run(current, fn)
end

local function clientPlayHandler(client, skillName)
  local handler = ReqPlayCard:new(client)
  handler.skill_name = skillName
  handler:setup()
  return handler
end

Testqiao_em_wu001_sunquan = {
  setup = function()
    Fk.currentResponsePattern = nil
    support.initQiaoRoom()
    ascendLord()
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_em_wu001_sunquan:testDataAndRegistration()
  lu.assertEquals(DATA.generals[1].id, LORD)
  lu.assertEquals(DATA.generals[1].name, "孙权")
  lu.assertEquals(DATA.versions[1].normal, NORMAL)
  local general = assert(Fk.generals[LORD])
  lu.assertTrue(general.hidden, "君主版不得进入普通发将池")
  lu.assertTrue(general.is_lord)
  lu.assertEquals(general.trueName, "孙权")
  lu.assertEquals(general.prefix, "qiao_prefix_bian")
  lu.assertEquals(Fk:translate(general.prefix), "变")
  lu.assertEquals(Fk:translate(LORD), '<font color="#FFFF00">君</font>孙权')
end

function Testqiao_em_wu001_sunquan:testAscensionGrantsEntryAndFenghuoChangesRange()
  local lord, other, enemy = p(1), p(2), p(3)
  lu.assertEquals(lord.general, LORD)
  lu.assertTrue(lord:hasSkill(P.JIAHE))
  lu.assertTrue(lord:hasSkill(P.FLAG), "嘉禾应授予缘江烽火图")
  lu.assertTrue(lord:hasSkill(P.ENTRY), "君主本人也有旗入口")
  lu.assertTrue(other:hasSkill(P.ENTRY), "同势力吴角色应获得旗入口")
  lu.assertFalse(enemy:hasSkill(P.ENTRY), "异势力不获得旗入口")

  local card
  inRoom(function()
    local printed = FkTest.room:printCard(P.PEARL, Card.Heart, 1)
    FkTest.room:obtainCard(other, printed, false, fk.ReasonJustMove)
    card = printed.id
    other.phase = Player.Play
    lu.assertEquals(lord:getAttackRange(), 1, "持旗前基础攻击范围")
    Fk.skills[P.ENTRY]:onUse(FkTest.room, { from = other, cards = { card }, tos = {} })
  end)
  lu.assertEquals(P.count(lord), 1, "烽火应真实置入旗牌堆")
  lu.assertEquals(lord:getAttackRange(), 2, "持旗者攻击范围应+X")
end

function Testqiao_em_wu001_sunquan:testJiaheLossRemovesEntryAndRange()
  local room, lord, other = FkTest.room, p(1), p(2)
  local second
  inRoom(function()
    local first = room:printCard(P.PEARL, Card.Heart, 1)
    room:obtainCard(other, first, false, fk.ReasonJustMove)
    other.phase = Player.Play
    Fk.skills[P.ENTRY]:onUse(room, { from = other, cards = { first.id }, tos = {} })
    second = room:printCard(P.PEARL, Card.Spade, 2)
    room:obtainCard(other, second, false, fk.ReasonJustMove)
    room:handleAddLoseSkills(lord, "-" .. P.JIAHE, nil)
  end)
  lu.assertFalse(lord:hasSkill(P.JIAHE))
  lu.assertFalse(lord:hasSkill(P.FLAG), "失去嘉禾后旗来源应撤回")
  lu.assertFalse(lord:hasSkill(P.ENTRY))
  lu.assertFalse(other:hasSkill(P.ENTRY))
  lu.assertFalse(Fk.skills[P.ENTRY]:canUse(other), "失去嘉禾后入口不可再选")
  lu.assertEquals(lord:getAttackRange(), 1, "失去嘉禾后攻击范围加成撤回")
  inRoom(function()
    Fk.skills[P.ENTRY]:onUse(room, { from = other, cards = { second.id }, tos = {} })
  end)
  lu.assertEquals(P.count(lord), 1, "失去嘉禾后的入口提交应被拒绝")
end

function Testqiao_em_wu001_sunquan:testLianziBelowCharacterThreshold()
  local room, lord = FkTest.room, p(1)
  local discardId
  inRoom(function()
    lu.assertEquals(#room.alive_players, 8, "场上应有 8 名存活角色")
    History.clear(room)
    local discard = room:printCard("qiao__jink", Card.Spade, 7)
    room:obtainCard(lord, discard, false, fk.ReasonJustMove)
    discardId = discard.id
    -- 再得 2 张，共 3 张；X=4，8 名角色门槛为 8。亮出的 4 张中仅 1 张同类，
    -- 最终累计 4 张：达到 X 但不足场上角色数，本次不转换。
    for i = 1, 2 do
      local extra = room:printCard("qiao__jink", Card.Heart, i)
      room:obtainCard(lord, extra, false, fk.ReasonJustMove)
    end
    local match = room:printCard("qiao__jink", Card.Heart, 8)
    local cards = { match }
    for i = 1, 3 do
      cards[#cards + 1] = room:printCard("qiao__nullification", Card.Club, i)
    end
    prepareDrawTop(room, lord, cards)
    lord.phase = Player.Play
    Fk.skills[P.LIANZI]:onUse(room, { from = lord, cards = { discardId }, tos = {} })
  end)
  lu.assertTrue(lord:hasSkill(P.LIANZI), "本回合得牌未达场上角色数，不应失去敛资")
  lu.assertFalse(lord:hasSkill("qiao__skill_wu001_1"))
end

function Testqiao_em_wu001_sunquan:testLianziReachesCharacterThreshold()
  local room, lord = FkTest.room, p(1)
  local discardId
  inRoom(function()
    History.clear(room)
    local discard = room:printCard("qiao__jink", Card.Spade, 7)
    room:obtainCard(lord, discard, false, fk.ReasonJustMove)
    discardId = discard.id
    -- 先累计 7 张，亮出的 4 张中至少 1 张同类，使本回合累计达到 8 名角色。
    for i = 1, 6 do
      local extra = room:printCard("qiao__jink", Card.Heart, i)
      room:obtainCard(lord, extra, false, fk.ReasonJustMove)
    end
    local match = room:printCard("qiao__jink", Card.Heart, 8)
    local cards = { match }
    for i = 1, 3 do
      cards[#cards + 1] = room:printCard("qiao__nullification", Card.Club, i)
    end
    prepareDrawTop(room, lord, cards)
    lord.phase = Player.Play
    Fk.skills[P.LIANZI]:onUse(room, { from = lord, cards = { discardId }, tos = {} })
  end)
  lu.assertFalse(lord:hasSkill(P.LIANZI), "本回合得牌达到 8 名角色后应失去敛资")
  lu.assertTrue(lord:hasSkill("qiao__skill_wu001_1"), "应获得同文制衡")
end

function Testqiao_em_wu001_sunquan:testJubaoBlocksOrdinaryTreasureMoveButNotDiscard()
  local room, lord, other = FkTest.room, p(1), p(2)
  local treasure, afterEquip, afterSteal, afterDiscard, ownerAfterSteal
  inRoom(function()
    local printed = room:printCard(ORDINARY_TREASURE, Card.Heart, 2)
    room:moveCardTo(printed, Card.PlayerEquip, lord, fk.ReasonJustMove, "test", nil, true, lord)
    treasure = printed.id
    afterEquip = room:getCardArea(treasure)
    room:moveCardTo(treasure, Card.PlayerHand, other, fk.ReasonPrey, "test", nil, true, other)
    afterSteal = room:getCardArea(treasure)
    ownerAfterSteal = room:getCardOwner(treasure)
    room:moveCardTo(treasure, Card.DiscardPile, nil, fk.ReasonDiscard, "test", nil, true, other)
    afterDiscard = room:getCardArea(treasure)
  end)
  lu.assertEquals(afterEquip, Card.PlayerEquip)
  lu.assertEquals(afterSteal, Card.PlayerEquip, "普通宝物的非弃置移动也应被取消")
  lu.assertIs(ownerAfterSteal, lord)
  lu.assertEquals(afterDiscard, Card.DiscardPile, "弃置宝物不受聚宝保护")
end

function Testqiao_em_wu001_sunquan:testJubaoDoesNotCountPearlInHand()
  local room, lord, holder = FkTest.room, p(1), p(3)
  local pearl, before
  inRoom(function()
    pearl = room:printCard(P.PEARL, Card.Heart, 3)
    room:obtainCard(holder, pearl, false, fk.ReasonJustMove)
    lord.phase = Player.Finish
    before = #lord:getCardIds("h")
    room.logic:trigger(fk.EventPhaseStart, lord, PhaseData:new { who = lord, phase = Player.Finish })
  end)
  lu.assertEquals(#lord:getCardIds("h"), before, "手牌中的夜明珠不属于场上，不触发聚宝摸牌")
end

--- 完整来源接线：真实准备阶段授予攻心后，同一回合实际发动该技能（私看、只列红桃、
--- 真实选牌请求、展示并弃置），最后回合结束只撤本次授予。
function Testqiao_em_wu001_sunquan:testPrepareGrantsGongxinAtThreeFenghuo()
  local room, lord, wu, target = FkTest.room, p(1), p(2), p(3)
  clearCards(wu)
  clearCards(target)
  local heart = give(target, "qiao__jink", Card.Heart, 3)
  local otherHeart = give(target, "qiao__jink", Card.Heart, 4)
  local spade = give(target, "qiao__jink", Card.Spade, 5)
  local asks, asked = 0, nil
  putFenghuo(lord, 3)
  inRoom(function()
    lu.assertEquals(P.count(lord), 3, "烽火应实际置入旗牌堆")
    lu.assertTrue(room:hasSkill(P.RULE), "准备阶段授技的到期清理应已安装")
  end)
  skill_test.withSkillRequests(room, P.FLAG, {
    askToChoices = function(self, who, params, original)
      if params.skill_name ~= P.FLAG then return original(self, who, params) end
      asks = asks + 1
      asked = params
      return { GONGXIN }
    end,
  }, function()
    preparePhase(wu)
  end)
  lu.assertEquals(asks, 1, "吴势力角色自己的准备阶段应询问一次")
  lu.assertEquals(#asked.choices, 3, "三张烽火时逐档累积为英姿、好施、攻心")
  lu.assertEquals(asked.max_num, 1, "不足五张时只能选一个技能")
  lu.assertTrue(asked.detailed, "授技多选应在确认前显示技能说明")
  for _, skillName in ipairs(asked.choices) do
    lu.assertNotEquals(Fk:translate(":" .. skillName), ":" .. skillName,
      "授技选项应有正式技能说明：" .. skillName)
  end
  lu.assertTrue(wu:hasSkill(GONGXIN), "应实际获得攻心")
  lu.assertFalse(lord:hasSkill(GONGXIN), "未选择的其他吴角色不获得")
  lu.assertFalse(target:hasSkill(GONGXIN), "异势力角色不获得")
  lu.assertFalse(table.contains(wu:getSkillNameList(), GONGXIN), "所授技能不附在武将牌上")

  -- 同一回合实际发动刚授予的攻心：私看 -> 红桃候选 -> 真实 AskForPoxi 选牌 ->
  -- 展示所选一张红桃并弃置；另一张红桃与非红桃都不得移动。
  local viewed, offered, shown, shownFrom = nil, nil, nil, nil
  inRoom(function()
    room.current = wu
    wu.phase = Player.Play
  end)
  local originalShow = room.showCards
  room.showCards = function(self, cards, from, proposer)
    shown = Card:getIdList(cards)
    shownFrom = from
    return originalShow(self, cards, from, proposer)
  end
  FkTest.setNextReplies(wu, { { heart } })
  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, GONGXIN, {
      viewCards = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        viewed = { who = who, cards = table.simpleClone(params.cards) }
        return nil
      end,
      askToChooseCards = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        offered = params
        -- 不伪造选牌结果：走真实请求，回复由 setNextReplies 提供。
        return original(self, who, params)
      end,
      askToChoice = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        return DISCARD
      end,
    }, function()
      inRoom(function()
        local skill = Fk.skills[GONGXIN]
        room:useSkill(wu, skill, function()
          skill:onUse(room, { from = wu, cards = {}, tos = { target } })
        end, { from = wu, cards = {}, tos = { target } })
      end)
    end)
  end)
  room.showCards = originalShow
  if not ok then error(err, 0) end
  lu.assertIs(viewed.who, wu, "私看只发给发动者")
  lu.assertEquals(#viewed.cards, 3, "应私看目标全部手牌")
  lu.assertEquals(#offered.flag.card_data[1][2], 2, "真实选牌请求的候选只列红桃")
  lu.assertEquals(#shown, 1, "只展示所选的这一张红桃")
  lu.assertEquals(shown[1], heart)
  lu.assertIs(shownFrom, target)
  lu.assertEquals(room:getCardArea(heart), Card.DiscardPile, "所选红桃应弃置")
  lu.assertEquals(room:getCardArea(otherHeart), Card.PlayerHand, "未选中的红桃不移动")
  lu.assertEquals(room:getCardArea(spade), Card.PlayerHand, "非红桃不移动")

  -- 烽火减少不撤回已建立的授技。
  inRoom(function()
    local ids = lord:getPile(P.PILE)
    room:moveCardTo(ids[1], Card.DiscardPile, nil, fk.ReasonDiscard, "test", nil, false)
  end)
  lu.assertEquals(P.count(lord), 2, "应实际移去一张烽火")
  lu.assertTrue(wu:hasSkill(GONGXIN), "烽火减少不撤已建立授技")

  -- 本回合结束：只撤本次授予。
  inRoom(function() room.logic:trigger(fk.TurnEnd, wu, {}) end)
  lu.assertFalse(wu:hasSkill(GONGXIN), "回合结束应撤销本次授予")
end

--- 五张烽火可多选一个不同技能；到期不误删独立来源的同名技能。
function Testqiao_em_wu001_sunquan:testFiveFenghuoTwoSkillsKeepIndependentSource()
  local room, lord, wu = FkTest.room, p(1), p(2)
  local asked
  putFenghuo(lord, 5)
  inRoom(function()
    -- 另一独立来源提供的英姿：与本次授予同名但来源不同。
    room:handleAddLoseSkills(wu, P.YINGZI, P.JIAHE, false, true)
  end)
  lu.assertTrue(wu:hasSkill(P.YINGZI))
  skill_test.withSkillRequests(room, P.FLAG, {
    askToChoices = function(self, who, params, original)
      if params.skill_name ~= P.FLAG then return original(self, who, params) end
      asked = params
      return { P.YINGZI, GONGXIN }
    end,
  }, function()
    preparePhase(wu)
  end)
  lu.assertEquals(asked.max_num, 2, "达到五张烽火时可多选一个不同技能")
  lu.assertEquals(#asked.choices, 4, "五张烽火时四项技能均可选")
  lu.assertTrue(asked.detailed, "授技多选应在确认前显示技能说明")
  for _, skillName in ipairs(asked.choices) do
    lu.assertNotEquals(Fk:translate(":" .. skillName), ":" .. skillName,
      "授技选项应有正式技能说明：" .. skillName)
  end
  lu.assertTrue(wu:hasSkill(P.YINGZI), "应获得英姿")
  lu.assertTrue(wu:hasSkill(GONGXIN), "应同时获得攻心")

  inRoom(function() room.logic:trigger(fk.TurnEnd, wu, {}) end)
  lu.assertFalse(wu:hasSkill(GONGXIN), "攻心只来自本次授予，到期应撤销")
  lu.assertTrue(wu:hasSkill(P.YINGZI), "独立来源的英姿不应被到期清理误删")
  inRoom(function() lu.assertFalse(P.hasTemp(room, wu), "本回合授予记录应清空") end)
end

--- 攻心：私看目标手牌，只列红桃；展示所选红桃后弃置。
function Testqiao_em_wu001_sunquan:testGongxinViewsShowsAndDiscardsHeart()
  local room, user, target = FkTest.room, p(2), p(3)
  clearCards(user)
  clearCards(target)
  local heart = give(target, "qiao__jink", Card.Heart, 3)
  local spade = give(target, "qiao__jink", Card.Spade, 4)
  local club = give(target, "qiao__jink", Card.Club, 5)
  local viewed, offered, shown, shownFrom
  inRoom(function()
    room:handleAddLoseSkills(user, GONGXIN, P.SOURCE, false, true)
    room.current = user
    user.phase = Player.Play
  end)
  local originalShow = room.showCards
  room.showCards = function(self, cards, from, proposer)
    shown = Card:getIdList(cards)
    shownFrom = from
    return originalShow(self, cards, from, proposer)
  end
  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, GONGXIN, {
      viewCards = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        viewed = { who = who, cards = table.simpleClone(params.cards) }
        return nil
      end,
      askToChooseCards = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        offered = params
        return { heart }
      end,
      askToChoice = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        return DISCARD
      end,
    }, function()
      inRoom(function()
        local skill = Fk.skills[GONGXIN]
        room:useSkill(user, skill, function()
          skill:onUse(room, { from = user, cards = {}, tos = { target } })
        end, { from = user, cards = {}, tos = { target } })
      end)
    end)
  end)
  room.showCards = originalShow
  if not ok then error(err, 0) end

  lu.assertIs(viewed.who, user, "观看只发给发动者")
  lu.assertEquals(#viewed.cards, 3, "应私看目标的全部手牌")
  lu.assertEquals(#offered.flag.card_data[1][2], 1, "候选只列红桃")
  lu.assertEquals(offered.flag.card_data[1][2][1], heart)
  lu.assertEquals(offered.min, 0, "可以不选红桃")
  lu.assertEquals(#shown, 1, "应公开展示所选红桃")
  lu.assertEquals(shown[1], heart)
  lu.assertIs(shownFrom, target, "展示的来源是手牌所有者")
  lu.assertEquals(room:getCardArea(heart), Card.DiscardPile, "所选红桃应被弃置")
  lu.assertEquals(room:getCardArea(spade), Card.PlayerHand, "未展示的牌不动")
  lu.assertEquals(room:getCardArea(club), Card.PlayerHand, "未展示的牌不动")
end

--- 攻心：置于牌堆顶、无红桃只看、取消不移动。
function Testqiao_em_wu001_sunquan:testGongxinPutOnTopNoHeartAndCancel()
  local room, user = FkTest.room, p(2)
  local target, blackTarget = p(3), p(4)
  clearCards(user)
  clearCards(target)
  clearCards(blackTarget)
  local heart = give(target, "qiao__jink", Card.Heart, 3)
  local spade = give(target, "qiao__jink", Card.Spade, 4)
  local club = give(blackTarget, "qiao__jink", Card.Club, 5)
  inRoom(function()
    room:handleAddLoseSkills(user, GONGXIN, P.SOURCE, false, true)
    room.current = user
    user.phase = Player.Play
  end)

  -- 弃置分支之外的另一合法去向：置于牌堆顶。
  skill_test.withSkillRequests(room, GONGXIN, {
    viewCards = function(self, who, params, original)
      if params.skill_name ~= GONGXIN then return original(self, who, params) end
      return nil
    end,
    askToChooseCards = function(self, who, params, original)
      if params.skill_name ~= GONGXIN then return original(self, who, params) end
      return { heart }
    end,
    askToChoice = function(self, who, params, original)
      if params.skill_name ~= GONGXIN then return original(self, who, params) end
      return ON_TOP
    end,
  }, function()
    inRoom(function()
      local skill = Fk.skills[GONGXIN]
      room:useSkill(user, skill, function()
        skill:onUse(room, { from = user, cards = {}, tos = { target } })
      end, { from = user, cards = {}, tos = { target } })
    end)
  end)
  lu.assertEquals(room:getCardArea(heart), Card.DrawPile, "应置于牌堆")
  lu.assertEquals(room.draw_pile[1], heart, "应置于牌堆顶")
  lu.assertEquals(room:getCardArea(spade), Card.PlayerHand, "未展示的牌不动")

  -- 无红桃：只完成观看，不再要求选牌，也不移动任何牌。
  local askCount = 0
  skill_test.withSkillRequests(room, GONGXIN, {
    viewCards = function(self, who, params, original)
      if params.skill_name ~= GONGXIN then return original(self, who, params) end
      return nil
    end,
    askToChooseCards = function(self, who, params, original)
      if params.skill_name ~= GONGXIN then return original(self, who, params) end
      askCount = askCount + 1
      return {}
    end,
  }, function()
    inRoom(function()
      local skill = Fk.skills[GONGXIN]
      skill:onUse(room, { from = user, cards = {}, tos = { blackTarget } })
    end)
  end)
  lu.assertEquals(askCount, 0, "没有红桃时不应要求选牌")
  lu.assertEquals(room:getCardArea(club), Card.PlayerHand, "无红桃时不动手牌")

  -- 有红桃但取消：不展示也不移动。
  local heart2 = give(target, "qiao__jink", Card.Heart, 9)
  local shown = 0
  local originalShow = room.showCards
  room.showCards = function(...)
    shown = shown + 1
    return originalShow(...)
  end
  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, GONGXIN, {
      viewCards = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        return nil
      end,
      askToChooseCards = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        return {}
      end,
    }, function()
      inRoom(function()
        local skill = Fk.skills[GONGXIN]
        skill:onUse(room, { from = user, cards = {}, tos = { target } })
      end)
    end)
  end)
  room.showCards = originalShow
  if not ok then error(err, 0) end
  lu.assertEquals(shown, 0, "取消后不展示任何牌")
  lu.assertEquals(room:getCardArea(heart2), Card.PlayerHand, "取消后不移动手牌")
end

--- 旗第三段：真实牌造成伤害后由持旗者选择移去一张烽火、正常扣血；本回合下一次
--- 伤害（不限定渠道）减 1 且只消耗一次；攻击范围随移去即时下降。
function Testqiao_em_wu001_sunquan:testFenghuoDamageRemovesOneAndReducesNextDamage()
  local room, lord, attacker, caster = FkTest.room, p(1), p(2), p(3)
  clearCards(lord)
  putFenghuo(lord, 2)
  local hp0 = lord.hp
  local slash = give(attacker, "qiao__slash", Card.Spade, 2)
  local ids = {}
  inRoom(function()
    room.current = attacker
    attacker.phase = Player.Play
    ids = table.simpleClone(lord:getPile(P.PILE))
  end)
  lu.assertEquals(P.count(lord), 2)
  lu.assertEquals(lord:getAttackRange(), 3, "两张烽火时攻击范围为基础值+2")
  -- 先取消【杀】的响应，再提供真实选牌请求的答复（选第一张烽火）。
  FkTest.setNextReplies(lord, { "__cancel", ids[1] })
  inRoom(function()
    room:useCard { from = attacker, tos = { lord }, card = Fk:getCardById(slash) }
  end)
  lu.assertEquals(lord.hp, hp0 - 1, "此次伤害正常扣血，不回溯减免")
  lu.assertEquals(P.count(lord), 1, "应实际移去一张烽火")
  lu.assertEquals(room:getCardArea(ids[1]), Card.DiscardPile, "移去的烽火置入弃牌堆")
  inRoom(function()
    lu.assertTrue(table.contains(lord:getPile(P.PILE), ids[2]), "其余烽火保留")
  end)
  lu.assertEquals(P.pending(lord), 1, "应建立本回合下次受到的伤害-1")
  lu.assertEquals(lord:getAttackRange(), 2, "攻击范围随移去烽火即时下降")

  -- 本回合下一次伤害来自技能（无牌渠道）也应减 1，且只用一次。
  inRoom(function()
    room:damage { from = caster, to = lord, damage = 1, skillName = "test_skill" }
  end)
  lu.assertEquals(lord.hp, hp0 - 1, "下一次技能伤害应减1")
  lu.assertEquals(P.pending(lord), 0, "减伤用后消耗")
  inRoom(function()
    room:damage { from = caster, to = lord, damage = 1, skillName = "test_skill" }
  end)
  lu.assertEquals(lord.hp, hp0 - 2, "减伤只对那一次伤害生效")
end

--- 多张烽火时由持旗者选择：实际请求可选出非末张，只有所选那张移去。
function Testqiao_em_wu001_sunquan:testFenghuoDamageRemovesChosenFenghuoNotLast()
  local room, lord, attacker = FkTest.room, p(1), p(2)
  clearCards(lord)
  putFenghuo(lord, 3)
  local ids, asked = {}, nil
  inRoom(function()
    room.current = attacker
    attacker.phase = Player.Play
    ids = table.simpleClone(lord:getPile(P.PILE))
  end)
  lu.assertEquals(#ids, 3)
  local slash = give(attacker, "qiao__slash", Card.Spade, 2)
  FkTest.setNextReplies(lord, { "__cancel", ids[1] })
  skill_test.withSkillRequests(room, P.FLAG, {
    askToChooseCard = function(self, who, params, original)
      if params.skill_name ~= P.FLAG then return original(self, who, params) end
      asked = params
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:useCard { from = attacker, tos = { lord }, card = Fk:getCardById(slash) }
    end)
  end)
  lu.assertNotNil(asked, "多张烽火时必须走正式选牌请求")
  lu.assertEquals(#asked.flag.card_data[1][2], 3, "候选为公开的三张烽火")
  lu.assertFalse(asked.cancelable == true, "该选择不可取消")
  lu.assertEquals(room:getCardArea(ids[1]), Card.DiscardPile, "应移去所选的那一张")
  local remain = {}
  inRoom(function() remain = table.simpleClone(lord:getPile(P.PILE)) end)
  lu.assertEquals(#remain, 2, "其余烽火保留")
  lu.assertTrue(table.contains(remain, ids[2]), "未选的第二张保留")
  lu.assertTrue(table.contains(remain, ids[3]), "作为末张的第三张未被固定移去")
  lu.assertEquals(P.pending(lord), 1)
end

--- 无烽火时不能取得减伤；未消耗的减伤在本回合结束时清除。
function Testqiao_em_wu001_sunquan:testFenghuoNoFenghuoAndTurnEndClearsReduction()
  local room, lord, attacker, caster = FkTest.room, p(1), p(2), p(3)
  clearCards(lord)
  local hp0 = lord.hp
  lu.assertEquals(P.count(lord), 0)
  local slash = give(attacker, "qiao__slash", Card.Spade, 2)
  inRoom(function()
    room.current = attacker
    attacker.phase = Player.Play
  end)
  FkTest.setNextReplies(lord, { "__cancel" })
  inRoom(function()
    room:useCard { from = attacker, tos = { lord }, card = Fk:getCardById(slash) }
  end)
  lu.assertEquals(lord.hp, hp0 - 1, "无烽火仍正常受到伤害")
  lu.assertEquals(P.pending(lord), 0, "没有实际移去烽火，不能取得减伤")
  inRoom(function()
    room:damage { from = caster, to = lord, damage = 1, skillName = "test_skill" }
  end)
  lu.assertEquals(lord.hp, hp0 - 2, "未取得减伤时下一次伤害不减免")

  -- 建立一次减伤后在本回合结束时清除。
  inRoom(function() lord.hp = lord.maxHp end)
  putFenghuo(lord, 1)
  local slash2 = give(attacker, "qiao__slash", Card.Club, 3)
  FkTest.setNextReplies(lord, { "__cancel" })
  inRoom(function()
    room:useCard { from = attacker, tos = { lord }, card = Fk:getCardById(slash2) }
  end)
  lu.assertEquals(P.pending(lord), 1)
  inRoom(function() room.logic:trigger(fk.TurnEnd, caster, {}) end)
  lu.assertEquals(P.pending(lord), 0, "回合结束应清除尚未消耗的减伤")
  local hp1 = lord.hp
  inRoom(function()
    room:damage { from = caster, to = lord, damage = 1, skillName = "test_skill" }
  end)
  lu.assertEquals(lord.hp, hp1 - 1, "回合结束后不再减免")
end

--- 已建立的减伤是独立延时效果：失去嘉禾与旗后仍执行。
function Testqiao_em_wu001_sunquan:testEstablishedReductionSurvivesLosingJiahe()
  local room, lord, attacker, caster = FkTest.room, p(1), p(2), p(3)
  clearCards(lord)
  putFenghuo(lord, 1)
  local slash = give(attacker, "qiao__slash", Card.Spade, 2)
  inRoom(function()
    room.current = attacker
    attacker.phase = Player.Play
  end)
  FkTest.setNextReplies(lord, { "__cancel" })
  inRoom(function()
    room:useCard { from = attacker, tos = { lord }, card = Fk:getCardById(slash) }
  end)
  lu.assertEquals(P.pending(lord), 1)
  lu.assertEquals(P.count(lord), 0)

  inRoom(function() room:handleAddLoseSkills(lord, "-" .. P.JIAHE, nil) end)
  lu.assertFalse(lord:hasSkill(P.JIAHE), "嘉禾应已失去")
  lu.assertFalse(lord:hasSkill(P.FLAG), "旗来源应随嘉禾撤回")
  lu.assertEquals(P.pending(lord), 1, "已建立的减伤不随失旗撤销")
  local hp = lord.hp
  inRoom(function()
    room:damage { from = caster, to = lord, damage = 1, skillName = "test_skill" }
  end)
  lu.assertEquals(lord.hp, hp, "失去嘉禾后仍执行已建立的减伤")
end

--- 攻心客户端可用性：真实 ClientPlayer 无 room 字段，走
--- ReqPlayCard.setup → skillButtonValidity，再真实点击进入技能并选择目标。
function Testqiao_em_wu001_sunquan:testGongxinClientAvailabilityWithoutPlayerRoom()
  local room, user = FkTest.room, p(2)
  clearCards(user)
  give(p(3), "qiao__jink", Card.Heart, 3)
  inRoom(function()
    room:handleAddLoseSkills(user, GONGXIN, P.SOURCE, false, true)
    room.current = user
    user.phase = Player.Play
  end)
  withClientRoom(room, function(clients)
    local me, other = clients[2], clients[3]
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    lu.assertEquals(me.class.name, "ClientPlayer")
    local handler = clientPlayHandler(me, GONGXIN)
    lu.assertTrue(handler:skillButtonValidity(GONGXIN), "合法场景应由真实按钮校验通过")

    -- 真实点击技能按钮 → 选目标 → 确认可用。
    handler:selectSkill(GONGXIN, { selected = true })
    lu.assertEquals(handler.skill_name, GONGXIN, "点击后应进入技能选择")
    lu.assertTrue(handler:targetValidity(other.id), "其他角色应可被选中")
    lu.assertFalse(handler:targetValidity(me.id), "自己不能被选中")
    lu.assertFalse(handler:feasible(), "未选目标时不应可确认")
    handler:selectTarget(other.id, { selected = true })
    lu.assertEquals(#handler.selected_targets, 1, "应实际选中一个目标")
    lu.assertTrue(handler:feasible(), "选中合法目标后应可确认")
    handler:_finish()

    me.phase = Player.Finish
    local finished = clientPlayHandler(me, GONGXIN)
    lu.assertFalse(finished:skillButtonValidity(GONGXIN), "非出牌阶段应禁用")
    finished:_finish()
  end)
end

return { name = "qiao_em_wu001_sunquan" }
