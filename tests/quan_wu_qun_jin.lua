-- 六势力权包回归（下）：吴/群/晋六将与偏将胡车儿（限一）。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")

local H = require "packages.hegemony.util"
local Junling = require "packages.qiao.pkg.qiao_mode.rules.junling"
local SkillStatus = require "packages.qiao.pkg.qiao_mode.skill_status"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"
local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"
local Duanchang = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"

local function room() return FkTest.room end
local function p(n) return FkTest.room.players[n] end
local function inRoom(fn)
  local ret
  FkTest.runInRoom(function() ret = fn() end)
  return ret
end

local function clearAllZones(player)
  for _, zone in ipairs({ "h", "e", "j" }) do
    local ids = player:getCardIds(zone)
    if #ids > 0 then
      room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end
end

local function give(player, name, suit, number)
  local card
  inRoom(function()
    card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
  end)
  return card
end

local function equip(player, name, suit, number)
  local card
  inRoom(function()
    card = room():printCard(name, suit or Card.Spade, number or 7)
    room():moveCardTo(card, Card.PlayerEquip, player, fk.ReasonJustMove, "test", nil, true)
  end)
  return card
end

local function prepareRoom(kingdoms)
  Fk.currentResponsePattern = nil
  local r = support.initQiaoRoom()
  inRoom(function()
    skill_test.installBlankGenerals(r, kingdoms or { "wu", "wu", "qun", "qun", "jin", "jin", "han", "wei" })
    for _, pl in ipairs(r.players) do
      clearAllZones(pl)
    end
    r.current = r.players[1]
    r:setBanner("RoundCount", 1)
  end)
  return r
end

