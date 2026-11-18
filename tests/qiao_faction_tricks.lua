-- 势力锦囊共用流程 + 固国安邦／党锢之祸／文和乱武正式使用链。
--
-- 覆盖验收：
--   1. 七张特殊实体仍在默认牌堆外；进入弃牌堆的实际移动按牌本身身份改到
--      游戏外，不误动同批其他牌，且保留原移动原因与技能名。
--   2. 用牌时记录“使用者是否已确定为该牌所属势力”，本次用牌只读该快照。
--   3. 固国安邦：摸八弃六后经 expand_pile 入口把仍在弃牌堆的牌分给其他吴势力，
--      每名至多两张、可取消；非吴使用者只摸弃。
--   4. 党锢之祸：逐目标暗置一张可暗置的明置武将牌并建立按来源到期的禁明置；
--      汉目标实际交牌后仅其自身无效；无牌可暗置时仍保留禁明置。
--   5. 文和乱武：展示手牌并让使用者选可执行项；群条款按用牌时快照与该目标
--      当前势力检查，手牌为零补至当前体力。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local FactionTricks = require "packages.qiao.pkg.qiao_mode.rules.faction_tricks"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"
local FreeUse = require "packages.qiao.pkg.qiao_mode.rules.free_use"
local ReqActive = require "ltk.core.request_type.active_skill"

local STRENGTHEN = "qiao__strengthen_state"
local SKILL = "qiao__strengthen_state_skill"
local DANGGU = "qiao__danggu_zhihuo"
local LUANWU = "qiao__luanwu_chaos"
local COMMAND_WORLD = "qiao__command_world"
local JINK = "qiao__jink"

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

--- 游戏外区中的正式势力锦囊实体；按牌本身身份查找。
local function voidTrick(room, name)
  return table.find(room.void, function(id)
    local card = Fk:getCardById(id, true)
    return card ~= nil and card.name == name
  end)
end

--- 把一张游戏外实体牌交给角色手牌。
local function giveFromVoid(room, id, player)
  lu.assertNotNil(id, "缺少所需实体牌")
  room:moveCardTo(id, Card.PlayerHand, player, fk.ReasonJustMove,
    "qiao_test", nil, true, player)
end

--- 夹具：先弃掉所有手牌/装备中的无懈，避免无懈询问打乱回复队列。
local function clearNullifications(room)
  local nullify = {
    ["qiao__nullification"] = true,
    ["qiao__guozhan__nullification"] = true,
    ["qiao_test__nullification"] = true,
  }
  for _, player in ipairs(room.players) do
    local ids = {}
    for _, id in ipairs(player:getCardIds("he")) do
      local card = Fk:getCardById(id, true)
      if card ~= nil and nullify[card.name] then table.insert(ids, id) end
    end
    if #ids > 0 then room:throwCard(ids, "qiao_test_clear", player, player) end
  end
end

--- 预置确定的牌堆顶普通牌：夹具需要固定会摸到的牌，避免随机牌堆波动。
local function presetDrawTop(room, count)
  local suits = { Card.Spade, Card.Heart, Card.Club, Card.Diamond }
  local ids = {}
  for i = 1, count do
    local card = room:printCard(JINK, suits[(i - 1) % 4 + 1], i)
    table.removeOne(room.void, card.id)
    room:setCardArea(card.id, Card.DrawPile, nil)
    table.insert(room.draw_pile, 1, card.id)
    table.insert(ids, card.id)
  end
  return ids
end

--- 建立与当前房间对应的真实客户端角色/房间，用于请求处理夹具。
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

Testqiao_faction_tricks = {
  setup = function()
    Fk.currentResponsePattern = nil
    support.initQiaoRoom()
    local room = FkTest.room
    inRoom(function()
      -- 1/2/4 为吴，3 为魏；其余用于凑满房间。
      skill_test.installBlankGenerals(room, { "wu", "wu", "wei", "wu", "shu", "qun", "han", "jin" })
      room.current = room.players[1]
      clearNullifications(room)
    end, "setup")
  end,
  tearDown = function() support.clearRoom() end,
}

function Testqiao_faction_tricks:testSevenTricksKeepIdentityAndStayOutsideTheDeck()
  local room = FkTest.room
  local expected = {
    { DANGGU, "han" },
    { COMMAND_WORLD, "wei" },
    { "qiao__restore_heartland", "shu" },
    { STRENGTHEN, "wu" },
    { LUANWU, "qun" },
    { "qiao__sihai_guiping", "jin" },
    { "qiao__luoshui_zhishi", "wild" },
  }
  local inPile = {}
  for _, id in ipairs(room.draw_pile) do inPile[id] = true end
  for _, player in ipairs(room.players) do
    for _, id in ipairs(player:getCardIds("he")) do inPile[id] = true end
  end
  for _, spec in ipairs(expected) do
    local name, kingdom = spec[1], spec[2]
    lu.assertEquals(Cards.tricks[name], kingdom, "独立牌表登记的所属势力不符: " .. name)
    local id = voidTrick(room, name)
    lu.assertNotNil(id, "缺少游戏外实体: " .. name)
    local card = Fk:getCardById(id, true)
    lu.assertEquals(FactionTricks.kingdomOf(card), kingdom, "牌本身身份不符: " .. name)
    lu.assertTrue(FactionTricks.isFactionTrick(card), "应识别为势力锦囊: " .. name)
    lu.assertNil(inPile[id], "势力锦囊不得进入默认牌堆: " .. name)
    lu.assertEquals(room:getCardArea(id), Card.Void, "势力锦囊默认在游戏外: " .. name)
  end
end

function Testqiao_faction_tricks:testImplementedTricksLoadAsFormalUsableCards()
  local room = FkTest.room
  local H = assert(Fk.packages.qiao_cards.qiao_cards)
  local expected = {
    { STRENGTHEN, "qiao__strengthen_state_skill", "摸八张" },
    { DANGGU, "qiao__danggu_zhihuo_skill", "不能明置" },
    { LUANWU, "qiao__luanwu_chaos_skill", "类别不同" },
  }
  for _, spec in ipairs(expected) do
    local name, skillName, keyword = spec[1], spec[2], spec[3]
    lu.assertEquals(H.reuse[name].status, "reused", "复用决定未更新: " .. name)
    local id = voidTrick(room, name)
    local card = Fk:getCardById(id, true)
    lu.assertFalse(H.isInert(card), "已实装牌不得标记为空壳: " .. name)
    lu.assertEquals(Fk.all_card_types[name].skill.name, skillName,
      "正式牌型应挂接已实现技能: " .. name)
    local text = Fk:translate(":" .. name)
    lu.assertTrue(text:find(keyword, 1, true) ~= nil, "牌面描述缺少关键效果: " .. name)
    lu.assertNil(text:find("尚未实装", 1, true), "已实装牌不应显示空壳描述: " .. name)
  end
  -- 多目标牌需要正式 multi_targets 元数据，客户端才能一次选齐所有合法目标。
  lu.assertTrue(Fk.all_card_types[DANGGU].multiple_targets == true)
  lu.assertTrue(Fk.all_card_types[LUANWU].multiple_targets == true)
  lu.assertFalse(Fk.all_card_types[STRENGTHEN].multiple_targets == true,
    "固国安邦只对自己使用，不是多目标牌")
  -- printCard 生成的副本不继承 extra_data，仍须按牌型识别为势力锦囊。
  local printed
  inRoom(function() printed = room:printCard(STRENGTHEN, Card.Heart, 1) end)
  lu.assertTrue(FactionTricks.isFactionTrick(printed), "打印副本仍应按牌本身身份识别")
  lu.assertEquals(FactionTricks.kingdomOf(printed), "wu")
