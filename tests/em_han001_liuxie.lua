-- EM(HAN001) 君刘协：登记/升变、诏书标记、入口与四花色消费核心验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"
local H = require "packages.hegemony.util"
local ReqPlayCard = require "ltk.core.request_type.play_card"
local A = require "packages.qiao.pkg.qiao_mode.rules.ascension"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"

local LORD = "qiao_heg__em_han001"
local NORMAL = "qiao_heg__han001"
local BANNER = P.BANNER

local function inRoom(fn, label)
  local room = FkTest.room
  local entered, completed, result = false, false, nil
  local before = tostring(room.game_finished)
  FkTest.runInRoom(function() entered = true result = fn() completed = true end)
  local after = tostring(room.game_finished)
  lu.assertTrue(entered, (label or "inRoom") .. " 未进入; finished " .. before .. "->" .. after)
  lu.assertTrue(completed, (label or "inRoom") .. " 未完成; finished " .. before .. "->" .. after)
  return result
end
local function p(n) return FkTest.room.players[n] end

Testqiao_em_han001_liuxie = {
  setup = function()
    Fk.currentResponsePattern = nil
    support.initQiaoRoom()
    local room = FkTest.room
    inRoom(function()
      skill_test.installBlankGenerals(room, { "han", "han", "han", "wei", "shu", "wu", "qun", "jin" })
      skill_test.installDualGenerals(room, room.players[1], {
        main = NORMAL, deputy = "qiao_test__han_2", kingdom = "han",
      })
      room.current = room.players[1]
      A.ascend(room, room.players[1], LORD, "han", { kind = "lord" })
    end, "setup")
  end,
  tearDown = function() support.clearRoom() end,
}

function Testqiao_em_han001_liuxie:testRegistrationAscensionAndZhaoshuMark()
  local lord = p(1)
  lu.assertEquals(lord.general, LORD)
  lu.assertEquals(Fk.generals[LORD].trueName, "刘协")
  lu.assertEquals(Fk:translate(LORD), '<font color="#FFFF00">君</font>刘协')
  lu.assertTrue(Fk.generals[LORD].hidden)
  lu.assertTrue(lord:hasSkill(P.JIANPING))
  lu.assertEquals(lord:getMark(P.MARK), 1, "君主牌实际明置后应取得诏书标记")
  lu.assertTrue(lord:hasSkill(BANNER), "同势力角色应获得诏书入口")
  lu.assertTrue(p(2):hasSkill(BANNER))
  lu.assertFalse(p(4):hasSkill(BANNER), "异势力不获得入口")
end

function Testqiao_em_han001_liuxie:testZhaoshuEntryAndFourSuitConsume()
  local room, lord, ally = FkTest.room, p(1), p(2)
  local card
  inRoom(function()
    card = room:printCard("qiao__jink", Card.Heart, 4)
    room:obtainCard(ally, card, false, fk.ReasonJustMove)
    ally.phase = Player.Play
    Fk.skills[BANNER]:onUse(room, { from = ally, cards = { card.id }, tos = {} })
  end)
  lu.assertEquals(P.count(lord), 1, "同势力角色应交一张手牌到诏书")
  local suits = { Card.Spade, Card.Heart, Card.Club, Card.Diamond }
  inRoom(function()
    for i, suit in ipairs(suits) do
      local c = room:printCard("qiao__jink", suit, i)
      lord:addToPile(P.PILE, { c.id }, true, BANNER)
    end
    lord.phase = Player.Play
  end)
  local consumeAsked, consumeDetailed = false, false
  skill_test.withSkillRequests(room, P.CONSUME, {
    askToChoice = function(self, who, params, original)
      if params.skill_name == P.CONSUME then
        consumeAsked = true
        consumeDetailed = params.detailed == true
        for _, name in ipairs(params.choices) do
          -- 测试房间会登记 qiao_test__ 势力锦囊；正式牌面断言只覆盖正式牌。
          if Cards.tricks[name] ~= nil and not name:startsWith("qiao_test__") then
            lu.assertNotEquals(Fk:translate(":" .. name), ":" .. name,
              "诏书锦囊选项应有正式牌面说明：" .. name)
          end
        end
        return params.choices[1]
      end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      Fk.skills[P.CONSUME]:onUse(room, { from = lord, tos = {} })
    end)
  end)
  lu.assertTrue(consumeAsked, "多张势力锦囊时应询问取哪一张")
  lu.assertTrue(consumeDetailed, "势力锦囊选项应带详细牌面")
  lu.assertEquals(P.count(lord), 0, "四花色消费应移去诏书所有牌")
  local trickFound = false
  for _, id in ipairs(lord:getCardIds("h")) do
    local c = Fk:getCardById(id, true)
    if c ~= nil and Cards.tricks[c.name] ~= nil and room:getCardArea(id) == Card.PlayerHand
      and room:getCardOwner(id) ~= nil and room:getCardOwner(id).id == lord.id and c.suit ~= nil then
      trickFound = true
    end
  end
  lu.assertTrue(trickFound, "应取得一张真实势力锦囊实体")