Testqiao_quan_wu_qun_jin = {
  setup = function() prepareRoom() end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_quan_wu_qun_jin:testWu019LukangJueyanAndKeshou()
  local lukang, enemy = p(1), p(7)
  inRoom(function()
    skill_test.installDualGenerals(room(), lukang, { main = "qiao_heg__wu019", deputy = "qiao_test__wu_2", kingdom = "wu" })
    room().current = lukang
    lukang.phase = Player.Start
  end)
  -- 给陆抗判定区塞一张【乐不思蜀】测试决堰选判定区牌当冰杀
  local ind
  inRoom(function()
    ind = room():printCard("qiao__indulgence", Card.Heart, 6)
    room():moveCardTo(ind, Card.PlayerJudge, lukang, fk.ReasonJustMove, "test", nil, true)
  end)
  local baseRange = lukang:getAttackRange()
  local allocs = { "#qiao__skill_wu019_1-draw", "#qiao__skill_wu019_1-slash", "#qiao__skill_wu019_1-range" }
  local allocIdx = 0
  skill_test.withSkillRequests(room(), "qiao__skill_wu019_1", {
    askToSkillInvoke = function() return true end,
    askToChooseCard = function() return ind.id end,
    askToChoosePlayers = function() return { enemy } end,
    askToOptions = function()
      allocIdx = allocIdx + 1
      return { allocs[allocIdx] }
    end,
    askToUseCard = function() return nil end, -- 不出闪
  }, function()
    inRoom(function()
      room().logic:trigger(fk.EventPhaseStart, lukang, {})
    end)
  end)
  lu.assertEquals(#lukang:getCardIds("j"), 0, "判定区牌已被当冰杀用出")
  lu.assertEquals(lukang:getMark(Quan.JUEYAN_DRAW_MARK), 1)
  lu.assertEquals(lukang:getMark(Quan.JUEYAN_SLASH_MARK), 1)
  lu.assertEquals(lukang:getMark(Quan.JUEYAN_RANGE_MARK), 1)
  lu.assertEquals(lukang:getAttackRange(), baseRange + 1, "决堰攻击范围+1应生效")
  local slashMax = inRoom(function()
    return Fk.skills["slash_skill"]:getMaxUseTime(lukang, Player.HistoryPhase, Fk:cloneCard("qiao__slash"))
  end)
  lu.assertEquals(slashMax, 2, "决堰出杀次数+1应生效")
  local states = SkillStatus.forPlayer(lukang)
  lu.assertTrue(table.find(states, function(s) return s.id == Quan.JUEYAN_DRAW_MARK end) ~= nil)

  -- 恪守：限使用不限打出；孤军（本势力仅存活自己 1 人）应变在 0 鱼时获得 1 鱼，有鱼时可消耗 1 鱼摸 1 牌
  inRoom(function()
    -- 将 p(2) 改为汉势力，使陆抗成为吴势力唯一存活角色（满足孤军条件）
    p(2).kingdom = "han"
    room():setPlayerProperty(p(2), "kingdom", "han")
  end)
  local keshou = assert(Fk.skills["qiao__skill_wu019_2"])
  local k1 = give(lukang, "qiao__slash", Card.Spade, 2)
  local k2 = give(lukang, "qiao__slash", Card.Club, 3)
  Fk.currentResponsePattern = "jink"
  lu.assertFalse(keshou:enabledAtResponse(lukang, true), "恪守仅限使用，不可用于纯打出响应")
  lu.assertTrue(keshou:enabledAtResponse(lukang, false), "恪守可用于使用【闪】窗口")
  local jinkCard = keshou:viewAs(lukang, { k1.id, k2.id })
  lu.assertNotNil(jinkCard)
  lu.assertEquals(jinkCard.name, "qiao__jink")
  -- 使用该转化闪响应【杀】（带真实 toCard）且此时孤军 -> 触发 qiao_keshou_yinyangfish 获得1枚阴阳鱼
  inRoom(function()
    room():setPlayerMark(lukang, "@!!yinyangfish", 0)
    room():useCard { from = lukang, tos = {}, toCard = Fk:cloneCard("qiao__slash"), card = jinkCard }
  end)
  lu.assertEquals(lukang:getMark("@!!yinyangfish"), 1, "孤军恪守0鱼时应获得1枚阴阳鱼")

  -- 已有1枚阴阳鱼时再孤军使用恪守（响应无懈可击），选择消耗阴阳鱼摸1牌
  local k3 = give(lukang, "qiao__slash", Card.Heart, 4)
  local k4 = give(lukang, "qiao__slash", Card.Diamond, 5)
  Fk.currentResponsePattern = "nullification"
  local nullCard = keshou:viewAs(lukang, { k3.id, k4.id })
  lu.assertNotNil(nullCard)
  lu.assertEquals(nullCard.name, "qiao__nullification")
  skill_test.withSkillRequests(room(), "qiao__skill_wu019_2", {
    askToOptions = function() return { "#qiao__skill_wu019_2-consume-draw" } end,
  }, function()
    inRoom(function()
      room():useCard { from = lukang, tos = {}, toCard = Fk:cloneCard("qiao__dismantlement"), card = nullCard }
    end)
  end)
  Fk.currentResponsePattern = nil
  lu.assertEquals(lukang:getMark("@!!yinyangfish"), 0, "消耗阴阳鱼后标记归零")
  lu.assertEquals(lukang:getHandcardNum(), 1, "消耗阴阳鱼摸1牌生效")
end

local function checkKeshouWithCargo(pattern, cargoCount, incoming)
  local lukang, attacker = p(1), p(2)
  local skillName = "qiao__skill_wu019_2"
  inRoom(function()
    skill_test.installDualGenerals(room(), lukang, { main = "qiao_heg__wu019", deputy = "qiao_test__wu_2", kingdom = "wu" })
    room().current, attacker.phase = attacker, Player.Play
  end)
  local ox = equip(lukang, "qiao__wooden_ox", Card.Diamond, 5)
  local first = give(lukang, "qiao__peach", Card.Heart, 3).id
  local second = give(lukang, "qiao__analeptic", Card.Club, 6).id
  inRoom(function()
    lukang:addToPile("$sa_carriage", cargoCount == 2 and { first, second } or { second }, false, "qiao__wooden_ox_skill")
  end)

  local reply
  client_room.run(room(), function(clients)
    local board = Fk:getBoardGame(room():getSettings("gameMode"))
    local client = board.client_klass:new(ClientInstance.client)
    local handler = client.request_handlers.AskForUseCard:new(clients[lukang.seat], { nil, pattern, "", true, {} })
    Fk.currentResponsePattern = pattern
    handler:setup()
    lu.assertTrue(handler:skillButtonValidity(skillName))
    handler:selectSkill(skillName, { selected = true })
    for _, id in ipairs({ first, second }) do
      lu.assertNotNil(handler.scene:getAllItems("CardItem")[id], "恪守应展开可用的辎")
      lu.assertTrue(handler:cardValidity(id))
      handler:selectCard(id, { selected = true })
    end
    lu.assertTrue(handler:feasible())
    local notify = ClientInstance.notifyUI
    ClientInstance.notifyUI = function(_, command, data)
      if command == "ReplyToServer" then reply = data end
    end
    local ok, err = pcall(function() handler:doOKButton() end)
    ClientInstance.notifyUI = notify
    assert(ok, err)
    handler:_finish()
  end)
  lu.assertNotNil(reply)
  local hp = lukang.hp
  FkTest.setNextReplies(lukang, { reply })
  inRoom(function()
    room():useCard { from = attacker, tos = { lukang }, card = Fk:cloneCard(incoming) }
  end)
  lu.assertEquals(lukang.hp, hp, "转化牌应实际抵消来牌")
  lu.assertEquals(room():getCardArea(first), Card.DiscardPile)
  lu.assertEquals(room():getCardArea(second), Card.DiscardPile)
  lu.assertEquals(lukang:getPile("$sa_carriage"), {})
  lu.assertEquals(lukang:getCardIds("e"), { ox.id })
end

function Testqiao_quan_wu_qun_jin:testKeshouJinkWithTwoCargo()
  checkKeshouWithCargo("jink", 2, "qiao__slash")
end

function Testqiao_quan_wu_qun_jin:testKeshouNullificationWithHandAndCargo()
  checkKeshouWithCargo("nullification", 1, "qiao__duel")
end

function Testqiao_quan_wu_qun_jin:testWu024WuguotaiBuyiAndGanlu()
  local wuguotai, wuAlly, caojie = p(1), p(2), p(7)
  inRoom(function()
    skill_test.installDualGenerals(room(), wuguotai, { main = "qiao_heg__wu024", deputy = "qiao_test__wu_2", kingdom = "wu" })
    skill_test.installDualGenerals(room(), wuAlly, { main = "qiao_heg__wu009", deputy = "qiao_test__wu_2", kingdom = "wu" })
    skill_test.installDualGenerals(room(), caojie, { main = "qiao_heg__han021", deputy = "qiao_test__han_2", kingdom = "han" })
  end)

  -- 补益：同势力角色脱离濒死（含自伤来源），发起军令不执行 -> 回复1血
  local origAsk = Junling.ask
  local junlingTargetId
  Junling.ask = function(from, to)
    junlingTargetId = to.id
    return false
  end
  inRoom(function()
    room():loseHp(wuAlly, wuAlly.hp - 1, "test") -- 剩 1 血
  end)
  skill_test.withSkillRequests(room(), "qiao__skill_wu024_1", {
    askToSkillInvoke = function() return true end,
  }, function()
    inRoom(function()
      -- 构造已脱离濒死的 AfterDying 事件（hp=1，damage.from = wuAlly 自伤）
      room().logic:trigger(fk.AfterDying, wuAlly, {
        who = wuAlly,
        damage = { from = wuAlly, to = wuAlly, damage = 1 },
      })
    end)
  end)
  Junling.ask = origAsk
  lu.assertEquals(junlingTargetId, wuAlly.id, "补益允许对自伤来源发起军令")
  lu.assertEquals(wuAlly.hp, 2, "补益不执行军令应令濒死角色回复1点体力")

  -- 甘露：装备数差<=已损体力值；与曹节【守玺】及废除栏位联动
  inRoom(function()
    room():loseHp(wuguotai, 1, "test") -- lostHp = 1
    room().current = wuguotai
    wuguotai.phase = Player.Play
  end)
  local eqA1 = equip(caojie, "qiao__crossbow", Card.Spade, 1)
  local eqA2 = equip(caojie, "qiao__chitu", Card.Heart, 5)
  local eqB1 = equip(wuAlly, "qiao__zhuahuangfeidian", Card.Diamond, 13)
  local cjSpade = give(caojie, "qiao__slash", Card.Spade, 9)
  local ganlu = assert(Fk.skills["qiao__skill_wu024_2"])

  -- 客户端校验：|2 - 1| = 1 <= lostHp(1) 合法
  client_room.run(room(), function(clients)
    local me = clients[1]
    lu.assertTrue(ganlu:canUse(me))
    lu.assertTrue(ganlu:targetFilter(me, clients[7], {}))
    lu.assertTrue(ganlu:targetFilter(me, clients[2], { clients[7] }))
  end)

  -- 甘露结算中，曹节弃黑桃发动【守玺】防住黑桃诸葛连弩离开，其余两件正常互换
  skill_test.withSkillRequests(room(), "qiao__skill_han021_1", {
    askToDiscard = function(self, who, params)
      if params.pattern == ".|.|spade" then
        self:throwCard({ cjSpade.id }, params.skill_name, who, who)
        return { cjSpade.id }
      end
      return {}
    end,
  }, function()
    inRoom(function()
      room():useSkill(wuguotai, ganlu, function()
        ganlu:onUse(room(), { from = wuguotai, cards = {}, tos = { caojie, wuAlly } })
      end, { from = wuguotai, cards = {}, tos = { caojie, wuAlly } })
    end)
  end)
  lu.assertTrue(table.contains(caojie:getCardIds("e"), eqA1.id), "被守玺防止的装备应留在曹节装备区")
  lu.assertTrue(table.contains(caojie:getCardIds("e"), eqB1.id), "对方装备应换入曹节装备区")
  lu.assertTrue(table.contains(wuAlly:getCardIds("e"), eqA2.id), "未防住的装备应换入盟友装备区")
end

function Testqiao_quan_wu_qun_jin:testQun021YuanshuYongsiAndWeidi()
  local yuanshu, drawnTarget, undrawnTarget = p(3), p(5), p(6)
  inRoom(function()
    skill_test.installDualGenerals(room(), yuanshu, { main = "qiao_heg__qun021", deputy = "qiao_test__qun_2", kingdom = "qun" })
    room().current = yuanshu
    yuanshu.phase = Player.Play
    drawnTarget:drawCards(2, "test_draw")
  end)
  give(undrawnTarget, "qiao__jink", Card.Club, 2) -- ReasonJustMove 不算摸牌
  local yongsi = assert(Fk.skills["qiao__skill_qun021_1"])

  -- 客户端校验：仅本回合摸过牌的其他角色可选
  client_room.run(room(), function(clients)
    local me = clients[3]
    clients[5].mark[Quan.DRAWN_TURN_MARK] = 1
    lu.assertTrue(yongsi:canUse(me))
    lu.assertTrue(yongsi:targetFilter(me, clients[5], {}))
    lu.assertFalse(yongsi:targetFilter(me, clients[6], {}))
    lu.assertFalse(yongsi:targetFilter(me, me, {}))
  end)

  -- 庸肆不执行军令：获得目标所有手牌（2张），然后交还等量（2张）牌
  local origAsk = Junling.ask
  Junling.ask = function() return false end
  give(yuanshu, "qiao__slash", Card.Spade, 2)
  skill_test.withSkillRequests(room(), "qiao__skill_qun021_1", {
    askToCards = function(self, who, params)
      lu.assertEquals(params.min_num, 2)
      local ids = who:getCardIds("h")
      return { ids[1], ids[2] }
    end,
  }, function()
    inRoom(function()
      room():useSkill(yuanshu, yongsi, function()
        yongsi:onUse(room(), { from = yuanshu, cards = {}, tos = { drawnTarget } })
      end, { from = yuanshu, cards = {}, tos = { drawnTarget } })
    end)
  end)
  Junling.ask = origAsk
  lu.assertEquals(drawnTarget:getHandcardNum(), 2, "庸肆应交还实际获得张数的牌")
  lu.assertEquals(yuanshu:getHandcardNum(), 1)

  -- 伪帝：场上无实体玉玺 -> 视为装备玉玺（大势力 + 摸牌+1）；实体玉玺入场后立即让位
  inRoom(function()
    lu.assertTrue(Quan.virtualJadeSealActive(yuanshu, room()))
    lu.assertTrue(H.isBigKingdomPlayer(yuanshu), "无实体玉玺时伪帝应为大势力")
    local drawData = { n = 2 }
    room().logic:trigger(fk.DrawNCards, yuanshu, drawData)
    lu.assertEquals(drawData.n, 3, "无实体玉玺时伪帝摸牌阶段+1")
  end)
  local seal = equip(drawnTarget, "qiao__jade_seal", Card.Club, 12)
  inRoom(function()
    lu.assertFalse(Quan.virtualJadeSealActive(yuanshu, room()), "实体玉玺在场时伪帝让位")
    local drawData = { n = 2 }
    room().logic:trigger(fk.DrawNCards, yuanshu, drawData)
    lu.assertEquals(drawData.n, 2, "实体玉玺在场时伪帝不再+1摸牌")
  end)
  lu.assertNotNil(seal)

  -- 伪帝：成为【知己知彼】目标后展示所有手牌
  local shownCards
  local origShow = yuanshu.showCards
  yuanshu.showCards = function(self, cards)
    shownCards = cards
    return origShow(self, cards)
  end
  inRoom(function()
    local kb = Fk:cloneCard("qiao__known_both")
    room().logic:trigger(fk.TargetConfirmed, yuanshu, { from = drawnTarget, to = yuanshu, card = kb })
  end)
  yuanshu.showCards = origShow
  lu.assertNotNil(shownCards)
  lu.assertEquals(#shownCards, yuanshu:getHandcardNum(), "成为知己知彼目标后应展示所有手牌")
end

function Testqiao_quan_wu_qun_jin:testQun023ZhangxiuCongjianFudiAndHucheer()
  local zhangxiu, unknownEnemy, other, wuLord = p(3), p(4), p(5), p(1)
  inRoom(function()
    skill_test.installDualGenerals(room(), zhangxiu, { main = "qiao_heg__qun023", deputy = "qiao_test__qun_2", kingdom = "qun" })
    unknownEnemy.kingdom = "unknown"
    room():setPlayerProperty(unknownEnemy, "kingdom", "unknown")
    room().current = zhangxiu
  end)

  -- 从谏：张绣回合内，其他角色造成伤害 +1，张绣自己造成伤害不 +1
  local hp1 = other.hp
  inRoom(function()
    room():damage { from = unknownEnemy, to = other, damage = 1, skillName = "test" }
  end)
  lu.assertEquals(other.hp, hp1 - 2, "张绣回合内其他角色造成伤害应+1")

  local hp2 = other.hp
  inRoom(function()
    room():damage { from = zhangxiu, to = other, damage = 1, skillName = "test" }
  end)
  lu.assertEquals(other.hp, hp2 - 1, "张绣回合内自己造成伤害不+1")

  -- 张绣回合外：受到未确定势力角色伤害 -> 附敌交1张手牌并对其势力（含自己）最大体力且>=张绣的角色造成1点伤害 -> 叠加从谏变2点
  local handCard = give(zhangxiu, "qiao__jink", Card.Club, 3)
  local enemyHpBefore = unknownEnemy.hp
  skill_test.withSkillRequests(room(), "qiao__skill_qun023_2", {
    askToCards = function() return { handCard.id } end,
  }, function()
    inRoom(function()
      room().current = unknownEnemy
      room():damage { from = unknownEnemy, to = zhangxiu, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertTrue(table.contains(unknownEnemy:getCardIds("h"), handCard.id), "附敌应交1张手牌给伤害来源")
  lu.assertEquals(unknownEnemy.hp, enemyHpBefore - 2, "回合外附敌伤害应与从谏叠加为2点")

  -- 偏将·胡车儿（限一）：相互在攻击范围内，排除明置聚宝宝物；获得装备并立即装备+1马离开其攻击范围 -> 摸1牌
  inRoom(function()
    skill_test.installDualGenerals(room(), wuLord, { main = "qiao_heg__em_wu001", deputy = "qiao_test__wu_2", kingdom = "wu" })
    -- 相邻座位 p(3) 和 p(4)：给张绣一把射程2武器，使张绣即使对方装有+1马也能打到对方（双方互在攻击范围内）
    R.grant(zhangxiu, { general = "qiao_heg__retinue_hucheer", skill = "qiao__retinue_skill_hucheer", position = "deputy" })
    clearAllZones(zhangxiu)
    clearAllZones(unknownEnemy)
  end)
  equip(zhangxiu, "qiao__qinggang_sword", Card.Spade, 6)
  local defHorse = equip(unknownEnemy, "qiao__jueying", Card.Spade, 5)
  local zxHandBefore = zhangxiu:getHandcardNum()
  skill_test.withSkillRequests(room(), "qiao__retinue_skill_hucheer", {
    askToSkillInvoke = function() return true end,
    askToUseRealCard = function(self, who, params)
      lu.assertEquals(params.pattern, { defHorse.id })
      local use = { from = who, tos = { who }, card = defHorse }
      self:useCard(use)
      return use
    end,
  }, function()
    inRoom(function()
      room().current = unknownEnemy
      unknownEnemy.phase = Player.Play
      room().logic:trigger(fk.EventPhaseStart, unknownEnemy, {})
    end)
  end)
  lu.assertTrue(table.contains(zhangxiu:getCardIds("e"), defHorse.id), "胡车儿应可使用刚获得的装备")
  lu.assertFalse(unknownEnemy:inMyAttackRange(zhangxiu), "装上+1马后应离开对方攻击范围")
  lu.assertEquals(zhangxiu:getHandcardNum(), zxHandBefore + 1, "离开对方攻击范围应摸1张牌")

  -- 校验聚宝保护过滤：只有明置聚宝的宝物牌时胡车儿不可触发
  inRoom(function()
    -- 将 p(2) 设为君孙权（与 p(3) 张绣相邻互在攻击范围），仅装定澜夜明珠
    skill_test.installDualGenerals(room(), p(2), { main = "qiao_heg__em_wu001", deputy = "qiao_test__wu_2", kingdom = "wu" })
    clearAllZones(p(2))
    clearAllZones(zhangxiu)
    local pearl = room():printCard(Wu.PEARL, Card.Club, 6)
    room():moveCardTo(pearl, Card.PlayerEquip, p(2), fk.ReasonJustMove, "test", nil, true)
    room():setBanner("RoundCount", 2) -- 新一轮重置轮次技
    zhangxiu:setSkillUseHistory("qiao__retinue_skill_hucheer", 0, Player.HistoryRound)
  end)
  local hucheerTriggered = false
  skill_test.withSkillRequests(room(), "qiao__retinue_skill_hucheer", {
    askToSkillInvoke = function() hucheerTriggered = true; return true end,
  }, function()
    inRoom(function()
      room().current = p(2)
      p(2).phase = Player.Play
      room().logic:trigger(fk.EventPhaseStart, p(2), {})
    end)
  end)
  lu.assertFalse(hucheerTriggered, "目标仅有明置聚宝保护的宝物牌时胡车儿不可触发")
end

function Testqiao_quan_wu_qun_jin:testShouxiProtectsEquipmentUsedByAnotherFaction()
  local lukang, caojie, enemy = p(1), p(2), p(7)
  local jueyan, shouxi = "qiao__skill_wu019_1", "qiao__skill_han021_1"
  local sword = equip(lukang, "qiao__qinggang_sword", Card.Spade)
  local payment = give(caojie, "qiao__slash", Card.Spade)
  local defenses = 0
  inRoom(function()
    skill_test.installDualGenerals(room(), lukang, { main = "qiao_heg__wu019", deputy = "qiao_test__wu_2", kingdom = "wu" })
    room():handleAddLoseSkills(caojie, shouxi, nil, false, true)
    room():setCurrent(lukang)
    lukang.phase = Player.Start
  end)
  skill_test.withSkillRequests(room(), shouxi, {
    askToDiscard = function(r, who, params)
      defenses = defenses + 1
      lu.assertEquals(params.pattern, ".|.|spade")
      r:throwCard(payment.id, shouxi, who, who)
      return { payment.id }
    end,
  }, function()
    skill_test.withSkillRequests(room(), jueyan, {
      askToSkillInvoke = function() return true end,
      askToChooseCard = function() return sword.id end,
      askToChoosePlayers = function() return { enemy } end,
      askToOptions = function() return { "#qiao__skill_wu019_1-draw" } end,
    }, function()
      inRoom(function() room().logic:trigger(fk.EventPhaseStart, lukang, {}) end)
    end)
  end)
  lu.assertEquals(defenses, 1)
  lu.assertEquals(room():getCardArea(payment.id), Card.DiscardPile)
  lu.assertEquals(lukang:getEquipments(Card.SubtypeWeapon), { sword.id })
end

return { name = "qiao_quan_wu_qun_jin" }