end

function Testqiao_faction_tricks:testDiscardPileMoveGoesOutOfGameWithoutTouchingTheBatch()
  local room, user = FkTest.room, p(1)
  local trick, normal = voidTrick(room, COMMAND_WORLD), nil
  local observed = {}
  inRoom(function()
    giveFromVoid(room, trick, user)
    normal = room:printCard(JINK, Card.Heart, 4)
    room:obtainCard(user, normal, false, fk.ReasonJustMove)

    local handled, records = {}, {}
    local probe = fk.CreateSkill { name = "#qiao_test_faction_trick_move_probe" }
    probe:addEffect(fk.AfterCardsMove, {
      global = true,
      can_refresh = function(self, event, target, player, data)
        return handled[event.id] ~= true
      end,
      on_refresh = function(self, event, target, player, data)
        handled[event.id] = true
        for _, move in ipairs(data or {}) do
          for _, info in ipairs(move.moveInfo or {}) do
            if info.cardId == trick then
              table.insert(records, {
                toArea = move.toArea,
                reason = move.moveReason,
                skill = move.skillName,
              })
            end
          end
        end
      end,
    })
    room:addSkill(probe:createSkill())
    -- 同一批一次弃置两张：势力锦囊改移出游戏，普通牌照常进入弃牌堆。
    room:throwCard({ trick, normal.id }, "qiao_test_probe", user, user)
    observed = records
  end)
  lu.assertEquals(room:getCardArea(trick), Card.Void, "势力锦囊应改为移出游戏")
  lu.assertTrue(table.contains(room.void, trick), "移出游戏后应位于游戏外区")
  lu.assertFalse(table.contains(room.discard_pile, trick), "不得进入弃牌堆")
  lu.assertEquals(room:getCardArea(normal.id), Card.DiscardPile, "同批普通牌照常进弃牌堆")
  lu.assertTrue(table.contains(room.discard_pile, normal.id))
  lu.assertEquals(#observed, 1, "势力锦囊应只发生一次重定向后的移动")
  lu.assertEquals(observed[1].toArea, Card.Void)
  lu.assertEquals(observed[1].reason, fk.ReasonDiscard, "应保留原移动原因")
  lu.assertEquals(observed[1].skill, "qiao_test_probe", "应保留原移动技能名")
end

function Testqiao_faction_tricks:testWuUserDistributesActuallyDiscardedCards()
  local room, user, ally, ally2 = FkTest.room, p(1), p(2), p(4)
  local card, before, allyBefore, ally2Before, discardIds
  local rounds, firstParams = 0, nil
  inRoom(function()
    card = voidTrick(room, STRENGTHEN)
    giveFromVoid(room, card, user)
    before = #user:getCardIds(Player.Hand) - 1 -- 交入的这张牌随后会被用掉
    allyBefore = #ally:getCardIds(Player.Hand)
    ally2Before = #ally2:getCardIds(Player.Hand)
    discardIds = table.slice(presetDrawTop(room, 8), 1, 7)
  end)
  skill_test.withSkillRequests(room, SKILL, {
    askToChooseCardsAndPlayers = function(self, who, params, original)
      rounds = rounds + 1
      if firstParams == nil then
        firstParams = {
          max_card_num = params.max_card_num,
          min_card_num = params.min_card_num,
          targets = table.map(params.targets, function(target) return target.id end),
          expand_pile = table.simpleClone(params.expand_pile or {}),
          cancelable = params.cancelable,
        }
      end
      return original(self, who, params)
    end,
  }, function()
    FkTest.setNextReplies(user, {
      FkTest.ReplyDiscard(discardIds),
      -- 第一轮：给 2 号两张；第二轮：给 4 号一张；随后取消结束分配。
      FkTest.ReplyUseSkill("ex__choose_skill", { ally }, { discardIds[1], discardIds[2] }),
      FkTest.ReplyUseSkill("ex__choose_skill", { ally2 }, { discardIds[3] }),
      "",
    })
    inRoom(function()
      room:useCard { from = user, card = Fk:getCardById(card, true), tos = { user } }
    end)
  end)
  lu.assertEquals(rounds, 3, "应进入三轮分配询问（含取消）")
  lu.assertNotNil(firstParams, "第一轮应经 expand_pile 入口")
  lu.assertEquals(firstParams.max_card_num, 2, "每名角色至多两张")
  lu.assertEquals(firstParams.cancelable, true, "分配应可取消")
  lu.assertEquals(#firstParams.expand_pile, 6, "expand_pile 应给出本次实际弃置的牌")
  lu.assertEquals(#firstParams.targets, 2, "只能分给其他吴势力角色")
  lu.assertFalse(table.contains(firstParams.targets, user.id), "不得把牌分给自己")
  lu.assertEquals(#user:getCardIds(Player.Hand), before + 8 - 6, "应摸八张后弃六张")
  lu.assertEquals(#ally:getCardIds(Player.Hand), allyBefore + 2, "其他吴势力角色应实际得到两张")
  lu.assertEquals(#ally2:getCardIds(Player.Hand), ally2Before + 1)
  lu.assertTrue(table.contains(ally:getCardIds(Player.Hand), discardIds[1]))
  lu.assertTrue(table.contains(ally2:getCardIds(Player.Hand), discardIds[3]))
  lu.assertEquals(room:getCardArea(card), Card.Void, "用后仍应移出游戏而非进入弃牌堆")
  lu.assertFalse(table.contains(room.discard_pile, card))
end

function Testqiao_faction_tricks:testDistributionEntrySelectsDiscardedCardsInRealClient()
  local room, user, ally = FkTest.room, p(1), p(2)
  local discardIds
  inRoom(function()
    clearNullifications(room)
    discardIds = {}
    for i = 1, 3 do
      local card = room:printCard(JINK, Card.Heart, i)
      room:obtainCard(user, card, false, fk.ReasonJustMove)
      table.insert(discardIds, card.id)
    end
    room:throwCard(discardIds, "qiao_test", user, user)
    for _, id in ipairs(discardIds) do
      lu.assertEquals(room:getCardArea(id), Card.DiscardPile, "夹具应先把牌放进弃牌堆")
    end
    discardIds = table.filter(discardIds, function(id)
      return room:getCardArea(id) == Card.DiscardPile
    end)
  end)
  local extra = {
    cards = discardIds,
    targets = { Util.IdMapper(ally) },
    max_c_num = 2,
    min_c_num = 1,
    max_t_num = 1,
    min_t_num = 1,
    pattern = ".",
    skillName = SKILL,
    expand_pile = discardIds,
    no_indicate = true,
  }
  local choose = assert(Fk.skills["ex__choose_skill"])
  choose._extra_data = extra
  local ok, err = pcall(function()
    withClientRoom(room, function(clients)
      local me = clients[1]
      lu.assertNil(me.room, "真实 ClientPlayer 不应有 room 字段")
      local handler = ReqActive:new(me, { "ex__choose_skill", "#qiao__test-distribute", true, extra })
      handler:setup()
      lu.assertTrue(handler:cardValidity(discardIds[1]),
        "弃牌堆中的牌经 expand_pile 应可在客户端选中")
      lu.assertFalse(handler:cardValidity(room.draw_pile[1]), "非本次候选不得选中")
      lu.assertTrue(handler:targetValidity(ally.id), "其他吴势力角色应可选为目标")
      lu.assertFalse(handler:targetValidity(p(3).id), "非吴势力不得选为接收者")
      handler:selectCard(discardIds[1], { selected = true })
      handler:selectTarget(ally.id, { selected = true })
      lu.assertTrue(handler:feasible(), "一牌一人应可确认")
    end)
  end)
  choose._extra_data = {}
  lu.assertTrue(ok, tostring(err))
end

function Testqiao_faction_tricks:testNonWuUserDrawsAndDiscardsWithoutDistribution()
  local room, user, ally = FkTest.room, p(3), p(2)
  local card, before, allyBefore, discardIds
  local asks = 0
  inRoom(function()
    card = voidTrick(room, STRENGTHEN)
    giveFromVoid(room, card, user)
    before = #user:getCardIds(Player.Hand) - 1
    allyBefore = #ally:getCardIds(Player.Hand)
    discardIds = table.slice(presetDrawTop(room, 8), 1, 7)
  end)
  skill_test.withSkillRequests(room, SKILL, {
    askToChooseCardsAndPlayers = function(self, who, params, original)
      asks = asks + 1
      return original(self, who, params)
    end,
  }, function()
    FkTest.setNextReplies(user, { FkTest.ReplyDiscard(discardIds) })
    inRoom(function()
      room:useCard { from = user, card = Fk:getCardById(card, true), tos = { user } }
    end)
  end)
  lu.assertEquals(asks, 0, "非吴势力使用者不得进入分配询问")
  lu.assertEquals(#user:getCardIds(Player.Hand), before + 8 - 6, "其他势力仍摸八弃六")
  lu.assertEquals(#ally:getCardIds(Player.Hand), allyBefore, "不得分配出去")
end

function Testqiao_faction_tricks:testFactionGateUsesTheUseTimeSnapshot()
  local room, user, ally = FkTest.room, p(1), p(2)
  local card, before, allyBefore, discardIds
  local asks = 0
  inRoom(function()
    -- 用牌时势力尚未确定：即使结算中途变为吴，本次用牌也不能分配。
    room:setPlayerProperty(user, "kingdom", "unknown")
    room:setPlayerMark(user, "__heg_kingdom", "unknown")
    card = voidTrick(room, STRENGTHEN)
    giveFromVoid(room, card, user)
    before = #user:getCardIds(Player.Hand) - 1
    allyBefore = #ally:getCardIds(Player.Hand)
    discardIds = table.slice(presetDrawTop(room, 8), 1, 7)
  end)
  skill_test.withSkillRequests(room, SKILL, {
    askToDiscard = function(self, who, params, original)
      local discarded = original(self, who, params)
      room:setPlayerProperty(user, "kingdom", "wu")
      room:setPlayerMark(user, "__heg_kingdom", "wu")
      return discarded
    end,
    askToChooseCardsAndPlayers = function(self, who, params, original)
      asks = asks + 1
      return original(self, who, params)
    end,
  }, function()
    FkTest.setNextReplies(user, { FkTest.ReplyDiscard(discardIds) })
    inRoom(function()
      room:useCard { from = user, card = Fk:getCardById(card, true), tos = { user } }
    end)
  end)
  lu.assertEquals(asks, 0, "势力效果只按用牌时的快照判定，不因结算中势力变化而生效")
  lu.assertEquals(#user:getCardIds(Player.Hand), before + 8 - 6)
  lu.assertEquals(#ally:getCardIds(Player.Hand), allyBefore, "快照不成立时不得分配")
end

function Testqiao_faction_tricks:testDangguHidesAndRestrictsEveryOtherTarget()
  local room, user, first, second = FkTest.room, p(1), p(2), p(3)
  local card, firstGeneral, secondGeneral
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "han")
    room:setPlayerMark(user, "__heg_kingdom", "han")
    card = voidTrick(room, DANGGU)
    giveFromVoid(room, card, user)
    firstGeneral, secondGeneral = first.general, second.general
    lu.assertNotEquals(firstGeneral, "anjiang")
    lu.assertNotEquals(secondGeneral, "anjiang")
  end)
  FkTest.setNextReplies(user, {
    { cards = { firstGeneral }, choice = "OK" },
    { cards = { secondGeneral }, choice = "OK" },
  })
  inRoom(function()
    room:useCard { from = user, card = Fk:getCardById(card, true), tos = { first, second } }
  end)
  for _, target in ipairs({ first, second }) do
    lu.assertEquals(target.general, "anjiang", "应暗置一张明置武将牌")
    lu.assertNotEquals(target.deputyGeneral, "anjiang")
    lu.assertTrue(target:prohibitReveal(), "主将不能明置")
    lu.assertTrue(target:prohibitReveal(true), "副将不能明置")
  end
  lu.assertEquals(room:getCardArea(card), Card.Void, "势力锦囊用后仍移出游戏")
end

function Testqiao_faction_tricks:testDangguHanTargetGivesCardAndIsOnlyNullifiedForItself()
  local room, user, hanTarget, other = FkTest.room, p(1), p(2), p(3)
  local card, hanGeneral, otherGeneral, gift
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "han")
    room:setPlayerMark(user, "__heg_kingdom", "han")
    room:setPlayerProperty(hanTarget, "kingdom", "han")
    room:setPlayerMark(hanTarget, "__heg_kingdom", "han")
    card = voidTrick(room, DANGGU)
    giveFromVoid(room, card, user)
    gift = room:printCard(JINK, Card.Heart, 5)
    room:obtainCard(hanTarget, gift, false, fk.ReasonJustMove)
    hanGeneral, otherGeneral = hanTarget.general, other.general
  end)
  FkTest.setNextReplies(hanTarget, { "1", gift.id })
  FkTest.setNextReplies(user, { { cards = { otherGeneral }, choice = "OK" } })
  inRoom(function()
    room:useCard { from = user, card = Fk:getCardById(card, true), tos = { hanTarget, other } }
  end)
  lu.assertTrue(table.contains(user:getCardIds("he"), gift.id), "汉目标应交出一张自己的牌")
  lu.assertNotEquals(hanTarget.general, "anjiang", "已交牌的汉目标不再被暗置")
  lu.assertFalse(hanTarget:prohibitReveal(), "已交牌的汉目标不受禁明置")
  lu.assertEquals(other.general, "anjiang", "其他目标照常暗置")
  lu.assertTrue(other:prohibitReveal(), "其他目标照常受禁明置")
end

function Testqiao_faction_tricks:testDangguRestrictionAppliesWithoutHideableGeneralAndExpires()
  local room, user, target = FkTest.room, p(1), p(2)
  local card
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "han")
    room:setPlayerMark(user, "__heg_kingdom", "han")
    card = voidTrick(room, DANGGU)
    giveFromVoid(room, card, user)
    target:hideGeneral(false)
    target:hideGeneral(true)
    lu.assertEquals(target.general, "anjiang")
    lu.assertEquals(target.deputyGeneral, "anjiang")
  end)
  -- 无可暗置将牌：不产生暗置询问，但仍建立禁明置限制。
  inRoom(function()
    room:useCard { from = user, card = Fk:getCardById(card, true), tos = { target } }
  end)
  lu.assertEquals(target.general, "anjiang", "无可暗置时不得改变将牌")
  lu.assertTrue(target:prohibitReveal(), "即使没有可暗置将牌仍受禁明置")
  lu.assertTrue(target:prohibitReveal(true))
  inRoom(function()
    room:setCurrent(user)
    room.logic:trigger(fk.TurnStart, user, {})
  end)
  lu.assertFalse(target:prohibitReveal(), "用牌者下回合开始应撤销其来源")
end

function Testqiao_faction_tricks:testLuanwuShowsCardsAndGroupDrawsEmptyHandToHp()
  local room, user, groupTarget, other = FkTest.room, p(1), p(2), p(3)
  local card, shown, firstDiscard
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "qun")
    room:setPlayerMark(user, "__heg_kingdom", "qun")
    room:setPlayerProperty(groupTarget, "kingdom", "qun")
    room:setPlayerMark(groupTarget, "__heg_kingdom", "qun")
    groupTarget.hp = 3
    card = voidTrick(room, LUANWU)
    giveFromVoid(room, card, user)
    -- 清空两个目标的初始手牌，令“弃光后为零”可观察。
    for _, target in ipairs({ groupTarget, other }) do
      local hand = target:getCardIds("he")
      if #hand > 0 then room:throwCard(hand, "qiao_test_clear", target, target) end
    end
    -- 群目标：一张基本牌 + 一张锦囊牌，类别不同，可执行第一项。
    local basic = room:printCard("qiao__slash", Card.Spade, 7)
    local trick = room:printCard("qiao__dismantlement", Card.Heart, 6)
    room:obtainCard(groupTarget, basic, false, fk.ReasonJustMove)
    room:obtainCard(groupTarget, trick, false, fk.ReasonJustMove)
    firstDiscard = { basic.id, trick.id }
    -- 另一目标只有一张手牌，由使用者选第二项弃置。
    shown = room:printCard("qiao__peach", Card.Diamond, 3)
    room:obtainCard(other, shown, false, fk.ReasonJustMove)
  end)
  FkTest.setNextReplies(user, { { "luanwu_target_discard" }, { "luanwu_user_discard" }, shown.id })
  -- askToChooseCards 走 AskForPoxi，测试用技能限定覆盖返回本次要弃的两张手牌。
  skill_test.withSkillRequests(room, "qiao__luanwu_chaos_skill", {
    askToChooseCards = function(self, who, params, original)
      lu.assertEquals(who.id, groupTarget.id, "第一项应由该目标自己选牌")
      lu.assertEquals(params.min, 2)
      lu.assertEquals(params.max, 2)
      return table.slice(firstDiscard, 1, 3)
    end,
  }, function()
    inRoom(function()
      room:useCard { from = user, card = Fk:getCardById(card, true), tos = { groupTarget, other } }
    end)
  end)
  for _, id in ipairs(firstDiscard) do
    lu.assertEquals(room:getCardArea(id), Card.DiscardPile, "第一项应由目标弃置两张不同类别手牌")
  end
  lu.assertEquals(#groupTarget:getCardIds(Player.Hand), 3,
    "群目标结算后手牌为零应补至当前体力值")
  lu.assertFalse(table.contains(other:getCardIds(Player.Hand), shown.id),
    "第二项应由使用者弃置其展示的一张手牌")
  lu.assertEquals(room:getCardArea(shown.id), Card.DiscardPile)
  lu.assertEquals(room:getCardArea(card), Card.Void, "势力锦囊用后仍移出游戏")
end

function Testqiao_faction_tricks:testCommandWorldTargetRuleAndParticipantChains()
  local room, user, target = FkTest.room, p(1), p(2)
  local nonWei, wei = p(3), p(4)
  local card, ownCard, targetCard, beforeWei, beforeHp
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "wei")
    room:setPlayerMark(user, "__heg_kingdom", "wei")
    room:setPlayerProperty(nonWei, "kingdom", "wu")
    room:setPlayerMark(nonWei, "__heg_kingdom", "wu")
    room:setPlayerProperty(wei, "kingdom", "wei")
    room:setPlayerMark(wei, "__heg_kingdom", "wei")
    card = voidTrick(room, COMMAND_WORLD)
    giveFromVoid(room, card, user)
    -- 场上最低体力：两名并列最低的角色均不合法。
    p(5).hp = 1
    p(6).hp = 1
    target.hp = 3
    beforeHp = target.hp
    ownCard = room:printCard(JINK, Card.Heart, 8)
    room:obtainCard(nonWei, ownCard, false, fk.ReasonJustMove)
    targetCard = room:printCard("qiao__peach", Card.Diamond, 9)
    room:obtainCard(target, targetCard, false, fk.ReasonJustMove)
    beforeWei = #wei:getCardIds("he")
  end)
  -- 合法目标判定：并列最低不合法，高于最低者合法。
  local candidates
  inRoom(function()
    candidates = Fk:getCardById(card, true):getAvailableTargets(user)
  end)
  lu.assertFalse(table.contains(candidates, p(5)), "并列最低的角色不合法")
  lu.assertFalse(table.contains(candidates, p(6)), "并列最低的角色不合法")
  lu.assertTrue(table.contains(candidates, target), "体力高于最低值的角色应合法")

  -- 3 号（非魏）弃手牌后对目标用杀；4 号（魏）免弃牌并取得目标被弃的牌。
  FkTest.setNextReplies(nonWei, {
    "1", { "command_world_own" }, FkTest.ReplyDiscard({ ownCard.id }),
  })
  FkTest.setNextReplies(wei, { "1", { "command_world_target" }, targetCard.id })
  inRoom(function()
    room:useCard { from = user, card = Fk:getCardById(card, true), tos = { target } }
  end)
  lu.assertEquals(target.hp, beforeHp - 1, "参与者视为使用的杀应实际造成伤害")
  lu.assertEquals(room:getCardArea(ownCard.id), Card.DiscardPile, "第一项应先弃置自己的手牌")
  lu.assertTrue(table.contains(wei:getCardIds(Player.Hand), targetCard.id),
    "魏势力参与者应取得第二项实际弃置的牌")
  lu.assertFalse(table.contains(target:getCardIds("he"), targetCard.id))
  lu.assertEquals(#wei:getCardIds("he"), beforeWei + 1)
  lu.assertEquals(room:getCardArea(card), Card.Void, "势力锦囊用后仍移出游戏")
end

function Testqiao_faction_tricks:testRestoreHeartlandChoicesAndShuBonus()
  local room, user, shuTarget, otherTarget = FkTest.room, p(1), p(2), p(3)
  local card, victim, beforeHp, otherHand
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "shu")
    room:setPlayerMark(user, "__heg_kingdom", "shu")
    room:setPlayerProperty(shuTarget, "kingdom", "shu")
    room:setPlayerMark(shuTarget, "__heg_kingdom", "shu")
    room:setPlayerProperty(otherTarget, "kingdom", "wei")
    room:setPlayerMark(otherTarget, "__heg_kingdom", "wei")
    card = voidTrick(room, "qiao__restore_heartland")
    giveFromVoid(room, card, user)
    -- 与蜀目标相邻的目标作为杀对象，避免占用来测试回复队列。
    victim = user
    victim.hp = victim.maxHp
    beforeHp = victim.hp
    otherHand = #otherTarget:getCardIds(Player.Hand)
  end)
  -- 蜀目标选视为用杀（伤害 +1），目标为相邻座次的非蜀目标；
  -- 非蜀目标随后选摸牌（不加强，摸一张）。
  FkTest.setNextReplies(shuTarget, {
    { "restore_heartland_slash" },
    FkTest.ReplyUseSkill("virtual_viewas", { victim }, {}),
  })
  FkTest.setNextReplies(otherTarget, { { "restore_heartland_draw" } })
  inRoom(function()
    room:useCard { from = user, card = Fk:getCardById(card, true), tos = { shuTarget, otherTarget } }
  end)
  lu.assertEquals(victim.hp, beforeHp - 2, "蜀目标的这次杀应伤害 +1")
  lu.assertEquals(#otherTarget:getCardIds(Player.Hand), otherHand + 1,
    "非蜀目标选摸牌只摸一张，不继承蜀修正")  lu.assertEquals(room:getCardArea(card), Card.Void, "势力锦囊用后仍移出游戏")
