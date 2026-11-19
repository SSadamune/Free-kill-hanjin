-- 赤霄剑 / 锦绣征袍 / 虚妄之冕：正式牌包装配与各一条实际入口用例。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local ReqPlayCard = require "ltk.core.request_type.play_card"
local Heg = require "packages.hegemony.util"

local CHIXIAO = "qiao__chixiao_sword"
local JINXIU = "qiao__jinxiu_zhengpao"
local XUWANG = "qiao__xuwang_zhimian"
local ZOUYU = "qiao__zouyu_fan"
local XUEHAI = "qiao__xuehai_mowangzun"
local SHENSHOU = "qiao__shenshou_sizhao"

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
    FkTest.setNextReplies(small, { red.id })
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
  FkTest.runInRoom(function()
    give(room, owner, seal)
    give(room, ally, gift)
    FkTest.setNextReplies(ally, { "1", gift.id })
    use(room, owner, { owner }, seal)
  end)
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
  local handBefore
  FkTest.runInRoom(function()
    give(room, owner, seal)
    use(room, owner, { owner }, seal)
    FkTest.setNextReplies(owner, { "1", "#qiao__zhoujun-draw2" })
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
    FkTest.setNextReplies(owner, { "1" })
    local originalChoice = room.askToChoice
    room.askToChoice = function(self, who, params)
      if params.skill_name == "qiao__zhoujun_lingbingyin_skill" then
        for _, c in ipairs(params.choices or {}) do
          if tostring(c):find("qiao__zhoujun-slash2-draw2", 1, true) then return c end
        end
      end
      return originalChoice(self, who, params)
    end
    room.logic:trigger(fk.EventPhaseStart, owner, { phase = Player.Start })
    room.askToChoice = originalChoice
    local drawData = { n = 2 }
    room.logic:trigger(fk.DrawNCards, owner, drawData)
    lu.assertEquals(drawData.n, 0, "摸牌-2按当前基数足额扣除")
    lu.assertEquals(Fk.skills["slash_skill"]:getMaxUseTime(
      owner, Player.HistoryPhase, Fk:cloneCard("slash")), 3, "出杀+2")
    room.logic:trigger(fk.TurnEnd, owner, {})
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
  end)
end

function Testqiao_lord_equipment:testXuehaiWineRequestUsesSpadeResponse()
  local room = FkTest.room
  local owner, helper, other = p(1), p(3), p(4)
  local pot = card(XUEHAI)
  local spade = card("qiao__slash", Card.Spade, 9)
  local spade2 = card("qiao__slash", Card.Spade, 10)
  local result
  FkTest.runInRoom(function()
    give(room, owner, pot)
    use(room, owner, { owner }, pot)
    owner.phase = Player.Play
    room.current = owner
    give(room, helper, spade)
    give(room, other, spade2)
    FkTest.setNextReplies(owner, { "1" })
    FkTest.setNextReplies(helper, { FkTest.ReplyCard(spade) })
    FkTest.setNextReplies(other, { FkTest.ReplyCard(spade2) })
    result = room:askToUseCard(owner, {
      pattern = "analeptic|0|nosuit|none",
      skill_name = "qiao__xuehai_mowangzun_skill",
      prompt = "test",
      cancelable = false,
    })
  end)
  lu.assertNotNil(result, "协助成功后应返回本次请求的使用结果")
  lu.assertEquals(result.card.name, "analeptic")
  local discarded = 0
  for _, c in ipairs({ spade, spade2 }) do
    if room:getCardArea(c.id) == Card.DiscardPile then discarded = discarded + 1 end
  end
  lu.assertEquals(discarded, 1, "只实际打出一张黑桃牌")
  lu.assertEquals(#helper:getCardIds("h") + #other:getCardIds("h"), 1, "后续候选未被消耗")
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
    FkTest.setNextReplies(target, { red.id })
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
function Testqiao_lord_equipment:testAllianceRealClientButtonMix()
  local room = FkTest.room
  local owner, target = p(1), p(2)
  local fan = card(SHENSHOU)
  local hand = card("qiao__peach", Card.Diamond, 3)
  FkTest.runInRoom(function()
    give(room, owner, fan)
    use(room, owner, { owner }, fan)
    give(room, owner, hand)
    room.logic:trigger(fk.TurnEnd, target, {})
  end)
  client_room.run(room, function(clients)
    local me = table.find(clients, function(c) return c.id == owner.id end)
    local to = table.find(clients, function(c) return c.id == target.id end)
    local handler = ReqPlayCard:new(me)
    handler.skill_name = "qiao__alliance"
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity("qiao__alliance"), "真实客户端按钮应可用")
    handler:selectSkill("qiao__alliance", { selected = true })
    lu.assertTrue(handler:cardValidity(fan.id), "神授装备应可在混选中点亮")
    handler:selectCard(fan.id, { selected = true })
    lu.assertTrue(handler:cardValidity(hand.id), "合纵手牌应可继续混选")
    handler:selectCard(hand.id, { selected = true })
    lu.assertTrue(handler:targetValidity(to.id), "异势力目标应合法")
    handler:selectTarget(to.id, { selected = true })
    lu.assertTrue(handler:feasible(), "混合选择后应可确认")
    handler:_finish()
  end)
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
    owner:setSkillUseHistory("analeptic_skill", 1, Player.HistoryTurn)
    FkTest.setNextReplies(owner, { "1" })
    result = room:askToUseCard(owner, {
      pattern = "analeptic|0|nosuit|none",
      skill_name = "qiao__xuehai_mowangzun_skill",
      prompt = "test",
      cancelable = true,
    })
    lu.assertNil(result, "普通出牌酒已用尽次数，不应询问")
    lu.assertTrue(table.contains(helper:getCardIds("h"), spade.id))

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
    owner:setSkillUseHistory("analeptic_skill", 1, Player.HistoryTurn)
    FkTest.setNextReplies(owner, { "1" })
    FkTest.setNextReplies(helper, { FkTest.ReplyCard(spade) })
    result = room:askToUseCard(owner, {
      pattern = "peach,analeptic",
      skill_name = "qiao__xuehai_mowangzun_skill",
      prompt = "test",
      cancelable = true,
      extra_data = {
        analepticRecover = true,
        must_targets = { owner.id },
        fix_targets = { owner.id },
      },
    })
  end)
  lu.assertNotNil(result)
  lu.assertEquals(result.card.name, "analeptic")
  lu.assertEquals(result.tos[1].id, owner.id)
  lu.assertTrue(result.extra_data.analepticRecover)
  lu.assertEquals(room:getCardArea(spade.id), Card.DiscardPile)
end
return { name = "qiao_lord_equipment" }
