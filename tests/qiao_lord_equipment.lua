-- 赤霄剑 / 锦绣征袍 / 虚妄之冕：正式牌包装配与各一条实际入口用例。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local ReqPlayCard = require "ltk.core.request_type.play_card"
local ReqUseCard = require "ltk.core.request_type.use_card"
local ReqActiveSkill = require "ltk.core.request_type.active_skill"
local Heg = require "packages.hegemony.util"
local AllianceCards = require "packages.qiao.pkg.qiao_mode.rules.cards"

local CHIXIAO = "qiao__chixiao_sword"
local JINXIU = "qiao__jinxiu_zhengpao"
local XUWANG = "qiao__xuwang_zhimian"
local ZOUYU = "qiao__zouyu_fan"
local XUEHAI = "qiao__xuehai_mowangzun"
local XUEHAI_SKILL = "qiao__xuehai_mowangzun_skill"
local SHENSHOU = "qiao__shenshou_sizhao"
local SHENSHOU_ACTIVE = "qiao_shenshou_active-turn"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room:getPlayerById(n) end
local function card(name, suit, number)
  return assert(table.find(Fk.cards, function(c)
    return c.name == name and (suit == nil or c.suit == suit)
      and (number == nil or c.number == number)
  end), "missing " .. name)
end

Testqiao_lord_equipment = {
  setup = function()
    local room = support.initQiaoRoom()
    inRoom(function()
      skill_test.installBlankGenerals(room, { "wei", "shu", "wei", "wei", "han", "qun", "wu", "jin" })
      local kingdoms = { "wei", "shu", "wei", "wei", "han", "qun", "wu", "jin" }
      for _, player in ipairs(room.players) do
        local kingdom = kingdoms[player.id]
        player.kingdom = kingdom
        player.role = kingdom
        local ids = player:getCardIds("he")
        if #ids > 0 then room:throwCard(ids, "test", player, player) end
      end
    end)
  end,
  tearDown = support.clearRoom,
}

local function give(room, player, c)
  room:obtainCard(player, c.id, true, fk.ReasonJustMove, player, "test")
  return c
end

local function use(room, from, tos, c)
  local data = UseCardData:new { from = from, tos = tos or {}, card = c, extra_data = {} }
  room:useCard(data)
  return data
end

--- 模拟客户端实际持有的实体牌：由 PrintCard 打印，只有公开合纵标记，没有
--- 服务端在打印后写入的 extra_data.qiao_heji。
local function printedAllianceCard(room, name, suit, number)
  local c = room:printCard(name, suit, number)
  room:setCardMark(c, "@@alliance-public", 1)
  return c
end

local function shenshouBypassesDistance(player)
  local snatch = Fk:cloneCard("qiao__snatch")
  local distant = assert(table.find(player.room:getOtherPlayers(player), function(other)
    return player:distanceTo(other) > 1
  end), "神授思召用例须有原本超出顺手牵羊距离的目标")
  return snatch.skill:withinDistanceLimit(player, false, snatch, distant)
end

local function totalInvokeLogs(logs)
  return #table.filter(logs, function(log)
    return type(log.type) == "string" and log.type:startsWith("#InvokeSkill")
      and type(log.arg) == "string" and log.arg:find("shenshou_sizhao", 1, true) ~= nil
  end)
end

local function confirmRequest(handler)
  local reply
  local originalNotify = ClientInstance.notifyUI
  ClientInstance.notifyUI = function(_, command, data)
    if command == "ReplyToServer" then reply = data end
  end
  local ok, err = pcall(function() handler:doOKButton() end)
  ClientInstance.notifyUI = originalNotify
  if not ok then error(err, 0) end
  return assert(reply, "client did not send a card-use reply")
end

