local support = __dofile("../../../tests/support/hegemony.lua")
local Deck = __dofile("../../../tests/support/deck_content.lua")
local Ban = require "packages.qiao.pkg.qiao_mode.rules.faction_ban"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
Testqiao_card_deck = { tearDown = support.clearRoom }

local function create(options)
  options = options or {}
  options.mode = "qiao_free_mode"
  options.realSelection = true
  return support.createRoom(options)
end

local function formal(ids)
  local result = {}
  for _, id in ipairs(ids) do
    local card = Fk:getCardById(id)
    if card.package == Fk.packages.qiao_cards then table.insert(result, card) end
  end
  return result
end

local function roomCards(room)
  local ids = table.simpleClone(room.draw_pile)
  for _, player in ipairs(room.players) do table.insertTable(ids, player:getCardIds("he")) end
  return formal(ids)
end

local function allowedSet(room)
  local set = {}
  for _, kingdom in ipairs(room:getBanner("all_kingdoms")) do set[kingdom] = true end
  return set
end

local function unavailable(room)
  local allowed = allowedSet(room)
  local result = {}
  for _, kingdom in ipairs(Ban.kingdoms) do
    if not allowed[kingdom] then table.insert(result, kingdom) end
  end
  return result
end

local function display(card)
  local text = Fk:translate(card.name)
  return (text:gsub("·合$", ""))
end

local function slotKey(card)
  local data = card.extra_data or {}
  if data.qiao_partition and data.qiao_suit and data.qiao_number then
    return data.qiao_partition .. "/" .. data.qiao_suit .. "/" .. data.qiao_number
  end
end

local function packageCard(name, suit, number)
  return table.find(Fk.packages.qiao_cards.cards, function(card)
    return card.name == name and (suit == nil or card.suit == suit)
      and (number == nil or card.number == number)
  end)
end

local function findCard(cards, name, suit, number)
  return table.find(cards, function(card)
    return display(card) == name and (suit == nil or card.suit == suit)
      and (number == nil or card.number == number)
  end)
end

