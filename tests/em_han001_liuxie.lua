-- EM(HAN001) 君刘协：登记/升变、诏书标记、入口与四花色消费核心验收。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"
local H = require "packages.hegemony.util"
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
  local assertMoveViews = __dofile("../../../tests/support/move_visibility.lua")
  assertMoveViews(pay.id, Card.PlayerHand, Card.PlayerHand, { lord, attacker })
end

local function checkReverseGift(redirectSword)
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
    if redirectSword then
      room:handleAddLoseSkills(attacker, P.TIANSHOU, nil, false, true)
      gift = room:printCard("qiao__chixiao_sword", Card.Club, 5)
      room:moveCardTo(gift, Card.PlayerEquip, attacker, fk.ReasonJustMove)
    else
      gift = room:printCard("qiao__jink", Card.Club, 5)
      room:obtainCard(attacker, gift, false, fk.ReasonJustMove)
    end
    lord.hp = lord.maxHp
  end)
  local use = { from = attacker, card = slash, tos = { lord } }
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
    inRoom(function() room:useCard(use) end)
  end)
  lu.assertEquals(table.contains(use.nullifiedTargets or {}, lord), redirectSword)
  lu.assertEquals(table.contains(lord:getCardIds("h"), gift.id), not redirectSword)
  if redirectSword then
    lu.assertTrue(table.contains(attacker:getPile(P.PILE), gift.id))
    lu.assertEquals(lord.hp, lord.maxHp, "反向交牌未送达，【杀】应无效")
  else
    lu.assertEquals(lord.hp, lord.maxHp - 1, "使用者实际交牌后，【杀】继续生效")
    local assertMoveViews = __dofile("../../../tests/support/move_visibility.lua")
    assertMoveViews(gift.id, Card.PlayerHand, Card.PlayerHand, { attacker, lord })
  end
end

function Testqiao_em_han001_liuxie:testZhuanpengReplacementWhenTrickUsed()
  checkReverseGift(false)
end

function Testqiao_em_han001_liuxie:testZhuanpengReverseSwordStillRequiresDelivery()
  checkReverseGift(true)
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


local function withEdictRequest(room, actor, fn)
  local result
  client_room.run(room, function(clients, clientRoom)
    local originalClient, originalSelf = ClientInstance, Self
    local board = assert(Fk:getBoardGame("qiao_heg_mode"))
    local client = board.client_klass:new(originalClient.client)
    client.players = clients
    client.banners = table.simpleClone(room.banners)
    clientRoom.banners = client.banners
    local notices = {}
    client.notifyUI = function(_, command, data) notices[command] = data end
    ClientInstance, Self = client, clients[actor.seat]
    local ok, err = xpcall(function()
      client:playCard({})
      local play = clientRoom.current_request_handler
      client.current_request_handler = play
      fn(client, play, notices)
      play:_finish()
      result = notices.ReplyToServer
    end, debug.traceback)
    ClientInstance, Self = originalClient, originalSelf
    if not ok then error(err, 0) end
  end)
  return result
end