end

function Testqiao_faction_tricks:testSihaiGuipingRealPlayPhaseChain()
  local room, user, allyJin, victim = FkTest.room, p(1), p(2), p(3)
  local guiping, slash, jink, allySlash
  local beforeHp
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "jin")
    room:setPlayerMark(user, "__heg_kingdom", "jin")
    room:setPlayerProperty(allyJin, "kingdom", "jin")
    room:setPlayerMark(allyJin, "__heg_kingdom", "jin")
    room:setPlayerProperty(victim, "kingdom", "wei")
    room:setPlayerMark(victim, "__heg_kingdom", "wei")
    -- 只保留本例安排的牌，保证本阶段弃牌集合确定。
    for _, player in ipairs({ user, allyJin, victim }) do
      local hand = player:getCardIds("he")
      if #hand > 0 then room:throwCard(hand, "qiao_test_clear", player, player) end
    end
    guiping = voidTrick(room, "qiao__sihai_guiping")
    giveFromVoid(room, guiping, user)
    slash = room:printCard("qiao__slash", Card.Spade, 7)
    room:obtainCard(user, slash, false, fk.ReasonJustMove)
    jink = room:printCard("qiao__jink", Card.Spade, 8)
    room:obtainCard(victim, jink, false, fk.ReasonJustMove)
    allySlash = room:printCard("qiao__slash", Card.Heart, 9)
    room:obtainCard(allyJin, allySlash, false, fk.ReasonJustMove)
    room:setCurrent(user)
    user.hp = user.maxHp
    beforeHp = user.hp
    victim.hp = victim.maxHp
  end)

  local phaseData = PhaseData:new { who = user, phase = Player.Play }
  -- 阶段内先用【杀】（目标【闪】响应，两张同花色进弃牌堆），再用四海归平；
  -- 之后依次：选同花色一张 → 放弃分牌 → 用户放弃用牌 → 其他晋角色用一张杀。
  FkTest.setNextReplies(user, {
    FkTest.ReplyCard(slash, { victim }),
    FkTest.ReplyCard(Fk:getCardById(guiping, true)),
    FkTest.ReplyUseSkill("ex__choose_skill", {}, { jink.id }),
    "",
    "",
  })
  FkTest.setNextReplies(victim, { FkTest.ReplyCard(jink) })
  FkTest.setNextReplies(allyJin, {
    -- 普通可选用牌请求：回复一张实体牌的使用。
    FkTest.ReplyCard(allySlash, { user }),
  })
  inRoom(function()
    GameEvent.Phase:create(phaseData):exec()
  end)

  lu.assertTrue(phaseData.phase_end, "四海归平应结束本次出牌阶段的自由用牌入口")
  lu.assertTrue(table.contains(user:getCardIds(Player.Hand), jink.id),
    "应取得本阶段弃牌堆中该花色被选中的那张")
  lu.assertFalse(table.contains(user:getCardIds(Player.Hand), slash.id),
    "同花色只取一张，未被选中的留在弃牌堆")
  lu.assertEquals(#user:getCardIds(Player.Hand), 1,
    "只取本阶段置入且仍在弃牌堆的牌，不含更早弃牌及结算中的此牌")
  lu.assertEquals(room:getCardArea(slash.id), Card.DiscardPile)
  lu.assertFalse(table.contains(allyJin:getCardIds("he"), jink.id), "本例放弃分牌")
  lu.assertEquals(user.hp, beforeHp - 1,
    "即使一张也没分出，其他晋势力角色仍可使用一张真实牌")
  lu.assertEquals(room:getCardArea(guiping), Card.Void, "此牌正常离开处理区时移出游戏")
