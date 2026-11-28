-- EM(QUN010) 张角君主版：数据、旗计数/大势力修正静态验收；失去体力防止；
-- 非持旗者独立使用/打出旗上的天兵当雷【杀】。
local support = __dofile("../../../tests/support/hegemony.lua")
local fixture = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local ReqUseCard = require "ltk.core.request_type.use_card"
local DATA = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_lord_qun"
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end
local function p(n) return FkTest.room.players[n] end

--- 固定为空白测试将并只给旗；返回所加天兵的 id。
local function installBanner(owner, count, kingdoms)
  local ids
  inRoom(function()
    fixture.installBlankGenerals(FkTest.room, kingdoms or "qun")
    FkTest.room:handleAddLoseSkills(owner, P.BANNER_SKILL, nil, false, true)
    owner.hp = 4
    ids = FkTest.room:getNCards(count)
    P.add(owner, ids, P.BANNER_SKILL)
  end)
  return ids
end

--- 记录雷杀的伤害属性；用于证明结果牌按正式雷杀结算。
local function installThunderProbe()
  local seen = {}
  local skel = fk.CreateSkill { name = "#qiao_test_tianbing_thunder" }
  skel:addEffect(fk.DamageInflicted, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return target == player and data.card ~= nil
        and data.card.name == "qiao__thunder__slash"
    end,
    on_refresh = function(self, event, target, player, data)
      seen[#seen + 1] = data.damageType
    end,
  })
  local instance = skel:createSkill()
  Fk.skills[instance.name] = instance
  inRoom(function() FkTest.room:addSkill(instance) end)
  return seen
end

--- 记录指定牌每次移动的去向区域；用于证明实体天兵实际离开旗牌堆。
local function installMoveProbe(cardId)
  local areas = {}
  local skel = fk.CreateSkill { name = "#qiao_test_tianbing_moves" }
  skel:addEffect(fk.AfterCardsMove, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      return player.seat == 1
    end,
    on_refresh = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        for _, info in ipairs(move.moveInfo or {}) do
          if info.cardId == cardId then
            areas[#areas + 1] = move.toArea
          end
        end
      end
    end,
  })
  local instance = skel:createSkill()
  Fk.skills[instance.name] = instance
  inRoom(function() FkTest.room:addSkill(instance) end)
  return areas
end

--- 正式客户端的出牌请求类：由 qiao_heg_mode 的 board 注册。
local function qiaoPlayCardClass()
  local board = assert(Fk:getBoardGame("qiao_heg_mode"))
  local client = board.client_klass:new(ClientInstance.client)
  return assert(client.request_handlers.PlayCard)
end

--- 用真实 ClientPlayer 按钮/选牌/选目标/确认生成回包；所牌可在其他角色的旗上。
local function clientUseReply(room, user, target, cardId)
  local reply
  client_room.run(room, function(clients)
    local me, to
    for index, original in ipairs(room.players) do
      if original == user then me = clients[index] end
      if original == target then to = clients[index] end
    end
    lu.assertNotNil(me, "缺少使用者客户端副本")
    lu.assertNotNil(to, "缺少目标客户端副本")
    local handler = qiaoPlayCardClass():new(me)
    lu.assertTrue(handler:skillButtonValidity(P.ENTRY), "真实客户端应显示旗入口按钮")
    handler:selectSkill(P.ENTRY, { selected = true })
    lu.assertTrue(handler:cardValidity(cardId), "跨角色旗上的天兵应由真实客户端可点选")
    handler:selectCard(cardId, { selected = true })
    lu.assertTrue(handler:targetValidity(to.id), "范围内目标应可由真实客户端选中")
    handler:selectTarget(to.id, { selected = true })
    lu.assertTrue(handler:feasible(), "合法选择后确认键应可提交")
    reply = {
      card = { skill = P.ENTRY, subcards = table.simpleClone(handler.pendings or {}) },
      targets = table.simpleClone(handler.selected_targets or {}),
    }
    handler:_finish()
  end)
  return reply
end

Testqiao_em_qun010_zhangjiao = {
  setup = function() support.initQiaoRoom() end,
  tearDown = support.clearRoom,
}