function Testqiao_lord_equipment:testWoodenOxMovesWithCargoFromOneCancelableTargetRequest()
  local room = FkTest.room
  local first, second, third = p(1), p(2), p(3)
  inRoom(function()
    local ox = give(room, first, room:printCard("qiao__wooden_ox", Card.Diamond, 5))
    use(room, first, { first }, ox)
    local original = room.askToUseActiveSkill
    local requests = 0
    room.askToUseActiveSkill = function(self, player, params)
      if params.prompt == "#wooden_ox-move" then
        requests = requests + 1
        local target = player == first and second or third
        lu.assertEquals(params.skill_name, "choose_players_skill")
        client_room.run(room, function(clients)
          local selector = Fk.skills[params.skill_name]
          local previous = selector._extra_data
          selector._extra_data = params.extra_data
          local handler = ReqActiveSkill:new(clients[player.seat], {
            params.skill_name, params.prompt, params.cancelable, params.extra_data,
          })
          local ok, err = pcall(function()
            handler:setup()
            lu.assertTrue(handler.cancelable)
            lu.assertFalse(handler:feasible(), "无目标时不能确认移动")
            lu.assertTrue(handler:targetValidity(target.id))
            handler:selectTarget(target.id, { selected = true })
            lu.assertTrue(handler:feasible())
            handler:_finish()
          end)
          selector._extra_data = previous
          if not ok then error(err, 0) end
        end)
      end
      return original(self, player, params)
    end
    local cargo = give(room, first, room:printCard("qiao__slash", Card.Spade, 3))
    local extra = give(room, second, room:printCard("qiao__jink", Card.Heart, 2))
    local oxSkill = "qiao__wooden_ox_skill"
    local function load(player, material, reply)
      room.current, player.phase = player, Player.Play
      FkTest.setNextReplies(player, { reply })
      room:handleUseCardReply(player, FkTest.ReplyUseSkill(oxSkill, {}, { material.id }), nil)
    end
    load(first, cargo, FkTest.ReplyChoosePlayer({ second }))
    local owner = room:getCardOwner(ox.id)
    lu.assertEquals(owner and owner.id, second.id)
    lu.assertEquals(room:getCardArea(ox.id), Card.PlayerEquip)
    lu.assertEquals(first:getPile("$sa_carriage"), {})
    lu.assertEquals(second:getPile("$sa_carriage"), { cargo.id })
    load(second, extra, "")
    owner = room:getCardOwner(ox.id)
    lu.assertEquals(owner and owner.id, second.id)
    lu.assertEquals(second:getPile("$sa_carriage"), { cargo.id, extra.id })
    lu.assertEquals(requests, 2)
    room.askToUseActiveSkill = original
    room:moveCardTo(ox.id, Card.PlayerSpecial, third, fk.ReasonJustMove,
      "test", "qiao_em_wu001_fenghuo", true, second)
    lu.assertEquals(third:getPile("qiao_em_wu001_fenghuo"), { ox.id })
    lu.assertEquals(second:getPile("$sa_carriage"), {})
    lu.assertEquals(room:getCardArea(cargo.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(extra.id), Card.DiscardPile)
  end)
end

function Testqiao_lord_equipment:testChixiaoBigSmallTargetGivesRedOrCannotOffset()
  local room = FkTest.room
  local user, small, big = p(1), p(2), p(4)
  local sword = card(CHIXIAO)
  local slash = card("qiao__slash", Card.Spade, 5)
  local red = card("qiao__peach", Card.Heart, 4)
  local black = card("qiao__slash", Card.Club, 3)
  local hpSmall = small.hp
  FkTest.runInRoom(function()
    give(room, user, sword)
    use(room, user, { user }, sword)
    lu.assertTrue(user:hasSkill("qiao__chixiao_sword_skill"))
    lu.assertTrue(Heg.isBigKingdomPlayer(user))
    lu.assertTrue(Heg.isSmallKingdomPlayer(small))
    give(room, small, red)
    FkTest.setNextReplies(small, { FkTest.ReplyChooseCards({ red.id }) })
    use(room, user, { small }, slash)
  end)
  lu.assertEquals(room:getCardArea(red.id), Card.PlayerHand)
  lu.assertTrue(table.contains(user:getCardIds("h"), red.id), "大／小不同目标应交红色手牌")
  lu.assertEquals(small.hp, hpSmall - 1)

  -- 没有红色手牌时不能抵消；不影响其他同为大势力的目标响应。
  local hpSmall2 = small.hp
  local hpBig = big.hp
  local jink = card("qiao__jink", Card.Diamond, 7)
  local slash2 = card("qiao__slash", Card.Spade, 9)
  FkTest.runInRoom(function()
    give(room, small, black)
    give(room, big, jink)
    lu.assertTrue(table.contains(big:getCardIds("h"), jink.id))
    FkTest.setNextReplies(big, { FkTest.ReplyCard(jink) })
    use(room, user, { small, big }, slash2)
  end)
  lu.assertEquals(small.hp, hpSmall2 - 1, "未交红色手牌的目标不能抵消")
  lu.assertTrue(table.contains(small:getCardIds("h"), black.id), "未交牌不额外弃置")
  lu.assertEquals(big.hp, hpBig, "同为一个大势力的目标仍可响应")
  lu.assertEquals(room:getCardArea(jink.id), Card.DiscardPile)
end

function Testqiao_lord_equipment:testJinxiuGetsMaterialAndOnlySelfIsNullified()
  local room = FkTest.room
  local attacker, owner, other = p(1), p(2), p(3)
  local armor = card(JINXIU)
  local slash = card("qiao__slash", Card.Spade, 5)
  local heart = card("qiao__peach", Card.Heart, 4)
  local club = card("qiao__slash", Card.Club, 3)
  local diamond = card("qiao__jink", Card.Diamond, 7)
  local ownerHp, otherHp = owner.hp, other.hp
  FkTest.runInRoom(function()
    give(room, owner, armor)
    use(room, owner, { owner }, armor)
    give(room, owner, heart)
    give(room, owner, club)
    give(room, owner, diamond)
    FkTest.setNextReplies(owner, { "1" })
    use(room, attacker, { owner, other }, slash)
  end)
  lu.assertEquals(owner.hp, ownerHp, "取得材料后四花色齐备，仅对自己无效")
  lu.assertEquals(other.hp, otherHp - 1, "其他目标仍正常结算")
  lu.assertTrue(table.contains(owner:getCardIds("h"), slash.id), "获得本次来牌的实体牌")
end

function Testqiao_lord_equipment:testXuwangDrawAndHandLimitFollowEquipment()
  local room = FkTest.room
  local owner = p(1)
  local crown = card(XUWANG)
  local lord = Fk.packages.qiao_cards.qiao_cards.lordEquipment[XUWANG]
  lu.assertTableContains(lord.kingdoms, "wei")
  lu.assertTableContains(lord.kingdoms, "jin")
  local handBefore
  FkTest.runInRoom(function()
    give(room, owner, crown)
    use(room, owner, { owner }, crown)
    lu.assertEquals(owner:getMaxCards(), math.max(owner.hp - 1, 0), "装备时手牌上限-1")
    handBefore = #owner:getCardIds("h")
    GameEvent.Turn:create(TurnData:new(owner, "game_rule", { Player.Draw })):exec()
    lu.assertEquals(#owner:getCardIds("h"), handBefore + 4, "自己的摸牌阶段额外摸2")
    room:moveCardTo(crown.id, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      "test", nil, true, owner)
    lu.assertEquals(owner:getMaxCards(), math.max(owner.hp, 0), "离装备失去手牌上限修正")
  end)
  lu.assertFalse(owner:hasSkill("qiao__xuwang_zhimian_skill"))
end

function Testqiao_lord_equipment:testSihaiPoxiKeepsHiddenHandAndSwapsChosenTwo()
  local room = FkTest.room
  local user = p(1)
  local target
  local treasure = card("qiao__sihai_liuqian")
  local mount = card("qiao__linxiao_yuyu")
  local hidden = card("qiao__peach", Card.Heart, 7)
  local kept = card("qiao__slash", Card.Club, 4)
  local request
  FkTest.runInRoom(function()
    give(room, user, treasure)
    use(room, user, { user }, treasure)
    for _, candidate in ipairs(room.players) do
      if candidate ~= user and user:distanceTo(candidate) > 1 then
        target = candidate
        break
      end
    end
    assert(target ~= nil)
    -- 目标装备区里有一张公开的临筱玉舆，手牌两张未公开。
    room:moveCardTo(mount.id, Card.PlayerEquip, target, fk.ReasonJustMove,
      "test", nil, true, target)
    give(room, target, hidden)
    give(room, target, kept)
    give(room, user, card("qiao__jink"))
    user.phase = Player.Play
    room.current = user
    client_room.run(room, function(clients)
      local me = table.find(clients, function(client) return client.id == user.id end)
      local handler = ReqPlayCard:new(me)
      local skill = "qiao__sihai_liuqian_skill"
      handler:setup()
      lu.assertTrue(handler:skillButtonValidity(skill))
      handler:selectSkill(skill, { selected = true })
      for _, id in ipairs(me:getCardIds("h")) do
        lu.assertFalse(handler:cardValidity(id), "四海流钱第一步只选择目标")
      end
      lu.assertTrue(handler:targetValidity(target.id))
      handler:selectTarget(target.id, { selected = true })
      lu.assertTrue(handler:feasible())
      handler:_finish()
    end)
    -- 真实 AskForPoxi 请求：记录引擎实际下发的可见性与固定候选分组。
    FkTest.setRoomBreakpoint(user, "AskForPoxi", function(data)
      request = data
      return false
    end)
    local skill = Fk.skills["qiao__sihai_liuqian_skill"]
    local data = { from = user, cards = {}, tos = { target } }
    FkTest.setNextReplies(user, { { mount.id, hidden.id } })
    skill:onUse(room, data)
  end)
  lu.assertNotNil(request, "三张可获得牌应发出真实 AskForPoxi 请求")
  lu.assertEquals(request.type, "AskForCardsChosen")
  lu.assertEquals(request.extra_data.to, target.id)
  lu.assertEquals(request.extra_data.min, 2)
  lu.assertEquals(request.extra_data.max, 2)
  lu.assertEquals(request.extra_data.skillName, "qiao__sihai_liuqian_skill")
  local visible = request.extra_data.visible_data
  lu.assertNotNil(visible, "未公开手牌必须附带 visible_data")
  lu.assertFalse(visible[tostring(hidden.id)], "未公开手牌应标为不可见")
  lu.assertFalse(visible[tostring(kept.id)], "未公开手牌应标为不可见")
  lu.assertNotEquals(visible[tostring(mount.id)], false, "公开装备不应被隐藏")
  local groups = {}
  for _, group in ipairs(request.data) do groups[group[1]] = group[2] end
  lu.assertEquals(#request.data, 2, "固定候选头为手牌与装备两组")
  lu.assertTableContains(groups["$Hand"], hidden.id)
  lu.assertTableContains(groups["$Hand"], kept.id)
  lu.assertTableContains(groups["$Equip"], mount.id)
  lu.assertEquals(room:getCardArea(treasure.id), Card.PlayerHand)
  lu.assertEquals(room:getCardOwner(treasure.id).id, target.id)
  lu.assertTrue(table.contains(user:getCardIds("h"), mount.id), "取得所选公开装备")
  lu.assertTrue(table.contains(user:getCardIds("h"), hidden.id), "取得所选手牌")
  lu.assertTrue(table.contains(target:getCardIds("h"), kept.id), "未选中的手牌保留")
  lu.assertFalse(table.contains(user:getCardIds("h"), kept.id))
  lu.assertFalse(user:hasSkill("qiao__sihai_liuqian_skill"))
end

function Testqiao_lord_equipment:testZhoujunEnteringSameCategoryAndNoBigKingdom()
  local room = FkTest.room
  local owner, ally, noBig = p(1), p(3), p(4)
  local seal = card("qiao__zhoujun_lingbingyin")
  local gift = card("qiao__peach", Card.Heart, 7)
  local giftPrompt
  FkTest.runInRoom(function()
    give(room, owner, seal)
    give(room, ally, gift)
    FkTest.setRoomBreakpoint(ally, "AskForUseActiveSkill", function(data)
      if data[1] == "choose_cards_skill" and data[4].skillName == "qiao__zhoujun_lingbingyin_skill" then
        giftPrompt = data[2]
      end
      return false
    end)
    FkTest.setNextReplies(ally, { FkTest.ReplyChooseCards({ gift.id }) })
    use(room, owner, { owner }, seal)
  end)
  lu.assertEquals(giftPrompt, "#qiao__zhoujun-give::" .. owner.id)
  lu.assertTrue(table.contains(owner:getCardIds("h"), gift.id),
    "同为一个大势力的角色可交牌给装备者")

  FkTest.runInRoom(function()
    -- 全体各自唯一势力：没有大势力，也没有小势力，不再询问。
    local kingdoms = { "wei", "shu", "wu", "qun", "han", "jin", "qun", "wu" }
    for _, player in ipairs(room.players) do
      player.kingdom = kingdoms[player.id]
      player.role = player.kingdom
    end
    room:moveCardTo(seal.id, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      "test", nil, true, owner)
    give(room, owner, seal)
    give(room, noBig, gift)
    FkTest.setNextReplies(noBig, {})
    use(room, owner, { owner }, seal)
    lu.assertFalse(table.contains(owner:getCardIds("h"), gift.id))
    lu.assertTrue(table.contains(noBig:getCardIds("h"), gift.id))
  end)
end

function Testqiao_lord_equipment:testZhoujunPrepareChoiceAndTurnPersistence()
  local room = FkTest.room
  local owner = p(1)
  local seal = card("qiao__zhoujun_lingbingyin")
  FkTest.runInRoom(function()
    give(room, owner, seal)
    use(room, owner, { owner }, seal)
    -- 摸牌+2，出杀-1，手牌上限-1：合法组合由服务端数值校验后生效。
    FkTest.setNextReplies(owner, { "1", { draw = 2, slash = -1, hand = -1 } })
    room.logic:trigger(fk.EventPhaseStart, owner, { phase = Player.Start })
    local drawData = { n = 2 }
    room.logic:trigger(fk.DrawNCards, owner, drawData)
    lu.assertEquals(drawData.n, 4, "额定摸牌数+2")
    lu.assertEquals(owner:getMaxCards(), math.max(owner.hp - 1, 0), "手牌上限-1")
    lu.assertEquals(Fk.skills["slash_skill"]:getMaxUseTime(
      owner, Player.HistoryPhase, Fk:cloneCard("slash")), 0, "出杀次数-1")
    client_room.run(room, function(clients)
      local me = table.find(clients, function(c) return c.id == owner.id end)
      lu.assertEquals(me:getMark("qiao_zhoujun_draw"), 2, "客户端读到公开摸牌修正")
      lu.assertEquals(me:getMaxCards(), owner:getMaxCards(), "客户端 maxcards 同步")
    end)
    room:moveCardTo(seal.id, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      "test", nil, true, owner)
    lu.assertEquals(owner:getMaxCards(), math.max(owner.hp - 1, 0),
      "失去装备后已建立的当回合修正仍保留")
    room.logic:trigger(fk.TurnEnd, owner, {})
    lu.assertEquals(owner:getMaxCards(), math.max(owner.hp, 0), "回合结束清除修正")
    lu.assertEquals(Fk.skills["slash_skill"]:getMaxUseTime(
      owner, Player.HistoryPhase, Fk:cloneCard("slash")), 1, "回合结束恢复出杀次数")
  end)
end

function Testqiao_lord_equipment:testZhoujunTwoPointReduction()
  local room = FkTest.room
  local owner = p(5)
  local seal = card("qiao__zhoujun_lingbingyin")
  FkTest.runInRoom(function()
    give(room, owner, seal)
    use(room, owner, { owner }, seal)
    FkTest.setNextReplies(owner, { "1", { draw = -2, slash = 2, hand = 0 } })
    room.logic:trigger(fk.EventPhaseStart, owner, { phase = Player.Start })
    local drawData = { n = 2 }
    room.logic:trigger(fk.DrawNCards, owner, drawData)
    lu.assertEquals(drawData.n, 0, "摸牌-2按当前基数足额扣除")
    lu.assertEquals(Fk.skills["slash_skill"]:getMaxUseTime(
      owner, Player.HistoryPhase, Fk:cloneCard("slash")), 3, "出杀+2")
    room.logic:trigger(fk.TurnEnd, owner, {})
  end)
end

function Testqiao_lord_equipment:testZhoujunDialogSendsLegalTriplesAndIgnoresInvalidReply()
  local room = FkTest.room
  local owner = p(6)
  local seal = card("qiao__zhoujun_lingbingyin")
  local request
  FkTest.runInRoom(function()
    give(room, owner, seal)
    use(room, owner, { owner }, seal)
    owner.hp = 1
    -- 分别尝试把出杀、手牌上限减成负数，以及同时给两项加点。
    local invalid = {
      { draw = 2, slash = -2, hand = 0 },
      { draw = 2, slash = 0, hand = -2 },
      { draw = -2, slash = 1, hand = 1 },
    }
    FkTest.setRoomBreakpoint(owner, "CustomDialog", function(data)
      request = data
      return false
    end)
    for _, reply in ipairs(invalid) do
      FkTest.setNextReplies(owner, { "1", reply })
      room.logic:trigger(fk.EventPhaseStart, owner, { phase = Player.Start })
      lu.assertEquals(owner:getMark("qiao_zhoujun_draw"), 0)
      lu.assertEquals(owner:getMark("qiao_zhoujun_slash"), 0)
      lu.assertEquals(owner:getMark("qiao_zhoujun_hand"), 0)
    end

    lu.assertNotNil(request, "准备阶段应打开数值调整弹窗")
    lu.assertEquals(request.component.url,
      "packages/qiao/pkg/qiao_mode/qml/ZhoujunValueBox.qml")
    local options = request.component.prop.options
    local values = request.component.prop.baseValues
    lu.assertEquals(values, { draw = 2, slash = 1, hand = 1 })
    lu.assertTrue(#options > 0, "服务端应提供合法组合")
    for _, option in ipairs(options) do
      lu.assertEquals(option.draw + option.slash + option.hand, 0,
        "合法组合三项增减值合计为 0")
      local increased = 0
      for _, value in ipairs({ option.draw, option.slash, option.hand }) do
        if value > 0 then increased = increased + 1 end
      end
      lu.assertEquals(increased, 1, "合法组合恰有一项增加")
      lu.assertTrue(option.draw >= -2 and option.draw <= 2)
      lu.assertTrue(option.slash >= -2 and option.slash <= 2)
      lu.assertTrue(option.hand >= -2 and option.hand <= 2)
      lu.assertTrue(values.draw + option.draw >= 0)
      lu.assertTrue(values.slash + option.slash >= 0)
      lu.assertTrue(values.hand + option.hand >= 0)
    end
    lu.assertEquals(owner:getMark("qiao_zhoujun_draw"), 0, "非合法组合不产生摸牌修正")
    lu.assertEquals(owner:getMark("qiao_zhoujun_slash"), 0, "非合法组合不产生出杀修正")
    lu.assertEquals(owner:getMark("qiao_zhoujun_hand"), 0, "非合法组合不产生手牌上限修正")
  end)
end

function Testqiao_lord_equipment:testZhoujunCancelLeavesNoBonus()
  local room = FkTest.room
  local owner = p(7)
  local seal = card("qiao__zhoujun_lingbingyin")
  FkTest.runInRoom(function()
    give(room, owner, seal)
    use(room, owner, { owner }, seal)
    FkTest.setNextReplies(owner, { "1", "" })
    room.logic:trigger(fk.EventPhaseStart, owner, { phase = Player.Start })
    lu.assertEquals(owner:getMark("qiao_zhoujun_draw"), 0, "取消不随机选择修正")
    lu.assertEquals(owner:getMark("qiao_zhoujun_slash"), 0)
    lu.assertEquals(owner:getMark("qiao_zhoujun_hand"), 0)
  end)
end

function Testqiao_lord_equipment:testZhoujunSlashReductionFloorsAtZeroAfterLosingBonus()
  local room, owner = FkTest.room, p(1)
  local seal = card("qiao__zhoujun_lingbingyin")
  local slash = Fk:cloneCard("qiao__slash")
  inRoom(function()
    give(room, owner, seal)
    use(room, owner, { owner }, seal)
    local extra = fk.CreateSkill { name = "test_zhoujun_temporary_slash_limit" }
    extra:addEffect("targetmod", {
      residue_func = function(self, player, cardSkill, scope, card)
        if player == owner and card and card.trueName == "slash" and scope == Player.HistoryPhase then
          return player:getMark("test_zhoujun_temporary_slash_limit")
        end
      end,
    })
    local extraSkill = extra:createSkill()
    Fk.skills[extraSkill.name] = extraSkill
    room:addSkill(extraSkill)
    room:setPlayerMark(owner, "test_zhoujun_temporary_slash_limit", 1)
    FkTest.setNextReplies(owner, { "1", { draw = 2, slash = -2, hand = 0 } })
    room.logic:trigger(fk.EventPhaseStart, owner, { phase = Player.Start })
    lu.assertEquals(owner:getMark("qiao_zhoujun_slash"), -2)
    lu.assertEquals(slash:getSkill(owner):getMaxUseTime(owner, Player.HistoryPhase, slash), 0)
    room:setPlayerMark(owner, "test_zhoujun_temporary_slash_limit", 0)
    lu.assertEquals(slash:getSkill(owner):getMaxUseTime(owner, Player.HistoryPhase, slash), 0)
  end)
end

function Testqiao_lord_equipment:testZouyuRequestSlashChoosesRealTarget()
  local room = FkTest.room
  local attacker, owner = p(1), p(2)
  local fan = card(ZOUYU)
  local far
  FkTest.runInRoom(function()
    give(room, owner, fan)
    use(room, owner, { owner }, fan)
    room.current = attacker
    far = attacker
    assert(far ~= nil)
    local before = far.hp
    FkTest.setNextReplies(owner, { "1" })
    local originalChoose = room.askToChoosePlayers
    room.askToChoosePlayers = function() return { far } end
    local use = room:askToUseCard(owner, {
      pattern = "slash",
      skill_name = "test_zouyu_slash",
      prompt = "test",
      cancelable = false,
      extra_data = { bypass_times = true, extraUse = true },
    })
    room.askToChoosePlayers = originalChoose
    assert(use ~= nil and use.tos ~= nil and use.tos[1] == far)
    room:useCard(use)
    lu.assertEquals(far.hp, before - 1, "真实带目标用杀经驺虞幡完成")
  end)
end

function Testqiao_lord_equipment:testZouyuProvidesJinkThenDelayedLoseHp()
  local room = FkTest.room
  local attacker, owner = p(1), p(2)
  local fan = card(ZOUYU)
  local slash = card("qiao__slash", Card.Spade, 5)
  local hp = owner.hp
  local sendLog = room.sendLog
  local ending = false
  local endingInvocations = 0
  room.sendLog = function(self, log, ...)
    if ending and log.type:startsWith("#InvokeSkill") and type(log.arg) == "string"
      and log.arg:find("zouyu_fan", 1, true) then
      endingInvocations = endingInvocations + 1
    end
    return sendLog(self, log, ...)
  end
  FkTest.runInRoom(function()
    give(room, owner, fan)
    use(room, owner, { owner }, fan)
    room.current = attacker
    give(room, attacker, slash)
    FkTest.setNextReplies(owner, { "1" })
    use(room, attacker, { owner }, slash)
    lu.assertEquals(owner.hp, hp, "视为打出【闪】，本次伤害被抵消")
    room:moveCardTo(fan.id, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      "test", nil, true, owner)
    room:damage { from = attacker, to = owner, damage = 1, damageType = fk.NormalDamage }
    lu.assertEquals(owner.hp, hp - 2, "本次伤害后再失去1点体力")
    ending = true
    room.logic:trigger(fk.TurnEnd, attacker, {})
    room.logic:trigger(fk.TurnEnd, attacker, {})
    lu.assertEquals(endingInvocations, 0, "驺虞幡已离开装备区，回合末不得反复报发动")
  end)
end

function Testqiao_lord_equipment:testXuehaiPlayCardUsesSpadeResponse()
  local room = FkTest.room
  local owner, helper, other = p(1), p(3), p(4)
  local pot = card(XUEHAI)
  local spade = card("qiao__slash", Card.Spade, 9)
  local spade2 = card("qiao__slash", Card.Spade, 10)
  local reply
  FkTest.runInRoom(function()
    give(room, owner, pot)
    use(room, owner, { owner }, pot)
    owner.phase = Player.Play
    room.current = owner
    give(room, helper, spade)
    give(room, other, spade2)
    client_room.run(room, function(clients)
      local me = table.find(clients, function(c) return c.id == owner.id end)
      local handler = ReqPlayCard:new(me)
      handler:setup()
      lu.assertNotNil(handler.scene:getAllItems("SkillButton")[XUEHAI_SKILL])
      lu.assertTrue(handler:skillButtonValidity(XUEHAI_SKILL))
      handler:selectSkill(XUEHAI_SKILL, { selected = true })
      lu.assertTrue(handler:feasible(), "点开宝物后可以确认无需材料的【酒】")
      reply = confirmRequest(handler)
      handler:_finish()
    end)
    FkTest.setNextReplies(helper, { FkTest.ReplyCard(spade) })
    FkTest.setNextReplies(other, { FkTest.ReplyCard(spade2) })
    room:handleUseCardReply(owner, reply)
    lu.assertEquals(owner.drank, 1, "正常出牌回包只结算一次【酒】")
    client_room.run(room, function(clients)
      local me = table.find(clients, function(c) return c.id == owner.id end)
      local handler = ReqPlayCard:new(me)
      handler:setup()
      lu.assertFalse(handler:skillButtonValidity(XUEHAI_SKILL), "普通用酒次数用尽后按钮置灰")
      handler:_finish()
    end)
  end)
  local discarded = 0
  for _, c in ipairs({ spade, spade2 }) do
    if room:getCardArea(c.id) == Card.DiscardPile then discarded = discarded + 1 end
  end
  lu.assertEquals(discarded, 1, "只实际打出一张黑桃牌")
  lu.assertEquals(#helper:getCardIds("h") + #other:getCardIds("h"), 1, "后续候选未被消耗")
end

function Testqiao_lord_equipment:testChixiaoMayDeclineOnlyRedCard()
  local room, user, target = FkTest.room, p(1), p(2)
  local sword = card(CHIXIAO)
  local jink = card("qiao__jink", Card.Diamond, 2)
  local slash = card("qiao__slash", Card.Spade, 5)
  inRoom(function()
    give(room, user, sword)
    use(room, user, { user }, sword)
    give(room, target, jink)
    local hp = target.hp
    local asked = false
    skill_test.withSkillRequests(room, "qiao__chixiao_sword_skill", {
      askToCards = function(self, who, params, original)
        asked = true
        lu.assertTrue(params.cancelable)
        lu.assertTrue(jink:matchPattern(params.pattern), "唯一红色手牌可选择")
        return original(self, who, params)
      end,
    }, function()
      FkTest.setNextReplies(target, { "" })
      use(room, user, { target }, slash)
    end)
    lu.assertTrue(asked, "唯一红色手牌也须发出请求")
    lu.assertEquals(target.hp, hp - 1)
    lu.assertIs(room:getCardOwner(jink.id), target, "取消后保留唯一红色手牌")
  end)
end

function Testqiao_lord_equipment:testXuehaiLeavingDyingGivesPotToDamageSource()
  local room = FkTest.room
  local owner, source = p(1), p(2)
  local pot = card(XUEHAI)
  FkTest.runInRoom(function()
    give(room, owner, pot)
    use(room, owner, { owner }, pot)
    room.logic:trigger(fk.AfterDying, owner, {
      who = owner,
      damage = { from = source, to = owner, damage = 1, card = Fk:cloneCard("slash") },
    })
  end)
  lu.assertEquals(room:getCardArea(pot.id), Card.PlayerHand)
  lu.assertEquals(room:getCardOwner(pot.id).id, source.id)
end
function Testqiao_lord_equipment:testSihaiAllOrNoneWhenTargetTreasureProtected()
  local room = FkTest.room
  local user, target = p(1), p(3)
  local treasure = card("qiao__sihai_liuqian")
  local pearl = card("qiao__luminous_pearl")
  local other = card("qiao__peach", Card.Heart, 4)
  local asked
  FkTest.runInRoom(function()
    give(room, user, treasure)
    use(room, user, { user }, treasure)
    room:moveCardTo(pearl.id, Card.PlayerEquip, target, fk.ReasonJustMove,
      "test", nil, true, target)
    give(room, target, other)
    room:handleAddLoseSkills(target, { "qiao__skill_em_wu001_3" }, nil, false, true)
    lu.assertTrue(target:hasSkill("qiao__skill_em_wu001_3"))
    -- 目标恰好两张可获得牌时引擎直接返回全部，不再发出选牌请求。
    FkTest.setRoomBreakpoint(user, "AskForPoxi", function()
      asked = true
      return false
    end)
    local skill = Fk.skills["qiao__sihai_liuqian_skill"]
    local data = { from = user, cards = {}, tos = { target } }
    FkTest.setNextReplies(user, { { pearl.id, other.id } })
    skill:onUse(room, data)
  end)
  lu.assertNil(asked, "恰两张时原生直接返回，不应再询问")
  lu.assertEquals(room:getCardOwner(treasure.id).id, user.id, "整次交换不成：宝物未交出")
  lu.assertEquals(room:getCardArea(treasure.id), Card.PlayerEquip)
  lu.assertEquals(room:getCardOwner(pearl.id).id, target.id, "受保护宝物未被拿走")
  lu.assertTrue(table.contains(target:getCardIds("h"), other.id), "另一张牌也未被拿走")
end
function Testqiao_lord_equipment:testLuminousDrawsActualDiscardedCount()
  local room = FkTest.room
  local owner = p(1)
  local pearl = card("qiao__luminous_pearl")
  local one = card("qiao__peach", Card.Heart, 4)
  local two = card("qiao__slash", Card.Club, 4)
  local skill = Fk.skills["qiao__luminous_pearl_skill"]
  local cancel = fk.CreateSkill { name = "test_pearl_cancel_partial" }
  cancel:addEffect(fk.BeforeCardsMove, {
    global = true,
    can_trigger = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        if move.skillName == "qiao__luminous_pearl_skill" then return true end
      end
      return false
    end,
    on_use = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        if move.skillName == "qiao__luminous_pearl_skill" and #move.moveInfo > 1 then
          table.remove(move.moveInfo)
          return
        end
      end
    end,
  })
  FkTest.runInRoom(function()
    give(room, owner, pearl)
    use(room, owner, { owner }, pearl)
    give(room, owner, one)
    give(room, owner, two)
    local cancelSkill = cancel:createSkill()
    Fk.skills[cancelSkill.name] = cancelSkill
    room:addSkill(cancelSkill)
    local before = #owner:getCardIds("h")
    skill:onUse(room, { from = owner, cards = { one.id, two.id } })
    lu.assertEquals(#owner:getCardIds("h"), before, "弃一张摸一张，按实际移动数")
  end)
end
function Testqiao_lord_equipment:testChixiaoGiveCancelMakesTargetUnableToOffset()
  local room = FkTest.room
  local user, target = p(1), p(2)
  local sword = card("qiao__chixiao_sword")
  local red = card("qiao__peach", Card.Heart, 4)
  local jink = card("qiao__jink", Card.Diamond, 2)
  local slash = card("qiao__slash", Card.Spade, 5)
  local cancel = fk.CreateSkill { name = "test_chixiao_cancel_give" }
  cancel:addEffect(fk.BeforeCardsMove, {
    global = true,
    can_trigger = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        if move.skillName == "qiao__chixiao_sword_skill" then return true end
      end
      return false
    end,
    on_use = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        if move.skillName == "qiao__chixiao_sword_skill" then move.moveInfo = {} end
      end
    end,
  })
  FkTest.runInRoom(function()
    give(room, user, sword)
    use(room, user, { user }, sword)
    give(room, target, red)
    give(room, target, jink)
    give(room, user, slash)
    local cancelSkill = cancel:createSkill()
    Fk.skills[cancelSkill.name] = cancelSkill
    room:addSkill(cancelSkill)
    FkTest.setNextReplies(target, { FkTest.ReplyChooseCards({ red.id }) })
    local hp = target.hp
    use(room, user, { target }, slash)
    lu.assertEquals(target.hp, hp - 1, "实际未发生给牌，目标不能抵消")
    lu.assertTrue(table.contains(target:getCardIds("h"), jink.id), "【闪】未被当作已给牌")
  end)
end
function Testqiao_lord_equipment:testXuehaiProhibitedWineDoesNotAskHelper()
  local room = FkTest.room
  local owner, helper = p(1), p(3)
  local pot = card(XUEHAI)
  local spade = card("qiao__slash", Card.Spade, 9)
  local ban = fk.CreateSkill { name = "test_xuehai_ban_wine" }
  ban:addEffect("prohibit", {
    prohibit_use = function(self, player, card)
      return card ~= nil and card.name == "analeptic"
    end,
  })
  FkTest.runInRoom(function()
    give(room, owner, pot)
    use(room, owner, { owner }, pot)
    give(room, helper, spade)
    local inst = ban:createSkill()
    Fk.skills[inst.name] = inst
    room:addSkill(inst)
    FkTest.setNextReplies(owner, { FkTest.ReplyUseSkill(XUEHAI_SKILL), "" })
    local result = room:askToUseCard(owner, {
      pattern = "analeptic|0|nosuit|none",
      skill_name = "qiao__xuehai_mowangzun_skill",
      prompt = "test",
      cancelable = true,
    })
    lu.assertNil(result, "被禁止的【酒】不应由装备者生成结果")
    lu.assertTrue(table.contains(helper:getCardIds("h"), spade.id), "协助者未被询问/消耗")
  end)
end
function Testqiao_lord_equipment:testShenshouEntryTurnHiddenThenClearedSilently()
  local room = FkTest.room
  local owner = p(1)
  local fan
  FkTest.runInRoom(function()
    fan = printedAllianceCard(room, SHENSHOU, Card.Spade, 5)
    -- 客户端打印牌没有服务端的合纵 extra_data，只有公开牌面标记。
    lu.assertFalse(AllianceCards.isHeji(fan), "PrintCard 实体牌不应带服务端 extra_data")
    give(room, owner, fan)
    room.current = owner
    use(room, owner, { owner }, fan)
    lu.assertEquals(owner:getMark(SHENSHOU_ACTIVE), 1, "置入装备区的回合建立状态")
    lu.assertTrue(shenshouBypassesDistance(owner), "当回合使用牌无距离限制")
    local phase = PhaseData:new { who = owner, reason = "game_rule", phase = Player.Discard }
    room.logic:trigger(fk.EventPhaseChanging, owner, phase)
    lu.assertTrue(phase.skipped, "当回合跳过弃牌阶段")

    -- 当回合只有神授思召：没有合法合纵牌，不能从装备区合纵。
    client_room.run(room, function(clients)
      local me = table.find(clients, function(c) return c.id == owner.id end)
      local handler = ReqPlayCard:new(me)
      handler.skill_name = "qiao__alliance"
      handler:setup()
      lu.assertFalse(handler:skillButtonValidity("qiao__alliance"),
        "当回合只有神授思召时合纵按钮不应可用")
      lu.assertFalse(handler:cardValidity(fan.id), "当回合不能从装备区合纵")
    end)

    local logs = {}
    local original = room.sendLog
    room.sendLog = function(self, log) table.insert(logs, log) end
    GameEvent.Turn:create(TurnData:new(owner, "game_rule", { Player.Finish })):exec()
    room.sendLog = original
    lu.assertEquals(totalInvokeLogs(logs), 0, "回合结束清理不应表现为一次可见技能发动")
    lu.assertEquals(owner:getMark(SHENSHOU_ACTIVE), 0, "回合结束清除置入回合状态")
    lu.assertFalse(shenshouBypassesDistance(owner), "后续回合不再获得无距离限制")
    local nextPhase = PhaseData:new { who = owner, reason = "game_rule", phase = Player.Discard }
    room.logic:trigger(fk.EventPhaseChanging, owner, nextPhase)
    lu.assertNotIsTrue(nextPhase.skipped, "额外回合及后续回合不再跳过弃牌阶段")
  end)
end

function Testqiao_lord_equipment:testShenshouAllianceFromEquipmentAfterOtherTurnEnds()
  local room = FkTest.room
  local owner, target = p(1), p(2)
  local fan, hand, armor, reply
  FkTest.runInRoom(function()
    fan = room:printCard(SHENSHOU, Card.Spade, 5)
    hand = printedAllianceCard(room, "qiao__peach", Card.Diamond, 3)
    armor = printedAllianceCard(room, JINXIU, Card.Spade, 2)
    lu.assertFalse(AllianceCards.isHeji(fan))
    lu.assertFalse(AllianceCards.isHeji(hand))
    give(room, owner, fan)
    -- 神授思召在他人回合进入装备区。
    room.current = target
    room:moveCardTo(fan.id, Card.PlayerEquip, owner, fk.ReasonJustMove,
      "test", nil, true, owner)
    room:moveCardTo(armor.id, Card.PlayerEquip, owner, fk.ReasonJustMove,
      "test", nil, true, owner)
    give(room, owner, hand)

    client_room.run(room, function(clients)
      local me = table.find(clients, function(c) return c.id == owner.id end)
      local to = table.find(clients, function(c) return c.id == target.id end)
      local handler = ReqPlayCard:new(me)
      handler.skill_name = "qiao__alliance"
      handler:setup()
      lu.assertTrue(handler:skillButtonValidity("qiao__alliance"), "有合纵手牌时按钮可用")
      lu.assertNotNil(handler.scene:getAllItems("CardItem")[fan.id],
        "装备区的神授思召应展开到选牌区")
      lu.assertFalse(handler:cardValidity(fan.id), "进入装备区的当回合不能选神授思召")
      lu.assertTrue(handler:cardValidity(hand.id), "当回合仍可正常合纵手牌")
      handler:selectSkill("qiao__alliance", { selected = true })
      handler:selectCard(hand.id, { selected = true })
      lu.assertTrue(handler:targetValidity(to.id), "手牌合纵目标仍然合法")
      handler:selectTarget(to.id, { selected = true })
      lu.assertTrue(handler:feasible(), "当回合手牌合纵可确认")
      handler:_finish()
    end)

    local logs = {}
    local original = room.sendLog
    room.sendLog = function(self, log) table.insert(logs, log) end
    GameEvent.Turn:create(TurnData:new(target, "game_rule", { Player.Finish })):exec()
    room.sendLog = original
    lu.assertEquals(totalInvokeLogs(logs), 0, "他人回合结束清理也应静默")
    lu.assertEquals(owner:getMark(SHENSHOU_ACTIVE), 0, "他人回合结束清除状态")
    room.current = owner
    owner.phase = Player.Play
  end)

  client_room.run(room, function(clients)
    local me = table.find(clients, function(c) return c.id == owner.id end)
    local to = table.find(clients, function(c) return c.id == target.id end)
    lu.assertEquals(me:getMark(SHENSHOU_ACTIVE), 0, "客户端同步到状态已清除")
    local handler = ReqPlayCard:new(me)
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity("qiao__alliance"), "后续回合按钮可用")
    handler:selectSkill("qiao__alliance", { selected = true })
    lu.assertNotNil(handler.scene:getAllItems("CardItem")[fan.id],
      "后续回合装备区牌仍在选牌区")
    lu.assertTrue(handler:cardValidity(fan.id), "后续回合可从装备区选择神授思召")
    lu.assertFalse(handler:cardValidity(armor.id), "其他有合纵标记的装备也不能从装备区选择")
    handler:selectCard(fan.id, { selected = true })
    lu.assertTrue(handler:cardValidity(hand.id), "装备与合纵手牌可继续混选")
    handler:selectCard(hand.id, { selected = true })
    lu.assertTrue(handler:targetValidity(to.id), "混选目标合法")
    handler:selectTarget(to.id, { selected = true })
    lu.assertTrue(handler:feasible(), "装备与手牌混选可确认")
    reply = confirmRequest(handler)
    handler:_finish()
  end)

  FkTest.runInRoom(function()
    local targetHand = #target:getCardIds("h")
    room:handleUseCardReply(owner, reply)
    lu.assertEquals(#target:getCardIds("h"), targetHand + 2, "装备与手牌一同交给目标")
    lu.assertEquals(room:getCardOwner(fan.id).id, target.id, "神授思召进入目标手牌区")
    lu.assertEquals(room:getCardOwner(hand.id).id, target.id, "合纵手牌进入目标手牌区")
  end)
end
function Testqiao_lord_equipment:testShenshouInstalledDuringTurnEndExpiresBeforeNextTurn()
  local room, owner, current = FkTest.room, p(1), p(2)
  local fan
  inRoom(function()
    fan = printedAllianceCard(room, SHENSHOU, Card.Spade, 5)
    local install = fk.CreateSkill { name = "test_shenshou_turn_end_install" }
    install:addEffect(fk.TurnEnd, {
      global = true,
      late_refresh = true,
      can_refresh = function(self, event, target, player)
        return target == current and target == player
      end,
      on_refresh = function()
        room:moveCardTo(fan.id, Card.PlayerEquip, owner, fk.ReasonJustMove, "test")
        lu.assertEquals(owner:getMark(SHENSHOU_ACTIVE), 1)
      end,
    })
    room:addSkill(install:createSkill())
    GameEvent.Turn:create(TurnData:new(current, "game_rule", { Player.Finish })):exec()
    lu.assertEquals(room:getCardArea(fan.id), Card.PlayerEquip)
    lu.assertEquals(owner:getMark(SHENSHOU_ACTIVE), 0)
    lu.assertEquals(#owner:getCardIds("h"), 0, "只有装备区的神授思召可合纵")
    room.current = owner
    owner.phase = Player.Play
    room:broadcastProperty(owner, "phase")
    room:broadcastProperty(owner, "kingdom")
    room:broadcastProperty(current, "kingdom")
  end)
  local reply
  FkTest.runInClient(function()
    local me = ClientInstance:getPlayerById(owner.id)
    local board = assert(Fk:getBoardGame("qiao_heg_mode"))
    local client = board.client_klass:new(ClientInstance.client)
    local handler = client.request_handlers.PlayCard:new(me)
    handler:setup()
    local button = handler.scene:getAllItems("SkillButton")["qiao__alliance"]
    lu.assertNotNil(button, "无合纵手牌时也应显示合纵按钮")
    lu.assertTrue(handler:skillButtonValidity("qiao__alliance"), "仅有神授思召也可点亮按钮")
    handler:selectSkill("qiao__alliance", { selected = true })
    lu.assertTrue(handler:cardValidity(fan.id))
    handler:selectCard(fan.id, { selected = true })
    lu.assertTrue(handler:targetValidity(current.id))
    handler:selectTarget(current.id, { selected = true })
    lu.assertTrue(handler:feasible())
    reply = confirmRequest(handler)
    handler:_finish()
  end)
  inRoom(function() room:handleUseCardReply(owner, reply) end)
  lu.assertIs(room:getCardOwner(fan.id), current)
end

function Testqiao_lord_equipment:testXuehaiWineCanUseRespectsLimitAndSelfTarget()
  local room = FkTest.room
  local owner, helper, other = p(1), p(3), p(4)
  local pot = card(XUEHAI)
  local spade = card("qiao__slash", Card.Spade, 9)
  local result
  FkTest.runInRoom(function()
    give(room, owner, pot)
    use(room, owner, { owner }, pot)
    owner.phase = Player.Play
    room.current = owner
    give(room, helper, spade)
    owner:addCardUseHistory("analeptic", 1)
    FkTest.setNextReplies(helper, { FkTest.ReplyCard(spade) })
    room:handleUseCardReply(owner, FkTest.ReplyUseSkill(XUEHAI_SKILL))
    lu.assertEquals(owner.drank, 0, "普通出牌酒已用尽次数")
    lu.assertTrue(table.contains(helper:getCardIds("h"), spade.id))
    FkTest.setNextReplies(owner, { FkTest.ReplyUseSkill(XUEHAI_SKILL), "" })
    result = room:askToUseCard(owner, {
      pattern = "analeptic|0|nosuit|none",
      skill_name = "qiao__xuehai_mowangzun_skill",
      prompt = "test",
      cancelable = true,
      extra_data = { bypass_times = false },
    })
    lu.assertNil(result, "普通出牌酒已用尽次数，不应询问")
    lu.assertTrue(table.contains(helper:getCardIds("h"), spade.id))

    FkTest.setNextReplies(owner, { FkTest.ReplyUseSkill(XUEHAI_SKILL), "" })
    result = room:askToUseCard(owner, {
      pattern = "analeptic|0|nosuit|none",
      skill_name = "qiao__xuehai_mowangzun_skill",
      prompt = "test",
      cancelable = true,
      extra_data = { must_targets = { other.id }, fix_targets = { other.id } },
    })
    lu.assertNil(result, "酒只能对自己使用，非己目标请求不应询问")
    lu.assertTrue(table.contains(helper:getCardIds("h"), spade.id))
  end)
end

function Testqiao_lord_equipment:testXuehaiRecoverBypassesWineTurnLimit()
  local room = FkTest.room
  local owner, helper = p(1), p(3)
  local pot = card(XUEHAI)
  local spade = card("qiao__slash", Card.Spade, 9)
  local result
  FkTest.runInRoom(function()
    give(room, owner, pot)
    use(room, owner, { owner }, pot)
    owner.phase = Player.Play
    room.current = owner
    give(room, helper, spade)
    owner:addCardUseHistory("analeptic", 1)
    local extra = {
      analepticRecover = true,
      must_targets = { owner.id },
      fix_targets = { owner.id },
      bypass_times = true,
    }
    local reply
    client_room.run(room, function(clients)
      local me = table.find(clients, function(c) return c.id == owner.id end)
      local handler = ReqUseCard:new(me, { "peach", "peach,analeptic", "", true, extra })
      local previous = ClientInstance.current_request_handler
      ClientInstance.current_request_handler = handler
      local ok, err = pcall(function()
        handler:setup()
        lu.assertTrue(handler:skillButtonValidity(XUEHAI_SKILL), "有【酒】自救时可以发动")
        handler:selectSkill(XUEHAI_SKILL, { selected = true })
        lu.assertTrue(handler:feasible())
        reply = confirmRequest(handler)
        handler:_finish()
      end)
      ClientInstance.current_request_handler = previous
      if not ok then error(err, 0) end
    end)
    FkTest.setNextReplies(owner, { reply, "" })
    FkTest.setNextReplies(helper, { FkTest.ReplyCard(spade) })
    result = room:askToUseCard(owner, {
      pattern = "peach,analeptic",
      skill_name = "qiao__xuehai_mowangzun_skill",
      prompt = "test",
      cancelable = true,
      extra_data = extra,
    })
  end)
  lu.assertNotNil(result)
  lu.assertEquals(result.card.name, "analeptic")
  lu.assertEquals(result.tos[1].id, owner.id)
  lu.assertTrue(result.extra_data.analepticRecover)
  lu.assertEquals(room:getCardArea(spade.id), Card.DiscardPile)
end
return { name = "qiao_lord_equipment" }