end

--- 把一张指定花色点数的牌放到牌堆顶，作为下一次判定牌。
local function putJudgeOnTop(room, suit, number)
  local id = table.find(room.draw_pile, function(candidate)
    local card = Fk:getCardById(candidate, true)
    return card ~= nil and card.suit == suit and card.number == number
  end)
  lu.assertNotNil(id, "牌堆中缺少所需判定牌")
  table.removeOne(room.draw_pile, id)
  table.insert(room.draw_pile, 1, id)
  return id
end

--- 记录真实伤害事件（来源、目标、点数与属性）。
local function damageProbe(room)
  local records, handled = {}, {}
  local probe = fk.CreateSkill { name = "#qiao_test_damage_probe" }
  probe:addEffect(fk.Damage, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return handled[event.id] ~= true
    end,
    on_refresh = function(self, event, target, player, data)
      handled[event.id] = true
      table.insert(records, {
        from = data.from and data.from.id,
        to = data.to and data.to.id,
        damage = data.damage,
        nature = data.damageType,
      })
    end,
  })
  room:addSkill(probe:createSkill())
  return records
end

function Testqiao_faction_tricks:testLuoshuiEntersJudgeAreaAndLateWildSpadeDamages()
  local room, user, target, victim = FkTest.room, p(1), p(2), p(4)
  local card
  inRoom(function()
    card = voidTrick(room, "qiao__luoshui_zhishi")
    giveFromVoid(room, card, user)
    -- 普通情况：用牌者与目标都还不是野心家，真实进入目标判定区。
    room:setPlayerProperty(target, "kingdom", "qun")
    room:setPlayerMark(target, "__heg_kingdom", "qun")
  end)
  local records
  inRoom(function() records = damageProbe(room) end)
  -- 牌面/模板/实体均为延时锦囊。
  lu.assertEquals(Fk.all_card_types["qiao__luoshui_zhishi"].sub_type,
    Card.SubtypeDelayedTrick, "牌型应为延时锦囊")
  lu.assertEquals(Fk:getCardById(card, true).sub_type, Card.SubtypeDelayedTrick,
    "实体牌应为延时锦囊")
  inRoom(function()
    room:useCard { from = user, card = Fk:getCardById(card, true), tos = { target } }
  end)
  lu.assertEquals(room:getCardArea(card), Card.PlayerJudge, "普通情况应进入目标判定区")
  lu.assertEquals(room:getCardOwner(card).id, target.id, "应属于目标")

  -- 进入判定区后才转为野心家：判定阶段仍按当时的野心家身份结算。
  inRoom(function()
    room:setPlayerProperty(target, "kingdom", "wild")
    room:setPlayerMark(target, "__heg_kingdom", "wild")
    putJudgeOnTop(room, Card.Spade, 3)
  end)
  local phaseData = PhaseData:new { who = target, phase = Player.Judge, reason = "game_rule" }
  FkTest.setNextReplies(target, { FkTest.ReplyChoosePlayer({ victim }) })
  inRoom(function()
    GameEvent.Phase:create(phaseData):exec()
  end)
  lu.assertEquals(victim.hp, victim.maxHp - 3, "黑桃 2～9 应造成 3 点雷电伤害")
  lu.assertEquals(#records, 1)
  lu.assertEquals(records[1].damage, 3)
  lu.assertEquals(records[1].nature, fk.ThunderDamage)
  lu.assertEquals(records[1].from, target.id, "伤害来源应为该牌的目标")
  lu.assertEquals(records[1].to, victim.id, "由目标选择受伤角色")
  lu.assertEquals(room:getCardArea(card), Card.Void, "结算后按势力锦囊移出游戏")
end

function Testqiao_faction_tricks:testLuoshuiWildSelfUseJudgesImmediately()
  local room, user, other = FkTest.room, p(1), p(4)
  local card
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "wild")
    room:setPlayerMark(user, "__heg_kingdom", "wild")
    card = voidTrick(room, "qiao__luoshui_zhishi")
    giveFromVoid(room, card, user)
    putJudgeOnTop(room, Card.Spade, 3)
  end)
  local records
  inRoom(function() records = damageProbe(room) end)
  FkTest.setNextReplies(user, { FkTest.ReplyChoosePlayer({ other }) })
  inRoom(function()
    room:useCard { from = user, card = Fk:getCardById(card, true), tos = { user } }
  end)
  lu.assertEquals(other.hp, other.maxHp - 3, "已确定为野心家且对自己应立刻判定并造成伤害")
  lu.assertEquals(#records, 1)
  lu.assertEquals(records[1].from, user.id)
  lu.assertEquals(records[1].damage, 3)
  lu.assertNotEquals(room:getCardArea(card), Card.PlayerJudge, "立即结算不再进入判定区")
  lu.assertEquals(room:getCardArea(card), Card.Void, "结算后按势力锦囊移出游戏")
end

function Testqiao_faction_tricks:testLuoshuiNonSpadeReplacesNextPhaseWithRealRejudge()
  local room, target, victim = FkTest.room, p(2), p(4)
  local card, turnData
  inRoom(function()
    room:setPlayerProperty(target, "kingdom", "wild")
    room:setPlayerMark(target, "__heg_kingdom", "wild")
    card = voidTrick(room, "qiao__luoshui_zhishi")
    room:moveCardTo(card, Card.PlayerJudge, target, fk.ReasonJustMove, "qiao_test", nil, true, target)
    -- 第一次判定非区间，把随后的弃牌阶段替换为判定阶段；第二次判定为黑桃 3。
    putJudgeOnTop(room, Card.Spade, 3)
    putJudgeOnTop(room, Card.Heart, 5)
    turnData = TurnData:new(target, "game_rule", { Player.Judge, Player.Discard })
  end)
  local records
  -- 普通 EventPhaseEnd 触发应能看到原牌尚未进入判定区（置回推迟到下一阶段准备点）。
  local seenAtPhaseEnd = {}
  local probe = fk.CreateSkill { name = "#qiao_test_luoshui_phase_end_probe" }
  local handled = {}
  probe:addEffect(fk.EventPhaseEnd, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return handled[event.id] ~= true
    end,
    on_refresh = function(self, event, target, player, data)
      handled[event.id] = true
      table.insert(seenAtPhaseEnd, FkTest.room and FkTest.room:getCardArea(card) or nil)
    end,
  })
  FkTest.setNextReplies(target, { FkTest.ReplyChoosePlayer({ victim }) })
  inRoom(function()
    records = damageProbe(room)
    room:addSkill(probe:createSkill())
    GameEvent.Turn:create(turnData):exec()
  end)
  lu.assertTrue(#seenAtPhaseEnd >= 1, "应观察到阶段结束时机")
  lu.assertNotEquals(seenAtPhaseEnd[1], Card.PlayerJudge,
    "阶段结束时机原牌应仍在处理区，而不是已置回判定区")
  lu.assertEquals(#turnData.phase_table, 2, "只替换一个后续阶段，不插入额外阶段")
  lu.assertEquals(turnData.phase_table[2].phase, Player.Judge, "后续阶段应被改为判定阶段")
  lu.assertEquals(victim.hp, victim.maxHp - 3, "重新判定为黑桃 2～9 时造成 3 点雷电伤害")
  lu.assertEquals(#records, 1, "同一张牌不重复结算伤害")
  lu.assertEquals(room:getCardArea(card), Card.Void, "结算后按势力锦囊移出游戏")
end

function Testqiao_faction_tricks:testLuoshuiSpadeWithoutWildDoesNotRewritePhase()
  local room, target = FkTest.room, p(2)
  local card, turnData
  inRoom(function()
    -- 目标不是野心家：命中黑桃 2～9 也不造成伤害，且不得改写后续阶段。
    room:setPlayerProperty(target, "kingdom", "qun")
    room:setPlayerMark(target, "__heg_kingdom", "qun")
    card = voidTrick(room, "qiao__luoshui_zhishi")
    room:moveCardTo(card, Card.PlayerJudge, target, fk.ReasonJustMove,
      "qiao_test", nil, true, target)
    putJudgeOnTop(room, Card.Spade, 3)
    turnData = TurnData:new(target, "game_rule", { Player.Judge, Player.Discard })
  end)
  local records
  inRoom(function()
    records = damageProbe(room)
    GameEvent.Turn:create(turnData):exec()
  end)
  lu.assertEquals(#records, 0, "命中区间但目标非野心家不得造成伤害")
  lu.assertEquals(turnData.phase_table[2].phase, Player.Discard,
    "命中区间不属于非区间分支，不应改写后续阶段")
  lu.assertEquals(room:getCardArea(card), Card.Void, "按共用处置移出游戏")
end

function Testqiao_faction_tricks:testLuoshuiPoolGateFollowsPublicWild()
  local room, lord, wildPlayer = FkTest.room, p(7), p(2)
  local Zed = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"
  local gated = "qiao__luoshui_zhishi"
  local others = { "qiao__danggu_zhihuo", "qiao__command_world",
    "qiao__restore_heartland", "qiao__strengthen_state", "qiao__luanwu_chaos",
    "qiao__sihai_guiping" }

  inRoom(function() Zed.syncTricks(room) end)
  lu.assertFalse(table.contains(Zed.trickNames(room), gated),
    "本局尚未出现野心家时洛水不得进入公开候选")
  inRoom(function()
    lu.assertFalse(Cards.trickAllowed(gated, {}, room), "池门槛应按本局状态判定")
    for _, name in ipairs(others) do
      lu.assertTrue(Cards.trickAllowed(name, {}, room), "其余六张不受池门槛影响: " .. name)
    end
  end)
  local trickId
  inRoom(function() trickId = voidTrick(room, gated) end)
  lu.assertNotNil(trickId, "洛水实体应在游戏外")
  inRoom(function()
    lu.assertNil(Zed.obtainTrick(room, lord, { name = gated }), "服务器按池门槛拒绝取得")
  end)

  -- 经由对局中的真实明置流程成为专属野心家（公开 player.kingdom 变为 wild）。
  local probe = fk.CreateSkill { name = "#qiao_test_wild_reveal_probe" }
  local revealed = false
  probe:addEffect(fk.TurnStart, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target ~= nil and target == wildPlayer and not revealed
    end,
    on_refresh = function(self, event, target, player, data)
      revealed = true
      wildPlayer:hideGeneral(false)
      room:setPlayerMark(wildPlayer, "__heg_general", "qiao_test__wild_1")
      room:setPlayerMark(wildPlayer, "__heg_deputy", "qiao_test__han_2")
      room:setPlayerMark(wildPlayer, "__heg_wild", 1)
      wildPlayer:revealGeneral(false)
    end,
  })
  inRoom(function()
    room:addSkill(probe:createSkill())
    GameEvent.Turn:create(TurnData:new(wildPlayer, "game_rule", { Player.Start })):exec()
  end)
  lu.assertTrue(revealed, "探针应在对局回合内完成明置")
  lu.assertEquals(wildPlayer.kingdom, "wild", "明置后公开势力应为野心家")
  lu.assertTrue(Cards.wildSeen(room), "公开出现野心家后应建立本局标记")
  lu.assertTrue(table.contains(Zed.trickNames(room), gated), "诏书候选应即时同步")
  local got
  inRoom(function() got = Zed.obtainTrick(room, lord, { name = gated }) end)
  lu.assertNotNil(got, "满足池门槛后应按实际实体取得")
  lu.assertEquals(room:getCardOwner(got).id, lord.id)
  lu.assertEquals(room:getCardArea(got), Card.PlayerHand)

  -- 死亡转势力/势力变化不重置本局曾出现的事实。
  inRoom(function() room:setPlayerProperty(wildPlayer, "kingdom", "qun") end)
  lu.assertTrue(Cards.wildSeen(room), "势力变化不重置本局标记")
  inRoom(function()
    lu.assertTrue(Cards.trickAllowed(gated, {}, room), "池门槛不因势力变化回收")
  end)
end

function Testqiao_faction_tricks:testStrengthenStateRealPlayCardDrawsAndDiscards()
  local room, user = FkTest.room, p(1)
  local card, before, discardIds
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "wu")
    room:setPlayerMark(user, "__heg_kingdom", "wu")
    local hand = user:getCardIds("he")
    if #hand > 0 then room:throwCard(hand, "qiao_test_clear", user, user) end
    card = voidTrick(room, STRENGTHEN)
    giveFromVoid(room, card, user)
    before = #user:getCardIds(Player.Hand) - 1 -- 此牌用后离开手牌
    discardIds = table.slice(presetDrawTop(room, 8), 1, 7)
    room:setCurrent(user)
    user.hp = user.maxHp
  end)
  local phaseData = PhaseData:new { who = user, phase = Player.Play }
  -- 真实 PlayCard 回复（固定目标为自己）：无目标参数也能结算，随后正常弃六。
  FkTest.setNextReplies(user, {
    FkTest.ReplyCard(Fk:getCardById(card, true)),
    FkTest.ReplyDiscard(discardIds),
    "",
  })
  inRoom(function()
    GameEvent.Phase:create(phaseData):exec()
  end)
  lu.assertEquals(#user:getCardIds(Player.Hand), before + 8 - 6,
    "固定自用目标后真实用牌入口应摸八弃六")
  lu.assertEquals(room:getCardArea(card), Card.Void, "用后按势力锦囊移出游戏")
end

function Testqiao_faction_tricks:testDangguCannotHideHanJinLordMainGeneral()
  local room, user, target = FkTest.room, p(1), p(2)
  local card
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "han")
    room:setPlayerMark(user, "__heg_kingdom", "han")
    -- 汉晋独立君主：程序 id 不含 lord，须按真实位置排除。
    skill_test.installDualGenerals(room, target, {
      main = "qiao_heg__em_han001", deputy = "qiao_test__han_2", kingdom = "han",
    })
    card = voidTrick(room, DANGGU)
    giveFromVoid(room, card, user)
  end)
  lu.assertEquals(target.general, "qiao_heg__em_han001", "夹具应已明置君主主将")
  inRoom(function()
    room:useCard { from = user, card = Fk:getCardById(card, true), tos = { target } }
  end)
  lu.assertNotEquals(target.general, "anjiang", "汉晋君主主将不可被暗置")
  lu.assertEquals(target.deputyGeneral, "anjiang", "有可暗副将时只可选副将")
  lu.assertTrue(target:prohibitReveal(), "无可暗主将时仍建立禁明置")