function Testqiao_em_qun010_zhangjiao:testDataFragment()
  local general = DATA.generals[1]
  lu.assertEquals(general.id, "qiao_heg__em_qun010")
  lu.assertEquals(DATA.skillCount, 3)
  lu.assertNotNil(Fk.generals["qiao_heg__em_qun010"], "正式将池尚未合入 EM(QUN010)")
  lu.assertEquals(DATA.versions[1].normal, "qiao_heg__qun010")
  lu.assertEquals(Fk:translate("qiao_em_qun010_tianbing"), "天兵", "天兵旗状态栏实际显示键应本地化")
end

function Testqiao_em_qun010_zhangjiao:testTianbingCountAndLargePowerOverlay()
  local lord = p(1)
  inRoom(function()
    fixture.installBlankGenerals(FkTest.room, "qun")
    FkTest.room:handleAddLoseSkills(lord, P.HONGFA, nil, false, true)
    local ids = FkTest.room:getNCards(3)
    P.add(lord, ids, P.BANNER_SKILL)
    lu.assertEquals(P.count(lord), 3)
    local qun = P.kingdomCount(FkTest.room, "qun")
    lu.assertTrue(qun >= 3)
    lu.assertTrue(P.largeCount(FkTest.room) >= qun)
  end)
end

local function checkWendao(payment, armorArea)
  local room, me, other = FkTest.room, p(1), p(2)
  local skill = Fk.skills["qiao__skill_em_qun010_3"]
  local finished = inRoom(function()
    fixture.installBlankGenerals(room, "qun")
    room:handleAddLoseSkills(me, skill.name, nil, false, true)
    me.phase = Player.Play
    me.hp = 3
    room:throwCard(me:getCardIds("he"), "test", me, me)
    -- A copy dealt in the initial hand would otherwise be the first eligible
    -- Peace Spell, before the one whose move is under test.
    local existing = table.filter(room.discard_pile, function(id)
      return Fk:getCardById(id).name == "qiao__peace_spell"
    end)
    if #existing > 0 then room:moveCardTo(existing, Card.Void, nil, fk.ReasonJustMove) end
    local armor = room:printCard("qiao__peace_spell", Card.Heart, 3)
    local cost = payment == "armor" and armor or room:printCard("qiao__jink", Card.Heart, 2)
    room:obtainCard(me, cost, false, fk.ReasonJustMove)
    if armorArea == "other" then room:obtainCard(other, armor, false, fk.ReasonJustMove) end
    if armorArea == "equip" then room:moveCardTo(armor, Card.PlayerEquip, me, fk.ReasonJustMove) end
    lu.assertTrue(skill:canUse(me))
    local use = { from = me, tos = {}, cards = {} }
    room:useSkill(me, skill, function() skill:onUse(room, use) end, use)
    lu.assertEquals(me:usedSkillTimes(skill.name, Player.HistoryPhase), 1)
    lu.assertFalse(skill:canUse(me))
    if payment == "armor" then
      lu.assertTrue(table.contains(me:getCardIds("h"), armor.id))
      if armorArea == "equip" then lu.assertEquals(me.hp, 2) end
    else
      lu.assertEquals(room:getCardArea(cost.id), Card.DiscardPile)
      lu.assertTrue(table.contains(other:getCardIds("h"), armor.id))
    end
    return true
  end)
  lu.assertTrue(finished)
end

function Testqiao_em_qun010_zhangjiao:testWendaoPaysWithoutFindingArmor()
  checkWendao("jink", "other")
end

function Testqiao_em_qun010_zhangjiao:testWendaoRecoversArmorUsedFromHand()
  checkWendao("armor", "hand")
end

function Testqiao_em_qun010_zhangjiao:testWendaoPaysEquippedArmorBeforeObtainingIt()
  checkWendao("armor", "equip")
end