end

function Testqiao_em_han001_liuxie:testZhuanpengPayBranchNullifiesRealSlash()
  local room, lord, attacker = FkTest.room, p(1), p(4)
  local slash, pay
  inRoom(function()
    slash = room:printCard("qiao__slash", Card.Spade, 8)
    room:obtainCard(attacker, slash, false, fk.ReasonJustMove)
    pay = room:printCard("qiao__jink", Card.Heart, 4)
    room:obtainCard(lord, pay, false, fk.ReasonJustMove)
    lord.hp = lord.maxHp
  end)
  local paymentRequests, invokeRequests = 0, 0
  skill_test.withSkillRequests(room, P.ZHUANPENG, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name ~= P.ZHUANPENG then return original(self, who, params) end
      invokeRequests = invokeRequests + 1
      return false
    end,
    askToCards = function(self, who, params, original)
      if params.skill_name ~= P.ZHUANPENG then return original(self, who, params) end
      paymentRequests = paymentRequests + 1
      lu.assertTrue(params.cancelable)
      return { pay.id }
    end,
  }, function()
    inRoom(function()
      room:useCard { from = attacker, tos = { lord }, card = Fk:getCardById(slash.id) }
    end)
  end)
  lu.assertEquals(paymentRequests, 1)
  lu.assertEquals(invokeRequests, 0)
  lu.assertEquals(lord.hp, lord.maxHp, "普通分支付牌后杀应无效")
  lu.assertTrue(table.contains(attacker:getCardIds("he"), pay.id), "应交给使用者一张牌")
end

function Testqiao_em_han001_liuxie:testZhuanpengReplacementWhenTrickUsed()
  local room, lord, attacker = FkTest.room, p(1), p(4)
  local trick, slash, gift
  inRoom(function()
    trick = table.find(room.void, function(id)
      local c = Fk:getCardById(id, true)
      return c ~= nil and c.name == "qiao__command_world"
    end)
    lu.assertNotNil(trick, "缺少魏势力锦囊实体")
    room:moveCardTo(trick, Card.PlayerHand, lord, fk.ReasonJustMove, "test", nil, true, lord)
    room:useCard { from = lord, card = Fk:getCardById(trick), tos = { p(2) } }
    lu.assertTrue(((room:getTag("qiao_em_han001_used_tricks") or {})[lord.id] or {}).wei == true,
      "刘协使用魏势力锦囊后应记录历史")
    slash = room:printCard("qiao__slash", Card.Spade, 9)
    room:obtainCard(attacker, slash, false, fk.ReasonJustMove)
    gift = room:printCard("qiao__jink", Card.Club, 5)
    room:obtainCard(attacker, gift, false, fk.ReasonJustMove)
    lord.hp = lord.maxHp
  end)
  skill_test.withSkillRequests(room, P.ZHUANPENG, {
    askToSkillInvoke = function(self, who, params, original)
      if params.skill_name == P.ZHUANPENG then return true end
      return original(self, who, params)
    end,
    askToCards = function(self, who, params, original)
      if params.skill_name == P.ZHUANPENG and who == attacker then return { gift.id } end
      return original(self, who, params)
    end,
  }, function()
    inRoom(function()
      room:useCard { from = attacker, tos = { lord }, card = Fk:getCardById(slash.id) }
    end)
  end)
  lu.assertEquals(lord.hp, lord.maxHp - 1, "替代分支已交牌时杀应继续生效")
  lu.assertTrue(table.contains(lord:getCardIds("he"), gift.id), "应由使用者交给刘协一张牌")
