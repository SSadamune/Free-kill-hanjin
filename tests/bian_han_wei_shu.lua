-- 六势力变包（注册核对 + 汉/魏/蜀 6 将）定向回归测试。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local client_room = __dofile("../../../tests/support/client_room.lua")
local Data = require "packages.qiao.pkg.qiao_generals.data.bian"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local BattleRoyal = require "packages.qiao.pkg.qiao_mode.rules.battle_royal"
local Discard = require "packages.qiao.pkg.qiao_mode.rules.general_discard"
local Change = require "packages.qiao.pkg.qiao_mode.rules.general_change"
local O = require "packages.qiao.pkg.qiao_mode.rules.only_as"

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function p(i) return FkTest.room.players[i] end

local function resetGeneralPool(room, pile, kingdoms)
  room.disabled_generals = {}
  Discard.reset(room)
  room:setTag(Guest.key, nil)
  room:setBanner("all_kingdoms", kingdoms or { "han", "wei", "shu", "wu", "qun", "jin" })
  room.general_pile = table.simpleClone(pile)
end

Testqiao_bian_han_wei_shu = {
  setup = function()
    Fk.currentResponsePattern = nil
    support.initQiaoRoom()
  end,
  tearDown = function()
    Fk.currentResponsePattern = nil
    support.clearRoom()
  end,
}

function Testqiao_bian_han_wei_shu:testBianRegistrationPrefixesCompanionsGuests()
  lu.assertEquals(Data.generalCount, 4)
  lu.assertEquals(Data.retinueCount, 0)
  lu.assertEquals(Data.commanderCount, 0)
  lu.assertEquals(Data.skillCount, 7)
  for _, entry in ipairs(Data.generals) do
    local g = assert(Fk.generals[entry.id], "缺少变包武将：" .. entry.id)
    lu.assertEquals(g.package.name, "qiao_zhenshi")
    lu.assertEquals(g.prefix, "qiao_prefix_bian")
    lu.assertEquals(Fk:translate(g.prefix), "变")
    lu.assertEquals(g.maxHp, entry.hp)
    for _, sk in ipairs(entry.skills) do
      local skel = assert(Fk.skill_skels[sk.id], "缺少技能骨架：" .. sk.id)
      lu.assertTrue(skel.qiaoImplemented == true)
      lu.assertTrue(#skel.effects > 0)
      lu.assertEquals(Fk:translate(sk.id), sk.name)
      lu.assertEquals(Fk:translate(":" .. sk.id), sk.text)
    end
  end
  -- 珠联与客将核对
  lu.assertTrue(Fk.generals["qiao_heg__wei020"]:isCompanionWith(Fk.generals["qiao_heg__wei013"]))
  lu.assertTrue(Fk.generals["qiao_heg__wei020"]:isCompanionWith(Fk.generals["qiao_heg__han023"]))
  lu.assertEquals(Guest.guestKingdoms("qiao_heg__wei020"), { "han" })
  lu.assertEquals(Guest.guestKingdoms("qiao_heg__shu020"), {})
end

-- HAN023 伍琼&种辑：除奸（无距离/无次数且不计次 + 阶段末延时伤害不因暗置撤销）
function Testqiao_bian_han_wei_shu:testHan023ChujianBypassSlashAndPhaseEndDamage()
  local room = FkTest.room
  local han, enemy, bystander = p(1), p(4), p(2)
  local s1, s2, s3
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "wei", "shu", "wu", "qun", "jin", "wei", "shu" })
    skill_test.installDualGenerals(room, han, {
      main = "qiao_heg__han023", deputy = "qiao_test__han_2", kingdom = "han", hp = 3,
    })
    -- 令 enemy 体力全场最大（4 > 3），且距离 han 超过 1。
    for _, who in ipairs(room.players) do
      who.hp = (who == enemy) and 4 or 3
      who:throwAllCards("he")
    end
    s1 = room:printCard("qiao__slash", Card.Spade, 2)
    s2 = room:printCard("qiao__slash", Card.Club, 3)
    s3 = room:printCard("qiao__slash", Card.Heart, 4)
    room:obtainCard(enemy, { s1, s2, s3 }, false, fk.ReasonJustMove)
    room:setCurrent(enemy)
    enemy.phase = Player.Play
  end)

  skill_test.withSkillRequests(room, "qiao__skill_han023_1", {
    askToSkillInvoke = function() return true end,
  }, function()
    inRoom(function()
      room.logic:trigger(fk.EventPhaseStart, enemy, PhaseData:new { who = enemy, phase = Player.Play })
    end)
  end)

  local canFarFirst, canFarSecond, canHitOtherAfter, usedNormalCount
  inRoom(function()
    lu.assertTrue(enemy:distanceTo(han) > 1, "默认距离应大于 1")
    canFarFirst = enemy:canUseTo(s1, han)
    -- 连续对伍琼&种辑使用两张杀：均无视距离与次数且不计入通常次数。
    room:useCard { from = enemy, tos = { han }, card = s1 }
    usedNormalCount = enemy:usedCardTimes("slash", Player.HistoryPhase)
    canFarSecond = enemy:canUseTo(s2, han)
    room:useCard { from = enemy, tos = { han }, card = s2 }
    -- 仍保留原本的 1 次对其他距离内角色出杀的通常次数（若相距 1）。
    canHitOtherAfter = enemy:usedCardTimes("slash", Player.HistoryPhase) == 0
    -- 中途暗置伍琼&种辑后，已建立的阶段末延时伤害仍应触发。
    han:hideGeneral(false)
  end)
  lu.assertTrue(canFarFirst, "除奸后对伍琼&种辑出杀应无视距离")
  lu.assertEquals(usedNormalCount, 0, "仅对除奸目标出杀不应计入通常出杀次数")
  lu.assertTrue(canFarSecond, "除奸后对伍琼&种辑应可继续出杀")
  lu.assertTrue(canHitOtherAfter)

  local hpBefore = enemy.hp
  inRoom(function()
    room.logic:trigger(fk.EventPhaseEnd, enemy, PhaseData:new { who = enemy, phase = Player.Play })
  end)
  lu.assertEquals(enemy.hp, hpBefore - 1, "出牌阶段结束时即使来源已暗置仍应造成1点伤害")
