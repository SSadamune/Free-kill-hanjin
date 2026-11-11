local M = {}

-- Independent HanJin deck policy. These tables describe identities and which
-- physical card occupies a slot for a given allowed-faction set. Card effects
-- live in pkg/hanjin_cards and are deliberately not represented here.
M.equipment = {}
M.tricks = {}

M.regularKingdoms = { "wei", "shu", "wu", "qun", "han", "jin" }
M.trickKingdoms = { "wei", "shu", "wu", "qun", "han", "jin", "wild" }
M.HEJI_KEY = "hanjin_heji"

-- The complete base table has 52 + 52 + 52 + 6 positions. EX is mandatory and
-- is not an optional extension. This structural manifest is used by tests and
-- audits; physical cards are still owned by pkg/hanjin_cards.
M.baseSlotCount = 162
M.partitionSizes = { standard1 = 52, standard2 = 52, shibei = 52, ex = 6 }
M.basePositions = {}
for _, partition in ipairs({ "standard1", "standard2", "shibei" }) do
  for rank = 1, 13 do
    for suit = Card.Spade, Card.Diamond do
      table.insert(M.basePositions, { partition = partition, suit = suit, number = rank })
    end
  end
end
for _, slot in ipairs({
  { suit = Card.Spade, number = 2 },
  { suit = Card.Club, number = 2 },
  { suit = Card.Club, number = 4 },
  { suit = Card.Heart, number = 9 },
  { suit = Card.Heart, number = 12 },
  { suit = Card.Diamond, number = 12 },
}) do
  table.insert(M.basePositions, { partition = "ex", suit = slot.suit, number = slot.number })
end

local function toSet(value)
  if type(value) == "table" then
    if value[1] ~= nil then
      local set = {}
      for _, item in ipairs(value) do set[item] = true end
      return set
    end
    return value
  end
  return {}
end

local function kingdomList(kingdom)
  if type(kingdom) == "table" then return table.simpleClone(kingdom) end
  return { kingdom }
end