end

function Testqiao_faction_tricks:testSihaiGuipingUseEntryAcceptsConversionCard()
  local room, victim, jin = FkTest.room, p(1), p(2)
  local material, use
  local viewas = fk.CreateSkill { name = "qiao_test_sihai_viewas" }
  viewas:addEffect("viewas", {
    pattern = "qiao__jink",
    view_as = function(self, player, cards)
      if cards == nil or #cards ~= 1 then return nil end
      local card = Fk:cloneCard("qiao__slash")
      card:addSubcards(cards)
      card.skillName = "qiao_test_sihai_viewas"
      return card
    end,
  })
  inRoom(function()
    room:setPlayerProperty(jin, "kingdom", "jin")
    room:setPlayerMark(jin, "__heg_kingdom", "jin")
    local hand = jin:getCardIds("he")
    if #hand > 0 then room:throwCard(hand, "qiao_test_clear", jin, jin) end
    material = room:printCard("qiao__jink", Card.Heart, 6)
    room:obtainCard(jin, material, false, fk.ReasonJustMove)
    victim.hp = victim.maxHp
    room:setCurrent(jin)
    Fk:addSkill(viewas:createSkill())
    room:handleAddLoseSkills(jin, "qiao_test_sihai_viewas", nil, false, true)
  end)
  FkTest.setNextReplies(jin, {
    FkTest.ReplyUseSkill("qiao_test_sihai_viewas", { victim }, { material.id }),
  })
  inRoom(function()
    use = FreeUse.askToUseCard(jin, {
      pattern = ".",
      skill_name = "qiao__sihai_guiping_skill",
      prompt = "#qiao__sihai_guiping-use",
      cancelable = true,
      extra_data = { bypass_times = false, extraUse = false },
    })
    if use ~= nil then room:useCard(use) end
  end)
  lu.assertNotNil(use, "普通可选用牌请求应接受已确认合法的转化牌")
  lu.assertEquals(use.card.name, "qiao__slash", "转化牌应作为【杀】使用")
  lu.assertTrue(use.card:isVirtual(), "转化牌应为虚拟牌")
  lu.assertEquals(victim.hp, victim.maxHp - 1, "转化牌应只执行一次并真实造成伤害")
  lu.assertEquals(room:getCardArea(material.id), Card.DiscardPile, "实体材料牌照常结算")