end

function Testqiao_em_han001_liuxie:testTianshouRedirectsEquipToPileAndDraws()
  local room, lord, other = FkTest.room, p(1), p(4)
  local seal, handBefore
  inRoom(function()
    seal = room:printCard("qiao__jade_seal", Card.Spade, 1)
    room:obtainCard(other, seal, false, fk.ReasonJustMove)
    room:moveCardTo(seal, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, true, other)
  end)
  lu.assertEquals(room:getCardArea(seal.id), Card.PlayerEquip, "其他角色玉玺应改入刘协装备区")
  local owner1 = room:getCardOwner(seal.id)
  lu.assertNotNil(owner1, "玉玺应有所属者")
  lu.assertEquals(owner1.id, lord.id, "玉玺应归刘协")
  inRoom(function()
    handBefore = #lord:getCardIds("h")
    room:moveCardTo(seal, Card.PlayerHand, other, fk.ReasonJustMove, "test", nil, true, other)
  end)
  lu.assertEquals(room:getCardArea(seal.id), Card.PlayerSpecial, "刘协装备离开应改置诏书")
  local owner2 = room:getCardOwner(seal.id)
  lu.assertNotNil(owner2, "诏书上的玉玺应有所属者")
  lu.assertEquals(owner2.id, lord.id, "玉玺应仍在刘协的诏书")
  lu.assertTrue(#lord:getCardIds("h") >= handBefore + 2, "改置诏书后应摸两张")
end

function Testqiao_em_han001_liuxie:testNormalSealToZhaoshuDoesNotDraw()
  local room, lord = FkTest.room, p(1)
  local seal, before
  inRoom(function()
    seal = room:printCard("qiao__jade_seal", Card.Heart, 2)
    room:obtainCard(lord, seal, false, fk.ReasonJustMove)
    before = #lord:getCardIds("h")
    lord.phase = Player.Play
    Fk.skills[BANNER]:onUse(room, { from = lord, cards = { seal.id }, tos = {} })
  end)
  lu.assertEquals(P.count(lord), 1, "普通交牌应进入诏书")
  lu.assertEquals(#lord:getCardIds("h"), before - 1, "普通交牌不得触发天授摸两张")
end


local function withClientRoom(current, fn)
  local ClientPlayer = require "ltk.client.clientplayer"
  local clients = {}
  for _, original in ipairs(current.players) do
    local copy = ClientPlayer:new(original._splayer)
    for key, value in pairs(original) do
      if key ~= "room" and key ~= "class" and key ~= "serverplayer" then copy[key] = value end
    end
    local cards = {}
    for area, ids in pairs(copy.player_cards or {}) do cards[area] = table.simpleClone(ids) end
    copy.player_cards = cards
    table.insert(clients, copy)
  end
  for index, player in ipairs(clients) do player.next = clients[index % #clients + 1] end
  local clientRoom = setmetatable({ players = clients, alive_players = clients, current = clients[1] },
    { __index = current })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = pcall(function() fn(clients, clientRoom) end)
  Fk.currentRoom = originalRoom
  if not ok then error(err, 0) end
  return clients, clientRoom
end

function Testqiao_em_han001_liuxie:testClientBannerConsumeAvailability()
  local room, lord = FkTest.room, p(1)
  local suits = { Card.Spade, Card.Heart, Card.Club, Card.Diamond }
  inRoom(function()
    for i, suit in ipairs(suits) do
      local c = room:printCard("qiao__jink", suit, i)
      lord:addToPile(P.PILE, { c.id }, true, BANNER)
    end
    lord.phase = Player.Play
    P.syncTricks(room)
  end)
  local reply
  withClientRoom(room, function(clients)
    local me = clients[1]
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    lu.assertTrue(Fk.skills[P.BANNER]:canUse(me), "客户端诏书入口应可用")
    lu.assertTrue(Fk.skills[P.CONSUME]:canUse(me), "客户端四花色消费应可用")
    lu.assertFalse(Fk.skills[P.CONSUME].visible, "取锦囊不应出现在技能按钮栏")
    lu.assertEquals(Fk:translate("qiao__edict_take_trick"), "获得势力锦囊")

    local mark = assert(Fk.qml_marks[P.PILE_MARK])
    lu.assertEquals(mark.how_to_show(P.PILE, me:getPile(P.PILE), me), "4")
    local popup = mark.qml(P.PILE, me:getPile(P.PILE), me)
    lu.assertEquals(popup.url, "packages/qiao/pkg/qiao_mode/qml/EdictPile.qml")
    lu.assertEquals(popup.prop.holderId, me.id)

    local board = assert(Fk:getBoardGame("qiao_heg_mode"))
    local client = board.client_klass:new(ClientInstance.client)
    local play = client.request_handlers.PlayCard:new(me)
    client.current_request_handler = play
    lu.assertFalse(client:canConsumeEdict(clients[2].id), "他人的诏书不可操作")
    me.phase = Player.Finish
    lu.assertFalse(client:canConsumeEdict(me.id), "出牌阶段外不可操作")
    me.phase = Player.Play
    lu.assertTrue(client:canConsumeEdict(me.id))

    local originalNotify = ClientInstance.notifyUI
    ClientInstance.notifyUI = function(self, cmd, data)
      if cmd == "ReplyToServer" then reply = data end
    end
    local ok, err = pcall(function()
      play:update("QiaoEdict", me.id, "click", {})
    end)
    ClientInstance.notifyUI = originalNotify
    if not ok then error(err, 0) end
    lu.assertNotNil(reply, "点击弹窗按钮应直接产生标准技能回包")
    lu.assertEquals(reply.card.skill, P.CONSUME)
    lu.assertEquals(reply.card.subcards, {})
    lu.assertEquals(reply.targets, {})
    lu.assertFalse(client:canConsumeEdict(me.id), "请求提交后不可重复点击")
    play:_finish()
  end)

  skill_test.withSkillRequests(room, P.CONSUME, {
    askToChoice = function(_, _, params) return params.choices[1] end,
  }, function()
    inRoom(function() room:handleUseCardReply(lord, reply) end)
  end)
  lu.assertEquals(P.count(lord), 0, "标准回包应支付诏书上的所有牌")
  lu.assertEquals(lord:usedSkillTimes(P.CONSUME, Player.HistoryPhase), 1)
end


function Testqiao_em_han001_liuxie:testZhaoshuSelectSkillCardLimit()
  local room, lord = FkTest.room, p(1)
  local hand, equip = {}, nil
  inRoom(function()
    lord.phase = Player.Play
    for i = 1, 3 do
      local c = room:printCard("qiao__jink", Card.Heart, i)
      room:obtainCard(lord, c, false, fk.ReasonJustMove)
      hand[i] = c.id
    end
    equip = room:printCard("qiao__chitu", Card.Spade, 8)
    room:moveCardIntoEquip(lord, equip, "test", true, lord)
    for i = 2, 8 do
      local k = i % 2 == 0 and "wei" or "qun"
      room:setPlayerProperty(p(i), "kingdom", k)
      room:setPlayerMark(p(i), "__heg_kingdom", k)
    end
    room:setPlayerProperty(lord, "kingdom", "han")
    room:setPlayerMark(lord, "__heg_kingdom", "han")
  end)
  lu.assertTrue(H.isSmallKingdomPlayer(lord), "夹具应让刘协成为小势力")
  withClientRoom(room, function(clients)
    local me = clients[1]
    local handler = ReqPlayCard:new(me)
    handler.skill_name = P.BANNER
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity(P.BANNER), "诏书按钮应可用")
    handler:selectSkill(P.BANNER, { selected = true })
    lu.assertTrue(handler:cardValidity(hand[1]), "第一张手牌应可选")
    handler:selectCard(hand[1], { selected = true })
    lu.assertTrue(handler:cardValidity(hand[2]), "小势力第二张手牌应可选")
    handler:selectCard(hand[2], { selected = true })
    lu.assertFalse(handler:cardValidity(hand[3]), "小势力不能选择第三张")
    lu.assertFalse(handler:cardValidity(equip.id), "非手牌不能选择")
    handler:_finish()
  end)
  inRoom(function()
    for i = 1, 8 do
      room:setPlayerProperty(p(i), "kingdom", "han")
      room:setPlayerMark(p(i), "__heg_kingdom", "han")
    end
  end)
  lu.assertFalse(H.isSmallKingdomPlayer(lord), "全为汉时刘协应不是小势力")
  withClientRoom(room, function(clients)
    local me = clients[1]
    local handler = ReqPlayCard:new(me)
    handler.skill_name = P.BANNER
    handler:setup()
    handler:selectSkill(P.BANNER, { selected = true })
    lu.assertTrue(handler:cardValidity(hand[1]))
    handler:selectCard(hand[1], { selected = true })
    lu.assertFalse(handler:cardValidity(hand[2]), "非小势力不能选择第二张")
    handler:_finish()
  end)
end


-- ===== 敕令 / 诏书 / 挟天子：真实回合定向验收 =====

local IMPERIAL_CARD = "qiao__imperial_order"
local THREATEN = "qiao__threaten_emperor_skill"
local THREATEN_CARD = "qiao__threaten_emperor"

--- 走真实移动把一张敕令实体置入弃牌堆（AfterCardsMove 跟踪）。
local function imperialToDiscard(room)
  local card = room:printCard(IMPERIAL_CARD, Card.Club, 3)
  room:moveCardTo(card, Card.DiscardPile, nil, fk.ReasonDiscard, "test")
  return card
end

--- 撤掉初平取得的诏书，模拟本局尚无人持有。
local function clearZhaoshu(room)
  for _, player in ipairs(room.players) do
    room:setPlayerMark(player, P.MARK, 0)
  end
  P.sync(room)
end

function Testqiao_em_han001_liuxie:testImperialOrderTurnEndGrantsZhaoshuWhenNobodyHoldsIt()
  local room, lord, user = FkTest.room, p(1), p(2)
  local card
  inRoom(function()
    clearZhaoshu(room)
    lu.assertNil(P.holder(room))
    card = imperialToDiscard(room)
    room:setCurrent(user)
    room.logic:trigger(fk.TurnEnd, user, {})
  end)
  lu.assertIs(P.holder(room), user, "无持有者时由当前回合角色获得诏书")
  lu.assertEquals(room:getCardArea(card), Card.Void, "满足后段时该实体移出游戏")
  lu.assertTrue(user:hasSkill(P.CONSUME), "持有者获得四花色消费入口")
  lu.assertTrue(lord:hasSkill(P.BANNER), "同势力角色获得交牌入口")
  lu.assertFalse(p(4):hasSkill(P.BANNER), "异势力不获得交牌入口")
end

function Testqiao_em_han001_liuxie:testImperialOrderTurnEndSkipsEntityThatLeftDiscardPile()
  local room, user, third = FkTest.room, p(2), p(3)
  local card
  inRoom(function()
    clearZhaoshu(room)
    card = imperialToDiscard(room)
    room:obtainCard(third, card, true, fk.ReasonPrey)
    room:setCurrent(user)
    room.logic:trigger(fk.TurnEnd, user, {})
  end)
  lu.assertNil(P.holder(room), "回合结束前离开弃牌堆的实体不发放诏书")
  lu.assertEquals(room:getCardArea(card), Card.PlayerHand, "未被移出游戏")
  lu.assertTrue(table.contains(third:getCardIds(Player.Hand), card.id))
end

function Testqiao_em_han001_liuxie:testImperialOrderTurnEndKeepsExistingZhaoshuAndStillRemovesCard()
  local room, lord, user = FkTest.room, p(1), p(2)
  local card
  lu.assertIs(P.holder(room), lord)
  inRoom(function()
    card = imperialToDiscard(room)
    room:setCurrent(user)
    room.logic:trigger(fk.TurnEnd, user, {})
  end)
  lu.assertEquals(room:getCardArea(card), Card.Void, "已有诏书时敕令照常移出游戏")
  lu.assertIs(P.holder(room), lord, "全场诏书唯一，不转移已有诏书")
  lu.assertEquals(user:getMark(P.MARK), 0, "不再发放第二份诏书")
end

function Testqiao_em_han001_liuxie:testZhaoshuHolderRemovedStillOwnsTokenAndEntryIsSeparate()
  local room, lord, ally = FkTest.room, p(1), p(2)
  inRoom(function()
    room:setPlayerMark(lord, "PlayerRemoved", 1)
    P.sync(room)
  end)
  lu.assertIs(P.holder(room), lord, "被移出游戏期间仍拥有诏书")
  lu.assertNil(P.availableHolder(room), "入口可用性另行过滤")
  lu.assertFalse(ally:hasSkill(P.BANNER), "暂离期间不向同势力开放入口")
  inRoom(function()
    local card = imperialToDiscard(room)
    room:setCurrent(ally)
    room.logic:trigger(fk.TurnEnd, ally, {})
    room:setPlayerMark(lord, "PlayerRemoved", 0)
    P.sync(room)
  end)
  lu.assertIs(P.holder(room), lord, "不据不可见或不可用发第二份诏书")
  lu.assertEquals(ally:getMark(P.MARK), 0)
  lu.assertTrue(ally:hasSkill(P.BANNER), "移回后入口恢复")
end

function Testqiao_em_han001_liuxie:testThreatenEmperorNominalTurnEndsPlayPhaseThenRequiresRealDiscard()
  local room, user = FkTest.room, p(1)
  local card, pay
  inRoom(function()
    card = room:printCard(THREATEN_CARD, Card.Spade, 1)
    room:obtainCard(user, card, false, fk.ReasonJustMove)
    pay = room:printCard("qiao__jink", Card.Heart, 3)
    room:obtainCard(user, pay, false, fk.ReasonJustMove)
    room:setCurrent(user)
  end)

  local phaseData = PhaseData:new { who = user, phase = Player.Play }
  FkTest.setNextReplies(user, { FkTest.ReplyCard(card, { user }) })
  inRoom(function() GameEvent.Phase:create(phaseData):exec() end)
  lu.assertTrue(phaseData.phase_end, "挟天子应结束本人出牌阶段")
  lu.assertEquals(user:getMark("qiao__threaten_emperor-turn"), 1,
    "实际结束出牌阶段后建立回合结束的支付")
  lu.assertEquals(room:getCardArea(card), Card.DiscardPile, "牌按正常用牌流程进入弃牌堆")

  FkTest.setNextReplies(user, { FkTest.ReplyDiscard({ pay.id }) })
  inRoom(function() room.logic:trigger(fk.TurnEnd, user, {}) end)
  lu.assertEquals(room:getCardArea(pay.id), Card.DiscardPile, "回合结束须弃置一张手牌")
  lu.assertEquals(#room.extra_turn_list, 1, "实际弃置后获得一个额外回合")
  lu.assertIs(room.extra_turn_list[1].who, user)
end

function Testqiao_em_han001_liuxie:testThreatenEmperorUsableOnlyInOwnNominalTurn()
  local room, user, foreign = FkTest.room, p(1), p(4)
  local card
  inRoom(function()
    card = room:printCard(THREATEN_CARD, Card.Spade, 1)
    room:obtainCard(user, card, false, fk.ReasonJustMove)
    room:setCurrent(user)
    user.phase = Player.Play
  end)
  local sk = card:getSkill(user)
  inRoom(function()
    lu.assertTrue(sk:canUse(user, card), "额定回合的大势力角色可使用")
    lu.assertFalse(sk:canUse(foreign, card), "非大势力角色不可使用")
    room:addTableMark(user, "_extra_turn_count", "test")
    lu.assertFalse(sk:canUse(user, card), "额外回合内不可使用")
    room:setPlayerMark(user, "_extra_turn_count", 0)
  end)
end

return { name = "qiao_em_han001_liuxie" }