local function assertKingdoms(kingdoms, valid, what)
  assert(#kingdoms > 0, "Missing " .. what .. " kingdom")
  local seen = {}
  for _, kingdom in ipairs(kingdoms) do
    assert(table.contains(valid, kingdom), "Invalid " .. what .. " kingdom: " .. tostring(kingdom))
    assert(not seen[kingdom], "Duplicate " .. what .. " kingdom: " .. tostring(kingdom))
    seen[kingdom] = true
  end
end

-- `kingdom` may be a single id or an array. A multi-kingdom entry is available
-- when any of its kingdoms is allowed (the 魏/晋 虚妄之冕 rule), never only when
-- all of them are allowed.
--
-- `opts.slots` records the printed position(s), for audits only. `opts.partition`
-- names the section of the base table. `opts.slotId`, when known, is the card
-- package's replacement position used when a material has to be printed.
function M.registerEquipment(name, kingdom, replacement, opts)
  assert(type(name) == "string" and name ~= "", "Invalid equipment name")
  assert(replacement == nil or (type(replacement) == "string" and replacement ~= ""),
    "Invalid equipment replacement")
  local kingdoms = kingdomList(kingdom)
  assertKingdoms(kingdoms, M.regularKingdoms, "equipment")
  opts = opts or {}
  M.equipment[name] = {
    kingdom = kingdoms[1],
    kingdoms = kingdoms,
    replacement = replacement,
    slots = opts.slots,
    partition = opts.partition,
    slotId = opts.slotId,
  }
end

function M.registerTrick(name, kingdom)
  assert(type(name) == "string" and name ~= "", "Invalid trick name")
  assertKingdoms({ kingdom }, M.trickKingdoms, "trick")
  M.tricks[name] = kingdom
end

-- The six already-named independent lord equipments. Further entries are added
-- when pkg/hanjin_cards defines the corresponding independent identities; the
-- deck algorithm below is already generic over the registry.
M.registerEquipment("hanjin__liulongcanjia", "wei", "hanjin__zhuahuangfeidian",
  { partition = "standard1", slots = { { suit = Card.Heart, number = 13 } } })
M.registerEquipment("hanjin__dragon_phoenix", "shu", "hanjin__double_swords",
  { partition = "standard1", slots = { { suit = Card.Spade, number = 2 } } })
M.registerEquipment("hanjin__luminous_pearl", "wu", "hanjin__six_swords",
  { partition = "standard1", slots = { { suit = Card.Diamond, number = 6 } } })
M.registerEquipment("hanjin__peace_spell", "qun", "hanjin__jingfan",
  { partition = "shibei", slots = { { suit = Card.Heart, number = 3 } } })
M.registerEquipment("hanjin__chixiao_sword", "han", nil,
  { partition = "ex", slots = { { suit = Card.Heart, number = 9 } } })
M.registerEquipment("hanjin__linxiao_yuyu", "jin", "hanjin__jueying",
  { partition = "standard2", slots = { { suit = Card.Spade, number = 5 } } })
-- The engine currently stores one sub_type; the eventual card must implement the
-- two mount-slot semantics explicitly, as upstream liulongcanjia does.
M.equipment.hanjin__linxiao_yuyu.subtypes = { Card.SubtypeOffensiveRide, Card.SubtypeDefensiveRide }

-- The four tricks whose independent identities were registered before the full
-- base table existed. The remaining three (汉/晋/野心家) are registered together
-- with their pkg/hanjin_cards definitions.
M.registerTrick("hanjin__command_world", "wei")
M.registerTrick("hanjin__restore_heartland", "shu")
M.registerTrick("hanjin__strengthen_state", "wu")
M.registerTrick("hanjin__luanwu_chaos", "qun")

-- Declarative table from rules/card-deck.md and BAN-004. pkg/hanjin_cards owns the
-- internal identities; resolving by the required display name keeps this side
-- independent of those identifiers. Explicit registrations above win, and a
-- package may provide its own metadata without being overwritten here.
M.lordEquipmentTable = {
  { display = "赤霄剑", kingdoms = { "han" }, partition = "ex",
    slot = { suit = Card.Heart, number = 9 } },
  { display = "四海流钱", kingdoms = { "han" }, partition = "standard1",
    slot = { suit = Card.Spade, number = 4 }, replacement = "过河拆桥" },
  { display = "六龙骖驾", kingdoms = { "wei" }, partition = "standard1",
    slot = { suit = Card.Heart, number = 13 }, replacement = "爪黄飞电" },
  { display = "州郡领兵印", kingdoms = { "wei" }, partition = "ex",
    slot = { suit = Card.Spade, number = 2 }, replacement = "太公阴符" },
  { display = "飞龙夺凤", kingdoms = { "shu" }, partition = "standard1",
    slot = { suit = Card.Spade, number = 2 }, replacement = "雌雄双股剑" },
  { display = "锦绣征袍", kingdoms = { "shu" }, partition = "shibei",
    slot = { suit = Card.Spade, number = 2 }, replacement = "黑光铠" },
  { display = "定澜夜明珠", kingdoms = { "wu" }, partition = "standard1",
    slot = { suit = Card.Diamond, number = 6 }, replacement = "吴六剑" },
  { display = "飞云盖海", kingdoms = { "wu" }, partition = "standard2",
    slot = { suit = Card.Diamond, number = 13 }, replacement = "紫骍" },
  { display = "太平要术", kingdoms = { "qun" }, partition = "shibei",
    slot = { suit = Card.Heart, number = 3 }, replacement = "惊帆" },
  { display = "神授思召", kingdoms = { "qun" }, partition = "shibei",
    slot = { suit = Card.Spade, number = 5 }, replacement = "青龙偃月刀" },
  { display = "血海魔王樽", kingdoms = { "qun" }, partition = "shibei",
    slot = { suit = Card.Club, number = 2 }, replacement = "天机图" },
  { display = "临筱玉舆", kingdoms = { "jin" }, partition = "standard2",
    slot = { suit = Card.Spade, number = 5 }, replacement = "绝影" },
  { display = "驺虞幡", kingdoms = { "jin" }, partition = "standard1",
    slot = { suit = Card.Club, number = 1 }, replacement = "护心镜" },
  { display = "虚妄之冕", kingdoms = { "wei", "jin" }, partition = "ex",
    slot = { suit = Card.Club, number = 4 } },
}

M.factionTrickTable = {
  { display = "党锢之祸", kingdom = "han" },
  { display = "号令天下", kingdom = "wei" },
  { display = "克复中原", kingdom = "shu" },
  { display = "固国安邦", kingdom = "wu" },
  { display = "文和乱武", kingdom = "qun" },
  { display = "四海归平", kingdom = "jin" },
  { display = "洛水之誓", kingdom = "wild" },
}

-- The confirmed 16 adaptation groups (35 physical cards). This is metadata and
-- UI text only; effects and card-specific resolution remain in pkg/hanjin_cards.
-- Ordinary/fire/thunder/ice Slash are distinct names for this grouping.
M.adaptationGroups = {
  { key = "water_attack_zhuzhan", display = "水淹七军", condition = "zhuzhan",
    effect = "execute_both", text = "执行两项",
    slots = { { "standard1", Card.Spade, 3 }, { "standard2", Card.Spade, 4 } } },
  { key = "slash_kongchao", display = "杀", condition = "kongchao",
    effect = "add_target", text = "目标+1",
    slots = { { "standard1", Card.Club, 4 }, { "standard2", Card.Club, 5 },
      { "shibei", Card.Club, 6 } } },
  { key = "savage_assault_fujia", display = "南蛮入侵", condition = "fujia",
    effect = "remove_target", text = "目标-1",
    slots = { { "standard1", Card.Club, 7 }, { "standard2", Card.Spade, 13 } } },
  { key = "jink_kongchao", display = "闪", condition = "kongchao",
    effect = "draw", text = "摸一张牌",
    slots = { { "standard1", Card.Diamond, 7 }, { "standard1", Card.Diamond, 8 },
      { "standard2", Card.Diamond, 7 }, { "standard2", Card.Diamond, 8 },
      { "shibei", Card.Heart, 5 }, { "shibei", Card.Heart, 6 } } },
  { key = "slash_canqu", display = "杀", condition = "canqu",
    effect = "add_target", text = "目标+1",
    slots = { { "standard1", Card.Spade, 10 }, { "standard1", Card.Spade, 11 },
      { "shibei", Card.Club, 8 } } },
  { key = "reaching_zhuzhan", display = "逐近弃远", condition = "zhuzhan",
    effect = "execute_both", text = "执行两项",
    slots = { { "standard1", Card.Club, 12 }, { "standard2", Card.Spade, 3 } } },
  { key = "unexpected_zhuzhan", display = "出其不意", condition = "zhuzhan",
    effect = "add_target", text = "目标+1",
    slots = { { "standard2", Card.Heart, 2 }, { "standard2", Card.Heart, 3 } } },
  { key = "fire_slash_canqu", display = "火杀", condition = "canqu",
    effect = "damage", text = "伤害+1",
    slots = { { "standard2", Card.Heart, 4 }, { "standard2", Card.Diamond, 4 },
      { "shibei", Card.Diamond, 8 } } },
  { key = "nullification_kongchao", display = "无懈可击", condition = "kongchao",
    effect = "draw", text = "摸一张牌",
    slots = { { "standard2", Card.Spade, 11 } } },
  { key = "slash_gujun", display = "杀", condition = "gujun",
    effect = "add_target", text = "目标+1",
    slots = { { "shibei", Card.Spade, 4 }, { "shibei", Card.Club, 4 } } },
  { key = "fire_attack_zhuzhan", display = "火攻", condition = "zhuzhan",
    effect = "add_target", text = "目标+1",
    slots = { { "shibei", Card.Diamond, 4 }, { "shibei", Card.Heart, 13 } } },
  { key = "jink_gujun", display = "闪", condition = "gujun",
    effect = "obtain_response_card", text = "获得响应牌",
    slots = { { "shibei", Card.Heart, 7 }, { "shibei", Card.Diamond, 7 } } },
  { key = "thunder_slash_gujun", display = "雷杀", condition = "gujun",
    effect = "ignore_times", text = "无视次数",
    slots = { { "shibei", Card.Spade, 9 }, { "shibei", Card.Spade, 10 } } },
  { key = "slash_zhuzhan", display = "杀", condition = "zhuzhan",
    effect = "add_target", text = "目标+1",
    slots = { { "shibei", Card.Heart, 11 } } },
  { key = "collateral_fujia", display = "借刀杀人", condition = "fujia",
    effect = "disresponsive", text = "不可响应",
    slots = { { "shibei", Card.Club, 12 } } },
  { key = "nullification_gujun", display = "无懈可击", condition = "gujun",
    effect = "draw", text = "摸一张牌",
    slots = { { "shibei", Card.Spade, 13 } } },
}

M.adaptationCardCount = 0
for _, group in ipairs(M.adaptationGroups) do
  M.adaptationCardCount = M.adaptationCardCount + #group.slots
end

-- 合纵 belongs to the concrete physical card. These are the printed positions
-- marked `·合`; the 惊帆 replacement is included because the marker is on 惊帆,
-- while 神授思召's replacement 青龙偃月刀 has no marker of its own.
M.hejiSlots = {
  { display = "挟天子", partition = "shibei", suit = Card.Spade, number = 1 },
  { display = "挟天子", partition = "shibei", suit = Card.Diamond, number = 1 },
  { display = "火烧连营", partition = "shibei", suit = Card.Spade, number = 3 },
  { display = "火烧连营", partition = "shibei", suit = Card.Club, number = 11 },
  { display = "火烧连营", partition = "shibei", suit = Card.Heart, number = 12 },
  { display = "桃", partition = "shibei", suit = Card.Diamond, number = 3 },
  { display = "神授思召", partition = "shibei", suit = Card.Spade, number = 5 },
  { display = "雷杀", partition = "shibei", suit = Card.Club, number = 5 },
  { display = "雷杀", partition = "shibei", suit = Card.Spade, number = 11 },
  { display = "酒", partition = "shibei", suit = Card.Spade, number = 6 },
  { display = "调虎离山", partition = "shibei", suit = Card.Diamond, number = 10 },
  { display = "顺手牵羊", partition = "standard2", suit = Card.Diamond, number = 3 },
  { display = "惊帆", partition = "shibei", suit = Card.Heart, number = 3 },
}

local function displayedName(card)
  local display = Fk:translate(card.name)
  if display == card.name then return nil end
  -- 合纵 is a marker, not part of the printed name. Accept either presentation
  -- (惊帆 / 惊帆·合) while resolving the concrete card.
  return (display:gsub("·合$", ""))
end

local function rankNumber(value)
  if type(value) == "number" then return value end
  local map = { A = 1, J = 11, Q = 12, K = 13 }
  return map[value] or tonumber(value)
end

local function rankCode(value)
  if type(value) == "string" and value ~= "" and not tonumber(value) then return value end
  return ({ [1] = "A", [11] = "J", [12] = "Q", [13] = "K" })[tonumber(value)] or tostring(value)
end

local function suitConstant(value)
  if type(value) == "number" then return value end
  return ({ S = Card.Spade, H = Card.Heart, C = Card.Club, D = Card.Diamond })[value]
end

local function registeredAt(partition, suit, number)
  for name, entry in pairs(M.equipment) do
    local first = entry.slots and entry.slots[1]
    if first and entry.partition == partition and first.suit == suit and first.number == number then
      return name, entry
    end
  end
end

-- The card package publishes the authoritative position table. Consume it when
-- present so internal identities never have to be guessed from translations.
local function installContentData(data)
  M.contentData = data
  for _, spec in ipairs(data.lordEquipment or {}) do
    local suit, number = suitConstant(spec.suit), rankNumber(spec.number)
    if not suit or not number or not Fk.all_card_types[spec.card] then
      table.insert(M.missingDefinitions, { kind = "equipment", display = spec.display,
        suit = suit, number = number })
    else
      local existingName, existing = registeredAt(spec.partition, suit, number)
      local slotId = "replacement/" .. spec.partition .. "/" .. spec.suit .. "/" .. rankCode(number)
      if existing then
        M.equipment[spec.card] = existing
        existing.replacement = spec.replacementCard
        existing.slotId = slotId
      else
        M.registerEquipment(spec.card, spec.kingdoms, spec.replacementCard,
          { partition = spec.partition, slots = { { suit = suit, number = number } },
            slotId = slotId })
      end
    end
  end
  for _, spec in ipairs(data.factionTricks or {}) do
    if not Fk.all_card_types[spec.card] then
      table.insert(M.missingDefinitions, { kind = "trick", display = spec.display })
    else
      M.tricks[spec.card] = M.tricks[spec.card] or spec.kingdom
    end
  end
end

-- Resolve the declarative table against the concrete independent card package.
-- This is deliberately tolerant: the mode can be loaded while the content pack
-- is still incomplete, and missing definitions are recorded for the deck audit.
function M.installCardMetadata()
  if M._metadataInstalled then return end
  M._metadataInstalled = true
  M.missingDefinitions = {}
  local ok, data = pcall(require, "packages.hanjin.pkg.hanjin_cards.data.slots")
  if ok and type(data) == "table" then
    installContentData(data)
  else
    local cards = Fk.packages.hanjin_cards and Fk.packages.hanjin_cards.cards or {}
    local byDisplay = {}
    for _, card in ipairs(cards) do
      local display = displayedName(card)
      if display then
        byDisplay[display] = byDisplay[display] or {}
        table.insert(byDisplay[display], card)
      end
    end
    local function find(display, suit, number)
      for _, card in ipairs(byDisplay[display] or {}) do
        if (suit == nil or card.suit == suit) and (number == nil or card.number == number) then
          return card
        end
      end
    end
    -- A replacement type may exist without a printed spec when the deck is meant
    -- to print it on demand. Resolve that type too, still only inside hanjin_cards.
    local function findType(display)
      for _, prototype in pairs(Fk.all_card_types) do
        if prototype.package == Fk.packages.hanjin_cards and displayedName(prototype) == display then
          return prototype
        end
      end
    end
    for _, spec in ipairs(M.lordEquipmentTable) do
      local card = find(spec.display, spec.slot.suit, spec.slot.number)
      if not card then
        table.insert(M.missingDefinitions, { kind = "equipment", display = spec.display,
          suit = spec.slot.suit, number = spec.slot.number })
      else
        local ordinary
        if spec.replacement then
          ordinary = find(spec.replacement) or findType(spec.replacement)
          if not ordinary then
            table.insert(M.missingDefinitions, { kind = "replacement", display = spec.replacement,
              for_equipment = spec.display })
          end
        end
        local existingName, existing = registeredAt(spec.partition, spec.slot.suit, spec.slot.number)
        if existing then
          -- Explicit registrations survive an internal-name change; also accept the
          -- package's actual identity and read the replacement's own identity.
          M.equipment[card.name] = existing
          if ordinary then existing.replacement = ordinary.name end
        else
          M.registerEquipment(card.name, spec.kingdoms, ordinary and ordinary.name or nil,
            { partition = spec.partition, slots = { spec.slot } })
        end
      end
    end
    for _, spec in ipairs(M.factionTrickTable) do
      local card = find(spec.display)
      if not card then
        table.insert(M.missingDefinitions, { kind = "trick", display = spec.display })
      elseif not M.tricks[card.name] then
        M.registerTrick(card.name, spec.kingdom)
      end
    end
  end
  local cards = Fk.packages.hanjin_cards and Fk.packages.hanjin_cards.cards or {}
  local byDisplay = {}
  for _, card in ipairs(cards) do
    local display = displayedName(card)
    if display then
      byDisplay[display] = byDisplay[display] or {}
      table.insert(byDisplay[display], card)
    end
  end
  for _, slot in ipairs(M.hejiSlots) do
    local found = false
    for _, card in ipairs(byDisplay[slot.display] or {}) do
      if card.suit == slot.suit and card.number == slot.number then
        found = true
        -- Isolate the marker from a table shared with other printed positions.
        card.extra_data = table.simpleClone(card.extra_data or {})
        card.extra_data[M.HEJI_KEY] = true
      end
    end
    if not found then
      table.insert(M.missingDefinitions, { kind = "heji", display = slot.display,
        suit = slot.suit, number = slot.number })
    end
  end
  return M.missingDefinitions
end

function M.kingdomsOf(name)
  local spec = M.equipment[name]
  if spec then return spec.kingdoms end
  local trick = M.tricks[name]
  return trick and { trick } or nil
end

-- Cards use `unavailable` (the complement of this game's allowed set), not only
-- the random ban list: when |C| <= L there is no ban, yet every faction outside
-- C is still unavailable.
function M.equipmentAllowed(spec, unavailable)
  assert(spec and spec.kingdoms, "Unknown equipment specification")
  for _, kingdom in ipairs(spec.kingdoms) do
    if not unavailable[kingdom] then return true end
  end
  return false
end

function M.trickAllowed(name, unavailable)
  local kingdom = M.tricks[name]
  if not kingdom then return false end
  -- 野心家 never belongs to the regular allowed set and is not therefore banned.
  if kingdom == "wild" then return true end
  return not unavailable[kingdom]
end

-- Number of base positions that become empty because a no-replacement lord
-- equipment is unavailable. This follows the printed table rather than the
-- runtime registry, so test-only equipment can never alter the expected count.
function M.expectedVacancies(unavailable)
  unavailable = toSet(unavailable)
  local count = 0
  for _, spec in ipairs(M.lordEquipmentTable) do
    if not spec.replacement then
      local allowed = false
      for _, kingdom in ipairs(spec.kingdoms) do
        if not unavailable[kingdom] then allowed = true; break end
      end
      if not allowed then count = count + 1 end
    end
  end
  return count
end

local function matching(draw, name, suit, number, skip)
  for _, id in ipairs(draw) do
    if not skip[id] then
      local card = Fk:getCardById(id)
      if card.name == name and card.suit == suit and card.number == number then return id end
    end
  end
end

function M.apply(room, draw, void, unavailable, options)
  M.installCardMetadata()
  unavailable = toSet(unavailable)
  options = options or {}
  local includedTricks = toSet(options.include_tricks)
  local result, removed, replacements = {}, {}, {}
  local placed, suppressed, used = {}, {}, {}
  void = table.simpleClone(void or {})

  local function addResult(id)
    if not placed[id] then
      placed[id] = true
      table.insert(result, id)
    end
  end
  local function addVoid(id)
    if not table.contains(void, id) then table.insert(void, id) end
  end

  -- An available lord equipment replaces the ordinary card printed in the same
  -- position. Only that one matching physical copy is removed, never all cards
  -- sharing its name.
  for _, id in ipairs(draw) do
    local card = Fk:getCardById(id)
    local spec = M.equipment[card.name]
    if spec and spec.replacement and M.equipmentAllowed(spec, unavailable) then
      local ordinary = matching(draw, spec.replacement, card.suit, card.number, suppressed)
      if ordinary then
        suppressed[ordinary] = true
        addVoid(ordinary)
      end
    end
  end

  for _, id in ipairs(draw) do
    local card = Fk:getCardById(id)
    if suppressed[id] then
      -- The independent special equipment already occupies this slot.
    elseif M.tricks[card.name] and not (includedTricks[card.name] and M.trickAllowed(card.name, unavailable)) then
      -- All seven faction tricks stay outside the default draw pile even when
      -- their faction is allowed. A special effect may explicitly include one.
      addVoid(id)
    else
      local spec = M.equipment[card.name]
      if spec and not M.equipmentAllowed(spec, unavailable) then
        addVoid(id)
        table.insert(removed, id)
        if spec.replacement then
          local replacement
          -- Prefer the matching ordinary card already in the draw pile. If a
          -- custom deck omits it, print a room-local copy of the independent
          -- card with the same suit and number.
          replacement = matching(draw, spec.replacement, card.suit, card.number, used)
          if replacement then
            used[replacement] = true
            addResult(replacement)
          else
            replacement = table.find(void, function(candidate)
              if used[candidate] then return false end
              local c = Fk:getCardById(candidate)
              return c.name == spec.replacement and c.suit == card.suit and c.number == card.number
            end)
            if replacement then
              table.removeOne(void, replacement)
            else
              local prototype = assert(Fk.all_card_types[spec.replacement],
                "Missing independent replacement: " .. spec.replacement)
              assert(prototype.package.extensionName == "hanjin",
                "Replacement must be an independent HanJin card")
              local packageApi = Fk.packages.hanjin_cards
                and Fk.packages.hanjin_cards.hanjin_cards
              local printed
              if packageApi and packageApi.printCard and spec.slotId then
                -- Let the card package stamp the replacement slot's own metadata
                -- (adaptation and 合纵), not the replaced card's metadata.
                printed = packageApi.printCard(room, spec.replacement, card.suit, card.number, spec.slotId)
              else
                printed = room:printCard(spec.replacement, card.suit, card.number)
                local template = table.find(prototype.package.cards, function(candidate)
                  return candidate.name == spec.replacement and candidate.suit == card.suit
                    and candidate.number == card.number
                end) or prototype
                if template and template.extra_data then
                  printed.extra_data = table.simpleClone(template.extra_data)
                end
              end
              replacement = printed.id
            end
            used[replacement] = true
            addResult(replacement)
          end
          table.insert(replacements, { from = id, to = replacement })
        end
      else
        addResult(id)
      end
    end
  end

  room:setBanner("hanjin_banned_cards", removed)
  room:setBanner("hanjin_card_replacements", replacements)
  return result, void
end

-- 合纵 is card metadata, not a condition or an alias. This helper only reads the
-- concrete card's own marker; replacement code never copies it from another card.
function M.isHeji(card)
  local data = card ~= nil and card.extra_data or nil
  return type(data) == "table" and (data[M.HEJI_KEY] == true or data.hanjin_hezong == true)
end

return M
