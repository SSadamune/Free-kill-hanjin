-- 蜀势力标准包第一批：仁德、武圣、咆哮、龙胆、马术、集智、连环、八阵、火计、享乐。
-- 规则依据：rules/standard-generals.md 蜀区；集智见 rules/generals/shu007-huangyueying.md；
-- 龙胆与鏖战见 rules/battle-royal.md。
-- 夹具复用白板双将与公共请求辅助；只用真实房间流程，不替换 useCard/damage。
local support = __dofile("../../../tests/support/hegemony.lua")
local skill_test = __dofile("../../../tests/support/skill_test.lua")
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local RENDE = "qiao__skill_shu001_1"
local WUSHENG = "qiao__skill_shu002_1"
local PAOXIAO = "qiao__skill_shu003_1"
local LONGDAN = "qiao__skill_shu005_1"
local MASHU = "qiao__skill_shu006_1"
local JIZHI = "qiao__skill_shu007_1"
local LIANHUAN = "qiao__skill_shu010_1"
local LIANHUAN_RECAST = "qiao__skill_shu010_1_recast"
local BAZHEN = "qiao__skill_shu011_1"
local HUOJI = "qiao__skill_shu011_2"
local XIANGL = "qiao__skill_shu013_1"

local ARMOR_SKILL = "qiao__eight_diagram_skill"
local RENDE_TARGET_MARK = "qiao__skill_shu001_1-targets-phase"

local DEFAULT_KINGDOMS = { "shu", "shu", "shu", "shu", "shu", "shu", "shu", "shu" }

local function room() return FkTest.room end
local function p(n) return room().players[n] end

local function inRoom(fn)
  local result
  FkTest.runInRoom(function() result = fn() end)
  return result
end

local function grant(player, name)
  inRoom(function() player.room:handleAddLoseSkills(player, name, nil, false, true) end)
end

local function revoke(player, name)
  inRoom(function() player.room:handleAddLoseSkills(player, "-" .. name, nil, false, true) end)
end

local function clearCards(player)
  inRoom(function()
    local ids = player:getCardIds("he")
    if #ids > 0 then
      room():moveCardTo(ids, Card.DiscardPile, nil, fk.ReasonJustMove, "test", nil, false)
    end
  end)
end

local function give(player, name, suit, number)
  local id
  inRoom(function()
    local card = room():printCard(name, suit or Card.Spade, number or 7)
    room():obtainCard(player, card, false, fk.ReasonJustMove)
    id = card.id
  end)
  return id
end

local function setHand(player, specs)
  clearCards(player)
  local ids = {}
  inRoom(function()
    for _, spec in ipairs(specs or {}) do
      local card = room():printCard(spec[1], spec[2] or Card.Spade, spec[3] or 1)
      room():obtainCard(player, card, false, fk.ReasonJustMove)
      table.insert(ids, card.id)
    end
  end)
  return ids
end

local function equip(player, id)
  inRoom(function() room():moveCardIntoEquip(player, id, "test", true, player) end)
end

local function activate(player, name, targets, cards, interaction)
  inRoom(function()
    local reply = FkTest.ReplyUseSkill(name, targets, cards or {})
    reply.interaction_data = interaction
    room():handleUseCardReply(player, reply)
  end)
end

local function setPlayPhase(player)
  inRoom(function()
    room().current = player
    player.phase = Player.Play
    room():setBanner("RoundCount", 1)
  end)
end

local function use(player, card, targets)
  inRoom(function()
    room():useCard(UseCardData:new {
      from = player,
      tos = targets or {},
      card = card,
      extra_data = {},
    })
  end)
end

local function prepare()
  Fk.currentResponsePattern = nil
  local r = support.initQiaoRoom()
  inRoom(function() skill_test.installBlankGenerals(r, DEFAULT_KINGDOMS) end)
  return r
end

local function teardown()
  Fk.currentResponsePattern = nil
  support.clearRoom()
end

Testqiao_shu_conversion = { setup = prepare, tearDown = teardown }