function Testqiao_em_qun010_zhangjiao:testWuxinRealPileChangesAndBigKingdomTies()
 local room=FkTest.room
 local owner=p(1)
 inRoom(function()
  fixture.installBlankGenerals(room,{"qun","qun","qun","wei","wei","wei","shu","shu"})
  room:handleAddLoseSkills(owner,P.HONGFA .. "|qiao__skill_em_qun010_2",nil,false,true)
 end)
 local seen,ids={},nil
 fixture.withSkillRequests(room,"qiao__skill_em_qun010_2",{
  askToSkillInvoke=function() return true end,
  askToGuanxing=function(self,who,params)
   table.insert(seen,#params.cards)
   return {top=params.cards,bottom={}}
  end,
 },function()
  inRoom(function()
   ids=room:getNCards(2)
   P.add(owner,ids)
   P.remove(owner,{ids[1]})
   P.remove(owner,{ids[2]})
  end)
 end)
 lu.assertEquals(seen,{5,6},"增加和减至0各卜算，减少未归0不触发；并列大势力人数累计")
 lu.assertEquals(P.physicalCounts(room).qun,3)
end

function Testqiao_em_qun010_zhangjiao:testPreHpLostSpendsOneTianbingToPreventWholeLoss()
  local room = FkTest.room
  local owner = p(1)
  local ids = installBanner(owner, 3)
  local before = owner.hp
  local asked = 0
  fixture.withSkillRequests(room, P.BANNER_SKILL, {
    askToCards = function(_, _, params)
      asked = asked + 1
      lu.assertEquals(params.skill_name, P.BANNER_SKILL)
      lu.assertEquals(params.expand_pile, P.PILE, "只能从旗牌堆选择天兵")
      lu.assertEquals(params.pattern, ".|.|.|" .. P.PILE)
      lu.assertEquals(params.cancelable, true)
      lu.assertEquals(params.min_num, 1)
      lu.assertEquals(params.max_num, 1)
      return { ids[2] }
    end,
  }, function()
    inRoom(function() room:loseHp(owner, 3, "test") end)
  end)
  lu.assertEquals(asked, 1)
  lu.assertEquals(owner.hp, before, "防止整个多点失去体力事件")
  lu.assertEquals(P.count(owner), 2, "只支付一张天兵")
  lu.assertEquals(room:getCardArea(ids[2]), Card.DiscardPile, "支付走真实旗牌堆移动")
  lu.assertTrue(table.contains(owner:getPile(P.PILE), ids[1]))
  lu.assertTrue(table.contains(owner:getPile(P.PILE), ids[3]))
end

function Testqiao_em_qun010_zhangjiao:testPreHpLostCancelSettlesLossNormally()
  local room = FkTest.room
  local owner = p(1)
  local ids = installBanner(owner, 2)
  local before = owner.hp
  local asked = 0
  fixture.withSkillRequests(room, P.BANNER_SKILL, {
    askToCards = function() asked = asked + 1; return {} end,
  }, function()
    inRoom(function() room:loseHp(owner, 2, "test") end)
  end)
  lu.assertEquals(asked, 1)
  lu.assertEquals(owner.hp, before - 2, "取消后按正常失去体力结算")
  lu.assertEquals(P.count(owner), 2, "取消不支付天兵")
  for _, id in ipairs(ids) do
    lu.assertTrue(table.contains(owner:getPile(P.PILE), id))
  end
end

function Testqiao_em_qun010_zhangjiao:testPreHpLostRejectsChoiceOutsidePile()
  local room = FkTest.room
  local owner = p(1)
  installBanner(owner, 2)
  local outsider
  inRoom(function()
    local card = room:printCard("qiao__jink", Card.Heart, 2)
    room:obtainCard(owner, card, false, fk.ReasonJustMove)
    outsider = card.id
  end)
  local before = owner.hp
  fixture.withSkillRequests(room, P.BANNER_SKILL, {
    askToCards = function() return { outsider } end,
  }, function()
    inRoom(function() room:loseHp(owner, 2, "test") end)
  end)
  lu.assertEquals(owner.hp, before - 2, "非旗牌堆的返回牌不是有效支付")
  lu.assertEquals(P.count(owner), 2)
  lu.assertEquals(room:getCardArea(outsider), Card.PlayerHand)
end

function Testqiao_em_qun010_zhangjiao:testDamageDoesNotConsumeTianbing()
  local room = FkTest.room
  local owner = p(1)
  local ids = installBanner(owner, 2)
  local before = owner.hp
  local asked = 0
  fixture.withSkillRequests(room, P.BANNER_SKILL, {
    askToCards = function() asked = asked + 1; return {} end,
  }, function()
    inRoom(function() room:damage{from = p(2), to = owner, damage = 2} end)
  end)
  lu.assertEquals(asked, 0, "伤害不经过失去体力时机")
  lu.assertEquals(owner.hp, before - 2)
  lu.assertEquals(P.count(owner), 2)
  for _, id in ipairs(ids) do
    lu.assertTrue(table.contains(owner:getPile(P.PILE), id))
  end
end

-- 同步发生在弘法无效期间。恢复后直接进入原用牌/响应请求，中间不靠回合开始补发入口。
local function restoreAfterKingdomChanges(owner, count)
  local room = FkTest.room
  return inRoom(function()
    fixture.installBlankGenerals(room, { "qun", "qun", "wei", "qun", "wei", "wu", "jin", "han" })
    room:handleAddLoseSkills(owner, P.HONGFA, nil, false, true)
    local ids = room:getNCards(count)
    P.add(owner, ids, P.BANNER_SKILL)
    room:invalidateSkill(owner, P.HONGFA)
    room:changeKingdom(p(3), "qun")
    room:changeKingdom(p(4), "wei")
    lu.assertEquals(P.tianbingIds(room), {})
    lu.assertEquals(P.kingdomCount(room, "qun"), 3)
    for _, member in ipairs({ p(2), p(3) }) do
      lu.assertNil(Fk.skills[P.ENTRY]:viewAs(member, { ids[1] }))
      lu.assertFalse(Fk.skills[P.ENTRY]:enabledAtResponse(member, false))
    end
    room:validateSkill(owner, P.HONGFA)
    lu.assertTrue(p(2):hasSkill(P.ENTRY), "原群角色应立即有入口")
    lu.assertTrue(p(3):hasSkill(P.ENTRY), "新群角色应立即有入口")
    lu.assertFalse(p(4):hasSkill(P.ENTRY), "已离开群势力的角色不再有入口")
    lu.assertEquals(P.kingdomCount(room, "qun"), 3 + count)
    return ids
  end)
end

function Testqiao_em_qun010_zhangjiao:testNonHolderUsesTianbingImmediatelyAfterHongfaRestores()
  local room = FkTest.room
  local owner, user, target = p(1), p(2), p(3)
  inRoom(function()
    target.hp = target.maxHp
    room.current = user
    user.phase = Player.Play
  end)
  local ids = restoreAfterKingdomChanges(owner, 3)
  local chosen = ids[2]
  local thunder = installThunderProbe()
  local moves = installMoveProbe(chosen)
  local reply = clientUseReply(room, user, target, chosen)
  FkTest.setNextReplies(user, { reply })
  local use = inRoom(function()
    return room:askToUseCard(user, {
      pattern = "slash", skill_name = P.ENTRY, cancelable = true,
    })
  end)
  lu.assertNotNil(use, "真实请求应接受非持旗者的旗入口回包")
  lu.assertEquals(use.card.name, "qiao__thunder__slash")
  lu.assertEquals(use.card.skillName, P.ENTRY)
  lu.assertEquals(Card:getIdList(use.card), { chosen })
  lu.assertTrue(table.contains(owner:getPile(P.PILE), chosen), "确认前实体天兵仍在旗上")
  inRoom(function() room:useCard(use) end)
  lu.assertEquals(thunder, { fk.ThunderDamage }, "应造成雷电伤害")
  lu.assertEquals(target.hp, target.maxHp - 1)
  lu.assertTrue(table.contains(moves, Card.Processing), "实体天兵先从旗进入处理区")
  lu.assertEquals(moves[#moves], Card.DiscardPile, "结算后进入弃牌堆")
  lu.assertEquals(room:getCardArea(chosen), Card.DiscardPile)
  lu.assertFalse(table.contains(owner:getPile(P.PILE), chosen))
  lu.assertEquals(P.count(owner), 2)
end

function Testqiao_em_qun010_zhangjiao:testNewQunMemberRespondsImmediatelyAfterHongfaRestores()
  local room = FkTest.room
  local owner, user = p(1), p(3)
  local ids = restoreAfterKingdomChanges(owner, 2)
  local chosen = ids[1]
  local moves = installMoveProbe(chosen)
  FkTest.setNextReplies(user, {
    { card = { skill = P.ENTRY, subcards = { chosen } }, targets = {} },
  })
  local response = inRoom(function()
    return room:askToResponse(user, {
      pattern = "slash", skill_name = P.ENTRY, cancelable = true,
    })
  end)
  lu.assertNotNil(response, "非持旗者应能以旗上一张天兵响应打出")
  lu.assertEquals(response.card.name, "qiao__thunder__slash")
  lu.assertEquals(Card:getIdList(response.card), { chosen })
  lu.assertTrue(table.contains(owner:getPile(P.PILE), chosen), "确认前实体天兵仍在旗上")
  inRoom(function() room:responseCard(response) end)
  lu.assertTrue(table.contains(moves, Card.Processing), "打出的实体天兵先进入处理区")
  lu.assertEquals(moves[#moves], Card.DiscardPile, "打出后进入弃牌堆")
  lu.assertEquals(room:getCardArea(chosen), Card.DiscardPile)
  lu.assertFalse(table.contains(owner:getPile(P.PILE), chosen))
  lu.assertEquals(P.count(owner), 1)
end

function Testqiao_em_qun010_zhangjiao:testFlagEntryFollowsKingdomAndFlagLoss()
  local room = FkTest.room
  local owner, member, outsider, other, preserved = p(1), p(2), p(5), p(3), p(4)
  local ids = installBanner(owner, 3,
    { "qun", "qun", "qun", "qun", "wei", "wei", "shu", "shu" })
  lu.assertTrue(member:hasSkill(P.ENTRY), "同势力非持旗者获得入口")
  lu.assertFalse(outsider:hasSkill(P.ENTRY), "异势力不获得入口")

  inRoom(function() room:changeKingdom(outsider, "qun") end)
  lu.assertTrue(outsider:hasSkill(P.ENTRY), "转为群势力后应动态获得入口")
  inRoom(function() room:changeKingdom(member, "wei") end)
  lu.assertFalse(member:hasSkill(P.ENTRY), "转为其他势力后应撤回入口")
  lu.assertTrue(other:hasSkill(P.ENTRY), "其他群势力角色的入口不受影响")

  local hand
  inRoom(function()
    local card = room:printCard("qiao__jink", Card.Heart, 3)
    room:obtainCard(other, card, false, fk.ReasonJustMove)
    hand = card.id
    room.current = other
    other.phase = Player.Play
  end)
  client_room.run(room, function(clients)
    local me = clients[3]
    local use = ReqUseCard:new(me)
    use.pattern = "jink"
    lu.assertFalse(use:skillButtonValidity(P.ENTRY), "非法牌名模式不应显示入口")
    use.pattern = "slash"
    lu.assertTrue(use:skillButtonValidity(P.ENTRY), "杀类请求应显示入口")
    use:_finish()

    local play = qiaoPlayCardClass():new(me)
    lu.assertTrue(play:skillButtonValidity(P.ENTRY), "出牌阶段按钮应可用")
    play:selectSkill(P.ENTRY, { selected = true })
    lu.assertTrue(play:cardValidity(ids[1]), "旗上天兵可选")
    lu.assertFalse(play:cardValidity(hand), "普通手牌不能作为旗上天兵")
    play:selectCard(ids[1], { selected = true })
    lu.assertFalse(play:feasible(), "没有合法目标时确认键不可提交")
    local near, far = clients[4], clients[8]
    lu.assertTrue(play:targetValidity(near.id), "攻击范围内目标可选")
    lu.assertFalse(play:targetValidity(far.id), "攻击范围外目标不可提交")
    play:selectTarget(near.id, { selected = true })
    lu.assertTrue(play:feasible(), "有合法目标时确认键应可用")
    play:_finish()
  end)

  inRoom(function()
    lu.assertNotNil(Fk.skills[P.ENTRY]:viewAs(other, { ids[3] }))
    -- 独立来源：先给 p4 另一份入口来源，再触发一次同步，旗只追加自己的来源。
    local sourceSkel = fk.CreateSkill { name = "#qiao_test_tianbing_source" }
    local source = sourceSkel:createSkill()
    Fk.skills[source.name] = source
    preserved:addSkill(P.ENTRY, source)
    room.logic:trigger(fk.AfterPropertyChange, preserved, {})
    local derived = preserved.derivative_skills[Fk.skills[P.BANNER_SKILL]] or {}
    lu.assertTrue(table.contains(derived, Fk.skills[P.ENTRY]),
      "已有其他来源时，旗仍应记录自己的入口来源而不吞并")
    room:handleAddLoseSkills(owner, "-" .. P.BANNER_SKILL)
  end)
  lu.assertFalse(owner:hasSkill(P.BANNER_SKILL), "旗应已失去")
  lu.assertFalse(other:hasSkill(P.ENTRY), "旗消失后仅由旗授予的入口应撤回")
  lu.assertTrue(preserved:hasSkill(P.ENTRY), "独立来源的入口应保留")
  lu.assertFalse(table.contains(
    preserved.derivative_skills[Fk.skills[P.BANNER_SKILL]] or {}, Fk.skills[P.ENTRY]),
    "旗来源应只撤回自己那份")
  lu.assertEquals(P.flagHolders(room), {})
  lu.assertEquals(P.tianbingIds(room), {})
  inRoom(function()
    for _, id in ipairs(ids) do
      lu.assertEquals(room:getCardArea(id), Card.DiscardPile, "旗失去时天兵移入弃牌堆")
    end
    lu.assertNil(Fk.skills[P.ENTRY]:viewAs(other, { ids[3] }), "旗消失后不能再用旗上的牌转化")
  end)
end

function Testqiao_em_qun010_zhangjiao:testWuxinCountsLoneJadeSealHolder()
  local room, lord, holder = FkTest.room, p(1), p(7)
  local seen
  inRoom(function()
    fixture.installBlankGenerals(room, {"qun","qun","qun","wei","wei","wu","shu","jin"})
    local wuxin = "qiao__skill_em_qun010_2"
    room:handleAddLoseSkills(lord, P.HONGFA .. "|" .. wuxin, nil, false, true)
    local seal = room:printCard("qiao__jade_seal", Card.Heart, 2)
    room:moveCardTo(seal, Card.PlayerEquip, holder, fk.ReasonJustMove)
    fixture.withSkillRequests(room, wuxin, {
      askToSkillInvoke = function() return true end,
      askToGuanxing = function(_, _, params)
        seen = #params.cards
        return {top = params.cards, bottom = {}}
      end,
    }, function() P.add(lord, room:getNCards(1)) end)
  end)
  lu.assertEquals(seen, 1)
end

function Testqiao_em_qun010_zhangjiao:testHongfaInvalidationAndLoss()
  local room, lord, ally = FkTest.room, p(1), p(2)
  local finished = inRoom(function()
    fixture.installBlankGenerals(room, {"qun","qun","wei","wei","shu","wu","jin","han"})
    room:handleAddLoseSkills(lord, P.HONGFA, nil, false, true)
    local ids = room:getNCards(2)
    P.add(lord, ids)
    room:invalidateSkill(lord, P.HONGFA)
    lu.assertEquals(P.kingdomCount(room, "qun"), 2)
    lu.assertNil(Fk.skills[P.ENTRY]:viewAs(ally, {ids[1]}))
    local hp = lord.hp
    fixture.withSkillRequests(room, P.BANNER_SKILL, {
      askToCards = function() error("弘法无效期间不能请移天兵") end,
    }, function() room:loseHp(lord, 1) end)
    lu.assertEquals(lord.hp, hp - 1)
    lu.assertEquals(P.count(lord), 2)
    room:validateSkill(lord, P.HONGFA)
    lu.assertEquals(P.kingdomCount(room, "qun"), 4)
    lu.assertNotNil(Fk.skills[P.ENTRY]:viewAs(ally, {ids[1]}))
    room:handleAddLoseSkills(lord, "-" .. P.HONGFA, nil, false, true)
    lu.assertEquals(P.kingdomCount(room, "qun"), 2)
    lu.assertEquals(P.tianbingIds(room), {})
    lu.assertFalse(ally:hasSkill(P.ENTRY, true))
    for _, id in ipairs(ids) do lu.assertEquals(room:getCardArea(id), Card.DiscardPile) end
    return true
  end)
  lu.assertTrue(finished)
end

return { name = "qiao_em_qun010_zhangjiao" }
