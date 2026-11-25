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
  lu.assertEquals(Data.generalCount, 12)
  lu.assertEquals(Data.retinueCount, 1)
  lu.assertEquals(Data.commanderCount, 1)
  lu.assertEquals(Data.skillCount, 22)
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
  lu.assertTrue(Fk.generals["qiao_heg__wei022"]:isCompanionWith(Fk.generals["qiao_heg__wei001"]))
  lu.assertTrue(Fk.generals["qiao_heg__wei022"]:isCompanionWith(Fk.generals["qiao_heg__em_wei001"]))
  lu.assertTrue(Fk.generals["qiao_heg__wu021"]:isCompanionWith(Fk.generals["qiao_heg__wu002"]))
  lu.assertTrue(Fk.generals["qiao_heg__wu022"]:isCompanionWith(Fk.generals["qiao_heg__wu010"]))
  lu.assertTrue(Fk.generals["qiao_heg__qun022a"]:isCompanionWith(Fk.generals["qiao_heg__qun007"]))
  lu.assertTrue(Fk.generals["qiao_heg__jin018"]:isCompanionWith(Fk.generals["qiao_heg__jin015"]))
  lu.assertTrue(Fk.generals["qiao_heg__jin020"]:isCompanionWith(Fk.generals["qiao_heg__jin004"]))
  lu.assertFalse(Fk.generals["qiao_heg__qun009"]:isCompanionWith(Fk.generals["qiao_heg__qun011"]))
  lu.assertEquals(Guest.guestKingdoms("qiao_heg__qun009"), { "wei", "shu", "wu" })
  lu.assertEquals(Guest.guestKingdoms("qiao_heg__wei020"), { "han" })
  lu.assertEquals(Guest.guestKingdoms("qiao_heg__qun022a"), { "han" })
  lu.assertEquals(Guest.guestKingdoms("qiao_heg__shu020"), {})
  -- 翼从与统领核对
  local feixiong = assert(Fk.generals["qiao_heg__retinue_feixiongjun"])
  lu.assertEquals(feixiong.package.name, "qiao_zhenshi")
  lu.assertEquals(feixiong.prefix, "qiao_prefix_bian")
  lu.assertTrue(Commander.isRetinue(feixiong.name))
  lu.assertFalse(Commander.retinues[feixiong.name].limited)
  lu.assertTrue(Commander.isCommander("qiao_heg__qun022a"))
  lu.assertEquals(Commander.commanders["qiao_heg__qun022a"].card, "qiao__fire_attack")
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