function Testqiao_shu_conversion:testRendeGivesPerTargetAndOnlyOffersOnceAfterSecondCard()
  local p1, p2, p3, p4, p5 = p(1), p(2), p(3), p(4), p(5)
  grant(p1, RENDE)
  clearCards(p2)
  clearCards(p3)
  clearCards(p4)
  local cards = setHand(p1, {
    { "qiao__jink", Card.Spade, 1 },
    { "qiao__jink", Card.Spade, 2 },
    { "qiao__jink", Card.Spade, 3 },
    { "qiao__jink", Card.Spade, 4 },
  })
  setPlayPhase(p1)

  local asks = {}
  skill_test.withSkillRequests(room(), RENDE, {
    askToUseVirtualCard = function(self, player, params)
      table.insert(asks, params)
      return nil
    end,
  }, function()
    activate(p1, RENDE, { p2 }, { cards[1] })
    activate(p1, RENDE, { p3 }, { cards[2] })
    activate(p1, RENDE, { p4 }, { cards[3] })
  end)

  -- 累计给出第二张后只提供一次基本牌；第三次给牌不再询问。
  lu.assertEquals(#asks, 1)
  lu.assertTrue(table.contains(asks[1].name, "qiao__slash"))
  lu.assertTrue(table.contains(asks[1].name, "qiao__peach"))
  lu.assertEquals(#p1:getCardIds("h"), 1)
  lu.assertEquals(#p2:getCardIds("h"), 1)
  lu.assertEquals(#p3:getCardIds("h"), 1)
  lu.assertEquals(#p4:getCardIds("h"), 1)

  -- 每名角色每阶段一次：已给出的目标不能再次选择。
  local skill = Fk.skills[RENDE]
  lu.assertFalse(skill:targetFilter(p1, p2, {}, {}))
  lu.assertTrue(skill:targetFilter(p1, p5, {}, {}))
  lu.assertTrue(table.contains(p1:getTableMark(RENDE_TARGET_MARK), p2.id))
end

--- 真实虚拟牌回复：选择牌名与目标后由引擎实际使用，不拦截虚拟牌请求。
local function replyVirtualSlash(target)
  return {
    card = { skill = "virtual_viewas", subcards = {} },
    targets = { target.id },
    interaction_data = "qiao__slash",
  }
end

function Testqiao_shu_conversion:testRendeRealSlashWhenNormalQuotaIsUsed()
  local p1, p2, p3, p4 = p(1), p(2), p(3), p(4)
  grant(p1, RENDE)
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p2.maxHp = 20; p2.hp = 20 end)
  setPlayPhase(p1)
  local first = give(p1, "qiao__slash", Card.Spade, 5)
  local second = give(p1, "qiao__slash", Card.Spade, 6)
  local give1 = give(p1, "qiao__jink", Card.Heart, 1)
  local give2 = give(p1, "qiao__jink", Card.Heart, 2)

  FkTest.setNextReplies(p2, { "__cancel" })
  use(p1, Fk:getCardById(first), { p2 })
  lu.assertEquals(p1:usedCardTimes("slash", Player.HistoryPhase), 1)
  lu.assertNotIsTrue(p1:canUse(Fk:getCardById(second)))

  -- 给第二张牌时提供基本牌，真实回复选择【杀】并对已用完次数的同一目标使用。
  FkTest.setNextReplies(p1, { replyVirtualSlash(p2) })
  FkTest.setNextReplies(p2, { "__cancel" })
  activate(p1, RENDE, { p3 }, { give1 })
  activate(p1, RENDE, { p4 }, { give2 })

  lu.assertEquals(p2.hp, 18) -- 普通【杀】+ 仁德视为【杀】
  -- 视为使用按 extraUse 处理，不进入通常用牌次数历史。
  lu.assertEquals(p1:usedCardTimes("slash", Player.HistoryPhase), 1)
end

function Testqiao_shu_conversion:testRendeRealSlashDoesNotSpendNormalQuota()
  local p1, p2, p3, p4 = p(1), p(2), p(3), p(4)
  grant(p1, RENDE)
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p2.maxHp = 20; p2.hp = 20 end)
  setPlayPhase(p1)
  local slash = give(p1, "qiao__slash", Card.Spade, 5)
  local give1 = give(p1, "qiao__jink", Card.Heart, 1)
  local give2 = give(p1, "qiao__jink", Card.Heart, 2)

  FkTest.setNextReplies(p1, { replyVirtualSlash(p2) })
  FkTest.setNextReplies(p2, { "__cancel", "__cancel" })
  activate(p1, RENDE, { p3 }, { give1 })
  activate(p1, RENDE, { p4 }, { give2 })
  lu.assertEquals(p1:usedCardTimes("slash", Player.HistoryPhase), 0)
  lu.assertTrue(p1:canUse(Fk:getCardById(slash)))

  use(p1, Fk:getCardById(slash), { p2 })
  lu.assertEquals(p1:usedCardTimes("slash", Player.HistoryPhase), 1)
  lu.assertEquals(p2.hp, 18)
end

function Testqiao_shu_conversion:testWushengViewAsAndDiamondIgnoresDistance()
  local p1, p4 = p(1), p(4)
  grant(p1, WUSHENG)
  clearCards(p1)
  local red = give(p1, "qiao__jink", Card.Diamond, 2)
  local skill = Fk.skills[WUSHENG]
  local card = skill:viewAs(p1, { red })
  lu.assertNotNil(card)
  lu.assertEquals(card.name, "qiao__slash")
  lu.assertEquals(card.skillName, WUSHENG)
  lu.assertEquals(card:getEffectiveId(), red)

  -- 方片牌无距离限制：p4 在普通攻击范围外，方片【杀】仍可指定；黑桃不可。
  local diamondSlash = give(p1, "qiao__slash", Card.Diamond, 7)
  local spadeSlash = give(p1, "qiao__slash", Card.Spade, 8)
  lu.assertTrue(inRoom(function() return p1:distanceTo(p4) > p1:getAttackRange() end))
  lu.assertTrue(p1:canUseTo(Fk:getCardById(diamondSlash), p4))
  lu.assertNotIsTrue(p1:canUseTo(Fk:getCardById(spadeSlash), p4))
  -- 非【杀】的方片牌同样无距离限制。
  local diamondSnatch = give(p1, "qiao__snatch", Card.Diamond, 9)
  lu.assertTrue(p1:canUseTo(Fk:getCardById(diamondSnatch), p4))
end

function Testqiao_shu_conversion:testWushengHeartCardDamageTriggersDrowning()
  local p1, p2 = p(1), p(2)
  grant(p1, WUSHENG)
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p2.hp = p2.maxHp end)
  local sword = give(p2, "qiao__qinggang_sword", Card.Spade, 5)
  equip(p2, sword)
  local heartSlash = give(p1, "qiao__slash", Card.Heart, 5)
  setPlayPhase(p1)

  FkTest.setNextReplies(p1, { "1" }) -- 武圣：视为使用【水淹七军】
  FkTest.setNextReplies(p2, { "__cancel" }) -- 不打出【闪】
  local oldChoice = room().askToChoice
  local choiceSeen = 0
  room().askToChoice = function(self, player, params)
    if params.skill_name ~= "qiao__drowning" then
      return oldChoice(self, player, params)
    end
    choiceSeen = choiceSeen + 1
    return "qiao__drowning_damage:" .. p1.id
  end
  local ok, err = pcall(function()
    use(p1, Fk:getCardById(heartSlash), { p2 })
  end)
  room().askToChoice = oldChoice
  assert(ok, err)
  lu.assertEquals(choiceSeen, 1)

  -- 红桃【杀】1 点 + 水淹七军雷电伤害 1 点；目标选择受伤，装备保留。
  lu.assertEquals(p2.hp, p2.maxHp - 2)
  lu.assertEquals(#p2:getCardIds("e"), 1)
end

function Testqiao_shu_conversion:testPaoxiaoSecondSlashDrawsAndBypassesTimes()
  local p1, p2 = p(1), p(2)
  grant(p1, PAOXIAO)
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p2.maxHp = 20; p2.hp = 20 end)
  local first = give(p1, "qiao__slash", Card.Spade, 1)
  local second = give(p1, "qiao__slash", Card.Spade, 2)
  local third = give(p1, "qiao__slash", Card.Spade, 3)
  setPlayPhase(p1)
  FkTest.setNextReplies(p2, { "__cancel", "__cancel" })

  use(p1, Fk:getCardById(first), { p2 })
  use(p1, Fk:getCardById(second), { p2 })

  lu.assertEquals(#p1:getCardIds("h"), 2) -- 3 - 2 + 第二张【杀】摸 1
  -- 状态型无次数限制：已使用过【杀】仍可选第三张。
  lu.assertTrue(p1:canUse(Fk:getCardById(third)))
end

function Testqiao_shu_conversion:testPaoxiaoSecondSlashAfterAcquiringSkill()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p2.maxHp = 20; p2.hp = 20 end)
  setPlayPhase(p1)
  local first = give(p1, "qiao__slash", Card.Spade, 1)
  local second = give(p1, "qiao__slash", Card.Spade, 2)
  -- 第一张【杀】发生时尚未获得咆哮。
  inRoom(function() lu.assertFalse(p1:hasSkill(PAOXIAO)) end)
  use(p1, Fk:getCardById(first), { p2 })
  grant(p1, PAOXIAO)
  local before = #p1:getCardIds("h")
  use(p1, Fk:getCardById(second), { p2 })
  -- 第二张是全回合事实：取得咆哮后仍应摸一张。
  lu.assertEquals(#p1:getCardIds("h"), before)
  lu.assertEquals(p2.hp, 18)
end

function Testqiao_shu_conversion:testPaoxiaoEventHistoryIncludesExtraUseSlash()
  local p1, p2 = p(1), p(2)
  clearCards(p1)
  clearCards(p2)
  inRoom(function() p2.maxHp = 20; p2.hp = 20 end)
  setPlayPhase(p1)
  -- 第一张为 extraUse 的视为【杀】：不进入引擎使用次数历史。
  inRoom(function()
    C.useVirtualCard(room(), p1, "qiao__slash", nil, { p2 }, "qiao_test_extra", true)
  end)
  lu.assertEquals(p1:usedCardTimes("slash", Player.HistoryPhase), 0)
  grant(p1, PAOXIAO)
  local second = give(p1, "qiao__slash", Card.Spade, 2)
  local before = #p1:getCardIds("h")
  use(p1, Fk:getCardById(second), { p2 })
  -- 事件历史统计含 extraUse：第二张仍触发；通常次数历史只记录第二张。
  lu.assertEquals(#p1:getCardIds("h"), before)
  lu.assertEquals(p1:usedCardTimes("slash", Player.HistoryPhase), 1)
end

function Testqiao_shu_conversion:testLongdanFourConversionsAndRealJinkResponse()
  local p1, p2 = p(1), p(2)
  grant(p1, LONGDAN)
  clearCards(p1)
  local slash = give(p1, "qiao__slash", Card.Spade, 1)
  local jink = give(p1, "qiao__jink", Card.Heart, 2)
  local peach = give(p1, "qiao__peach", Card.Club, 3)
  local analeptic = give(p1, "qiao__analeptic", Card.Diamond, 4)
  local skill = Fk.skills[LONGDAN]

  local function converted(material, expected)
    local card = skill:viewAs(p1, { material })
    lu.assertNotNil(card)
    lu.assertEquals(card.name, expected)
    lu.assertEquals(card.skillName, LONGDAN)
  end
  converted(slash, "qiao__jink")
  converted(jink, "qiao__slash")
  converted(peach, "qiao__analeptic")
  converted(analeptic, "qiao__peach")

  lu.assertEquals(skill:filterPattern(p1, "qiao__jink", {}).pattern, "slash")
  lu.assertEquals(skill:filterPattern(p1, "qiao__slash", {}).pattern, "jink")
  lu.assertEquals(skill:filterPattern(p1, "qiao__peach", {}).pattern, "analeptic")
  lu.assertEquals(skill:filterPattern(p1, "qiao__analeptic", {}).pattern, "peach")

  -- 真实打出权限：【杀】当【闪】响应别人的【杀】。
  inRoom(function() p1.hp = p1.maxHp; p2.hp = p2.maxHp end)
  FkTest.setNextReplies(p1, { {
    card = { skill = LONGDAN, subcards = { slash } },
    targets = {},
  } })
  use(p2, Fk:cloneCard("qiao__slash"), { p1 })
  lu.assertEquals(p1.hp, p1.maxHp)
  lu.assertFalse(table.contains(p1:getCardIds("h"), slash))
end

function Testqiao_shu_conversion:testMashuOnlyChangesOwnDistance()
  local p1, p4 = p(1), p(4)
  local before = inRoom(function() return p1:distanceTo(p4) end)
  grant(p1, MASHU)
  local after = inRoom(function() return p1:distanceTo(p4) end)
  lu.assertEquals(after, before - 1)
  local reverse = inRoom(function() return p4:distanceTo(p1) end)
  lu.assertEquals(reverse, before)
end

function Testqiao_shu_conversion:testJizhiRealTrickAndDelayedTrickDraw()
  local p1, p2 = p(1), p(2)
  grant(p1, JIZHI)
  clearCards(p1)
  clearCards(p2)
  local foresight = give(p1, "qiao__foresight", Card.Heart, 2)
  local top1, top2 = inRoom(function()
    return room().draw_pile[1], room().draw_pile[2]
  end)
  setPlayPhase(p1)

  FkTest.setNextReplies(p1, { "1", { { top1 }, { top2 } } })
  use(p1, Fk:getCardById(foresight), { p1 })
  -- 洞烛先机摸 2 + 集智摸 1。
  lu.assertEquals(#p1:getCardIds("h"), 3)

  -- 延时锦囊同样触发。
  clearCards(p1)
  local indulgence = give(p1, "qiao__indulgence", Card.Club, 6)
  FkTest.setNextReplies(p1, { "1" })
  use(p1, Fk:getCardById(indulgence), { p2 })
  lu.assertEquals(#p1:getCardIds("h"), 1)
end

function Testqiao_shu_conversion:testJizhiExcludesConvertedAndVirtualTricks()
  local p1 = p(1)
  grant(p1, JIZHI)
  local jink = give(p1, "qiao__jink", Card.Spade, 9)
  local handBefore = #p1:getCardIds("h")

  local converted = Fk:cloneCard("qiao__dismantlement")
  converted.skillName = "test"
  converted:addSubcard(jink)
  local virtual = Fk:cloneCard("qiao__dismantlement")
  inRoom(function()
    room().logic:trigger(fk.CardUsing, p1, { card = converted })
    room().logic:trigger(fk.CardUsing, p1, { card = virtual })
  end)
  lu.assertEquals(#p1:getCardIds("h"), handBefore)
end

function Testqiao_shu_conversion:testLianhuanViewAsRealIronChainAndRecast()
  local p1, p2 = p(1), p(2)
  grant(p1, LIANHUAN)
  clearCards(p1)
  local club = give(p1, "qiao__jink", Card.Club, 3)
  local spade = give(p1, "qiao__jink", Card.Spade, 4)
  setPlayPhase(p1)
  local skill = Fk.skills[LIANHUAN]
  lu.assertTrue(skill:cardFilter(p1, club, {}, {}))
  lu.assertFalse(skill:cardFilter(p1, spade, {}, {}))

  -- 正式 ViewAs 入口：其他效果要求使用【铁索连环】时，梅花手牌可转化。
  local use
  FkTest.setNextReplies(p1, { {
    card = { skill = LIANHUAN, subcards = { club } },
    targets = { p1.id, p2.id },
  } })
  inRoom(function()
    use = room():askToUseCard(p1, {
      pattern = "iron_chain", skill_name = "qiao_test_lianhuan", cancelable = true,
    })
  end)
  lu.assertNotNil(use)
  lu.assertEquals(use.card.trueName, "iron_chain")
  lu.assertEquals(use.card.subcards, { club })
  lu.assertEquals(use.card.skillName, LIANHUAN)
  inRoom(function() room():useCard(use) end)
  lu.assertTrue(p1.chained)
  lu.assertTrue(p2.chained)

  -- 重铸：独立衍生主动效果，置入弃牌堆并摸一张。
  local club2 = give(p1, "qiao__jink", Card.Club, 6)
  lu.assertTrue(p1:hasSkill(LIANHUAN_RECAST))
  local before = #p1:getCardIds("h")
  activate(p1, LIANHUAN_RECAST, nil, { club2 })
  lu.assertEquals(room():getCardArea(club2), Card.DiscardPile)
  lu.assertEquals(#p1:getCardIds("h"), before)
end

function Testqiao_shu_conversion:testBazhenGrantFormalArmorAndArmorSwitch()
  local p1, p2 = p(1), p(2)
  grant(p1, BAZHEN)
  lu.assertEquals(#p1:getEquipments(Card.SubtypeArmor), 0)
  lu.assertTrue(p1:hasSkill(ARMOR_SKILL))

  -- 真实八卦阵判定：红色判定牌提供【闪】，抵消【杀】。
  inRoom(function()
    room():moveCardTo(room():printCard("qiao__slash", Card.Heart, 3), Card.DrawPile)
  end)
  FkTest.setNextReplies(p1, { "1" })
  inRoom(function() p1.hp = p1.maxHp end)
  use(p2, Fk:cloneCard("qiao__slash"), { p1 })
  lu.assertEquals(p1.hp, p1.maxHp)

  -- 装备防具后虚拟八卦阵失效；移除后恢复。
  local armor = give(p1, "qiao__vine", Card.Club, 2)
  equip(p1, armor)
  lu.assertFalse(p1:hasSkill(ARMOR_SKILL))
  inRoom(function() room():throwCard({ armor }, "test", p1, p1) end)
  lu.assertTrue(p1:hasSkill(ARMOR_SKILL))

  -- 无视防具（青釭剑）：虚拟八卦阵同样失效，不能提供【闪】。
  local p3 = p(3)
  local sword = give(p3, "qiao__qinggang_sword", Card.Spade, 5)
  equip(p3, sword)
  inRoom(function() p1.hp = p1.maxHp end)
  FkTest.setNextReplies(p1, { "__cancel" })
  use(p3, Fk:cloneCard("qiao__slash"), { p1 })
  lu.assertEquals(p1.hp, p1.maxHp - 1)

  revoke(p1, BAZHEN)
  lu.assertFalse(p1:hasSkill(ARMOR_SKILL))
end

function Testqiao_shu_conversion:testBazhenDoesNotStripRealEightDiagramSkill()
  local p1 = p(1)
  local armor = give(p1, "qiao__eight_diagram", Card.Spade, 2)
  equip(p1, armor)
  grant(p1, BAZHEN)
  -- 真实装备自己提供同名技能；八阵不额外授予，也不在失去时移除它。
  lu.assertTrue(p1:hasSkill(ARMOR_SKILL))
  revoke(p1, BAZHEN)
  lu.assertTrue(p1:hasSkill(ARMOR_SKILL))
  inRoom(function() room():throwCard({ armor }, "test", p1, p1) end)
  lu.assertFalse(p1:hasSkill(ARMOR_SKILL))
end

function Testqiao_shu_conversion:testBazhenRealShu011HiddenAndRemovalDoesNotLeakArmor()
  local p1 = p(1)
  -- 初始暗将阶段不因八阵白得八卦阵。
  lu.assertFalse(p1:hasSkill(ARMOR_SKILL))

  -- 真实 SHU011 武将接线：明置后无防具，八阵生效。
  inRoom(function()
    skill_test.installDualGenerals(room(), p1, {
      main = "qiao_heg__shu011",
      deputy = "qiao_test__shu_1",
      kingdom = "shu",
    })
  end)
  lu.assertTrue(p1:hasShownSkill(BAZHEN))
  lu.assertTrue(p1:hasSkill(ARMOR_SKILL))

  -- 暗置/失去来源：八阵不再提供虚拟八卦阵。
  inRoom(function()
    p1:loseSkill(BAZHEN)
    p1:addFakeSkill(Fk.skills[BAZHEN])
  end)
  lu.assertFalse(p1:hasShownSkill(BAZHEN))
  lu.assertFalse(p1:hasSkill(ARMOR_SKILL))

  -- 重新明置/获得技能：恢复。
  inRoom(function()
    p1:loseFakeSkill(Fk.skills[BAZHEN])
    room():handleAddLoseSkills(p1, BAZHEN, nil, false, true)
  end)
  lu.assertTrue(p1:hasShownSkill(BAZHEN))
  lu.assertTrue(p1:hasSkill(ARMOR_SKILL))
end

function Testqiao_shu_conversion:testBazhenHiddenPrelightCanRevealOnJinkRequest()
  local p1 = p(1)
  clearCards(p1)
  inRoom(function()
    p1.general = "anjiang"
    room():setPlayerMark(p1, "__heg_general", "qiao_heg__shu011")
    p1:addFakeSkill(Fk.skills[BAZHEN])
    room().logic:trigger(fk.GamePrepared, p1, {})
  end)
  lu.assertTrue(table.contains(p1.prelighted_skills, Fk.skills[BAZHEN]))
  lu.assertFalse(p1:hasSkill(ARMOR_SKILL))

  -- 需要【闪】时由八阵自身询问；答应后自动明置并调用正式八卦阵判定。
  inRoom(function()
    room():moveCardTo(room():printCard("qiao__slash", Card.Heart, 3), Card.DrawPile)
    p1.hp = p1.maxHp
  end)
  FkTest.setNextReplies(p1, { "1" })
  use(p(2), Fk:cloneCard("qiao__slash"), { p1 })
  lu.assertEquals(p1.hp, p1.maxHp)
  lu.assertEquals(p1.general, "qiao_heg__shu011")
  lu.assertTrue(p1:hasSkill(BAZHEN))
  lu.assertTrue(p1:hasSkill(ARMOR_SKILL))

end

function Testqiao_shu_conversion:testLianhuanRecastStopsWithMainSkill()
  local p1 = p(1)
  grant(p1, LIANHUAN)
  lu.assertTrue(p1:hasSkill(LIANHUAN_RECAST))
  revoke(p1, LIANHUAN)
  lu.assertFalse(p1:hasSkill(LIANHUAN))
  lu.assertFalse(p1:hasSkill(LIANHUAN_RECAST))
  -- 暗置/失去主技能时只保留假技能，不额外授予重铸。
  inRoom(function()
    p1:addFakeSkill(Fk.skills[LIANHUAN])
  end)
  lu.assertFalse(p1:hasSkill(LIANHUAN_RECAST))

  -- 主技能仅失效（未失去）时，重铸入口也必须停止。
  inRoom(function() p1:loseFakeSkill(Fk.skills[LIANHUAN]) end)
  grant(p1, LIANHUAN)
  give(p1, "qiao__jink", Card.Club, 3)
  setPlayPhase(p1)
  inRoom(function()
    local recast = Fk.skills[LIANHUAN_RECAST]
    lu.assertTrue(recast:canUse(p1))
    room():setPlayerMark(p1, MarkEnum.InvalidSkills, { [LIANHUAN] = true })
    lu.assertFalse(recast:canUse(p1))
    room():setPlayerMark(p1, MarkEnum.InvalidSkills, 0)
  end)
end

function Testqiao_shu_conversion:testHuojiViewAsRedHandOnly()
  local p1 = p(1)
  grant(p1, HUOJI)
  clearCards(p1)
  local red = give(p1, "qiao__jink", Card.Heart, 2)
  local black = give(p1, "qiao__jink", Card.Spade, 3)
  give(p(2), "qiao__jink", Card.Club, 4)
  setPlayPhase(p1)
  local skill = Fk.skills[HUOJI]
  local card = skill:viewAs(p1, { red })
  lu.assertNotNil(card)
  lu.assertEquals(card.name, "qiao__fire_attack")
  lu.assertEquals(card.skillName, HUOJI)
  -- 其他测试遗留的响应 pattern 会让 canUseOrResponseInCurrent 走响应分支。
  local savedPattern = Fk.currentResponsePattern
  Fk.currentResponsePattern = nil
  local redOK = skill:cardFilter(p1, red, {}, {})
  local blackOK = skill:cardFilter(p1, black, {}, {})
  Fk.currentResponsePattern = savedPattern
  lu.assertTrue(redOK)
  lu.assertFalse(blackOK)
end

function Testqiao_shu_conversion:testXiangleNullifiesWhenNoBasicOrChosen()
  local p1, p2 = p(1), p(2)
  grant(p2, XIANGL)
  clearCards(p1)
  clearCards(p2)
  setPlayPhase(p1)

  -- 无基本牌：直接无效。
  local first = give(p1, "qiao__slash", Card.Spade, 1)
  inRoom(function() p1.hp = p1.maxHp; p2.hp = p2.maxHp end)
  FkTest.setNextReplies(p2, { "__cancel" })
  use(p1, Fk:getCardById(first), { p2 })
  lu.assertEquals(p2.hp, p2.maxHp)

  -- 有基本牌但选择让【杀】无效：不弃牌，仍不受伤。
  local second = give(p1, "qiao__slash", Card.Spade, 2)
  local basic = give(p1, "qiao__jink", Card.Heart, 3)
  local choiceCount = 0
  skill_test.withSkillRequests(room(), XIANGL, {
    askToChoice = function(self, player, params)
      choiceCount = choiceCount + 1
      lu.assertIs(player, p1)
      return "#qiao__skill_shu013_1-nullify"
    end,
  }, function()
    use(p1, Fk:getCardById(second), { p2 })
  end)
  lu.assertEquals(choiceCount, 1)
  lu.assertTrue(table.contains(p1:getCardIds("h"), basic))
  lu.assertEquals(p2.hp, p2.maxHp)
end

function Testqiao_shu_conversion:testXiangleDiscardBasicKeepsSlashEffective()
  local p1, p2 = p(1), p(2)
  grant(p2, XIANGL)
  clearCards(p1)
  clearCards(p2)
  setPlayPhase(p1)
  inRoom(function() p1.hp = p1.maxHp; p2.hp = p2.maxHp end)
  local slash = give(p1, "qiao__slash", Card.Spade, 1)
  local basic = give(p1, "qiao__jink", Card.Heart, 3)

  -- 记录真实移动事件的 proposer：享乐弃牌应由【杀】使用者自己操作。
  local proposer
  local probe = fk.CreateSkill { name = "#qiao_shu_xiangle_proposer_probe" }
  probe:addEffect(fk.AfterCardsMove, {
    global = true,
    can_refresh = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        for _, info in ipairs(move.moveInfo or {}) do
          if info.cardId == basic and move.moveReason == fk.ReasonDiscard then return true end
        end
      end
      return false
    end,
    on_refresh = function(self, event, target, player, data)
      for _, move in ipairs(data or {}) do
        for _, info in ipairs(move.moveInfo or {}) do
          if info.cardId == basic then proposer = move.proposer end
        end
      end
    end,
  })
  inRoom(function() room():addSkill(probe:createSkill()) end)

  skill_test.withSkillRequests(room(), XIANGL, {
    askToChoice = function(self, player, params)
      lu.assertIs(player, p1)
      return "#qiao__skill_shu013_1-discard"
    end,
    askToCards = function(self, player, params)
      lu.assertIs(player, p1)
      return { basic }
    end,
  }, function()
    use(p1, Fk:getCardById(slash), { p2 })
  end)

  lu.assertFalse(table.contains(p1:getCardIds("h"), basic))
  lu.assertEquals(room():getCardArea(basic), Card.DiscardPile)
  lu.assertNotNil(proposer)
  lu.assertEquals(proposer.id, p1.id)
  lu.assertEquals(p2.hp, p2.maxHp - 1)
end


function Testqiao_shu_conversion:testBazhenRealHideRestoresHiddenRequestEntry()
  local player = p(1)
  inRoom(function()
    skill_test.installDualGenerals(room(), player, {
      main = "qiao_heg__shu011", deputy = "qiao_test__shu_1", kingdom = "shu",
    })
    player:hideGeneral(false)
  end)
  lu.assertEquals(player.general, "anjiang")
  lu.assertTrue(table.contains(player.prelighted_skills, Fk.skills[BAZHEN]))
  lu.assertFalse(player:hasSkill(ARMOR_SKILL))
end

return { name = "qiao_shu_conversion" }
