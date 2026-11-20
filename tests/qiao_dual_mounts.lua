-- 六龙骖驾 / 临筱玉舆 / 飞云盖海 双副类别坐骑：双栏占用、正常使用替换、
-- 直接置入空栏要求、动态距离与进出装备区触发。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local QiaoClient = require "packages.qiao.pkg.qiao_mode.client"

local SIX = "qiao__liulongcanjia"
local LIN = "qiao__linxiao_yuyu"
local FEIYUN = "qiao__feiyun_gaihai"
local CHITU = "qiao__chitu"
local JUEYING = "qiao__jueying"

local SIX_SKILL = "qiao__liulongcanjia_skill"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room:getPlayerById(n) end

Testqiao_dual_mounts = {
  setup = function()
    local room = support.initQiaoRoom()
    inRoom(function()
      skill_test.installBlankGenerals(room, { "wei", "jin", "wu", "shu", "qun", "han", "jin", "wu" })
      room.current = room.players[1]
    end)
  end,
  tearDown = support.clearRoom,
}

--- 直接置入空装备栏（不是使用装备牌）。
local function place(player, name, suit, number)
  local card
  inRoom(function()
    card = FkTest.room:printCard(name, suit or Card.Heart, number or 5)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
    FkTest.room:moveCardIntoEquip(player, card, "test", false, player)
  end)
  return card
end

--- 正常使用装备牌；当前回合角色由用例自行设置。
local function use(player, card)
  inRoom(function()
    FkTest.room:useCard {
      from = player, tos = { player }, card = Fk:getCardById(card.id),
    }
  end)
end

local function toHand(player, name, suit, number)
  local card
  inRoom(function()
    card = FkTest.room:printCard(name, suit or Card.Heart, number or 5)
    FkTest.room:obtainCard(player, card, false, fk.ReasonJustMove)
  end)
  return card
end