-- WEI022 卞夫人：挽危（一次挡下同势力多张失牌改为自己 1 张）+ 约俭（手牌上限初值叠加与弃牌末摸牌）
function Testqiao_bian_han_wei_shu:testWei022WanweiBlocksMultipleCardsAndYuejianStacks()
  local room = FkTest.room
  local bian, ally, enemy = p(1), p(2), p(3)
  local allyC1, allyC2, bianC1, bianC2
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wei", "wei", "wu", "shu" })
    skill_test.installDualGenerals(room, bian, {
      main = "qiao_heg__wei022", deputy = "qiao_test__wei_2", kingdom = "wei", hp = 3,
    })
    ally.maxHp = 4
    ally.hp = 1
    bian:throwAllCards("he")
    ally:throwAllCards("he")
    allyC1 = room:printCard("qiao__slash", Card.Spade, 2)
    allyC2 = room:printCard("qiao__jink", Card.Heart, 3)
    bianC1 = room:printCard("qiao__slash", Card.Club, 4)
    bianC2 = room:printCard("qiao__jink", Card.Diamond, 5)
    room:obtainCard(ally, { allyC1, allyC2 }, false, fk.ReasonJustMove)
    room:obtainCard(bian, { bianC1, bianC2 }, false, fk.ReasonJustMove)
  end)

  -- 敌方一次弃置队友 2 张手牌：卞夫人挽危全部挡下，改为弃置卞夫人的 1 张牌。
  skill_test.withSkillRequests(room, "qiao__skill_wei022_1", {
    askToCards = function() return { bianC1.id } end,
  }, function()
    inRoom(function()
      room:throwCard({ allyC1.id, allyC2.id }, "test", ally, enemy)
    end)
  end)
  lu.assertEquals(#ally:getCardIds("h"), 2, "挽危应挡下同势力队友全部 2 张原定弃牌")
  lu.assertFalse(table.contains(bian:getCardIds("h"), bianC1.id), "改为弃置卞夫人所选的 1 张牌")
  lu.assertEquals(#bian:getCardIds("h"), 1)

  -- 约俭：队友体力 1 / 上限 4，准备阶段发动后手牌上限初值变为 4，且叠加 +2 标记应为 6；弃牌阶段未弃牌摸 1 张。
  skill_test.withSkillRequests(room, "qiao__skill_wei022_2", {
    askToSkillInvoke = function() return true end,
  }, function()
    inRoom(function()
      room:setCurrent(ally)
      ally.phase = Player.Start
      room.logic:trigger(fk.EventPhaseStart, ally, PhaseData:new { who = ally, phase = Player.Start })
    end)
  end)
  local maxBase, maxStacked
  inRoom(function()
    maxBase = ally:getMaxCards()
    room:addPlayerMark(ally, MarkEnum.AddMaxCardsInTurn, 2)
    maxStacked = ally:getMaxCards()
  end)
  lu.assertEquals(maxBase, 4, "约俭应将手牌上限初值设为体力上限 4")
  lu.assertEquals(maxStacked, 6, "约俭不阻止后续手牌上限加减效果叠加（4 + 2 = 6）")

  local allyHandBefore = #ally:getCardIds("h")
  inRoom(function()
    ally.phase = Player.Discard
    GameEvent.Phase:create(PhaseData:new { who = ally, phase = Player.Discard }):exec()
  end)
  lu.assertEquals(#ally:getCardIds("h"), allyHandBefore + 1, "弃牌阶段未弃置牌时约俭应摸 1 张牌")
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

-- SHU022 马谡：散谣（最大体力或最大手牌，客户端过滤）+ 制蛮（防伤取判定区 + 同势力可选变更限一次）
function Testqiao_bian_han_wei_shu:testShu022SanyaoAndZhimanSameKingdomChange()
  local room = FkTest.room
  local masu, ally, richHand = p(1), p(2), p(3)
  local costCard, judgeCard
  inRoom(function()
    skill_test.installBlankGenerals(room, { "shu", "shu", "wei", "wu" })
    skill_test.installDualGenerals(room, masu, {
      main = "qiao_heg__shu022", deputy = "qiao_test__shu_2", kingdom = "shu", hp = 3,
    })
    ally.hp = 4
    richHand.hp = 2
    p(4).hp = 2
    for _, who in ipairs(room.players) do who:throwAllCards("he") end
    costCard = room:printCard("qiao__jink", Card.Heart, 2)
    room:obtainCard(masu, costCard, false, fk.ReasonJustMove)
    for i = 1, 5 do
      room:obtainCard(richHand, room:printCard("qiao__slash", Card.Spade, i), false, fk.ReasonJustMove)
    end
    judgeCard = room:printCard("qiao__indulgence", Card.Heart, 6)
    room:moveCardTo(judgeCard, Player.Judge, ally, fk.ReasonJustMove, "test", nil, true, ally)
    masu.phase = Player.Play
    resetGeneralPool(room, { "qiao_heg__shu001", "qiao_heg__shu002", "qiao_heg__shu003" }, { "shu", "wei", "wu", "han" })
  end)

  -- 客户端目标筛选：ally 体力最大、richHand 手牌最大均合法，p(4) 不合法；调离者不合法。
  client_room.run(room, function(clients)
    local sk = Fk.skills["qiao__skill_shu022_1"]
    lu.assertTrue(sk:targetFilter(clients[1], clients[2], {}))
    lu.assertTrue(sk:targetFilter(clients[1], clients[3], {}))
    lu.assertFalse(sk:targetFilter(clients[1], clients[4], {}))
  end)
  inRoom(function() room:setPlayerMark(ally, MarkEnum.PlayerRemoved .. "-turn", 1) end)
  client_room.run(room, function(clients)
    local sk = Fk.skills["qiao__skill_shu022_1"]
    lu.assertFalse(sk:targetFilter(clients[1], clients[2], {}), "被调离的角色不得成为散谣目标")
  end)
  inRoom(function() room:setPlayerMark(ally, MarkEnum.PlayerRemoved .. "-turn", 0) end)

  -- 散谣对 richHand 造成 1 点伤害
  local richHpBefore = richHand.hp
  inRoom(function()
    Fk.skills["qiao__skill_shu022_1"]:onUse(room, {
      from = masu, tos = { richHand }, cards = { costCard.id },
    })
  end)
  lu.assertEquals(richHand.hp, richHpBefore - 1, "散谣应对手牌数最大目标造成 1 点伤害")

  -- 制蛮：对同势力队友造成伤害时防止伤害、获得其判定区【乐不思蜀】、队友变更副将并消耗限一次。
  local allyHpBefore = ally.hp
  skill_test.withSkillRequests(room, "qiao__skill_shu022_2", {
    askToSkillInvoke = function() return true end,
    askToChooseCard = function() return judgeCard.id end,
    askToChoice = function() return "changeDeputy" end,
    askToCustomDialog = function(self, who, params)
      return { general = params.component.prop.candidates[1] }
    end,
  }, function()
    inRoom(function()
      room:damage { from = masu, to = ally, damage = 1, skillName = "test" }
    end)
  end)
  lu.assertEquals(ally.hp, allyHpBefore, "制蛮应防止本次伤害")
  lu.assertTrue(table.contains(masu:getCardIds("h"), judgeCard.id), "制蛮应可获得判定区牌")
  lu.assertNotEquals(ally.deputyGeneral, "qiao_test__shu_2", "同势力目标应成功变更副将")
  lu.assertFalse(Change.canUseSkillChange(room, masu, "qiao__skill_shu022_2"), "制蛮变更每局限一次")
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

-- 审阅回归（第 1、2 项）：挽危覆盖巧变格式敌方获得、排除队友拿牌、替代暗手牌不泄露给无关座位且保留本已明牌。
function Testqiao_bian_han_wei_shu:testWei022WanweiQiaobianTeammateAndPrivateVisibility()
  local room = FkTest.room
  local bian, ally, enemy, viewer = p(1), p(2), p(3), p(4)
  local allyCard, allyCard2, bianPrivate, bianPublic, armor, cost
  local asks = 0
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wei", "wei", "qun", "shu" })
    skill_test.installDualGenerals(room, bian, {
      main = "qiao_heg__wei022", deputy = "qiao_test__wei_2", kingdom = "wei", hp = 3,
    })
    skill_test.installDualGenerals(room, enemy, {
      main = "qiao_heg__em_qun010", deputy = "qiao_test__qun_2", kingdom = "qun", hp = 4,
    })
    allyCard = room:printCard("qiao__slash", Card.Spade, 7)
    allyCard2 = room:printCard("qiao__slash", Card.Club, 8)
    bianPrivate = room:printCard("qiao__jink", Card.Diamond, 9)
    bianPublic = room:printCard("qiao__peach", Card.Heart, 6)
    armor = room:printCard("qiao__peace_spell", Card.Heart, 8)
    cost = room:printCard("qiao__peach", Card.Heart, 5)
    room:obtainCard(ally, { allyCard, allyCard2 }, false, fk.ReasonJustMove)
    room:obtainCard(bian, { bianPrivate, bianPublic }, false, fk.ReasonJustMove)
    room:moveCardTo(armor, Player.Equip, ally, fk.ReasonPut, "test", nil, true, ally)
    room:obtainCard(enemy, cost, false, fk.ReasonJustMove)
  end)

  -- 1. 队友拿队友牌不触发挽危
  skill_test.withSkillRequests(room, "qiao__skill_wei022_1", {
    askToCards = function() asks = asks + 1; return { bianPrivate.id } end,
  }, function()
    inRoom(function()
      room:obtainCard(bian, allyCard2.id, false, fk.ReasonPrey, ally, "test")
    end)
  end)
  lu.assertEquals(asks, 0, "同势力队友之间拿牌不应触发挽危")

  -- 2. 敌方按【巧变】格式（proposer=原持有者, to=敌方）拿队友牌，应触发挽危
  skill_test.withSkillRequests(room, "qiao__skill_wei022_1", {
    askToCards = function() asks = asks + 1; return { bianPublic.id } end,
  }, function()
    inRoom(function()
      room:obtainCard(enemy, allyCard.id, false, fk.ReasonPrey, ally, "qiao__skill_wei009_1")
    end)
  end)
  lu.assertEquals(asks, 1, "巧变格式敌方获得应触发挽危")

  -- 3. 新回合：君张角【问道】拿队友装备区【太平要术】，挽危改付暗手牌时第四座位不可见
  local privateVisible, publicVisible
  inRoom(function()
    local turn = GameEvent.Turn:create(TurnData:new(enemy, "game_rule", {}))
    function turn:main()
      enemy.phase = Player.Play
      local oldTrigger = room.logic.trigger
      room.logic.trigger = function(this, ev, target, data, ...)
        if ev == fk.AfterCardsMove then
          for _, move in ipairs(data or {}) do
            for _, info in ipairs(move.moveInfo or {}) do
              if info.cardId == bianPrivate.id and move.to == enemy then
                privateVisible = viewer:cardVisible(bianPrivate.id, move)
              end
            end
          end
        end
        return oldTrigger(this, ev, target, data, ...)
      end
      skill_test.withSkillRequests(room, "qiao__skill_wei022_1", {
        askToCards = function() return { bianPrivate.id } end,
      }, function()
        skill_test.withSkillRequests(room, "qiao__skill_em_qun010_3", {
          askToDiscard = function()
            room:throwCard({ cost.id }, "qiao__skill_em_qun010_3", enemy, enemy)
            return { cost.id }
          end,
        }, function()
          local sk = Fk.skills["qiao__skill_em_qun010_3"]
          local use = { from = enemy, tos = {}, cards = {} }
          room:useSkill(enemy, sk, function() sk:onUse(room, use) end, use)
        end)
      end)
      room.logic.trigger = oldTrigger
    end
    turn:exec()
  end)
  lu.assertFalse(privateVisible, "挽危替代暗手牌不得被无关第四座位看到牌面")

  -- 4. 若卞夫人手牌本就处于【武督】公开状态，替代牌仍应保持公开可见
  inRoom(function()
    local Visibility = require "packages.qiao.pkg.qiao_mode.rules.card_visibility"
    local openCard = room:printCard("qiao__jink", Card.Heart, 4)
    room:obtainCard(bian, openCard, false, fk.ReasonJustMove)
    room:setPlayerMark(bian, Visibility.WUDU_OPEN, 1)
    local turn = GameEvent.Turn:create(TurnData:new(viewer, "game_rule", {}))
    function turn:main()
      local oldTrigger = room.logic.trigger
      room.logic.trigger = function(this, ev, target, data, ...)
        if ev == fk.AfterCardsMove then
          for _, move in ipairs(data or {}) do
            for _, info in ipairs(move.moveInfo or {}) do
              if info.cardId == openCard.id and move.to == enemy then
                publicVisible = viewer:cardVisible(openCard.id, move)
              end
            end
          end
        end
        return oldTrigger(this, ev, target, data, ...)
      end
      skill_test.withSkillRequests(room, "qiao__skill_wei022_1", {
        askToCards = function() return { openCard.id } end,
      }, function()
        room:obtainCard(enemy, allyCard.id, false, fk.ReasonPrey, enemy, "test")
      end)
      room.logic.trigger = oldTrigger
    end
    turn:exec()
  end)
  lu.assertTrue(publicVisible, "本就处于明牌状态的替代手牌仍应保持公开可见")
end

-- 审阅回归（第 10 项）：约俭弃牌阶段被他人弃牌不算自己弃牌，阶段结束仍应摸 1 张。
function Testqiao_bian_han_wei_shu:testWei022YuejianOpponentDiscardStillDraws()
  local room = FkTest.room
  local ally, foe = p(1), p(2)
  local handCountAfter
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wei", "wu", "shu", "han" })
    room:setCurrent(ally)
    ally:throwAllCards("he")
    local card = room:printCard("qiao__jink", Card.Heart, 7)
    room:obtainCard(ally, card, false, fk.ReasonJustMove)
    room:setPlayerMark(ally, "qiao_wei022_yuejian-turn", 1)
    local oldTrigger = room.logic.trigger
    local fired = false
    room.logic.trigger = function(this, ev, target, ...)
      if ev == fk.EventPhaseStart and target == ally and ally.phase == Player.Discard and not fired then
        fired = true
        room:throwCard({ card.id }, "test", ally, foe)
      end
      return oldTrigger(this, ev, target, ...)
    end
    GameEvent.Phase:create(PhaseData:new { who = ally, phase = Player.Discard }):exec()
    room.logic.trigger = oldTrigger
    handCountAfter = ally:getHandcardNum()
  end)
  lu.assertEquals(handCountAfter, 1, "弃牌阶段仅被他人弃置手牌不算自己弃牌，阶段结束应摸 1 张")
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

-- 复审回归（第 1 项）：卞夫人挽危覆盖祝融【烈刃】与【白马义从】从对方处获得牌。
function Testqiao_bian_han_wei_shu:testWei022WanweiLierenAndBaimaPrey()
  local room = FkTest.room
  local bian, ally, zhu = p(1), p(2), p(3)
  local askedLieren, askedBaima = 0, 0
  local lootOwnerAfterLieren, lootOwnerAfterBaima
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wei", "wei", "shu", "wu" })
    skill_test.installDualGenerals(room, bian, {
      main = "qiao_heg__wei022", deputy = "qiao_test__wei_2", kingdom = "wei", hp = 4,
    })
    skill_test.installDualGenerals(room, zhu, {
      main = "qiao_heg__shu015", deputy = "qiao_test__shu_2", kingdom = "shu", hp = 4,
    })
    ally:throwAllCards("he")
    zhu:throwAllCards("he")
    local pay1 = room:printCard("qiao__jink", Card.Diamond, 6)
    local pay2 = room:printCard("qiao__jink", Card.Diamond, 7)
    local loot = room:printCard("qiao__slash", Card.Club, 2)
    local slash = room:printCard("qiao__slash", Card.Spade, 10)
    room:obtainCard(bian, { pay1, pay2 }, false, fk.ReasonJustMove)
    room:obtainCard(ally, loot, false, fk.ReasonJustMove)
    room:obtainCard(zhu, { slash, room:printCard("qiao__jink", Card.Heart, 12) }, false, fk.ReasonJustMove)
    room:setCurrent(zhu)
    zhu.phase = Player.Play
    local origPindian = zhu.pindian
    zhu.pindian = function() return { results = { [ally] = { winner = zhu } } } end
    skill_test.withSkillRequests(room, "qiao__skill_wei022_1", {
      askToCards = function() askedLieren = askedLieren + 1; return { pay1.id } end,
    }, function()
      skill_test.withSkillRequests(room, "qiao__skill_shu015_2", {
        askToSkillInvoke = function() return true end,
        askToChooseCards = function() return { loot.id } end,
      }, function()
        room:useCard { from = zhu, tos = { ally }, card = slash }
      end)
    end)
    zhu.pindian = origPindian
    local owner1 = room:getCardOwner(loot.id)
    lootOwnerAfterLieren = owner1 and owner1.id

    -- 新回合：【白马义从】因使用【闪】获得魏队友手牌时，同样触发挽危。
    room:handleAddLoseSkills(zhu, "qiao__retinue_skill_baima_yicong", nil, false, true)
    local turn = GameEvent.Turn:create(TurnData:new(ally, "game_rule", {}))
    function turn:main()
      skill_test.withSkillRequests(room, "qiao__skill_wei022_1", {
        askToCards = function() askedBaima = askedBaima + 1; return { pay2.id } end,
      }, function()
        skill_test.withSkillRequests(room, "qiao__retinue_skill_baima_yicong", {
          askToSkillInvoke = function() return true end,
          askToChooseCards = function() return { loot.id } end,
        }, function()
          room.logic:trigger(fk.CardUsing, zhu, {
            card = Fk:cloneCard("qiao__jink"),
            responseToEvent = { from = ally },
          })
        end)
      end)
    end
    turn:exec()
    local owner2 = room:getCardOwner(loot.id)
    lootOwnerAfterBaima = owner2 and owner2.id
  end)
  lu.assertEquals(askedLieren, 1, "祝融烈刃拼点赢获得魏方手牌应触发挽危")
  lu.assertEquals(lootOwnerAfterLieren, ally.id, "魏队友原手牌应被挽危保下（烈刃）")
  lu.assertEquals(askedBaima, 1, "白马义从获得魏方手牌应触发挽危")
  lu.assertEquals(lootOwnerAfterBaima, ally.id, "魏队友原手牌应被挽危保下（白马义从）")
