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
local END_CHOICE = "#qiao__gongxin-end"

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

--- 限次夹具使用实际注册到正式客户端的 QiaoPlayCard，而不是基类请求。
local qiaoPlayCardRequest
local function qiaoPlayCardClass()
  if qiaoPlayCardRequest == nil then
    local board = assert(Fk:getBoardGame("qiao_heg_mode"))
    local client = board.client_klass:new(ClientInstance.client)
    qiaoPlayCardRequest = assert(client.request_handlers.PlayCard)
  end
  return qiaoPlayCardRequest
end

local function clientLimitHandler(client, skillName)
  local handler = qiaoPlayCardClass():new(client)
  handler.skill_name = skillName
  handler:setup()
  return handler
end

--- 客户端副本按座位顺序创建；用服务端角色对象定位对应副本。
local function clientFor(room, player, clients)
  for index, original in ipairs(room.players) do
    if original == player then return clients[index] end
  end
  error("clientFor: player is not in room")
end

--- 在真实 ClientPlayer 上查询主动技按钮是否可用。
local function clientButtonValid(room, user, skillName)
  local valid
  withClientRoom(room, function(clients)
    local handler = clientLimitHandler(clientFor(room, user, clients), skillName)
    valid = handler:skillButtonValidity(skillName)
    handler:_finish()
  end)
  return valid
end

--- 真实按钮 → 点击技能 → 选牌／选目标 → 确认，返回客户端主动技回包，
--- 供服务端 handleUseCardReply 按真实回包流程处理。
local function clientActiveReply(room, user, skillName, opts)
  opts = opts or {}
  local reply
  withClientRoom(room, function(clients)
    local me = clientFor(room, user, clients)
    local handler = clientLimitHandler(me, skillName)
    lu.assertTrue(handler:skillButtonValidity(skillName),
      "首次应由真实客户端按钮发起：" .. skillName)
    handler:selectSkill(skillName, { selected = true })
    if opts.card ~= nil then
      lu.assertTrue(handler:cardValidity(opts.card), "所选牌应可由真实客户端点击：" .. skillName)
      handler:selectCard(opts.card, { selected = true })
    end
    if opts.target ~= nil then
      local clientTarget = clientFor(room, opts.target, clients)
      lu.assertTrue(handler:targetValidity(clientTarget.id),
        "目标应可由真实客户端选中：" .. skillName)
      handler:selectTarget(clientTarget.id, { selected = true })
    end
    lu.assertTrue(handler:feasible(), "合法选择后应可确认：" .. skillName)
    -- 与 ReqActiveSkill:doOKButton 的非二级选择回包同形；测试环境有 ClientInstance
    -- 时该方法只负责发送 UI 通知，因此直接取当前选择构造同一回包。
    local chosen = Fk.skills[skillName]
    reply = {
      card = { skill = skillName, subcards = table.simpleClone(handler.pendings or {}) },
      targets = table.simpleClone(handler.selected_targets or {}),
      interaction_data = chosen and chosen.interaction and chosen.interaction.data,
    }
    handler:_finish()
  end)
  lu.assertNotNil(reply, "真实客户端应生成主动技回包")
  return reply
end