function Testqiao_dual_mounts:testDualMountOccupiesBothSlotsAndReplacesBothWhenUsed()
  local room, user = FkTest.room, p(1)
  local offensive, defensive, six
  inRoom(function()
    offensive = FkTest.room:printCard(CHITU, Card.Heart, 5)
    defensive = FkTest.room:printCard(JUEYING, Card.Spade, 5)
    FkTest.room:moveCardIntoEquip(user, offensive, "test", false, user)
    FkTest.room:moveCardIntoEquip(user, defensive, "test", false, user)
    six = FkTest.room:printCard(SIX, Card.Heart, 13)
    FkTest.room:obtainCard(user, six, false, fk.ReasonJustMove)
  end)
  use(user, six)
  inRoom(function()
    lu.assertEquals(room:getCardArea(six.id), Card.PlayerEquip)
    lu.assertEquals(room:getCardArea(offensive.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(defensive.id), Card.DiscardPile)
    lu.assertEquals(user:getEquipments(Card.SubtypeOffensiveRide), { six.id },
      "双副类别坐骑同时占用进攻坐骑栏")
    lu.assertEquals(user:getEquipments(Card.SubtypeDefensiveRide), { six.id },
      "双副类别坐骑同时占用防御坐骑栏")
    lu.assertFalse(user:hasEmptyEquipSlot(Card.SubtypeOffensiveRide))
    lu.assertFalse(user:hasEmptyEquipSlot(Card.SubtypeDefensiveRide))
  end)
end

function Testqiao_dual_mounts:testSingleMountReplacesDualAndFreesTheOtherSlot()
  local room, user = FkTest.room, p(1)
  local six = place(user, SIX, Card.Heart, 13)
  local chitu = toHand(user, CHITU, Card.Heart, 6)
  use(user, chitu)
  inRoom(function()
    lu.assertEquals(room:getCardArea(chitu.id), Card.PlayerEquip)
    lu.assertEquals(room:getCardArea(six.id), Card.DiscardPile,
      "正常使用单栏坐骑替换占据该栏的双栏坐骑")
    lu.assertEquals(user:getEquipments(Card.SubtypeOffensiveRide), { chitu.id })
    lu.assertEquals(#user:getEquipments(Card.SubtypeDefensiveRide), 0,
      "双栏坐骑只移动一次，另一栏随之腾空")
    lu.assertTrue(user:hasEmptyEquipSlot(Card.SubtypeDefensiveRide))
  end)
end

function Testqiao_dual_mounts:testDirectPlacementRequiresEmptyDualSlots()
  local room, user = FkTest.room, p(1)
  local chitu = place(user, CHITU, Card.Heart, 7)
  local six = toHand(user, SIX, Card.Heart, 13)
  inRoom(function()
    -- 直接置入不是使用装备牌：不能顶掉任一已有坐骑。
    room:moveCardTo(six.id, Card.PlayerEquip, user, fk.ReasonPut,
      "test", nil, true, user)
  end)
  inRoom(function()
    lu.assertEquals(room:getCardArea(six.id), Card.PlayerHand, "占用任一坐骑栏时不能直接置入")
    lu.assertEquals(room:getCardArea(chitu.id), Card.PlayerEquip)
    -- 同批其他牌不受影响。
    local peach = room:printCard("qiao__peach", Card.Heart, 2)
    room:obtainCard(user, peach, false, fk.ReasonJustMove)
    room:moveCards(
      { ids = { six.id }, from = user, to = user, toArea = Card.PlayerEquip, moveReason = fk.ReasonPut },
      { ids = { peach.id }, from = user, toArea = Card.DiscardPile,
        moveReason = fk.ReasonPutIntoDiscardPile }
    )
    lu.assertEquals(room:getCardArea(six.id), Card.PlayerHand, "非法置入不移动目标牌")
    lu.assertEquals(room:getCardArea(peach.id), Card.DiscardPile, "同批其他牌仍正常移动")
    lu.assertEquals(room:getCardArea(chitu.id), Card.PlayerEquip, "原坐骑不被替换")
    room:moveCardTo(chitu.id, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      "test", nil, true, user)
    room:moveCardIntoEquip(user, six, "test", false, user)
    lu.assertEquals(room:getCardArea(six.id), Card.PlayerEquip, "两栏均空后可以置入")
  end)
end

function Testqiao_dual_mounts:testLinxiaoEnterWithReplacementRecoversCurrentTurn()
  local room, user, current = FkTest.room, p(1), p(2)
  local lin, offensive, defensive
  inRoom(function()
    offensive = FkTest.room:printCard(CHITU, Card.Heart, 6)
    defensive = FkTest.room:printCard(JUEYING, Card.Spade, 6)
    FkTest.room:moveCardIntoEquip(user, offensive, "test", false, user)
    FkTest.room:moveCardIntoEquip(user, defensive, "test", false, user)
    lin = FkTest.room:printCard(LIN, Card.Spade, 5)
    FkTest.room:obtainCard(user, lin, false, fk.ReasonJustMove)
    current.hp = current.maxHp - 1
    FkTest.room.current = current
    FkTest.room:useCard { from = user, tos = { user }, card = Fk:getCardById(lin.id) }
  end)
  inRoom(function()
    lu.assertEquals(room:getCardArea(lin.id), Card.PlayerEquip)
    lu.assertEquals(room:getCardArea(offensive.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(defensive.id), Card.DiscardPile)
    lu.assertEquals(current.hp, current.maxHp, "同次进出实际替换坐骑时当前回合角色回复1")
  end)
end

function Testqiao_dual_mounts:testLinxiaoDirectEntryDrawsAndLeavingDraws()
  local room, user, current = FkTest.room, p(1), p(2)
  local lin
  local handBefore
  inRoom(function()
    current.hp = current.maxHp - 1
    FkTest.room.current = current
    lin = FkTest.room:printCard(LIN, Card.Spade, 5)
    FkTest.room:obtainCard(user, lin, false, fk.ReasonJustMove)
    handBefore = #current:getCardIds("h")
    FkTest.room:moveCardIntoEquip(user, lin, "test", false, user)
    lu.assertEquals(#current:getCardIds("h"), handBefore + 1, "进入空装备区由当前回合角色摸1")
    lu.assertEquals(current.hp, current.maxHp - 1, "未替换坐骑不回复")
    handBefore = #current:getCardIds("h")
    FkTest.room:moveCardTo(lin.id, Card.DiscardPile, nil, fk.ReasonPutIntoDiscardPile,
      "test", nil, true, user)
    lu.assertEquals(#current:getCardIds("h"), handBefore + 1, "由装备区进入非装备区由当前回合角色摸1")
  end)
end

function Testqiao_dual_mounts:testNormalMountReplacingLinxiaoRecoversOnce()
  local room, user, current = FkTest.room, p(1), p(2)
  local lin = place(user, LIN, Card.Spade, 5)
  local chitu = toHand(user, CHITU, Card.Heart, 8)
  inRoom(function()
    current.hp = current.maxHp - 1
    room.current = current
  end)
  use(user, chitu)
  inRoom(function()
    lu.assertEquals(room:getCardArea(chitu.id), Card.PlayerEquip)
    lu.assertEquals(room:getCardArea(lin.id), Card.DiscardPile)
    lu.assertEquals(current.hp, current.maxHp, "普通坐骑换下临筱玉舆由当前回合角色回复一次")
  end)
end

function Testqiao_dual_mounts:testSixDragonsDynamicXAndHiddenHolder()
  local room, user, other, ally = FkTest.room, p(1), p(2), p(3)
  local six = place(user, SIX, Card.Heart, 13)
  local function outBase() return user:distanceTo(other, nil, nil, nil, { SIX_SKILL }) end
  local function inBase() return other:distanceTo(user, nil, nil, nil, { SIX_SKILL }) end
  inRoom(function()
    lu.assertEquals(user:distanceTo(other), math.max(1, outBase() - 1), "只有自己的六龙骖驾时X=1")
    lu.assertEquals(other:distanceTo(user), inBase() + 1)
    -- 另一名同势力角色的坐骑也计入 X。
    user.kingdom = "wei"
    room:setPlayerProperty(user, "kingdom", "wei")
    ally.kingdom = "wei"
    room:setPlayerProperty(ally, "kingdom", "wei")
  end)
  place(ally, CHITU, Card.Heart, 9)
  inRoom(function()
    lu.assertEquals(user:distanceTo(other), math.max(1, outBase() - 2), "同势力坐骑各计一张")
    lu.assertEquals(other:distanceTo(user), inBase() + 2)
    -- 全暗且势力尚未确定时只计自身的六龙骖驾。
    user.kingdom = "unknown"
    room:setPlayerProperty(user, "kingdom", "unknown")
    lu.assertEquals(user:distanceTo(other), math.max(1, outBase() - 1))
    lu.assertEquals(other:distanceTo(user), inBase() + 1)
  end)
  lu.assertEquals(room:getCardArea(six.id), Card.PlayerEquip)
end

function Testqiao_dual_mounts:testSixDragonsExcludesDeadRemovedAndSeparatesWild()
  local room, user, other, ally = FkTest.room, p(1), p(5), p(3)
  inRoom(function()
    user.kingdom = "wei"
    room:setPlayerProperty(user, "kingdom", "wei")
    ally.kingdom = "wei"
    room:setPlayerProperty(ally, "kingdom", "wei")
  end)
  local six = place(user, SIX, Card.Heart, 13)
  place(ally, CHITU, Card.Heart, 9)
  local function outBase() return user:distanceTo(other, nil, nil, nil, { SIX_SKILL }) end
  local function inBase() return other:distanceTo(user, nil, nil, nil, { SIX_SKILL }) end
  inRoom(function()
    lu.assertEquals(user:distanceTo(other), math.max(1, outBase() - 2), "同势力坐骑各计一张")
    lu.assertEquals(other:distanceTo(user), inBase() + 2)
    room:setPlayerMark(ally, MarkEnum.PlayerRemoved, 1)
    lu.assertEquals(user:distanceTo(other), math.max(1, outBase() - 1), "移出游戏的角色不计入")
    lu.assertEquals(other:distanceTo(user), inBase() + 1)
    room:setPlayerMark(ally, MarkEnum.PlayerRemoved, 0)
    ally.dead = true
    lu.assertEquals(user:distanceTo(other), math.max(1, outBase() - 1), "死亡角色不计入")
    lu.assertEquals(other:distanceTo(user), inBase() + 1)
    ally.dead = false
    -- 野心家按已确定的势力角色区分，不把所有 wild 合并。
    user.kingdom = "wild"
    user.role = "wei"
    ally.kingdom = "wild"
    ally.role = "shu"
    lu.assertEquals(user:distanceTo(other), math.max(1, outBase() - 1), "不同角色的野心家不同势力")
    lu.assertEquals(other:distanceTo(user), inBase() + 1)
  end)
end

function Testqiao_dual_mounts:testDualUseRequiresBothRideSlots()
  local room, user = FkTest.room, p(1)
  local six, chitu
  inRoom(function()
    room:abortPlayerArea(user, Player.DefensiveRideSlot)
    six = room:printCard(SIX, Card.Heart, 13)
    room:obtainCard(user, six, false, fk.ReasonJustMove)
    chitu = room:printCard(CHITU, Card.Heart, 6)
    room:obtainCard(user, chitu, false, fk.ReasonJustMove)
    lu.assertFalse(user:canUse(Fk:getCardById(six.id)),
      "任一坐骑栏被封印时不能使用双副类别坐骑")
    lu.assertTrue(user:canUse(Fk:getCardById(chitu.id)),
      "普通单栏坐骑的可用性不受双副类别规则影响")
    -- 绕过来源检查直接结算时，装备端仍须复核两栏。
    room:useCard { from = user, tos = { user }, card = Fk:getCardById(six.id) }
  end)
  inRoom(function()
    lu.assertNotEquals(room:getCardArea(six.id), Card.PlayerEquip,
      "结算端不得把双副类别坐骑装备到被封印的栏位")
  end)
end

function Testqiao_dual_mounts:testLinxiaoUnrelatedSameBatchMoveDraws()
  local room, user, rider, current = FkTest.room, p(1), p(2), p(2)
  local lin = place(user, LIN, Card.Spade, 5)
  local chitu = place(rider, CHITU, Card.Heart, 10)
  local handBefore
  inRoom(function()
    current.hp = current.maxHp - 1
    room.current = current
    handBefore = #current:getCardIds("h")
    room:moveCards(
      { ids = { lin.id }, from = user, toArea = Card.DiscardPile,
        moveReason = fk.ReasonPutIntoDiscardPile, skillName = "test_unrelated" },
      { ids = { chitu.id }, from = rider, to = user, toArea = Card.PlayerEquip,
        moveReason = fk.ReasonUse }
    )
    lu.assertEquals(#current:getCardIds("h"), handBefore + 1,
      "同批无关的坐骑移动不构成替换，摸1")
    lu.assertEquals(current.hp, current.maxHp - 1, "无关同批移动不回复")
  end)
  inRoom(function()
    lu.assertEquals(room:getCardArea(lin.id), Card.DiscardPile)
    lu.assertEquals(room:getCardArea(chitu.id), Card.PlayerEquip)
  end)
end

function Testqiao_dual_mounts:testLinxiaoReplacedBySameNameLinxiaoRecovers()
  local room, user, current = FkTest.room, p(1), p(2)
  local first = place(user, LIN, Card.Spade, 5)
  local second
  inRoom(function()
    current.hp = current.maxHp - 1
    room.current = current
    second = room:printCard(LIN, Card.Spade, 5)
    room:obtainCard(user, second, false, fk.ReasonJustMove)
    room:useCard { from = user, tos = { user }, card = Fk:getCardById(second.id) }
  end)
  inRoom(function()
    lu.assertEquals(room:getCardArea(second.id), Card.PlayerEquip)
    lu.assertEquals(room:getCardArea(first.id), Card.DiscardPile)
    lu.assertEquals(current.hp, current.maxHp,
      "另一张同名临筱玉舆换下时按实际替换回复")
  end)
end

function Testqiao_dual_mounts:testFeiyunUsesOnlyTheApplicableDirection()
  local room, user, other = FkTest.room, p(1), p(2)
  local baseForward, baseBackward
  inRoom(function()
    baseForward = user:distanceTo(other)
    baseBackward = other:distanceTo(user)
  end)
  place(user, FEIYUN, Card.Diamond, 13)
  inRoom(function()
    lu.assertEquals(user:distanceTo(other), math.max(1, baseForward - 2), "未横置时只减自身到其他角色")
    lu.assertEquals(other:distanceTo(user), baseBackward, "未横置时不增加他人到自身")
    user:setChainState(true)
    lu.assertEquals(user:distanceTo(other), baseForward, "横置后不再减少自身到其他角色")
    lu.assertEquals(other:distanceTo(user), baseBackward + 2, "横置时只增加他人到自身")
    user:setChainState(false)
    lu.assertEquals(user:distanceTo(other), math.max(1, baseForward - 2), "重置即时恢复")
    lu.assertEquals(other:distanceTo(user), baseBackward)
  end)
end

function Testqiao_dual_mounts:testFormalPackageLoadsAndTemplateEntitySync()
  local pack = Fk.packages.qiao_cards
  lu.assertNotNil(pack, "正式卡包必须加载")
  local qiao = pack.qiao_cards
  lu.assertNotNil(qiao)
  local entities = {}
  for _, card in ipairs(pack.cards) do
    if card.name == SIX or card.name == LIN or card.name == FEIYUN then
      entities[card.name] = card
    end
  end
  for _, name in ipairs({ SIX, LIN, FEIYUN }) do
    local template = Fk.all_card_types[name]
    local entity = entities[name]
    lu.assertNotNil(template, "缺少卡牌模板 " .. name)
    lu.assertNotNil(entity, "缺少实体牌 " .. name)
    lu.assertEquals(template.sub_type, entity.sub_type)
    lu.assertEquals(template.skill.name, entity.skill.name)
    lu.assertEquals(template.equip_skill.name, entity.equip_skill.name)
    lu.assertEquals(#entity.extra_data.qiao_subtypes, 2, "实体牌须登记双副类别")
    lu.assertEquals(#template.extra_data.qiao_subtypes, 2)
    lu.assertTrue(qiao.isDualMount(entity))
    lu.assertTrue(Fk:translate(":" .. name):find("进攻坐骑") ~= nil, "牌面须为双副类别坐骑")
  end
  lu.assertEquals(entities[SIX].equip_skill.name, "qiao__liulongcanjia_skill")
  lu.assertEquals(entities[LIN].equip_skill.name, "qiao__linxiao_yuyu_skill")
  lu.assertEquals(entities[FEIYUN].equip_skill.name, "qiao__feiyun_gaihai_skill")
end

function Testqiao_dual_mounts:testClientDistanceUsesPublicRoomState()
  local room, user, other, ally = FkTest.room, p(1), p(2), p(3)
  inRoom(function()
    room:setPlayerProperty(user, "kingdom", "wei")
    room:setPlayerProperty(ally, "kingdom", "wei")
  end)
  local six = place(user, SIX, Card.Heart, 13)
  local chitu = place(ally, CHITU)
  local jueying = place(ally, JUEYING)
  local jade = place(p(4), LIN)
  local feiyun = place(p(5), FEIYUN)
  local function delta(from, to)
    return from:distanceTo(to) - from:distanceTo(to, nil, nil, nil, { SIX_SKILL })
  end
  local serverForward = delta(user, other)
  local serverBackward = delta(other, user)

  local ClientPlayer = require "ltk.client.clientplayer"
  local clients, byId = {}, {}
  for _, original in ipairs(room.players) do
    local copy = ClientPlayer:new(original._splayer)
    for key, value in pairs(original) do
      if key ~= "room" and key ~= "class" and key ~= "serverplayer" then copy[key] = value end
    end
    local cards = {}
    for area, ids in pairs(copy.player_cards or {}) do cards[area] = table.simpleClone(ids) end
    copy.player_cards = cards
    table.insert(clients, copy)
    byId[copy.id] = copy
  end
  for _, original in ipairs(room.players) do
    local copy = byId[original.id]
    copy.next = original.next and byId[original.next.id] or copy
  end
  local clientRoom = setmetatable(
    { players = clients, alive_players = clients, current = byId[room.current.id] },
    { __index = room })
  local originalRoom = Fk.currentRoom
  Fk.currentRoom = function() return clientRoom end
  local ok, err = pcall(function()
    lu.assertNil(byId[user.id].room, "ClientPlayer 不应有服务端 room 字段")
    lu.assertEquals(delta(byId[user.id], byId[other.id]), serverForward,
      "客户端距离查询与公开状态一致")
    lu.assertEquals(delta(byId[other.id], byId[user.id]), serverBackward)
    local function labels() return QiaoClient.mountDistanceLabels(clientRoom) end
    lu.assertEquals(labels(), {
      [tostring(six.id)] = "±3",
      [tostring(chitu.id)] = "-1",
      [tostring(jueying.id)] = "+1",
      [tostring(jade.id)] = "±1",
      [tostring(feiyun.id)] = "-2",
    })
    byId[p(5).id].chained = true
    lu.assertEquals(labels()[tostring(feiyun.id)], "+2")
    byId[ally.id].player_cards[Player.Equip] = { jueying.id }
    lu.assertEquals(labels()[tostring(six.id)], "±2")
    lu.assertNil(labels()[tostring(chitu.id)])
    byId[ally.id].dead = true
    lu.assertEquals(labels()[tostring(six.id)], "±1")
    lu.assertEquals(labels()[tostring(jueying.id)], "0")
  end)
  Fk.currentRoom = originalRoom
  if not ok then error(err) end
end

return { name = "qiao_dual_mounts" }