end

-- HAN023 伍琼&种辑：心疾（个人鏖战与暗置退出 + 濒死失救减上限回血至1 + 上限1死亡）
function Testqiao_bian_han_wei_shu:testHan023XinjiPersonalBattleRoyalAndDyingSelfSave()
  local room = FkTest.room
  local han, other = p(1), p(2)
  local peach1, peach2
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "wei", "shu", "wu" })
    skill_test.installDualGenerals(room, han, {
      main = "qiao_heg__han023", deputy = "qiao_test__han_2", kingdom = "han", hp = 3,
    })
    peach1 = room:printCard("qiao__peach", Card.Heart, 6)
    peach2 = room:printCard("qiao__peach", Card.Heart, 7)
    room:obtainCard(han, peach1, false, fk.ReasonJustMove)
    room:obtainCard(other, peach2, false, fk.ReasonJustMove)
  end)

  lu.assertFalse(BattleRoyal.entered(room), "全局不应被拉入鏖战")
  lu.assertTrue(BattleRoyal.inBattleRoyal(room, han), "明置伍琼&种辑本人应处于鏖战状态")
  lu.assertFalse(BattleRoyal.inBattleRoyal(room, other), "其他角色不应进入鏖战")
  lu.assertTrue(O.isForbidden(han, peach1), "伍琼&种辑的实体桃应被禁止直接当桃使用")
  lu.assertFalse(O.isForbidden(other, peach2), "其他角色的实体桃应仍可正常使用")

  -- 暗置后退出个人鏖战
  inRoom(function() han:hideGeneral(false) end)
  lu.assertFalse(BattleRoyal.inBattleRoyal(room, han), "暗置心疾且全局未鏖战时应退出鏖战")
  lu.assertFalse(O.isForbidden(han, peach1))

  -- 重新明置后进入濒死并求桃失败：减 1 体力上限并回复至 1 体力存活。
  inRoom(function()
    han:revealGeneral(false)
    han:throwAllCards("he")
    other:throwAllCards("he")
    han.maxHp = 3
    han.hp = 1
    room:loseHp(han, 1, "test")
  end)
  lu.assertFalse(han.dead, "体力上限大于 1 时失救应减上限并回血至 1 存活")
  lu.assertEquals(han.maxHp, 2)
  lu.assertEquals(han.hp, 1)

  -- 体力上限为 1 时失救：减上限至 0 直接死亡，不能回复至 1。
  inRoom(function()
    han.maxHp = 1
    han.hp = 1
    room:loseHp(han, 1, "test")
  end)
  lu.assertTrue(han.dead, "体力上限为 1 时减上限至 0 应直接死亡")