end

function Testqiao_faction_tricks:testLuoshuiImmediateUseNullificationPreventsJudge()
  local room, user, responder = FkTest.room, p(1), p(3)
  local card, nullification
  local beforeDraw
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "wild")
    room:setPlayerMark(user, "__heg_kingdom", "wild")
    card = voidTrick(room, "qiao__luoshui_zhishi")
    giveFromVoid(room, card, user)
    nullification = room:printCard("qiao__nullification", Card.Heart, 2)
    room:obtainCard(responder, nullification, false, fk.ReasonJustMove)
    putJudgeOnTop(room, Card.Spade, 3)
    beforeDraw = #room.draw_pile
  end)
  local records
  inRoom(function() records = damageProbe(room) end)
  FkTest.setNextReplies(responder, { FkTest.ReplyCard(nullification) })
  inRoom(function()
    room:useCard { from = user, card = Fk:getCardById(card, true), tos = { user } }
  end)
  lu.assertEquals(#records, 0, "被无懈抵消后不得判定或造成伤害")
  lu.assertEquals(#room.draw_pile, beforeDraw, "不得消耗判定牌")
  lu.assertEquals(room:getCardArea(card), Card.Void, "被抵消后按共用规则移出游戏")
end

function Testqiao_faction_tricks:testLuoshuiImmediateUseTargetNullifiedSkipsJudge()
  local room, user = FkTest.room, p(1)
  local card, nullified
  local beforeDraw
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "wild")
    room:setPlayerMark(user, "__heg_kingdom", "wild")
    card = voidTrick(room, "qiao__luoshui_zhishi")
    giveFromVoid(room, card, user)
    putJudgeOnTop(room, Card.Spade, 3)
    beforeDraw = #room.draw_pile
  end)
  local probe = fk.CreateSkill { name = "#qiao_test_luoshui_nullify_probe" }
  probe:addEffect(fk.TargetConfirmed, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      if nullified or data == nil or data.card == nil or data.from == nil then return false end
      local entry = (data.extra_data or {})[FactionTricks.USE_KEY]
      return target == data.from and type(entry) == "table" and entry.kingdom == "wild"
    end,
    on_refresh = function(self, event, target, player, data)
      nullified = true
      data:setNullified(target)
    end,
  })
  local records
  inRoom(function()
    records = damageProbe(room)
    room:addSkill(probe:createSkill())
    room:useCard { from = user, card = Fk:getCardById(card, true), tos = { user } }
  end)
  lu.assertTrue(nullified, "探针应把本次目标无效")
  lu.assertEquals(#records, 0, "目标无效时不得判定或造成伤害")
  lu.assertEquals(#room.draw_pile, beforeDraw, "不得消耗判定牌")
  lu.assertEquals(room:getCardArea(card), Card.Void, "无效后按共用规则移出游戏")
end

return { name = "qiao_faction_tricks" }