--- 测试用禁止弃置技能：只禁止指定角色弃置指定牌。
local function installDiscardProhibit(room, owner, id)
  local skel = fk.CreateSkill { name = "#qiao_test_gongxin_prohibit" }
  skel:addEffect("prohibit", {
    prohibit_discard = function(self, player, card)
      return player == owner and card ~= nil and card.id == id
    end,
  })
  local instance = skel:createSkill()
  -- 房间状态技会广播 AddStatusSkill，客户端按 Fk.skills 查表；测试技能需先登记。
  Fk.skills[instance.name] = instance
  inRoom(function() room:addSkill(instance) end)
  return instance
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

  -- 同一回合实际发动刚授予的攻心：私密原生面板显示全部手牌、只允许选红桃，
  -- 选一张红桃弃置；另一张红桃与非红桃都不得移动。
  local asked, askedWho, shown, shownFrom
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
  FkTest.setNextReplies(wu, { { cards = { heart }, choice = DISCARD } })
  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, GONGXIN, {
      askToChooseCardsAndChoice = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        asked = params
        askedWho = who
        -- 不伪造结果：走真实 AskForCardsAndChoice 请求，回复由 setNextReplies 提供。
        return original(self, who, params)
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
  lu.assertIs(askedWho, wu, "面板只询问发动者")
  lu.assertEquals(#asked.all_cards, 3, "面板应显示目标全部手牌")
  for _, id in ipairs({ heart, otherHeart, spade }) do
    lu.assertTrue(table.contains(asked.all_cards, id), "面板应显示全部手牌：" .. id)
  end
  lu.assertEquals(#asked.cards, 2, "面板可选的只有当前有效红桃")
  lu.assertTrue(table.contains(asked.cards, heart))
  lu.assertTrue(table.contains(asked.cards, otherHeart))
  lu.assertFalse(table.contains(asked.cards, spade), "非红桃不可选")
  lu.assertEquals(asked.choices[1], END_CHOICE, "结束观看置于首位")
  lu.assertEquals(asked.default_choice, END_CHOICE, "超时默认结束观看")
  lu.assertEquals(asked.min_num, 0, "可以不选牌直接结束")
  lu.assertEquals(asked.max_num, 1, "最多选择一张红桃")
  lu.assertEquals(asked.filter_skel_name, GONGXIN, "按钮筛选使用本技能骨架")
  lu.assertEquals(#asked.extra_data.hearts, 2, "红桃快照随私密请求下发")
  lu.assertEquals(#asked.extra_data.prohibited, 0, "无禁止弃置的红桃")
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

--- 攻心：私密原生面板显示全部手牌、只允许选红桃；展示所选红桃后弃置。
function Testqiao_em_wu001_sunquan:testGongxinViewsShowsAndDiscardsHeart()
  local room, user, target = FkTest.room, p(2), p(3)
  clearCards(user)
  clearCards(target)
  local heart = give(target, "qiao__jink", Card.Heart, 3)
  local spade = give(target, "qiao__jink", Card.Spade, 4)
  local club = give(target, "qiao__jink", Card.Club, 5)
  local asked, askedWho, shown, shownFrom
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
  FkTest.setNextReplies(user, { { cards = { heart }, choice = DISCARD } })
  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, GONGXIN, {
      askToChooseCardsAndChoice = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        asked = params
        askedWho = who
        return original(self, who, params)
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

  lu.assertIs(askedWho, user, "观看只发给发动者")
  lu.assertEquals(#asked.all_cards, 3, "应显示目标的全部手牌")
  lu.assertEquals(#asked.cards, 1, "可选候选只列红桃")
  lu.assertEquals(asked.cards[1], heart)
  lu.assertEquals(asked.min_num, 0, "可以不选红桃直接结束")
  lu.assertEquals(asked.max_num, 1)
  lu.assertEquals(#shown, 1, "应公开展示所选红桃")
  lu.assertEquals(shown[1], heart)
  lu.assertIs(shownFrom, target, "展示的来源是手牌所有者")
  lu.assertEquals(room:getCardArea(heart), Card.DiscardPile, "所选红桃应被弃置")
  lu.assertEquals(room:getCardArea(spade), Card.PlayerHand, "未展示的牌不动")
  lu.assertEquals(room:getCardArea(club), Card.PlayerHand, "未展示的牌不动")
end

--- 攻心：置顶、无红桃、无答复与结束观看都只走原生面板，不展示未选牌。
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

  -- 置顶分支：真实回包选红桃 + 置顶。
  local shown = 0
  local originalShow = room.showCards
  room.showCards = function(...)
    shown = shown + 1
    return originalShow(...)
  end
  FkTest.setNextReplies(user, { { cards = { heart }, choice = ON_TOP } })
  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, GONGXIN, {
      askToChooseCardsAndChoice = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        return original(self, who, params)
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
  lu.assertEquals(shown, 1, "置顶前只展示所选红桃")
  lu.assertEquals(room:getCardArea(heart), Card.DrawPile, "应置于牌堆")
  lu.assertEquals(room.draw_pile[1], heart, "应置于牌堆顶")
  lu.assertEquals(room:getCardArea(spade), Card.PlayerHand, "未展示的牌不动")

  -- 无红桃且无答复：面板仍显示全部手牌，但无牌可选；不展示、不移动。
  local askedNoHeart, shownNoHeart = nil, 0
  room.showCards = function(...)
    shownNoHeart = shownNoHeart + 1
    return originalShow(...)
  end
  FkTest.setNextReplies(user, { "" })
  local ok2, err2 = pcall(function()
    skill_test.withSkillRequests(room, GONGXIN, {
      askToChooseCardsAndChoice = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        askedNoHeart = params
        return original(self, who, params)
      end,
    }, function()
      inRoom(function()
        local skill = Fk.skills[GONGXIN]
        skill:onUse(room, { from = user, cards = {}, tos = { blackTarget } })
      end)
    end)
  end)
  room.showCards = originalShow
  if not ok2 then error(err2, 0) end
  lu.assertNotNil(askedNoHeart, "没有红桃也应显示面板")
  lu.assertEquals(#askedNoHeart.all_cards, 1, "面板显示目标的唯一手牌")
  lu.assertEquals(#askedNoHeart.cards, 0, "没有红桃时无牌可选")
  lu.assertEquals(askedNoHeart.choices[1], END_CHOICE, "结束观看仍置于首位")
  lu.assertEquals(shownNoHeart, 0, "无答复结束不展示任何牌")
  lu.assertEquals(room:getCardArea(club), Card.PlayerHand, "无红桃时不动手牌")

  -- 客户端回包带牌但选择结束：仍不展示、不移动。
  local heart2 = give(target, "qiao__jink", Card.Heart, 9)
  local shownEnd = 0
  room.showCards = function(...)
    shownEnd = shownEnd + 1
    return originalShow(...)
  end
  FkTest.setNextReplies(user, { { cards = { heart2 }, choice = END_CHOICE } })
  local ok3, err3 = pcall(function()
    inRoom(function()
      local skill = Fk.skills[GONGXIN]
      skill:onUse(room, { from = user, cards = {}, tos = { target } })
    end)
  end)
  room.showCards = originalShow
  if not ok3 then error(err3, 0) end
  lu.assertEquals(shownEnd, 0, "结束观看不展示任何牌")
  lu.assertEquals(room:getCardArea(heart2), Card.PlayerHand, "结束观看不移动手牌")
end

--- 原生面板按钮：结束项始终可用；弃置/置顶只在恰好一张快照红桃时可用，
--- 禁止弃置只关闭弃置，不影响置顶。
function Testqiao_em_wu001_sunquan:testGongxinNativeChoiceFilter()
  local skel = assert(Fk.skill_skels[GONGXIN])
  local filter = assert(skel.extra and skel.extra.choiceFilter,
    "技能骨架应暴露面板按钮筛选")
  local data = { hearts = { 11, 12 }, prohibited = { 12 } }
  lu.assertTrue(filter({}, END_CHOICE, data), "未选牌时可结束观看")
  lu.assertTrue(filter({ 11 }, END_CHOICE, data), "选中红桃时仍可结束观看")
  lu.assertFalse(filter({}, DISCARD, data), "未选牌不可弃置")
  lu.assertFalse(filter({}, ON_TOP, data), "未选牌不可置顶")
  lu.assertFalse(filter({ 11, 12 }, DISCARD, data), "超过一张不可弃置")
  lu.assertTrue(filter({ 11 }, DISCARD, data), "一张未禁红桃可弃置")
  lu.assertFalse(filter({ 12 }, DISCARD, data), "禁止弃置的红桃不可弃置")
  lu.assertTrue(filter({ 12 }, ON_TOP, data), "禁止弃置的红桃仍可置顶")
  lu.assertFalse(filter({ 99 }, DISCARD, data), "非快照红桃不可弃置")
  lu.assertFalse(filter({ 99 }, ON_TOP, data), "非快照红桃不可置顶")
end

--- 私密面板的牌与禁令快照：显示全部手牌、只开放红桃；禁止弃置的红桃仍可置顶。
function Testqiao_em_wu001_sunquan:testGongxinProhibitedHeartSnapshotAllowsTop()
  local room, user, target = FkTest.room, p(2), p(3)
  clearCards(user)
  clearCards(target)
  local freeHeart = give(target, "qiao__jink", Card.Heart, 3)
  local prohibited = give(target, "qiao__jink", Card.Heart, 4)
  local spade = give(target, "qiao__jink", Card.Spade, 5)
  installDiscardProhibit(room, target, prohibited)
  inRoom(function()
    room:handleAddLoseSkills(user, GONGXIN, P.SOURCE, false, true)
    room.current = user
    user.phase = Player.Play
  end)

  local asked, shown = nil, nil
  local originalShow = room.showCards
  room.showCards = function(self, cards, from, proposer)
    shown = Card:getIdList(cards)
    return originalShow(self, cards, from, proposer)
  end
  FkTest.setNextReplies(user, { { cards = { prohibited }, choice = ON_TOP } })
  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, GONGXIN, {
      askToChooseCardsAndChoice = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        asked = params
        return original(self, who, params)
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

  lu.assertEquals(#asked.all_cards, 3, "面板应显示目标全部手牌")
  lu.assertTrue(table.contains(asked.all_cards, spade), "非红桃也在面板中显示")
  lu.assertEquals(#asked.cards, 2, "只把两张红桃作为可选候选")
  lu.assertTrue(table.contains(asked.cards, freeHeart))
  lu.assertTrue(table.contains(asked.cards, prohibited),
    "禁止弃置的红桃仍是可选候选")
  lu.assertEquals(#asked.extra_data.prohibited, 1, "禁令快照随请求下发")
  lu.assertEquals(asked.extra_data.prohibited[1], prohibited)
  lu.assertEquals(#shown, 1, "只公开所选的一张红桃")
  lu.assertEquals(shown[1], prohibited)
  lu.assertEquals(room:getCardArea(prohibited), Card.DrawPile, "禁止弃置的红桃仍可置顶")
  lu.assertEquals(room.draw_pile[1], prohibited, "应置于牌堆顶")
  lu.assertEquals(room:getCardArea(freeHeart), Card.PlayerHand, "未选红桃不移动")
  lu.assertEquals(room:getCardArea(spade), Card.PlayerHand, "非红桃不移动")
end

--- 服务端复核：回包后失位、非候选牌、非法动作与展示后失位都不得移动。
function Testqiao_em_wu001_sunquan:testGongxinServerRechecksStaleSelectionAndAction()
  local room, user, target = FkTest.room, p(2), p(3)
  clearCards(user)
  clearCards(target)
  local heart = give(target, "qiao__jink", Card.Heart, 3)
  local spade = give(target, "qiao__jink", Card.Spade, 4)
  inRoom(function()
    room:handleAddLoseSkills(user, GONGXIN, P.SOURCE, false, true)
    room.current = user
    user.phase = Player.Play
  end)

  local shown = 0
  local originalShow = room.showCards
  room.showCards = function(...)
    shown = shown + 1
    return originalShow(...)
  end
  local function useNow()
    inRoom(function()
      local skill = Fk.skills[GONGXIN]
      skill:onUse(room, { from = user, cards = {}, tos = { target } })
    end)
  end

  -- 请求返回后、展示前牌被移走：展示前复核拒绝。
  FkTest.setNextReplies(user, { { cards = { heart }, choice = DISCARD } })
  skill_test.withSkillRequests(room, GONGXIN, {
    askToChooseCardsAndChoice = function(self, who, params, original)
      if params.skill_name ~= GONGXIN then return original(self, who, params) end
      local cards, choice = original(self, who, params)
      -- 只改牌所在区域模拟结算窗口内的移动，避免在请求回包中再触发完整移牌流程。
      self.card_place[heart] = Card.DiscardPile
      return cards, choice
    end,
  }, useNow)
  lu.assertEquals(shown, 0, "回包后牌已离开原手牌区时不展示")
  lu.assertEquals(room:getCardArea(heart), Card.DiscardPile)

  -- 非候选牌与非法动作：即使携带牌也不展示、不移动。
  local shownBefore = shown
  FkTest.setNextReplies(user, { { cards = { spade }, choice = ON_TOP } })
  useNow()
  lu.assertEquals(shown, shownBefore, "非候选牌不得展示")
  lu.assertEquals(room:getCardArea(spade), Card.PlayerHand, "非候选牌不得移动")

  FkTest.setNextReplies(user, { { cards = { spade }, choice = "#qiao__gongxin-unknown" } })
  useNow()
  lu.assertEquals(shown, shownBefore, "非法动作不得展示")
  lu.assertEquals(room:getCardArea(spade), Card.PlayerHand, "非法动作不得移动")

  -- 展示后、移动前牌被移走：移动前复核拒绝。
  local late = give(target, "qiao__jink", Card.Heart, 5)
  FkTest.setNextReplies(user, { { cards = { late }, choice = ON_TOP } })
  local countingShow = room.showCards
  room.showCards = function(self, cards, from, proposer)
    local ret = countingShow(self, cards, from, proposer)
    -- 展示后、移动前失位；同样只改区域，不触发第二次完整移牌。
    self.card_place[late] = Card.DiscardPile
    return ret
  end
  useNow()
  room.showCards = countingShow
  lu.assertNotEquals(room:getCardArea(late), Card.DrawPile, "展示后失位不得置于牌堆")
  room.showCards = originalShow
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

--- 攻心限次：真实客户端首次可用；引擎在 on_use 前写入既有阶段历史后按钮禁用；
--- 回放同一主动技回包不得再次观看或结算；真实阶段结束清空阶段历史后，
--- 下个出牌阶段恢复。
function Testqiao_em_wu001_sunquan:testGongxinOncePerPlayPhaseAndServerRejectsDuplicate()
  local room, user, target = FkTest.room, p(2), p(3)
  clearCards(user)
  clearCards(target)
  local heart = give(target, "qiao__jink", Card.Heart, 3)
  local spade = give(target, "qiao__jink", Card.Spade, 4)
  inRoom(function()
    room:handleAddLoseSkills(user, GONGXIN, P.SOURCE, false, true)
    room.current = user
    user.phase = Player.Play
  end)

  local reply = clientActiveReply(room, user, GONGXIN, { target = target })
  lu.assertEquals(reply.card.skill, GONGXIN, "回包应携带真实技能 ID")
  lu.assertEquals(#reply.targets, 1, "回包应携带真实目标")

  local asks, shows = 0, 0
  local originalShow = room.showCards
  room.showCards = function(...)
    shows = shows + 1
    return originalShow(...)
  end
  FkTest.setNextReplies(user, { { cards = { heart }, choice = DISCARD } })
  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, GONGXIN, {
      askToChooseCardsAndChoice = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        asks = asks + 1
        return original(self, who, params)
      end,
    }, function()
      inRoom(function() room:handleUseCardReply(user, reply, nil) end)
    end)
  end)
  room.showCards = originalShow
  if not ok then error(err, 0) end
  lu.assertEquals(asks, 1, "真实回包应完成一次原生面板询问")
  lu.assertEquals(shows, 1, "第一次发动应展示所选红桃")
  lu.assertEquals(room:getCardArea(heart), Card.DiscardPile, "首次提交应正常结算")
  lu.assertEquals(user:usedSkillTimes(GONGXIN, Player.HistoryPhase), 1,
    "首次发动应写入既有阶段历史")
  lu.assertFalse(clientButtonValid(room, user, GONGXIN),
    "同一出牌阶段首次发动后不可再用")

  -- 服务端二次提交：回放同一技能回包，不得再次询问、展示或结算。
  inRoom(function() end)
  local asksBefore, showsBefore = asks, shows
  local originalShow2 = room.showCards
  room.showCards = function(...)
    shows = shows + 1
    return originalShow2(...)
  end
  skill_test.withSkillRequests(room, GONGXIN, {
    askToChooseCardsAndChoice = function(self, who, params, original)
      if params.skill_name ~= GONGXIN then return original(self, who, params) end
      asks = asks + 1
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:handleUseCardReply(user, {
        card = { skill = GONGXIN, subcards = {} },
        targets = { target.id },
      }, nil)
    end)
  end)
  room.showCards = originalShow2
  lu.assertEquals(asks, asksBefore, "服务端二次提交不得再次询问面板")
  lu.assertEquals(shows, showsBefore, "服务端二次提交不得再展示牌")
  lu.assertEquals(room:getCardArea(spade), Card.PlayerHand, "二次提交不得移动手牌")
  lu.assertEquals(user:usedSkillTimes(GONGXIN, Player.HistoryPhase), 1,
    "二次提交不得增加既有阶段历史")

  -- 下个出牌阶段：真实阶段结束清空阶段历史后恢复。
  FkTest.setNextReplies(user, { "" })
  inRoom(function()
    GameEvent.Phase:create(
      PhaseData:new { who = user, phase = Player.Play, reason = "game_rule" }):exec()
  end)
  lu.assertEquals(user:usedSkillTimes(GONGXIN, Player.HistoryPhase), 0,
    "阶段结束应清空本阶段历史")
  inRoom(function()
    room.current = user
    user.phase = Player.Play
  end)
  lu.assertTrue(clientButtonValid(room, user, GONGXIN), "下个出牌阶段恢复可用")
end

--- 攻心：观看后即使没有可展示的红桃而立即结束，也已消耗本阶段次数。
function Testqiao_em_wu001_sunquan:testGongxinViewOnlyStillConsumesPhaseUse()
  local room, user, target = FkTest.room, p(2), p(3)
  clearCards(user)
  clearCards(target)
  give(target, "qiao__jink", Card.Spade, 5)
  inRoom(function()
    room:handleAddLoseSkills(user, GONGXIN, P.SOURCE, false, true)
    room.current = user
    user.phase = Player.Play
  end)

  local reply = clientActiveReply(room, user, GONGXIN, { target = target })
  local asked, shows = nil, 0
  local originalShow = room.showCards
  room.showCards = function(...)
    shows = shows + 1
    return originalShow(...)
  end
  FkTest.setNextReplies(user, { "" })
  local ok, err = pcall(function()
    skill_test.withSkillRequests(room, GONGXIN, {
      askToChooseCardsAndChoice = function(self, who, params, original)
        if params.skill_name ~= GONGXIN then return original(self, who, params) end
        asked = params
        return original(self, who, params)
      end,
    }, function()
      inRoom(function() room:handleUseCardReply(user, reply, nil) end)
    end)
  end)
  room.showCards = originalShow
  if not ok then error(err, 0) end
  lu.assertNotNil(asked, "没有红桃也走原生面板")
  lu.assertEquals(#asked.cards, 0, "没有红桃时面板无牌可选")
  lu.assertEquals(shows, 0, "结束观看不展示任何牌")
  lu.assertEquals(user:usedSkillTimes(GONGXIN, Player.HistoryPhase), 1,
    "观看后结束也消耗攻心次数")
  lu.assertFalse(clientButtonValid(room, user, GONGXIN),
    "观看后结束的同一阶段不可再用")
end

--- 攻心：同阶段失去后重获不刷新既有次数。
function Testqiao_em_wu001_sunquan:testGongxinRegrantDoesNotRefreshSamePhaseUse()
  local room, user, target = FkTest.room, p(2), p(3)
  clearCards(user)
  clearCards(target)
  give(target, "qiao__jink", Card.Spade, 6)
  inRoom(function()
    room:handleAddLoseSkills(user, GONGXIN, P.SOURCE, false, true)
    room.current = user
    user.phase = Player.Play
  end)

  local reply = clientActiveReply(room, user, GONGXIN, { target = target })
  FkTest.setNextReplies(user, { "" })
  skill_test.withSkillRequests(room, GONGXIN, {
    askToChooseCardsAndChoice = function(self, who, params, original)
      if params.skill_name ~= GONGXIN then return original(self, who, params) end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function() room:handleUseCardReply(user, reply, nil) end)
  end)
  lu.assertFalse(clientButtonValid(room, user, GONGXIN), "首次发动后不可再用")

  inRoom(function()
    room:handleAddLoseSkills(user, "-" .. GONGXIN, P.SOURCE, false, true)
    lu.assertFalse(user:hasSkill(GONGXIN), "应实际失去本次授予")
    room:handleAddLoseSkills(user, GONGXIN, P.SOURCE, false, true)
    lu.assertTrue(user:hasSkill(GONGXIN), "同阶段应重获攻心")
  end)
  lu.assertFalse(clientButtonValid(room, user, GONGXIN),
    "重获技能不刷新同阶段既有次数")
end

--- 旗入口限次：真实客户端首次可用；二次提交不得再置入烽火；计次按角色隔离；
--- 下个出牌阶段恢复。
function Testqiao_em_wu001_sunquan:testFlagEntryOncePerPlayPhaseRejectsDuplicate()
  local room, lord, wu = FkTest.room, p(1), p(2)
  clearCards(lord)
  clearCards(wu)
  local first = give(wu, P.PEARL, Card.Heart, 2)
  local second = give(wu, P.PEARL, Card.Spade, 3)
  give(lord, P.PEARL, Card.Club, 4)
  inRoom(function()
    room.current = wu
    wu.phase = Player.Play
    lord.phase = Player.Play
  end)

  local reply = clientActiveReply(room, wu, P.ENTRY, { card = first })
  inRoom(function() room:handleUseCardReply(wu, reply, nil) end)
  lu.assertEquals(P.count(lord), 1, "首次提交应真实置入烽火")
  inRoom(function()
    lu.assertTrue(table.contains(lord:getPile(P.PILE), first), "所置的装备牌应进入旗牌堆")
  end)
  lu.assertEquals(wu:usedSkillTimes(P.ENTRY, Player.HistoryPhase), 1,
    "首次发动应写入既有阶段历史")
  lu.assertFalse(clientButtonValid(room, wu, P.ENTRY),
    "同一出牌阶段首次发动后不可再用")

  -- 服务端二次提交：同一入口回包不得再次置入。
  inRoom(function()
    room:handleUseCardReply(wu, {
      card = { skill = P.ENTRY, subcards = { second } },
      targets = {},
    }, nil)
  end)
  lu.assertEquals(P.count(lord), 1, "服务端二次提交不得再次置入烽火")
  lu.assertEquals(room:getCardArea(second), Card.PlayerHand, "二次提交的牌不应移动")
  lu.assertEquals(wu:usedSkillTimes(P.ENTRY, Player.HistoryPhase), 1,
    "二次提交不得增加既有阶段历史")

  -- 计次按角色隔离：同阶段其他吴势力角色的入口仍可用。
  lu.assertTrue(clientButtonValid(room, lord, P.ENTRY),
    "同阶段不同角色不共享旗入口的计次")

  -- 下个出牌阶段恢复。
  FkTest.setNextReplies(wu, { "" })
  inRoom(function()
    GameEvent.Phase:create(
      PhaseData:new { who = wu, phase = Player.Play, reason = "game_rule" }):exec()
  end)
  inRoom(function()
    room.current = wu
    wu.phase = Player.Play
  end)
  lu.assertTrue(clientButtonValid(room, wu, P.ENTRY), "下个出牌阶段恢复可用")
end

--- 攻心与旗入口分别计次：发动其一不影响另一技能的同阶段可用性。
function Testqiao_em_wu001_sunquan:testGongxinAndFlagEntryUseSeparatePhaseCounts()
  local room, lord, wu, target = FkTest.room, p(1), p(2), p(3)
  clearCards(lord)
  clearCards(wu)
  clearCards(target)
  give(target, "qiao__jink", Card.Spade, 5)
  local equip = give(wu, P.PEARL, Card.Heart, 6)
  inRoom(function()
    room:handleAddLoseSkills(wu, GONGXIN, P.SOURCE, false, true)
    room.current = wu
    wu.phase = Player.Play
  end)
  lu.assertTrue(clientButtonValid(room, wu, GONGXIN), "攻心首次可用")
  lu.assertTrue(clientButtonValid(room, wu, P.ENTRY), "旗入口首次可用")

  local reply = clientActiveReply(room, wu, GONGXIN, { target = target })
  FkTest.setNextReplies(wu, { "" })
  skill_test.withSkillRequests(room, GONGXIN, {
    askToChooseCardsAndChoice = function(self, who, params, original)
      if params.skill_name ~= GONGXIN then return original(self, who, params) end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function() room:handleUseCardReply(wu, reply, nil) end)
  end)
  lu.assertFalse(clientButtonValid(room, wu, GONGXIN), "攻心已计次")
  lu.assertTrue(clientButtonValid(room, wu, P.ENTRY), "攻心计次不影响旗入口")

  local entryReply = clientActiveReply(room, wu, P.ENTRY, { card = equip })
  inRoom(function() room:handleUseCardReply(wu, entryReply, nil) end)
  lu.assertEquals(P.count(lord), 1, "旗入口应正常置入烽火")
  lu.assertEquals(wu:usedSkillTimes(P.ENTRY, Player.HistoryPhase), 1,
    "旗入口独立计入自身历史")
  lu.assertFalse(clientButtonValid(room, wu, P.ENTRY), "旗入口已计次")
  lu.assertFalse(clientButtonValid(room, wu, GONGXIN), "两技能均已达本阶段上限")
end

return { name = "qiao_em_wu001_sunquan" }