end

-- 复审回归（第 5 项）：挽危不把局部可见（buddy）提升为全局公开，且【武督】明牌遵守旁观开关。
function Testqiao_bian_han_wei_shu:testWei022WanweiPartialVisibilityAndObserverWudu()
  local room = FkTest.room
  local bian, ally, taker, allowed, denied = p(1), p(2), p(3), p(4), p(5)
  local Visibility = require "packages.qiao.pkg.qiao_mode.rules.card_visibility"
  local allowedBefore, deniedBefore, deniedAfter, observerWudu, normalWudu
  inRoom(function()
    skill_test.installBlankGenerals(room, { "wei", "wei", "qun", "wu", "shu" })
    skill_test.installDualGenerals(room, bian, {
      main = "qiao_heg__wei022", deputy = "qiao_test__wei_2", kingdom = "wei", hp = 4,
    })
    local pay1 = room:printCard("qiao__peach", Card.Heart, 6)
    local pay2 = room:printCard("qiao__jink", Card.Heart, 7)
    local loot = room:printCard("qiao__slash", Card.Spade, 9)
    room:obtainCard(bian, { pay1, pay2 }, false, fk.ReasonJustMove)
    room:obtainCard(ally, loot, false, fk.ReasonJustMove)

    -- 仅 allowed 与卞夫人互通可见，denied 无查看权限：替代后 denied 仍不可见。
    allowed:addBuddy(bian)
    allowedBefore = allowed:cardVisible(pay1.id)
    deniedBefore = denied:cardVisible(pay1.id)
    local oldTrigger = room.logic.trigger
    room.logic.trigger = function(this, ev, target, data, ...)
      if ev == fk.AfterCardsMove then
        for _, move in ipairs(data or {}) do
          for _, info in ipairs(move.moveInfo or {}) do
            if info.cardId == pay1.id and move.to == taker then
              deniedAfter = denied:cardVisible(pay1.id, move)
            end
          end
        end
      end
      return oldTrigger(this, ev, target, data, ...)
    end
    skill_test.withSkillRequests(room, "qiao__skill_wei022_1", {
      askToCards = function() return { pay1.id } end,
    }, function()
      room:obtainCard(taker, loot, false, fk.ReasonPrey, taker, "test")
    end)
    room.logic.trigger = oldTrigger
    allowed:removeBuddy(bian)

    -- 新回合：【武督】公开手牌下，普通在场角色可见，关闭旁观查看手牌时旁观视角不可见。
    room:setPlayerMark(bian, Visibility.WUDU_OPEN, 1)
    local turn = GameEvent.Turn:create(TurnData:new(taker, "game_rule", {}))
    function turn:main()
      local prevTrigger = room.logic.trigger
      room.logic.trigger = function(this, ev, target, data, ...)
        if ev == fk.AfterCardsMove then
          for _, move in ipairs(data or {}) do
            for _, info in ipairs(move.moveInfo or {}) do
              if info.cardId == pay2.id and move.to == taker then
                normalWudu = denied:cardVisible(pay2.id, move)
                local prevObs, prevSettings = room.observing, room.getSettings
                room.observing = true
                room.getSettings = function(self, key, ...)
                  if key == "enableObserverViewCard" then return false end
                  return prevSettings(self, key, ...)
                end
                observerWudu = denied:cardVisible(pay2.id, move)
                room.getSettings, room.observing = prevSettings, prevObs
              end
            end
          end
        end
        return prevTrigger(this, ev, target, data, ...)
      end
      skill_test.withSkillRequests(room, "qiao__skill_wei022_1", {
        askToCards = function() return { pay2.id } end,
      }, function()
        room:obtainCard(taker, loot, false, fk.ReasonPrey, taker, "test")
      end)
      room.logic.trigger = prevTrigger
    end
    turn:exec()
  end)
  lu.assertTrue(allowedBefore)
  lu.assertFalse(deniedBefore)
  lu.assertFalse(deniedAfter, "局部可见权限不得因挽危提升为全局公开")
  lu.assertTrue(normalWudu, "正常在场角色仍应可见武督公开手牌")
  lu.assertFalse(observerWudu, "关闭旁观查看手牌时，旁观视角不应看到武督替代手牌")
end

return { name = "qiao_bian_han_wei_shu" }