end

-- HAN024 灵雎：竭缘（装备区红牌 +1/-1 防伤）与焚心（额外异势力 3 候选 + 势力不变 + 伪限定）
function Testqiao_bian_han_wei_shu:testHan024JieyuanAndFenxinExtraPool()
  local room = FkTest.room
  local lingju, victim, victim2 = p(1), p(2), p(3)
  local redEquip, redHand
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "wei", "wu", "shu" })
    skill_test.installDualGenerals(room, lingju, {
      main = "qiao_heg__han024", deputy = "qiao_test__han_2", kingdom = "han", hp = 2,
    })
    skill_test.installDualGenerals(room, victim, {
      main = "qiao_heg__wei001", deputy = "qiao_heg__wei003", kingdom = "wei", hp = 3,
    })
    skill_test.installDualGenerals(room, victim2, {
      main = "qiao_heg__wu001", deputy = "qiao_heg__wu002", kingdom = "wu", hp = 1,
    })
    lingju:throwAllCards("he")
    redEquip = room:printCard("qiao__chitu", Card.Heart, 5)
    redHand = room:printCard("qiao__jink", Card.Diamond, 2)
    room:moveCardTo(redEquip, Player.Equip, lingju, fk.ReasonJustMove, "test", nil, true, lingju)
    room:obtainCard(lingju, redHand, false, fk.ReasonJustMove)
    -- 确保将池中有足够的汉/魏武将用于焚心合并候选
    resetGeneralPool(room, { "qiao_heg__han002", "qiao_heg__wei004", "qiao_heg__wei005", "qiao_heg__wei006" },
      { "han", "wei", "wu", "shu" })
  end)

  -- 竭缘：弃装备区红牌令造成伤害 +1
  skill_test.withSkillRequests(room, "qiao__skill_han024_1", {
    askToCards = function() return { redEquip.id } end,
    askToChoice = function() return "#qiao__skill_han024_1-plus" end,
  }, function()
    inRoom(function()
      room:damage { from = lingju, to = victim, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(victim.hp, 1, "竭缘弃装备区红牌应令伤害 +1（3 -> 1）")
  lu.assertEquals(#lingju:getCardIds("e"), 0)

  -- 竭缘：受到体力 >= 自己的角色伤害时弃手牌红牌令伤害 -1 至 0（防止伤害）
  local ljBefore = lingju.hp
  inRoom(function() victim.hp = 2 end)
  skill_test.withSkillRequests(room, "qiao__skill_han024_1", {
    askToCards = function() return { redHand.id } end,
    askToChoice = function() return "#qiao__skill_han024_1-minus" end,
  }, function()
    inRoom(function()
      room:damage { from = victim, to = lingju, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(lingju.hp, ljBefore, "竭缘减 1 点伤害至 0 应防止本次伤害")

  -- 焚心：击杀副将为魏势力的 victim，候选应合并汉 + 魏并允许变更为魏将且保持灵雎汉势力。
  local offeredCandidates
  skill_test.withSkillRequests(room, "qiao__skill_han024_2", {
    askToSkillInvoke = function() return true end,
    askToCustomDialog = function(self, who, params)
      offeredCandidates = table.simpleClone(params.component.prop.candidates)
      -- 故意选额外翻出的魏势力武将，验证无视势力限制。
      return { general = "qiao_heg__wei004" }
    end,
  }, function()
    inRoom(function()
      victim:throwAllCards("he")
      victim.hp = 1
      room:damage { from = lingju, to = victim, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertNotNil(offeredCandidates)
  lu.assertTrue(table.contains(offeredCandidates, "qiao_heg__han002"), "常规候选应含同势力武将")
  lu.assertTrue(table.contains(offeredCandidates, "qiao_heg__wei004"), "额外候选应含死者副将牌面势力武将")
  lu.assertEquals(lingju.deputyGeneral, "qiao_heg__wei004", "灵雎应成功变更副将为异势力备选")
  lu.assertEquals(lingju.kingdom, "han", "变更异势力备选不得改变灵雎本局势力")
  lu.assertTrue(table.contains(Discard.list(room), "qiao_test__han_2"), "换下的旧副将应进入武将弃牌堆")
  lu.assertFalse(Change.canUseSkillChange(room, lingju, "qiao__skill_han024_2"), "焚心变更每局限一次")

  -- 再次击杀时不得再次触发焚心
  local secondAsk = 0
  skill_test.withSkillRequests(room, "qiao__skill_han024_2", {
    askToSkillInvoke = function() secondAsk = secondAsk + 1; return true end,
  }, function()
    inRoom(function()
      victim2:throwAllCards("he")
      room:damage { from = lingju, to = victim2, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(secondAsk, 0, "焚心伪限定次数耗尽后再次击杀不应再询问")
end

-- WEI020 荀攸：智愚（同色令来源弃手牌 / 混色不弃牌）
function Testqiao_bian_han_wei_shu:testWei020ZhiyuSameAndMixedColor()
  local room = FkTest.room
  local xunyou, attacker = p(1), p(2)
  local r1, r2, b1, aHand
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wei", "wu", "shu", "han" })
    skill_test.installDualGenerals(room, xunyou, {
      main = "qiao_heg__wei020", deputy = "qiao_test__wei_2", kingdom = "wei", hp = 3,
    })
    xunyou:throwAllCards("he")
    attacker:throwAllCards("he")
    r1 = room:printCard("qiao__jink", Card.Heart, 2)
    r2 = room:printCard("qiao__peach", Card.Diamond, 3)
    b1 = room:printCard("qiao__slash", Card.Spade, 4)
    aHand = room:printCard("qiao__slash", Card.Club, 5)
    room:obtainCard(xunyou, r1, false, fk.ReasonJustMove)
    room:obtainCard(attacker, aHand, false, fk.ReasonJustMove)
    -- 牌堆顶放红牌 r2，使智愚摸完后手牌全红。
    room:moveCardTo(r2, Card.DrawPile, nil, fk.ReasonJustMove, "test", nil, true)
  end)

  skill_test.withSkillRequests(room, "qiao__skill_wei020_2", {
    askToSkillInvoke = function() return true end,
    askToDiscard = function(self, who, params)
      local id = who:getCardIds("h")[1]
      self:throwCard({ id }, "qiao__skill_wei020_2", who, who)
      return { id }
    end,
  }, function()
    inRoom(function()
      room:damage { from = attacker, to = xunyou, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(#xunyou:getCardIds("h"), 2, "智愚应摸一张牌")
  lu.assertEquals(#attacker:getCardIds("h"), 0, "全红手牌应令伤害来源弃置一张手牌")

  -- 牌堆顶放黑牌 b1，摸完混色，来源不应弃牌。
  local aHand2
  inRoom(function()
    aHand2 = room:printCard("qiao__jink", Card.Heart, 9)
    room:obtainCard(attacker, aHand2, false, fk.ReasonJustMove)
    room:moveCardTo(b1, Card.DrawPile, nil, fk.ReasonJustMove, "test", nil, true)
  end)
  skill_test.withSkillRequests(room, "qiao__skill_wei020_2", {
    askToSkillInvoke = function() return true end,
  }, function()
    inRoom(function()
      room:damage { from = attacker, to = xunyou, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(#attacker:getCardIds("h"), 1, "手牌混色时伤害来源不应弃牌")

  -- 核对正式变包荀攸（qiao_heg__wei020）复用【奇策】并按自身武将牌记录变更副将。
  inRoom(function()
    xunyou:throwAllCards("he")
    room:obtainCard(xunyou, room:printCard("qiao__slash", Card.Spade, 10), false, fk.ReasonJustMove)
    room:setCurrent(xunyou)
    xunyou.phase = Player.Play
    resetGeneralPool(room, { "qiao_heg__wei004", "qiao_heg__wei005", "qiao_heg__wei006" }, { "wei", "wu", "shu", "han" })
  end)
  skill_test.withSkillRequests(room, "qiao__skill_wei020_1", {
    askToChoice = function() return "changeDeputy" end,
    askToCustomDialog = function(self, who, params)
      return { general = params.component.prop.candidates[1] }
    end,
  }, function()
    inRoom(function()
      local reply = FkTest.ReplyUseSkill("qiao__skill_wei020_1", {}, {})
      reply.interaction_data = "qiao__foresight"
      room:handleUseCardReply(xunyou, reply)
    end)
  end)
  lu.assertNotEquals(xunyou.deputyGeneral, "qiao_test__wei_2", "正式荀攸奇策应支持变更副将")
  lu.assertTrue(room:getTag("qiao_qice_change_used_qiao_heg__wei020") == true, "奇策变更应随荀攸武将牌独立记账")
end

-- SHU020 沙摩柯：蒺藜（动态攻击范围连续触发 + 回合外打出触发）
function Testqiao_bian_han_wei_shu:testShu020JiliDynamicAttackRangeAndRespond()
  local room = FkTest.room
  local smk, foe = p(1), p(2)
  local sword, slash, jink
  inRoom(function()
    skill_test.installBlankGenerals(room, { "shu", "wei", "wu", "han" })
    skill_test.installDualGenerals(room, smk, {
      main = "qiao_heg__shu020", deputy = "qiao_test__shu_2", kingdom = "shu", hp = 4,
    })
    smk:throwAllCards("he")
    sword = room:printCard("qiao__qinggang_sword", Card.Spade, 6) -- 攻击范围 2
    slash = room:printCard("qiao__slash", Card.Heart, 7)
    jink = room:printCard("qiao__jink", Card.Diamond, 8)
    room:obtainCard(smk, { sword, slash, jink }, false, fk.ReasonJustMove)
    room:setCurrent(smk)
  end)

  local drawnCounts = {}
  local beforeHand
  skill_test.withSkillRequests(room, "qiao__skill_shu020_1", {
    askToSkillInvoke = function(self, who)
      table.insert(drawnCounts, who:getAttackRange())
      return true
    end,
  }, function()
    inRoom(function()
      -- 第 1 张：使用青釭剑（使用时攻击范围仍为 1 -> 摸 1）；随后青釭剑入装备（攻击范围变 2）。
      -- 第 2 张：对 foe 使用杀（使用时攻击范围为 2 -> 摸 2）。
      local turn = GameEvent.Turn:create(TurnData:new(smk, "game_rule", {}))
      function turn:main()
        beforeHand = #smk:getCardIds("h")
        room:useCard { from = smk, tos = { smk }, card = sword }
        room:useCard { from = smk, tos = { foe }, card = slash }
      end
      turn:exec()
    end)
  end)
  lu.assertEquals(drawnCounts, { 1, 2 }, "第1张武器按装前范围1摸1，第2张杀按装后范围2摸2")
  lu.assertEquals(#smk:getCardIds("h"), beforeHand - 2 + 1 + 2, "两次蒺藜共摸 3 张牌")

  -- 回合外打出第 1 张牌（卸武器恢复攻击范围 1）也触发摸 1 张。
  drawnCounts = {}
  inRoom(function()
    smk:throwAllCards("he")
    room:obtainCard(smk, jink, false, fk.ReasonJustMove)
  end)
  skill_test.withSkillRequests(room, "qiao__skill_shu020_1", {
    askToSkillInvoke = function(self, who)
      table.insert(drawnCounts, who:getAttackRange())
      return true
    end,
  }, function()
    inRoom(function()
      local turn = GameEvent.Turn:create(TurnData:new(foe, "game_rule", {}))
      function turn:main()
        room:responseCard { from = smk, card = jink }
      end
      turn:exec()
    end)
  end)
  lu.assertEquals(drawnCounts, { 1 }, "回合外打出第 1 张牌且攻击范围 1 应触发蒺藜")
end

-- 审阅回归（第 6 项）：心疾暂时无效时桃恢复可用，恢复有效后个人鏖战立即恢复，全局鏖战仍覆盖。
function Testqiao_bian_han_wei_shu:testHan023XinjiInvalidationRestoreAndGlobalBattleRoyal()
  local room = FkTest.room
  local han = p(1)
  local peach
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "wei", "wu", "shu" })
    skill_test.installDualGenerals(room, han, {
      main = "qiao_heg__han023", deputy = "qiao_test__han_2", kingdom = "han", hp = 3,
    })
    peach = room:printCard("qiao__peach", Card.Heart, 6)
    room:obtainCard(han, peach, false, fk.ReasonJustMove)
  end)
  lu.assertTrue(O.isForbidden(han, peach))
  lu.assertTrue(BattleRoyal.inBattleRoyal(room, han))

  inRoom(function() room:invalidateSkill(han, "qiao__skill_han023_2", "", "test") end)
  lu.assertFalse(O.isForbidden(han, peach), "心疾暂时无效时桃应恢复按通常方式使用")
  lu.assertFalse(BattleRoyal.inBattleRoyal(room, han))
  client_room.run(room, function(clients)
    lu.assertFalse(O.isForbidden(clients[1], peach), "客户端同步视图下桃也应恢复可用")
  end)

  inRoom(function() room:validateSkill(han, "qiao__skill_han023_2", "", "test") end)
  lu.assertTrue(O.isForbidden(han, peach), "心疾恢复有效后个人鏖战应立即恢复")
  lu.assertTrue(BattleRoyal.inBattleRoyal(room, han))

  inRoom(function()
    BattleRoyal.enter(room)
    room:invalidateSkill(han, "qiao__skill_han023_2", "", "test")
  end)
  lu.assertTrue(O.isForbidden(han, peach), "全局已进入鏖战时即使心疾失效仍受全局鏖战约束")
end

-- 审阅回归（第 7、8 项）：专属野心家焚心额外候选严格按死者副将势力筛选；副将换走自己时来源记在旧副将牌上且取消不耗次。
function Testqiao_bian_han_wei_shu:testHan024FenxinWildExtraPoolAndSelfDeputySourceKey()
  local room = FkTest.room
  local holder = p(1)
  local regularWild, extraWei, originalKey, cancelledOk, changedOk
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "wei", "wu", "shu" })
    skill_test.installDualGenerals(room, holder, {
      main = "qiao_test__han_2", deputy = "qiao_heg__han024", kingdom = "han", hp = 3,
    })
    room:setPlayerMark(holder, "__heg_wild", 1)
    resetGeneralPool(room, { "qiao_heg__wei004", "qiao_heg__wu003", "qiao_heg__han002" })
    regularWild = Change.candidates(room, holder, true)
    extraWei = Change.candidates(room, holder, true, { kingdoms = { "wei" } })
    originalKey = Change.skillChangeSourceKey(room, holder, "qiao__skill_han024_2")
  end)
  lu.assertTrue(table.contains(regularWild, "qiao_heg__wu003"), "专属野心家常规变更仍从全可用将池随机取")
  lu.assertEquals(extraWei, { "qiao_heg__wei004" }, "显式限定魏势力的焚心额外池不得混入吴将")

  -- 取消变更不消耗来源次数
  skill_test.withSkillRequests(room, "qiao__skill_han024_2", {
    askToCustomDialog = function() return nil end,
  }, function()
    inRoom(function()
      cancelledOk = Change.performSkillChangeDeputy(room, holder, holder, "qiao__skill_han024_2")
    end)
  end)
  lu.assertFalse(cancelledOk)
  lu.assertNil(room:getTag(originalKey), "取消变更副将不得消耗每局限一次")

  -- 副将灵雎成功换走自己后，已用记录应落在原副将灵雎对应的来源键
  skill_test.withSkillRequests(room, "qiao__skill_han024_2", {
    askToCustomDialog = function() return { general = "qiao_heg__han002" } end,
  }, function()
    inRoom(function()
      changedOk = Change.performSkillChangeDeputy(room, holder, holder, "qiao__skill_han024_2")
    end)
  end)
  lu.assertTrue(changedOk)
  lu.assertTrue(room:getTag(originalKey) == true, "副将换走自己时应记账到发动前的旧副将来源键")
end

-- 复审回归（第 3 项）：心疾暂时无效期间获得其他技能，恢复有效后个人鏖战必须立即恢复。
function Testqiao_bian_han_wei_shu:testHan023XinjiInvalidAcquireSkillThenRestore()
  local room = FkTest.room
  local han = p(1)
  local before, whileInvalid, activeAfter, globalEntered, after
  inRoom(function()
    skill_test.installBlankGenerals(room, { "han", "wei", "shu", "wu" })
    skill_test.installDualGenerals(room, han, {
      main = "qiao_heg__han023", deputy = "qiao_test__han_2", kingdom = "han", hp = 4,
    })
    local peach = room:printCard("qiao__peach", Card.Heart, 6)
    room:obtainCard(han, peach, false, fk.ReasonJustMove)
    before = O.isForbidden(han, peach)
    room:invalidateSkill(han, "qiao__skill_han023_2", "", "test")
    room:handleAddLoseSkills(han, "qiao__skill_wei020_2")
    whileInvalid = O.isForbidden(han, peach)
    room:validateSkill(han, "qiao__skill_han023_2", "", "test")
    activeAfter = han:hasShownSkill("qiao__skill_han023_2")
    globalEntered = BattleRoyal.entered(room)
    after = O.isForbidden(han, peach)
  end)
  lu.assertTrue(before)
  lu.assertFalse(whileInvalid)
  lu.assertTrue(activeAfter)
  lu.assertFalse(globalEntered)
  lu.assertTrue(after, "心疾失效期间获得新技能后，恢复心疾时个人鏖战仍应恢复")
end

return { name = "qiao_bian_han_wei_shu" }