local function verifyClientEdictConsumption(room, holder)
  local candidates = P.availableTricks(room)
  lu.assertTrue(#candidates > 0)
  local suits = { Card.Spade, Card.Heart, Card.Club, Card.Diamond }
  local fourth
  inRoom(function()
    for i, suit in ipairs(suits) do
      local c = room:printCard("qiao__jink", suit, i)
      holder:addToPile(P.PILE, { c.id }, true, BANNER)
      fourth = c.id
    end
    holder:addToPile(P.PILE, room:printCard("qiao__jink", Card.Heart, 9), true, BANNER)
    room:obtainCard(holder, room:printCard("qiao__jink", Card.Heart, 6), false, fk.ReasonJustMove)
    holder.phase = Player.Play
  end)
  local reply = withEdictRequest(room, holder, function(client, play, notices)
    local me = Self
    lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
    lu.assertTrue(Fk.skills[P.BANNER]:canUse(me), "客户端诏书入口应可用")
    lu.assertTrue(Fk.skills[P.CONSUME]:canUse(me), "客户端四花色消费应可用")
    lu.assertFalse(Fk.skills[P.CONSUME].visible, "取锦囊不应出现在技能按钮栏")
    lu.assertEquals(Fk:translate("qiao__edict_take_trick"), "获得势力锦囊")

    local mark = assert(Fk.qml_marks[P.PILE_MARK])
    lu.assertEquals(mark.how_to_show(P.PILE, me:getPile(P.PILE), me), "5 ♠♥♣♦")
    local popup = mark.qml(P.PILE, me:getPile(P.PILE), me)
    lu.assertEquals(popup.url, "packages/qiao/pkg/qiao_mode/qml/EdictPile.qml")
    lu.assertEquals(popup.prop.holderId, me.id)

    local label = table.find(client:skillStates(me.id), function(state) return state.id == P.PILE end)
    lu.assertEquals(label.value, "5 ♠♥♣♦")
    lu.assertEquals(label.action, "edict")
    lu.assertEquals(label.cards, me:getPile(P.PILE))
    me.phase = Player.Finish
    lu.assertEquals(client:edictPanelState(me.id), {}, "出牌阶段外不可操作")
    me.phase = Player.Play
    client.observing = true
    lu.assertEquals(client:edictPanelState(me.id), {}, "旁观时只查看牌")
    client.observing = false
    play:update("QiaoEdict", me.id, "open", {})
    lu.assertEquals(notices.QiaoOpenEdict, { me.id }, "头像入口应打开本人的诏书")
    lu.assertTrue(client:edictPanelState(me.id).showTake)
    local pile = table.simpleClone(me:getPile(P.PILE))
    table.removeOne(pile, fourth)
    lu.assertEquals(mark.how_to_show(P.PILE, pile, me), "4 ♠♥♣")
    me.special_cards = table.simpleClone(me.special_cards)
    me.special_cards[P.PILE] = pile
    lu.assertFalse(client:edictPanelState(me.id).canTake, "三花色不能消费")
    play:update("QiaoEdict", me.id, "take", {})
    lu.assertNil(notices.ReplyToServer)
    table.insert(pile, fourth)

    client:handleSetBanner({ P.TRICK_BANNER, {} })
    lu.assertNotNil(notices.QiaoPileActionChanged)
    lu.assertFalse(client:edictPanelState(me.id).canTake, "没有公开候选时不能消费")
    client:handleSetBanner({ P.TRICK_BANNER, P.trickNames(room) })
    play:update("CardItem", me:getCardIds("h")[1], "click", { selected = true })
    lu.assertTrue(client:edictPanelState(me.id).canPlace)
    lu.assertTrue(client:edictPanelState(me.id).canTake, "选了手牌仍可改点获得势力锦囊")
    lu.assertTrue(play:update("QiaoEdict", me.id, "take", {}))
    lu.assertEquals(notices.ReplyToServer.card, { skill = P.CONSUME, subcards = {} })
    lu.assertEquals(notices.ReplyToServer.targets, {})
    lu.assertFalse(play:update("QiaoEdict", me.id, "take", {}), "请求提交后不可重复点击")
  end)

  skill_test.withSkillRequests(room, P.CONSUME, {
    askToChoice = function(_, _, params) return params.choices[1] end,
  }, function()
    inRoom(function() room:handleUseCardReply(holder, reply) end)
  end)
  lu.assertEquals(P.count(holder), 0, "标准回包应支付诏书上的所有牌")
  lu.assertEquals(holder:usedSkillTimes(P.CONSUME, Player.HistoryPhase), 1)
  lu.assertNotNil(table.find(candidates, function(candidate)
    return table.contains(holder:getCardIds("h"), candidate.id)
  end), "取得原游戏外区域的实体锦囊")
end

function Testqiao_em_han001_liuxie:testClientBannerConsumeAvailability()
  verifyClientEdictConsumption(FkTest.room, p(1))
end


function Testqiao_em_han001_liuxie:testZhaoshuSelectSkillCardLimit()
  local room, lord, ally = FkTest.room, p(1), p(2)
  local hand, equip = {}, nil
  inRoom(function()
    ally.phase = Player.Play
    for i = 1, 3 do
      local c = room:printCard("qiao__jink", Card.Heart, i)
      room:obtainCard(ally, c, false, fk.ReasonJustMove)
      hand[i] = c.id
    end
    equip = room:printCard("qiao__chitu", Card.Spade, 8)
    room:moveCardIntoEquip(ally, equip, "test", true, ally)
    for i = 3, 8 do
      local k = i % 2 == 0 and "wei" or "qun"
      room:setPlayerProperty(p(i), "kingdom", k)
      room:setPlayerMark(p(i), "__heg_kingdom", k)
    end
    room:setPlayerProperty(lord, "kingdom", "han")
    room:setPlayerMark(lord, "__heg_kingdom", "han")
  end)
  lu.assertTrue(H.isSmallKingdomPlayer(ally))
  withEdictRequest(room, ally, function(client, play, notices)
    lu.assertTrue(play.scene:getAllItems("SkillButton")[P.BANNER].enabled)
    play:update("SkillButton", P.BANNER, "click", { selected = true })
    lu.assertEquals(notices.QiaoOpenEdict, { lord.id }, "技能按钮应打开同势力持有者的诏书")
    local state = client:edictPanelState(lord.id)
    lu.assertEquals(state.maxCards, 2)
    lu.assertFalse(state.showTake)
    lu.assertFalse(state.canPlace)
    for _, id in ipairs({ hand[1], hand[2], hand[3], equip.id }) do
      play:update("CardItem", id, "click", { selected = true })
    end
    lu.assertEquals(play.pendings, { hand[1], hand[2] }, "只可选择至多两张手牌")
    lu.assertTrue(client:edictPanelState(lord.id).canPlace)
    lu.assertFalse(play.scene:getAllItems("Button").OK.enabled)
    play:update("QiaoEdict", lord.id, "cancel", {})
    lu.assertNil(play.skill_name)
    lu.assertNil(notices.ReplyToServer, "取消只结束此次诏书选择")
    lu.assertTrue(client:edictPanelState(lord.id).canOpen)
  end)
  inRoom(function()
    for i = 1, 8 do
      room:setPlayerProperty(p(i), "kingdom", "han")
      room:setPlayerMark(p(i), "__heg_kingdom", "han")
    end
  end)
  lu.assertFalse(H.isSmallKingdomPlayer(ally))
  local reply = withEdictRequest(room, ally, function(client, play, notices)
    play:update("QiaoEdict", lord.id, "open", {})
    lu.assertEquals(notices.QiaoOpenEdict, { lord.id })
    lu.assertEquals(client:edictPanelState(lord.id).maxCards, 1)
    play:update("QiaoEdict", lord.id, "place", {})
    lu.assertNil(notices.ReplyToServer, "选牌前不能提交")
    play:update("CardItem", hand[1], "click", { selected = true })
    lu.assertFalse(play:cardValidity(hand[2]), "非小势力不能选择第二张")
    lu.assertTrue(play:update("QiaoEdict", lord.id, "place", {}))
    lu.assertEquals(notices.ReplyToServer.card, { skill = P.BANNER, subcards = { hand[1] } })
  end)
  inRoom(function() room:handleUseCardReply(ally, reply) end)
  lu.assertEquals(lord:getPile(P.PILE), { hand[1] })
  lu.assertEquals(ally:usedSkillTimes(P.BANNER, Player.HistoryPhase), 1)

  withEdictRequest(room, ally, function(client, play, notices)
    -- 再次点击技能仍可查看诏书，放置限制反映在读条提示和选牌上。
    lu.assertTrue(play.scene:getAllItems("SkillButton")[P.BANNER].enabled)
    UpdateRequestUI("SkillButton", P.BANNER, "click", { selected = true })
    lu.assertEquals(notices.QiaoOpenEdict, { lord.id })
    lu.assertEquals(Fk:translate(notices.UpdateRequestUI._prompt), "此阶段已放置过诏书牌")
    lu.assertFalse(client:edictPanelState(lord.id).canPlace)
    lu.assertFalse(play:cardValidity(hand[2]))
    UpdateRequestUI("QiaoEdict", lord.id, "place", {})
    lu.assertNil(notices.ReplyToServer)
    UpdateRequestUI("QiaoEdict", lord.id, "cancel", {})
    lu.assertEquals(notices.UpdateRequestUI._prompt, "#PlayCard")
  end)
end

function Testqiao_em_han001_liuxie:testTwoEdictHoldersViewTheClickedPileWithoutAnAction()
  local room, a, b = FkTest.room, p(1), p(2)
  local cardA, cardB
  inRoom(function()
    -- 构造同势力双持有者，常规的授予路径仍受诏书唯一限制。
    room:setPlayerMark(b, P.MARK, 1)
    P.sync(room)
    cardA = room:printCard("qiao__jink", Card.Heart, 6).id
    cardB = room:printCard("qiao__slash", Card.Spade, 7).id
    a:addToPile(P.PILE, cardA, true, BANNER)
    b:addToPile(P.PILE, cardB, true, BANNER)
    a.phase = Player.Play
  end)
  withEdictRequest(room, a, function(client, play, notices)
    lu.assertTrue(client:edictPanelState(a.id).canOpen)
    local label = table.find(client:skillStates(b.id), function(state) return state.action == "edict" end)
    lu.assertEquals(label.cards, { cardB })
    lu.assertEquals(client:edictCardsForDisplay(b.id), { cardB })
    lu.assertEquals(client:edictCountForDisplay(b.id), 1)
    lu.assertEquals(client:edictCardsForDisplay(a.id), { cardA })
    lu.assertEquals(client:edictPanelState(b.id), {})
    play:update("QiaoEdict", b.id, "open", {})
    lu.assertNil(notices.QiaoOpenEdict)
    lu.assertNil(play.skill_name)
    lu.assertNil(notices.ReplyToServer)
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
  verifyClientEdictConsumption(room, user)
end

function Testqiao_em_han001_liuxie:testImperialOrderTurnEndStartsAtCurrentSeat()
  local room, current = FkTest.room, p(3)
  local asked = {}
  skill_test.withSkillRequests(room, "qiao__imperial_order_skill", {
    askToChoice = function(_, player)
      table.insert(asked, player.seat)
      return "loseHp"
    end,
  }, function()
    inRoom(function()
      room:setPlayerProperty(p(1), "kingdom", "unknown")
      room:setPlayerProperty(p(7), "kingdom", "unknown")
      imperialToDiscard(room)
      room:setCurrent(current)
      room.logic:trigger(fk.TurnEnd, current, {})
    end)
  end)
  lu.assertEquals(asked, { 7, 1 })
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
  lu.assertNil(P.availableHolder(room, ally), "入口可用性另行过滤")
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

local function checkForwardRedirect(cardName)
  local room, lord, attacker = FkTest.room, p(1), p(4)
  inRoom(function()
    local payment = room:printCard(cardName, Card.Spade, 3)
    room:moveCardTo(payment, Card.PlayerEquip, lord, fk.ReasonJustMove)
    local hp = lord.hp
    local slash = room:printCard("qiao__slash", Card.Spade, 8)
    room:obtainCard(attacker, slash, false, fk.ReasonJustMove)
    local use = { from = attacker, card = slash, tos = { lord } }
    skill_test.withSkillRequests(room, P.ZHUANPENG, {
      askToCards = function() return { payment.id } end,
    }, function() room:useCard(use) end)
    lu.assertTrue(table.contains(use.nullifiedTargets or {}, lord))
    lu.assertTrue(table.contains(lord:getPile(P.PILE), payment.id))
    lu.assertFalse(table.contains(attacker:getCardIds("h"), payment.id))
    lu.assertEquals(lord.hp, hp)
  end)
end

function Testqiao_em_han001_liuxie:testZhuanpengForwardSwordInEdictNullifiesSlash()
  checkForwardRedirect("qiao__chixiao_sword")
end

function Testqiao_em_han001_liuxie:testZhuanpengForwardSealInEdictNullifiesSlash()
  checkForwardRedirect("qiao__jade_seal")
end

function Testqiao_em_han001_liuxie:testDeputyRevealCannotReissueOccupiedEdict()
  local room, lord, holder = FkTest.room, p(1), p(2)
  inRoom(function()
    room:changeHero(lord, NORMAL, true, false, false, false, false)
    room:setPlayerMark(lord, "__heg_general", NORMAL)
    room:setPlayerMark(lord, P.MARK, 0)
    lu.assertTrue(P.grant(room, holder))
    lord:hideGeneral(true)
    A.ascend(room, lord, LORD, "han", {kind = "lord"})
    lu.assertIs(P.holder(room), holder)
    room:killPlayer {who = holder}
    lord:revealGeneral(true)
    lu.assertNil(P.holder(room))
    room:invalidateSkill(lord, P.JIANPING)
    room.logic:trigger(fk.GeneralRevealed, lord, {m = LORD})
    lu.assertNil(P.holder(room))
  end)
end

function Testqiao_em_han001_liuxie:testEdictUsesPublicKingdom()
  local room, lord, one, two = FkTest.room, p(1), p(2), p(3)
  inRoom(function()
    room:setPlayerMark(lord, P.MARK, 0)
    room:changeKingdom(one, "wild")
    room:changeKingdom(two, "wild")
    for _, role in ipairs({"wild", H.wildKingdoms[1]}) do
      room:setPlayerProperty(one, "role", role)
      room:setPlayerProperty(two, "role", role == "wild" and role or H.wildKingdoms[2])
      lu.assertFalse(P.isSameKingdom(one, two))
      lu.assertTrue(P.isSameKingdom(one, one))
    end
    room:setPlayerProperty(two, "role", H.wildKingdoms[1])
    lu.assertTrue(P.isSameKingdom(one, two))
    room:changeKingdom(one, "unknown")
    room:setPlayerMark(one, "__heg_kingdom", lord.kingdom)
    lu.assertFalse(P.isSameKingdom(one, lord))
    lu.assertTrue(P.isSameKingdom(one, one))
  end)
end

function Testqiao_em_han001_liuxie:testTianshouIgnoresPrivatePile()
  local room, other = FkTest.room, p(2)
  inRoom(function()
    local seal = room:printCard("qiao__jade_seal", Card.Club, 2)
    other:addToPile("test_soldiers", {seal.id}, true)
    room:moveCardTo(seal, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile)
    lu.assertEquals(room:getCardArea(seal.id), Card.DiscardPile)
  end)
end

return { name = "qiao_em_han001_liuxie" }
