local support = __dofile("../../../tests/support/hegemony.lua")
local Deck = __dofile("../../../tests/support/deck_content.lua")
local Ban = require "packages.hanjin.pkg.hanjin_mode.rules.faction_ban"
local Cards = require "packages.hanjin.pkg.hanjin_mode.rules.cards"
local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
Testhanjin_card_deck = { tearDown = support.clearRoom }

local function create(options)
  options = options or {}
  options.mode = "hanjin_heg_mode"
  options.realSelection = true
  return support.createRoom(options)
end

local function formal(ids)
  local result = {}
  for _, id in ipairs(ids) do
    local card = Fk:getCardById(id)
    if card.package == Fk.packages.hanjin_cards then table.insert(result, card) end
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
  if data.hanjin_partition and data.hanjin_suit and data.hanjin_number then
    return data.hanjin_partition .. "/" .. data.hanjin_suit .. "/" .. data.hanjin_number
  end
end

local function packageCard(name, suit, number)
  return table.find(Fk.packages.hanjin_cards.cards, function(card)
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

function Testhanjin_card_deck:testBaseTableHasExactly162UniquePrintedPositions()
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

function Testhanjin_card_deck:testLordEquipmentTableCoversFourteenPositionsAndTwelveReplacements()
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

function Testhanjin_card_deck:testWeiJinCrownUsesOrAndNeverAllOfThem()
  local crown = assert(table.find(Cards.lordEquipmentTable, function(spec)
    return spec.display == "虚妄之冕"
  end))
  lu.assertEquals(crown.kingdoms, { "wei", "jin" })
  lu.assertEquals(#crown.kingdoms, 2)
  lu.assertNil(crown.replacement)
end

function Testhanjin_card_deck:testSevenFactionTricksAndAllHejiPositionsAreRegistered()
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

function Testhanjin_card_deck:testAdaptationTableHasSixteenGroupsOfThirtyFivePhysicalCards()
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

function Testhanjin_card_deck:testDefaultDeckRespectsCandidateFilterAndSevenTrickExclusion()
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

function Testhanjin_card_deck:testWeiJinOrAndReplacementPairsInActualDeck()
  local room = create { settings = {
    hanjin_wild_count = 0,
    hanjin_candidate_kingdoms = { "wei", "shu" },
    hanjin_kingdom_limit = 2,
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

function Testhanjin_card_deck:testUnavailableBothWeiAndJinRemovesCrownWithoutReplacement()
  local room = create { settings = {
    hanjin_wild_count = 0,
    hanjin_candidate_kingdoms = { "shu", "wu" },
    hanjin_kingdom_limit = 2,
  } }
  local cards = roomCards(room)
  lu.assertNil(findCard(cards, "虚妄之冕"))
  -- 赤霄剑 and 虚妄之冕 are the only two no-replacement vacancies.
  lu.assertEquals(#cards, Cards.baseSlotCount - 2)
end

function Testhanjin_card_deck:testAdaptationMetadataOnActualCardsMatchesTheTable()
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

function Testhanjin_card_deck:testSyntheticBaseTableBuildsExactlyThePrintedPositions()
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

function Testhanjin_card_deck:testSyntheticReplacementPairsAndWeiJinOr()
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

function Testhanjin_card_deck:testSyntheticTricksCanOnlyEnterByExplicitSpecialMeans()
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

function Testhanjin_card_deck:testFormalPackagePublishesTheCompleteBaseTable()
  local H = assert(Fk.packages.hanjin_cards.hanjin_cards)
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
    return slot.card == "hanjin__thunder__slash"
  end)
  lu.assertEquals(#thunder, 2)
  for _, slot in ipairs(thunder) do
    lu.assertEquals(slot.partition, "shibei")
    lu.assertEquals(slot.suit, Card.Spade)
    lu.assertTrue(slot.number == 9 or slot.number == 10)
  end
end

function Testhanjin_card_deck:testCardsFollowTheDeclaredReuseOrShellDecision()
  local H = assert(Fk.packages.hanjin_cards.hanjin_cards)
  for _, slot in ipairs(H.baseSlots) do
    local card = packageCard(slot.card, slot.suit, slot.number)
    local reuse = assert(H.reuse[slot.card], "Missing reuse decision: " .. slot.card)
    lu.assertEquals(card.extra_data.hanjin_inert, reuse.status ~= "reused")
    if reuse.status == "reused" then
      lu.assertFalse(H.isInert(card), "Reused card must not be inert: " .. slot.id)
    else
      lu.assertTrue(H.isInert(card), "Deferred/missing card must stay inert: " .. slot.id)
    end
  end
  -- All seven printed Thunder Slash positions share the base effect, but only
  -- ♠9/♠10 carry the 孤军 entry.
  local thunder = table.filter(H.baseSlots, function(slot)
    return table.find({ "hanjin__thunder__slash", "hanjin__thunder_shell__slash" },
      function(name) return slot.card == name end) ~= nil
  end)
  lu.assertEquals(#thunder, 7)
  local gujun = 0
  for _, slot in ipairs(thunder) do
    local card = packageCard(slot.card, slot.suit, slot.number)
    lu.assertFalse(H.isInert(card))
    local entries = A.getEntries(card)
    lu.assertEquals(#entries, slot.card == "hanjin__thunder__slash" and 1 or 0)
    if #entries == 1 then gujun = gujun + 1 end
  end
  lu.assertEquals(gujun, 2)
end

function Testhanjin_card_deck:testFormalLordEquipmentMatchesThePolicyTable()
  local H = assert(Fk.packages.hanjin_cards.hanjin_cards)
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

function Testhanjin_card_deck:testAdaptationMetadataUsesTheExactPrintedSlots()
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

function Testhanjin_card_deck:testHejiMarkersBelongToTheirOwnPrintedPositions()
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

function Testhanjin_card_deck:testSevenFactionTricksExistOnlyOutsideTheDefaultDrawPile()
  local room = create()
  local H = assert(Fk.packages.hanjin_cards.hanjin_cards)
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

function Testhanjin_card_deck:testNationalAndOrdinaryNullificationStayDistinct()
  local national, ordinary = 0, 0
  for _, slot in ipairs(Cards.basePositions) do
    local card
    for _, entry in ipairs(Fk.packages.hanjin_cards.hanjin_cards.baseSlots) do
      if entry.partition == slot.partition and entry.suit == slot.suit
        and entry.number == slot.number then card = entry; break end
    end
    lu.assertNotNil(card, "Missing base position")
    if card.display == "无懈可击·国" then
      national = national + 1
      lu.assertEquals(card.card, "hanjin__guozhan__nullification")
    elseif card.display == "无懈可击" then
      ordinary = ordinary + 1
      lu.assertEquals(card.card, "hanjin__nullification")
    end
  end
  lu.assertEquals(national, 4)
  lu.assertEquals(ordinary, 2)
end

function Testhanjin_card_deck:testEveryReplacementMaterialCanOccupyItsSharedSlot()
  local room = create()
  local draw, void = {}, {}
  for _, card in ipairs(Fk.packages.hanjin_cards.cards) do
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

function Testhanjin_card_deck:testQunEquipmentKeepsOnlyItsOwnHejiMarkers()
  local room = create { settings = {
    hanjin_wild_count = 0,
    hanjin_candidate_kingdoms = { "qun", "wei" },
    hanjin_kingdom_limit = 2,
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

return { name = "hanjin_card_deck" }