function Testqiao_card_deck:testBaseTableHasExactly162UniquePrintedPositions()
  lu.assertEquals(Cards.baseSlotCount, 162)
  lu.assertEquals(#Cards.basePositions, 162)
  local counts, seen = {}, {}
  for _, slot in ipairs(Cards.basePositions) do
    counts[slot.partition] = (counts[slot.partition] or 0) + 1
    local key = slot.partition .. "/" .. slot.suit .. "/" .. slot.number
    lu.assertNil(seen[key])
    seen[key] = true
  end
  lu.assertEquals(counts, Cards.partitionSizes)
  lu.assertEquals(counts.standard1, 52)
  lu.assertEquals(counts.standard2, 52)
  lu.assertEquals(counts.shibei, 52)
  lu.assertEquals(counts.ex, 6)
  local ex = table.filter(Cards.basePositions, function(slot) return slot.partition == "ex" end)
  local exKeys = {}
  for _, slot in ipairs(ex) do exKeys[slot.suit .. "/" .. slot.number] = true end
  for _, key in ipairs({ "1/2", "2/2", "2/4", "3/9", "3/12", "4/12" }) do
    lu.assertTrue(exKeys[key], "Missing fixed EX position " .. key)
  end
end

function Testqiao_card_deck:testLordEquipmentTableCoversFourteenPositionsAndTwelveReplacements()
  lu.assertEquals(#Cards.lordEquipmentTable, 14)
  local replacements, none, multi = 0, 0, 0
  for _, spec in ipairs(Cards.lordEquipmentTable) do
    if spec.replacement then replacements = replacements + 1 else none = none + 1 end
    if #spec.kingdoms > 1 then multi = multi + 1 end
  end
  lu.assertEquals(replacements, 12)
  lu.assertEquals(none, 2) -- 赤霄剑 and 虚妄之冕
  lu.assertEquals(multi, 1)
  for _, spec in ipairs(Cards.lordEquipmentTable) do
    lu.assertTrue(table.find(Cards.basePositions, function(slot)
      return slot.partition == spec.partition and slot.suit == spec.slot.suit
        and slot.number == spec.slot.number
    end) ~= nil, "Equipment slot is outside the base table: " .. spec.display)
  end
end

function Testqiao_card_deck:testWeiJinCrownUsesOrAndNeverAllOfThem()
  local crown = assert(table.find(Cards.lordEquipmentTable, function(spec)
    return spec.display == "虚妄之冕"
  end))
  lu.assertEquals(crown.kingdoms, { "wei", "jin" })
  lu.assertEquals(#crown.kingdoms, 2)
  lu.assertNil(crown.replacement)
end

function Testqiao_card_deck:testSevenFactionTricksAndAllHejiPositionsAreRegistered()
  lu.assertEquals(#Cards.factionTrickTable, 7)
  local kingdoms = {}
  for _, spec in ipairs(Cards.factionTrickTable) do
    lu.assertNil(kingdoms[spec.kingdom])
    kingdoms[spec.kingdom] = true
  end
  for _, kingdom in ipairs({ "wei", "shu", "wu", "qun", "han", "jin", "wild" }) do
    lu.assertTrue(kingdoms[kingdom], "Missing faction trick for " .. kingdom)
  end
  lu.assertEquals(#Cards.hejiSlots, 13)
  local seen = {}
  for _, slot in ipairs(Cards.hejiSlots) do
    local key = slot.partition .. "/" .. slot.display .. "/" .. slot.suit .. "/" .. slot.number
    lu.assertNil(seen[key])
    seen[key] = true
  end
end

function Testqiao_card_deck:testAdaptationTableHasSixteenGroupsOfThirtyFivePhysicalCards()
  lu.assertEquals(#Cards.adaptationGroups, 16)
  lu.assertEquals(Cards.adaptationCardCount, 35)
  local count, seen = 0, {}
  local expected = {
    water_attack_zhuzhan = { "zhuzhan", "execute_both", "执行两项" },
    slash_kongchao = { "kongchao", "add_target", "目标+1" },
    savage_assault_fujia = { "fujia", "remove_target", "目标-1" },
    jink_kongchao = { "kongchao", "draw", "摸一张牌" },
    slash_canqu = { "canqu", "add_target", "目标+1" },
    reaching_zhuzhan = { "zhuzhan", "execute_both", "执行两项" },
    unexpected_zhuzhan = { "zhuzhan", "add_target", "目标+1" },
    fire_slash_canqu = { "canqu", "damage", "伤害+1" },
    nullification_kongchao = { "kongchao", "draw", "摸一张牌" },
    slash_gujun = { "gujun", "add_target", "目标+1" },
    fire_attack_zhuzhan = { "zhuzhan", "add_target", "目标+1" },
    jink_gujun = { "gujun", "obtain_response_card", "获得响应牌" },
    thunder_slash_gujun = { "gujun", "ignore_times", "无视次数" },
    slash_zhuzhan = { "zhuzhan", "add_target", "目标+1" },
    collateral_fujia = { "fujia", "disresponsive", "不可响应" },
    nullification_gujun = { "gujun", "draw", "摸一张牌" },
  }
  local groups = 0
  for _, group in ipairs(Cards.adaptationGroups) do
    groups = groups + 1
    count = count + #group.slots
    local spec = assert(expected[group.key], "Unexpected adaptation group " .. group.key)
    lu.assertEquals(group.condition, spec[1])
    lu.assertEquals(group.effect, spec[2])
    lu.assertEquals(group.text, spec[3])
    lu.assertTrue(#group.slots > 0)
    for _, slot in ipairs(group.slots) do
      local partition, suit, number = slot[1], slot[2], slot[3]
      lu.assertTrue(table.find(Cards.basePositions, function(position)
        return position.partition == partition and position.suit == suit and position.number == number
      end) ~= nil, "Adaptation slot outside the base table")
      local key = partition .. "/" .. suit .. "/" .. number
      lu.assertNil(seen[key], "Adaptation position used twice: " .. key)
      seen[key] = true
    end
  end
  lu.assertEquals(groups, 16)
  lu.assertEquals(count, 35)
end

function Testqiao_card_deck:testDefaultDeckRespectsCandidateFilterAndSevenTrickExclusion()
  local room = create()
  local cards = roomCards(room)
  local unavailable = unavailable(room)
  local expected = Cards.baseSlotCount - Cards.expectedVacancies(unavailable)
  lu.assertEquals(#cards, expected)
  for _, card in ipairs(cards) do
    local spec = Cards.equipment[card.name]
    if spec then
      lu.assertTrue(table.find(spec.kingdoms, function(kingdom)
        return table.contains(room:getBanner("all_kingdoms"), kingdom)
      end) ~= nil)
    end
    lu.assertNil(Cards.tricks[card.name], "Faction trick entered the default deck")
  end
end

function Testqiao_card_deck:testWeiJinOrAndReplacementPairsInActualDeck()
  local room = create { settings = {
    qiao_wild_count = 0,
    qiao_candidate_kingdoms = { "wei", "shu" },
    qiao_kingdom_limit = 2,
  } }
  local cards = roomCards(room)
  -- 魏 allowed: 虚妄之冕 stays even though 晋 is unavailable.
  lu.assertNotNil(findCard(cards, "虚妄之冕"))
  -- 汉 unavailable: 赤霄剑 leaves and gets no replacement.
  lu.assertNil(findCard(cards, "赤霄剑"))
  -- 汉 replacement pair keeps the slot.
  lu.assertNotNil(findCard(cards, "过河拆桥", Card.Spade, 4))
  lu.assertNil(findCard(cards, "四海流钱"))
  -- 晋 unavailable: 临筱玉舆 → 绝影, 驺虞幡 → 护心镜.
  lu.assertNotNil(findCard(cards, "绝影", Card.Spade, 5))
  lu.assertNotNil(findCard(cards, "护心镜", Card.Club, 1))
  lu.assertNil(findCard(cards, "临筱玉舆"))
  lu.assertNil(findCard(cards, "驺虞幡"))
  -- 群 unavailable: 太平要术 → 惊帆 (with its own 合纵 marker), not 青龙's.
  local jingfan = findCard(cards, "惊帆", Card.Heart, 3)
  lu.assertNotNil(jingfan)
  lu.assertTrue(Cards.isHeji(jingfan))
  local qinglong = findCard(cards, "青龙偃月刀", Card.Spade, 5)
  lu.assertNotNil(qinglong)
  lu.assertFalse(Cards.isHeji(qinglong))
  lu.assertEquals(#table.filter(cards, Cards.isHeji), 12)
end

function Testqiao_card_deck:testUnavailableBothWeiAndJinRemovesCrownWithoutReplacement()
  local room = create { settings = {
    qiao_wild_count = 0,
    qiao_candidate_kingdoms = { "shu", "wu" },
    qiao_kingdom_limit = 2,
  } }
  local cards = roomCards(room)
  lu.assertNil(findCard(cards, "虚妄之冕"))
  -- 赤霄剑 and 虚妄之冕 are the only two no-replacement vacancies.
  lu.assertEquals(#cards, Cards.baseSlotCount - 2)
end

function Testqiao_card_deck:testAdaptationMetadataOnActualCardsMatchesTheTable()
  local room = create()
  local groups = {}
  local count = 0
  for _, card in ipairs(roomCards(room)) do
    local entries = A.getEntries(card)
    if #entries > 0 then
      count = count + 1
      for _, entry in ipairs(entries) do
        local key = display(card) .. "/" .. entry.condition .. "/" .. entry.effect
        groups[key] = (groups[key] or 0) + 1
      end
    end
  end
  lu.assertEquals(count, 35)
  local keys = 0
  for _ in pairs(groups) do keys = keys + 1 end
  lu.assertEquals(keys, 16)
end

function Testqiao_card_deck:testSyntheticBaseTableBuildsExactlyThePrintedPositions()
  local room = create()
  local ids = Deck.drawIds()
  lu.assertEquals(#ids, 162 + 12 + 7)
  local result = Cards.apply(room, ids, {}, {})
  lu.assertEquals(#result, 162)
  local byId = {}
  for _, id in ipairs(result) do byId[id] = true end
  local heji, adaptations = 0, 0
  for _, id in ipairs(result) do
    local card = Fk:getCardById(id)
    lu.assertNil(Cards.tricks[card.name], "Faction trick entered the default deck")
    if Cards.isHeji(card) then heji = heji + 1 end
    adaptations = adaptations + #A.getEntries(card)
  end
  lu.assertEquals(heji, 12)
  lu.assertEquals(adaptations, 35)
end

function Testqiao_card_deck:testSyntheticReplacementPairsAndWeiJinOr()
  local room = create()
  local ids = Deck.drawIds()
  local function build(unavailable)
    local result = Cards.apply(room, ids, {}, unavailable)
    local cards = {}
    for _, id in ipairs(result) do table.insert(cards, Fk:getCardById(id)) end
    return result, cards
  end
  local function has(cards, name, suit, number)
    return findCard(cards, name, suit, number) ~= nil
  end
  local hanResult, han = build({ "han" })
  lu.assertEquals(#hanResult, 161)
  lu.assertFalse(has(han, "赤霄剑"))
  lu.assertTrue(has(han, "过河拆桥", Card.Spade, 4))
  lu.assertFalse(has(han, "四海流钱"))
  local weiJinResult, weiJin = build({ "wei", "jin" })
  lu.assertEquals(#weiJinResult, 161)
  lu.assertFalse(has(weiJin, "虚妄之冕"))
  lu.assertTrue(has(weiJin, "爪黄飞电", Card.Heart, 13))
  lu.assertTrue(has(weiJin, "绝影", Card.Spade, 5))
  lu.assertTrue(has(weiJin, "护心镜", Card.Club, 1))
  lu.assertFalse(has(weiJin, "六龙骖驾"))
  lu.assertFalse(has(weiJin, "临筱玉舆"))
  local bothResult, both = build({ "wei", "jin", "han" })
  lu.assertEquals(#bothResult, 160)
  lu.assertFalse(has(both, "赤霄剑"))
  lu.assertFalse(has(both, "虚妄之冕"))
  local jinResult, jin = build({ "jin" })
  lu.assertEquals(#jinResult, 162)
  lu.assertTrue(has(jin, "虚妄之冕")) -- 魏 is still allowed
  local qunResult, qun = build({ "qun" })
  local jingfan = findCard(qun, "惊帆", Card.Heart, 3)
  lu.assertNotNil(jingfan)
  lu.assertTrue(Cards.isHeji(jingfan))
  lu.assertFalse(Cards.isHeji(findCard(qun, "青龙偃月刀", Card.Spade, 5)))
  lu.assertEquals(#qunResult, 162)
end

function Testqiao_card_deck:testSyntheticTricksCanOnlyEnterByExplicitSpecialMeans()
  local room = create()
  local ids = Deck.drawIds()
  local trick = Fk:getCardById(Deck.trickIds[2]) -- 号令天下, 魏
  local included = Cards.apply(room, ids, {}, {}, { include_tricks = { trick.name } })
  lu.assertEquals(#included, 163)
  lu.assertTrue(table.contains(included, trick.id))
  local excluded = Cards.apply(room, ids, {}, { "wei" }, { include_tricks = { trick.name } })
  lu.assertEquals(#excluded, 162)
  lu.assertFalse(table.contains(excluded, trick.id))
end

function Testqiao_card_deck:testFormalPackagePublishesTheCompleteBaseTable()
  local H = assert(Fk.packages.qiao_cards.qiao_cards)
  lu.assertEquals(H.baseSlotCount, 162)
  lu.assertEquals(#H.baseSlots, 162)
  lu.assertEquals(H.partitions.standard1, 52)
  lu.assertEquals(H.partitions.standard2, 52)
  lu.assertEquals(H.partitions.shibei, 52)
  lu.assertEquals(H.partitions.ex, 6)
  lu.assertTrue(H.assertConsistent())
  local equipment, tricks, replacements = 0, 0, 0
  for _ in pairs(H.lordEquipment) do equipment = equipment + 1 end
  for _ in pairs(H.factionTricks) do tricks = tricks + 1 end
  for _ in pairs(H.replacements) do replacements = replacements + 1 end
  lu.assertEquals(equipment, 14)
  lu.assertEquals(tricks, 7)
  lu.assertEquals(replacements, 12)
  for _, slot in ipairs(H.baseSlots) do
    lu.assertNotNil(packageCard(slot.card, slot.suit, slot.number),
      "Missing physical card for base slot " .. slot.id)
  end
  local thunder = table.filter(H.baseSlots, function(slot)
    return slot.card == "qiao__thunder__slash"
  end)
  lu.assertEquals(#thunder, 7)
  local thunderKeys = {}
  for _, slot in ipairs(thunder) do thunderKeys[slot.id] = true end
  for _, id in ipairs({ "standard1/C/6", "standard2/C/7", "standard2/C/8",
    "shibei/C/5", "shibei/S/9", "shibei/S/10", "shibei/S/J" }) do
    lu.assertTrue(thunderKeys[id], "Missing Thunder Slash position " .. id)
  end
end

function Testqiao_card_deck:testCardsFollowTheDeclaredReuseOrShellDecision()
  local H = assert(Fk.packages.qiao_cards.qiao_cards)
  for _, slot in ipairs(H.baseSlots) do
    local card = packageCard(slot.card, slot.suit, slot.number)
    local reuse = assert(H.reuse[slot.card], "Missing reuse decision: " .. slot.card)
    lu.assertEquals(card.extra_data.qiao_inert, reuse.status ~= "reused")
    if reuse.status == "reused" then
      lu.assertFalse(H.isInert(card), "Reused card must not be inert: " .. slot.id)
    else
      lu.assertTrue(H.isInert(card), "Deferred/missing card must stay inert: " .. slot.id)
    end
  end
  -- All seven printed Thunder Slash positions share one identity and the base
  -- effect, but only 势备 ♠9/♠10 carry the 孤军 entry.
  local thunder = table.filter(H.baseSlots, function(slot)
    return slot.card == "qiao__thunder__slash"
  end)
  lu.assertEquals(#thunder, 7)
  local gujun = 0
  for _, slot in ipairs(thunder) do
    local card = packageCard(slot.card, slot.suit, slot.number)
    lu.assertFalse(H.isInert(card))
    local entries = A.getEntries(card)
    local expected = slot.id == "shibei/S/9" or slot.id == "shibei/S/10"
    lu.assertEquals(#entries, expected and 1 or 0)
    if expected then
      lu.assertEquals(entries[1].condition, "gujun")
      lu.assertEquals(entries[1].effect, "ignore_times")
      gujun = gujun + 1
    end
  end
  lu.assertEquals(gujun, 2)
end

function Testqiao_card_deck:testThunderSlashDescriptionUsesEachPrintedSlotOnly()
  local function face(suit, number)
    local card = packageCard("qiao__thunder__slash", suit, number)
    lu.assertNotNil(card, "Missing Thunder Slash " .. suit .. "/" .. number)
    return card:getDynamicDescription(nil, "zh_CN")
  end
  local base = face(Card.Club, 6)
  lu.assertTrue(base:find("对目标角色造成1点雷电伤害", 1, true) ~= nil)
  lu.assertNil(base:find("孤军", 1, true))
  lu.assertNil(base:find("合纵", 1, true))
  for _, slot in ipairs({ { Card.Club, 7 }, { Card.Club, 8 } }) do
    local text = face(slot[1], slot[2])
    lu.assertNil(text:find("孤军", 1, true), "Non-孤军 Thunder Slash must not show 孤军")
    lu.assertNil(text:find("合纵", 1, true), "Non-合纵 Thunder Slash must not show 合纵")
  end
  for _, number in ipairs({ 9, 10 }) do
    local text = face(Card.Spade, number)
    lu.assertTrue(text:find("<b>应变·孤军</b>：此牌无视次数。", 1, true) ~= nil,
      "孤军 Thunder Slash must keep the printed 孤军 text")
  end
  for _, slot in ipairs({ { Card.Club, 5 }, { Card.Spade, 11 } }) do
    local text = face(slot[1], slot[2])
    lu.assertTrue(text:find("<b>合纵</b>", 1, true) ~= nil, "合纵 Thunder Slash must show 合纵")
    lu.assertNil(text:find("孤军", 1, true), "合纵 Thunder Slash must not show 孤军")
  end
  -- The card type template and a virtual clone carry neither slot's markers.
  local template = assert(Fk.all_card_types["qiao__thunder__slash"])
  lu.assertNil((template.extra_data or {}).qiao_adaptation)
  local clone = Fk:cloneCard("qiao__thunder__slash")
  local cloneText = clone:getDynamicDescription(nil, "zh_CN")
  lu.assertNil(cloneText:find("孤军", 1, true))
  lu.assertNil(cloneText:find("合纵", 1, true))
end

function Testqiao_card_deck:testFormalLordEquipmentMatchesThePolicyTable()
  local H = assert(Fk.packages.qiao_cards.qiao_cards)
  for _, spec in ipairs(Cards.lordEquipmentTable) do
    local found
    for _, lord in pairs(H.lordEquipment) do
      if lord.display == spec.display then found = lord; break end
    end
    lu.assertNotNil(found, "Missing formal lord equipment " .. spec.display)
    lu.assertEquals(found.kingdoms, spec.kingdoms)
    lu.assertEquals(found.partition, spec.partition)
    lu.assertEquals(found.suit, spec.slot.suit)
    lu.assertEquals(found.number, spec.slot.number)
    if spec.replacement then
      lu.assertNotNil(found.replacementCard, "Missing replacement identity for " .. spec.display)
    else
      lu.assertNil(found.replacementCard)
    end
  end
end

function Testqiao_card_deck:testAdaptationMetadataUsesTheExactPrintedSlots()
  local room = create()
  local expected, seen = {}, {}
  for _, group in ipairs(Cards.adaptationGroups) do
    for _, slot in ipairs(group.slots) do
      expected[slot[1] .. "/" .. slot[2] .. "/" .. slot[3]] = group
    end
  end
  for _, card in ipairs(roomCards(room)) do
    local entries = A.getEntries(card)
    local key = slotKey(card)
    if #entries > 0 then
      lu.assertNotNil(key, "Adaptation card has no printed slot metadata")
      local group = assert(expected[key], "Unexpected adaptation slot " .. tostring(key))
      lu.assertEquals(#entries, 1)
      lu.assertEquals(entries[1].condition, group.condition)
      lu.assertEquals(entries[1].effect, group.effect)
      lu.assertNil(seen[key], "Adaptation slot repeated: " .. key)
      seen[key] = true
    elseif key and expected[key] then
      error("Missing adaptation metadata at " .. key)
    end
  end
  local count = 0
  for _ in pairs(seen) do count = count + 1 end
  lu.assertEquals(count, 35)
end

function Testqiao_card_deck:testEveryAdaptationCardExposesTheConfirmedConditionTextAndEffect()
  local room = create()
  local groups = {}
  for _, group in ipairs(Cards.adaptationGroups) do
    groups[group.display .. "/" .. group.condition .. "/" .. group.effect] = group
  end
  local seen, cards = {}, 0
  for _, card in ipairs(roomCards(room)) do
    local entries = A.getEntries(card)
    if #entries > 0 then
      lu.assertEquals(#entries, 1)
      local entry = entries[1]
      cards = cards + 1
      local key = display(card) .. "/" .. entry.condition .. "/" .. entry.effect
      local group = assert(groups[key], "Unexpected adaptation entry " .. key)
      local conditionText = Fk:translate("qiao_condition_" .. entry.condition)
      local effectText = Fk:translate("qiao_adaptation_" .. entry.effect)
      lu.assertNotEquals(conditionText, "qiao_condition_" .. entry.condition)
      lu.assertEquals(effectText, group.text)
      lu.assertEquals(display(card), group.display)
      lu.assertTrue(A.isAdaptationCard(card))
      lu.assertEquals(A.entryTip(entry), conditionText .. "·" .. effectText)
      local tips = assert(A.cardTips(card))
      lu.assertEquals(#tips, 1)
      lu.assertEquals(tips[1].content, conditionText .. "·" .. effectText)
      local mark = A.markValue(entry)
      lu.assertEquals(mark, { "·", "qiao_adaptation_" .. entry.effect })
      lu.assertEquals(Fk:translate(mark[1]), "·")
      lu.assertEquals(Fk:translate(mark[2]), group.text)
      local description = card:getDynamicDescription(room.players[1], "zh_CN")
      lu.assertNotNil(card.dynamicDesc, "Adaptation card must use the dynamic description: " .. key)
      local expectedEffect = effectText
      if card.name == "qiao__thunder__slash" then
        -- 势备 ♠9/♠10 保留卡面原文；效果标记仍为“无视次数”。
        expectedEffect = "此牌无视次数。"
      end
      lu.assertTrue(description:find("<b>应变·" .. conditionText .. "</b>：" .. expectedEffect, 1, true) ~= nil,
        "Missing dynamic face text for " .. key)
      seen[key] = (seen[key] or 0) + 1
    end
  end
  lu.assertEquals(cards, 35)
  local count = 0
  for key, group in pairs(groups) do
    count = count + 1
    lu.assertEquals(seen[key], #group.slots, "Wrong physical count for " .. key)
  end
  lu.assertEquals(count, 16)
end

function Testqiao_card_deck:testEveryAdaptationEffectHasARegisteredHandler()
  local room = create()
  local seen = 0
  for _, group in ipairs(Cards.adaptationGroups) do
    local card = Fk:cloneCard("qiao__slash")
    A.setCardEntries(card, {
      { id = "probe_" .. seen, condition = group.condition, effect = group.effect },
    })
    local use = UseCardData:new { from = room.players[1], tos = {}, card = card, extra_data = {} }
    FkTest.runInRoom(function() A.prepare(room, use) end)
    local result = A.getResult(use)
    lu.assertIsTrue(result.is_adaptation_card)
    lu.assertEquals(result.condition_timing, "sequential")
    seen = seen + 1
  end
  lu.assertEquals(seen, 16)
end

function Testqiao_card_deck:testHejiMarkersBelongToTheirOwnPrintedPositions()
  local room = create()
  local expected = {}
  for _, slot in ipairs(Cards.hejiSlots) do
    expected[slot.partition .. "/" .. slot.suit .. "/" .. slot.number] = true
  end
  local count = 0
  for _, card in ipairs(roomCards(room)) do
    if Cards.isHeji(card) then
      local key = slotKey(card)
      lu.assertNotNil(key, "合纵 card has no printed slot metadata")
      lu.assertTrue(expected[key], "Unexpected 合纵 slot " .. tostring(key))
      count = count + 1
    end
  end
  lu.assertEquals(count, 12)
end

function Testqiao_card_deck:testSevenFactionTricksExistOnlyOutsideTheDefaultDrawPile()
  local room = create()
  local H = assert(Fk.packages.qiao_cards.qiao_cards)
  local inPile = {}
  for _, id in ipairs(room.draw_pile) do inPile[id] = true end
  for _, player in ipairs(room.players) do
    for _, id in ipairs(player:getCardIds("he")) do inPile[id] = true end
  end
  local seen = 0
  for _, trick in pairs(H.factionTricks) do
    local card = packageCard(trick.card, trick.suit, trick.number)
    lu.assertNotNil(card, "Missing faction trick " .. trick.display)
    lu.assertNil(inPile[card.id], "Faction trick entered the default deck")
    lu.assertTrue(table.contains(room.void, card.id), "Faction trick should start in void")
    seen = seen + 1
  end
  lu.assertEquals(seen, 7)
end

function Testqiao_card_deck:testFactionTrickShellMetadataFollowsItsReuseDecision()
  local room = create()
  local H = assert(Fk.packages.qiao_cards.qiao_cards)
  local seen = 0
  for _, trick in pairs(H.factionTricks) do
    local card = packageCard(trick.card, trick.suit, trick.number)
    lu.assertNotNil(card, "Missing faction trick " .. trick.display)
    local position = assert(H.getSlot(card), "Missing faction trick position " .. trick.display)
    local reused = assert(H.reuse[trick.card], "Missing reuse decision " .. trick.display).status == "reused"
    lu.assertEquals(card.extra_data.qiao_inert, not reused,
      "势力锦囊的牌元数据空壳标记应与复用决定一致: " .. trick.display)
    lu.assertEquals(position.inert, not reused,
      "势力锦囊的牌位空壳标记应与复用决定一致: " .. trick.display)
    lu.assertEquals(H.isInert(card), not reused,
      "势力锦囊的运行时空壳判定应与复用决定一致: " .. trick.display)
    lu.assertEquals(room:getCardArea(card.id), Card.Void,
      "势力锦囊默认位于游戏外: " .. trick.display)
    seen = seen + 1
  end
  lu.assertEquals(seen, 7)
end

function Testqiao_card_deck:testNationalAndOrdinaryNullificationStayDistinct()
  local national, ordinary = 0, 0
  for _, slot in ipairs(Cards.basePositions) do
    local card
    for _, entry in ipairs(Fk.packages.qiao_cards.qiao_cards.baseSlots) do
      if entry.partition == slot.partition and entry.suit == slot.suit
        and entry.number == slot.number then card = entry; break end
    end
    lu.assertNotNil(card, "Missing base position")
    if card.display == "无懈可击·国" then
      national = national + 1
      lu.assertEquals(card.card, "qiao__guozhan__nullification")
    elseif card.display == "无懈可击" then
      ordinary = ordinary + 1
      lu.assertEquals(card.card, "qiao__nullification")
    end
  end
  lu.assertEquals(national, 4)
  lu.assertEquals(ordinary, 2)
end

function Testqiao_card_deck:testEveryReplacementMaterialCanOccupyItsSharedSlot()
  local room = create()
  local draw, void = {}, {}
  for _, card in ipairs(Fk.packages.qiao_cards.cards) do
    table.insert(card.is_derived and void or draw, card.id)
  end
  local function build(unavailable)
    local result = Cards.apply(room, draw, void, unavailable)
    local cards = {}
    for _, id in ipairs(result) do table.insert(cards, Fk:getCardById(id)) end
    return cards
  end
  local cards = build({ "shu", "wu", "qun", "han", "jin" })
  lu.assertEquals(#cards, 161) -- only 赤霄剑 has no replacement
  for _, name in ipairs({ "雌雄双股剑", "黑光铠", "吴六剑", "紫骍", "惊帆",
    "青龙偃月刀", "天机图", "绝影", "护心镜" }) do
    lu.assertNotNil(findCard(cards, name), "Missing replacement material " .. name)
  end
  lu.assertNotNil(findCard(cards, "过河拆桥", Card.Spade, 4))
  lu.assertNotNil(findCard(cards, "虚妄之冕")) -- 魏 is still allowed
  lu.assertNil(findCard(cards, "赤霄剑"))
  for _, name in ipairs({ "飞龙夺凤", "锦绣征袍", "定澜夜明珠", "飞云盖海",
    "太平要术", "神授思召", "血海魔王樽", "临筱玉舆", "驺虞幡", "四海流钱" }) do
    lu.assertNil(findCard(cards, name), "Unavailable lord equipment stayed in the deck: " .. name)
  end
  cards = build({ "wei", "wu", "qun", "han", "jin" })
  lu.assertEquals(#cards, 160) -- 赤霄剑 and 虚妄之冕 have no replacement
  for _, name in ipairs({ "爪黄飞电", "太公阴符", "吴六剑", "紫骍", "惊帆",
    "青龙偃月刀", "天机图", "绝影", "护心镜" }) do
    lu.assertNotNil(findCard(cards, name), "Missing replacement material " .. name)
  end
  lu.assertNotNil(findCard(cards, "过河拆桥", Card.Spade, 4))
  lu.assertNotNil(findCard(cards, "飞龙夺凤"))
  lu.assertNotNil(findCard(cards, "锦绣征袍"))
  lu.assertNil(findCard(cards, "虚妄之冕"))
end

function Testqiao_card_deck:testQunEquipmentKeepsOnlyItsOwnHejiMarkers()
  local room = create { settings = {
    qiao_wild_count = 0,
    qiao_candidate_kingdoms = { "qun", "wei" },
    qiao_kingdom_limit = 2,
  } }
  local cards = roomCards(room)
  local shenshou = findCard(cards, "神授思召")
  lu.assertNotNil(shenshou)
  lu.assertTrue(Cards.isHeji(shenshou))
  local taiping = findCard(cards, "太平要术")
  lu.assertNotNil(taiping)
  lu.assertFalse(Cards.isHeji(taiping))
  lu.assertNil(findCard(cards, "惊帆"))
  lu.assertNil(findCard(cards, "青龙偃月刀"))
end

return { name = "qiao_card_deck" }
