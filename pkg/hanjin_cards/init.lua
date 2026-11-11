-- 紫乔汉晋·卡牌
--
-- This package owns the formal, independent HanJin card identities. It defines
-- all 162 physical base positions from rules/card-deck.md, the twelve lord-
-- equipment replacement materials, and the seven faction tricks that stay
-- outside the default deck. Only the existing Thunder Slash positions (spade 9
-- and spade 10) keep a usable effect; every other card is an explicitly inert
-- shell whose card skill cannot be used.
--
-- The runtime policy side reads the same identities through the HanJin card
-- name and through extra_data. The public interface is exposed as
-- `Fk.packages.hanjin_cards.hanjin_cards` (also `.hanjin`).

local extension = Package:new("hanjin_cards", Package.CardPack)
extension.extensionName = "hanjin"
extension.game_modes_whitelist = { "hanjin_heg_mode" }
extension:loadSkillSkelsByPath("./packages/hanjin/pkg/hanjin_cards/skills")

local CardData = require "packages.hanjin.pkg.hanjin_cards.data.cards"
local SlotData = require "packages.hanjin.pkg.hanjin_cards.data.slots"
local ReuseData = require "packages.hanjin.pkg.hanjin_cards.data.reuse"

local SUITS = { S = Card.Spade, H = Card.Heart, C = Card.Club, D = Card.Diamond }
local RANKS = { A = 1, J = 11, Q = 12, K = 13, ["1"] = 1, ["11"] = 11, ["12"] = 12, ["13"] = 13 }
for rank = 2, 10 do RANKS[tostring(rank)] = rank end

local KINGDOM_LABEL = {
  wei = "魏", shu = "蜀", wu = "吴", qun = "群", han = "汉", jin = "晋", wild = "野心家",
}
local CONDITION_TEXT = {
  fujia = "富甲", canqu = "残躯", zhuzhan = "助战", kongchao = "空巢", gujun = "孤军",
}
local EFFECT_TEXT = {
  execute_both = "执行两项",
  add_target = "目标+1",
  remove_target = "目标-1",
  draw = "摸一张牌",
  damage = "伤害+1",
  obtain_response_card = "获得响应牌",
  ignore_times = "无视次数",
  disresponsive = "不可响应",
}

local function suit(value)
  return assert(SUITS[value], "Invalid HanJin card suit: " .. tostring(value))
end

local function rank(value)
  return assert(RANKS[value], "Invalid HanJin card rank: " .. tostring(value))
end

local function positionId(partition, suitCode, rankCode)
  return partition .. "/" .. suitCode .. "/" .. rankCode
end

local TYPE_BY_ID = {}
for _, cardType in ipairs(CardData.types) do
  assert(not TYPE_BY_ID[cardType.id], "Duplicate HanJin card type: " .. cardType.id)
  TYPE_BY_ID[cardType.id] = cardType
end

local LORD_BY_CARD = {}
local REPLACEMENT_BY_CARD = {}
for _, lord in ipairs(SlotData.lordEquipment) do
  LORD_BY_CARD[lord.card] = lord
  if lord.replacementCard then REPLACEMENT_BY_CARD[lord.replacementCard] = lord end
end

-- Card prototypes -----------------------------------------------------------

local function shellDescription(cardType)
  local lines
  if cardType.type == "basic" then
    lines = { "基本牌" }
  elseif cardType.type == "equip" then
    local label = "装备牌"
    if cardType.subtype == Card.SubtypeWeapon then label = "装备牌·武器"
    elseif cardType.subtype == Card.SubtypeArmor then label = "装备牌·防具"
    elseif cardType.subtype == Card.SubtypeOffensiveRide
      or cardType.subtype == Card.SubtypeDefensiveRide then label = "装备牌·坐骑"
    elseif cardType.subtype == Card.SubtypeTreasure then label = "装备牌·宝物" end
    lines = { label }
    if cardType.type == "equip" and cardType.subtype == Card.SubtypeWeapon
      and (cardType.range or 0) > 0 then
      table.insert(lines, "<b>攻击范围</b>：" .. cardType.range)
    end
    if cardType.subtypes then
      table.insert(lines, "<b>副类别</b>：进攻坐骑、防御坐骑")
    end
  else
    lines = { cardType.delayed and "延时锦囊牌" or "锦囊牌" }
  end
  if cardType.faction_trick then
    table.insert(lines, "<b>势力</b>：" .. (KINGDOM_LABEL[cardType.kingdom] or cardType.kingdom))
    table.insert(lines, "<b>牌堆</b>：仅通过特殊手段加入，不在默认牌堆")
  elseif cardType.national then
    table.insert(lines, "<b>版本</b>：国战")
  end
  table.insert(lines, "<b>状态</b>：正式牌位已登记，牌面效果尚未实装；本牌不能使用。")
  return table.concat(lines, "<br/>")
end

local THUNDER_SLASH_DESCRIPTION = "基本牌<br/><b>时机</b>：出牌阶段<br/>"
  .. "<b>目标</b>：攻击范围内的一名角色<br/>"
  .. "<b>效果</b>：对目标角色造成1点雷电伤害。<br/><b>应变·孤军</b>：此牌无视次数。"

local THUNDER_SHELL_DESCRIPTION = "基本牌<br/><b>时机</b>：出牌阶段<br/>"
  .. "<b>目标</b>：攻击范围内的一名角色<br/>"
  .. "<b>效果</b>：对目标角色造成1点雷电伤害。"

-- Reference implementations adapted into HanJin skills. These descriptions are
-- the confirmed local 应变 card texts, not invented effects.
local DESCRIPTION_OVERRIDES = {
  ["hanjin__ice__slash"] = "基本牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：攻击范围内的一名角色<br/>"
    .. "<b>效果</b>：对目标角色造成1点冰冻伤害。<br/>"
    .. "（一名角色造成不为连环伤害的冰冻伤害时，若受到此伤害的角色有牌，来源可防止此伤害，然后依次弃置其两张牌）。",
  ["hanjin__foresight"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：你<br/>"
    .. "<b>效果</b>：目标角色卜算2（观看牌堆顶的两张牌，将其中任意张以任意顺序置于牌堆顶，其余以任意顺序置于牌堆底），然后摸两张牌。",
  ["hanjin__chasing_near"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一名区域里有牌的其他角色<br/>"
    .. "<b>效果</b>：若你与目标角色距离为1，你获得其区域里一张牌；若你与目标角色距离大于1，你弃置其区域里一张牌。",
  ["hanjin__unexpectation"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一名有手牌的其他角色<br/>"
    .. "<b>效果</b>：你展示目标角色的一张手牌，若该牌与此【出其不意】花色不同，你对其造成1点伤害。",
  ["hanjin__five_elements_fan"] = "装备牌·武器<br/><b>攻击范围</b>：4<br/>"
    .. "<b>武器技能</b>：当你声明使用非普通【杀】后，你可以将此【杀】改为雷【杀】、火【杀】、冰【杀】或任意其他非普通【杀】。",
  ["hanjin__black_chain"] = "装备牌·武器<br/><b>攻击范围</b>：3<br/>"
    .. "<b>武器技能</b>：当你使用【杀】指定目标后，横置目标角色的武将牌。",
  ["hanjin__bronze_sparrow"] = "装备牌·宝物<br/>"
    .. "<b>宝物技能</b>：锁定技，你每回合首次使用具有应变效果的牌无需强化条件直接发动应变效果。",
  ["hanjin__dark_armor"] = "装备牌·防具<br/>"
    .. "<b>防具技能</b>：当你成为【杀】、伤害锦囊或黑色锦囊牌的目标后，若你不是唯一目标，此牌对你无效。",
  ["hanjin__breastplate"] = "装备牌·防具<br/>"
    .. "<b>防具技能</b>：当你受到大于1点的伤害或致命伤害时，你可以将装备区里的【护心镜】置入弃牌堆，防止此伤害。",
  ["hanjin__taigong_tactics"] = "装备牌·宝物<br/>"
    .. "<b>宝物技能</b>：出牌阶段开始时，你可以横置或重置一名角色；出牌阶段结束时，你可以重铸一张手牌。",
  ["hanjin__wonder_map"] = "装备牌·宝物<br/>"
    .. "<b>宝物技能</b>：锁定技，此牌进入你的装备区时，弃置一张其他牌；此牌离开你的装备区时，你将手牌摸至五张。",
}

local function cardDescription(cardType)
  if cardType.id == "hanjin__thunder__slash" then return THUNDER_SLASH_DESCRIPTION end
  if cardType.id == "hanjin__thunder_shell__slash" then return THUNDER_SHELL_DESCRIPTION end
  local override = DESCRIPTION_OVERRIDES[cardType.id]
  if override then return override end
  return shellDescription(cardType)
end

local function dynamicDescription(self, player, lang)
  local base = Fk:translate(":" .. self.name, lang)
  local data = self.extra_data or {}
  local lines = {}
  if data.hanjin_heji or data.hanjin_hezong then
    table.insert(lines, "<b>合纵</b>")
  end
  for _, entry in ipairs(data.hanjin_adaptation or {}) do
    local condition = CONDITION_TEXT[entry.condition] or entry.condition
    local effect = EFFECT_TEXT[entry.effect] or entry.effect
    table.insert(lines, "<b>应变·" .. condition .. "</b>：" .. effect)
  end
  if #lines > 0 then return base .. "<br/>" .. table.concat(lines, "<br/>") end
  return base
end

local prototypes = {}
for _, cardType in ipairs(CardData.types) do
  local reuse = ReuseData.cards[cardType.id]
  local inert = reuse and (reuse.status ~= "reused") or (not reuse and cardType.inert == true) or false
  local spec = {
    name = cardType.derived and ("&" .. cardType.id) or cardType.id,
    extra_data = {
      hanjin_package = "hanjin_cards",
      hanjin_type = cardType.type,
      hanjin_inert = inert,
      hanjin_national = true,
    },
  }
  if cardType.subtypes then
    spec.extra_data.hanjin_subtypes = table.clone(cardType.subtypes)
  end
  if cardType.type == "basic" then
    spec.type = Card.TypeBasic
    spec.is_damage_card = cardType.is_damage == true
    spec.damage_type = cardType.damage
  elseif cardType.type == "trick" then
    spec.type = Card.TypeTrick
    if cardType.delayed then spec.sub_type = Card.SubtypeDelayedTrick end
    spec.is_damage_card = cardType.is_damage == true
  else
    spec.type = Card.TypeEquip
    spec.sub_type = cardType.subtype
    spec.attack_range = cardType.range
    spec.equip_skill = cardType.equip_skill
    spec.on_install = cardType.on_install
    spec.on_uninstall = cardType.on_uninstall
  end
  if cardType.skill then spec.skill = cardType.skill end
  if not cardType.fixed_desc then spec.dynamic_desc = dynamicDescription end
  table.insert(prototypes, fk.CreateCard(spec))
end
extension:loadCardSkels(prototypes)

-- Physical slot metadata ----------------------------------------------------

local HData = {
  version = 1,
  mode = "hanjin_heg_mode",
  package = "hanjin_cards",
  hejiKey = "hanjin_heji",
  baseSlots = {},
  baseSlotCount = 0,
  partitions = { standard1 = 0, standard2 = 0, shibei = 0, ex = 0 },
  slotById = {},
  allPositions = {},
  byCard = {},
  types = TYPE_BY_ID,
  reuse = ReuseData.cards,
  lordEquipment = {},
  replacements = {},
  factionTricks = {},
}
-- Keep the public interface behind an empty proxy table. The package object is
-- compared structurally by some legacy tests; exposing the whole slot registry
-- as a direct package field makes that comparison traverse a large cyclic graph.
local H = setmetatable({}, { __index = HData, __newindex = HData })

local function addPosition(position)
  assert(not H.slotById[position.id], "Duplicate HanJin card position: " .. position.id)
  table.insert(H.allPositions, position)
  H.slotById[position.id] = position
  H.byCard[position.card] = H.byCard[position.card] or {}
  table.insert(H.byCard[position.card], position.id)
  if position.category == "base" then
    table.insert(H.baseSlots, position)
    H.baseSlotCount = H.baseSlotCount + 1
    H.partitions[position.partition] = (H.partitions[position.partition] or 0) + 1
  end
end

local function adaptationId(partition, suitCode, rankCode)
  local key = positionId(partition, suitCode, rankCode)
  -- Keep the existing public entry id of the two implemented Thunder Slashes.
  if key == "shibei/S/9" or key == "shibei/S/10" then
    return "hanjin_thunder_slash_gujun"
  end
  return "hanjin_adapt_" .. key:gsub("/", "_")
end

local function buildBaseExtra(row, s, n)
  local id = positionId(row.partition, row.suit, row.number)
  local extra = {
    hanjin_package = "hanjin_cards",
    hanjin_slot = id,
    hanjin_partition = row.partition,
    hanjin_suit = s,
    hanjin_number = n,
    hanjin_display = row.display,
    hanjin_card = row.card,
    hanjin_national = true,
    hanjin_guozhan = true,
    hanjin_variant = "base",
    hanjin_inert = not (H.reuse[row.card] and H.reuse[row.card].status == "reused"),
  }
  local cardType = TYPE_BY_ID[row.card]
  if cardType and cardType.subtypes then
    extra.hanjin_subtypes = table.clone(cardType.subtypes)
  end
  local adaptation = SlotData.adaptation[id]
  if adaptation then
    extra.hanjin_adaptation = {
      {
        id = adaptationId(row.partition, row.suit, row.number),
        condition = adaptation.condition,
        effect = adaptation.effect,
      },
    }
  end
  if SlotData.heji[id] then
    extra.hanjin_heji = true
    extra.hanjin_hezong = true
  end
  local lord = LORD_BY_CARD[row.card]
  if lord then
    extra.hanjin_variant = "lord_equipment"
    extra.hanjin_lord_equipment = {
      display = lord.display,
      kingdoms = table.clone(lord.kingdoms),
      replacement = lord.replacement,
      replacement_card = lord.replacementCard,
      partition = lord.partition,
      suit = suit(lord.suit),
      number = rank(lord.number),
    }
  end
  if row.display == "无懈可击·国" then
    extra.hanjin_variant = "guozhan"
    extra.hanjin_guozhan_card = true
  end
  return extra
end

for _, row in ipairs(SlotData.base) do
  local s, n = suit(row.suit), rank(row.number)
  local extra = buildBaseExtra(row, s, n)
  extension:addCardSpec(row.card, s, n, extra)
  addPosition {
    id = extra.hanjin_slot,
    category = "base",
    partition = row.partition,
    suit = s,
    number = n,
    rank = row.number,
    display = row.display,
    card = row.card,
    inert = row.inert == true,
    heji = extra.hanjin_heji == true,
    adaptation = extra.hanjin_adaptation,
    lordEquipment = extra.hanjin_lord_equipment,
    extra = extra,
  }
end

for _, row in ipairs(SlotData.replacements) do
  local s, n = suit(row.suit), rank(row.number)
  local shared = positionId(row.partition, row.suit, row.number)
  local extra = {
    hanjin_package = "hanjin_cards",
    hanjin_slot = "replacement/" .. shared,
    hanjin_partition = row.partition,
    hanjin_suit = s,
    hanjin_number = n,
    hanjin_display = row.display,
    hanjin_card = row.card,
    hanjin_national = true,
    hanjin_guozhan = true,
    hanjin_variant = "replacement",
    hanjin_inert = not (H.reuse[row.card] and H.reuse[row.card].status == "reused"),
    hanjin_replacement = true,
    hanjin_shared_slot = shared,
    hanjin_replacement_for = REPLACEMENT_BY_CARD[row.card] and REPLACEMENT_BY_CARD[row.card].card or nil,
  }
  if row.display == "惊帆" then
    extra.hanjin_heji = true
    extra.hanjin_hezong = true
  end
  if not row.printOnly then
    extension:addCardSpec(row.card, s, n, extra)
  end
  addPosition {
    id = extra.hanjin_slot,
    category = "replacement",
    partition = row.partition,
    suit = s,
    number = n,
    rank = row.number,
    display = row.display,
    card = row.card,
    inert = true,
    heji = extra.hanjin_heji == true,
    printOnly = row.printOnly == true,
    extra = extra,
  }
  H.replacements[row.card] = {
    card = row.card,
    display = row.display,
    partition = row.partition,
    suit = s,
    number = n,
    printOnly = row.printOnly == true,
    position = extra.hanjin_slot,
    replacementFor = extra.hanjin_replacement_for,
  }
end

for _, row in ipairs(SlotData.factionTricks) do
  local s, n = suit(row.suit), rank(row.number)
  local extra = {
    hanjin_package = "hanjin_cards",
    hanjin_slot = "faction_trick/" .. row.suit .. "/" .. row.number,
    hanjin_partition = "faction_trick",
    hanjin_suit = s,
    hanjin_number = n,
    hanjin_display = row.display,
    hanjin_card = row.card,
    hanjin_national = true,
    hanjin_guozhan = true,
    hanjin_variant = "faction_trick",
    hanjin_inert = true,
    hanjin_deck_policy = "special_only",
    hanjin_faction_trick = row.kingdom,
    hanjin_kingdom = row.kingdom,
  }
  extension:addCardSpec(row.card, s, n, extra)
  addPosition {
    id = extra.hanjin_slot,
    category = "faction_trick",
    partition = "faction_trick",
    suit = s,
    number = n,
    rank = row.number,
    display = row.display,
    card = row.card,
    inert = true,
    kingdom = row.kingdom,
    extra = extra,
  }
  H.factionTricks[row.card] = {
    card = row.card,
    display = row.display,
    kingdom = row.kingdom,
    suit = s,
    number = n,
    position = extra.hanjin_slot,
    deck = "special_only",
  }
end

for _, lord in ipairs(SlotData.lordEquipment) do
  H.lordEquipment[lord.card] = {
    card = lord.card,
    display = lord.display,
    kingdoms = table.clone(lord.kingdoms),
    replacement = lord.replacement,
    replacementCard = lord.replacementCard,
    partition = lord.partition,
    suit = suit(lord.suit),
    number = rank(lord.number),
    slot = positionId(lord.partition, lord.suit, lord.number),
    subtypes = TYPE_BY_ID[lord.card] and TYPE_BY_ID[lord.card].subtypes
      and table.clone(TYPE_BY_ID[lord.card].subtypes) or nil,
  }
end

-- Public interface ----------------------------------------------------------

local function copyExtra(template)
  local extra = table.clone(template)
  if template.hanjin_adaptation then
    extra.hanjin_adaptation = {}
    for _, entry in ipairs(template.hanjin_adaptation) do
      table.insert(extra.hanjin_adaptation, table.clone(entry))
    end
  end
  if template.hanjin_lord_equipment then
    extra.hanjin_lord_equipment = table.clone(template.hanjin_lord_equipment)
    extra.hanjin_lord_equipment.kingdoms =
      table.clone(template.hanjin_lord_equipment.kingdoms)
  end
  if template.hanjin_subtypes then
    extra.hanjin_subtypes = table.clone(template.hanjin_subtypes)
  end
  return extra
end

function H.getSlot(value)
  if type(value) == "string" then return H.slotById[value] end
  if type(value) ~= "table" then return nil end
  local data = value.extra_data or {}
  if data.hanjin_slot and H.slotById[data.hanjin_slot] then
    return H.slotById[data.hanjin_slot]
  end
  for _, position in ipairs(H.allPositions) do
    if position.card == value.name and position.suit == value.suit
      and position.number == value.number then
      return position
    end
  end
  return nil
end

function H.extraData(slotId)
  local position = assert(H.slotById[slotId], "Unknown HanJin card position: " .. tostring(slotId))
  return copyExtra(position.extra)
end

function H.stamp(card, slotId)
  local position = H.getSlot(slotId)
  assert(position, "Unknown HanJin card position: " .. tostring(slotId))
  assert(card.name == position.card, "Card " .. tostring(card.name)
    .. " does not occupy position " .. tostring(slotId))
  card.extra_data = copyExtra(position.extra)
  return card
end

function H.printCard(room, name, suitValue, numberValue, slotId)
  local card = room:printCard(name, suitValue, numberValue)
  local position = slotId and H.getSlot(slotId) or H.getSlot(card)
  if position then H.stamp(card, position.id) end
  return card
end

function H.isHanjinCard(card)
  return card ~= nil and card.package ~= nil and card.package.name == "hanjin_cards"
end

function H.isHeji(card)
  local data = card and card.extra_data
  return type(data) == "table" and (data.hanjin_heji == true or data.hanjin_hezong == true)
end

function H.reuseStatus(value)
  local name = type(value) == "string" and value
    or (type(value) == "table" and value.name)
  local reuse = name and H.reuse[name]
  return reuse and reuse.status or nil
end

function H.isInert(card)
  if not card then return true end
  if H.reuseStatus(card) == "reused" then return false end
  local data = card.extra_data or {}
  if data.hanjin_inert == true then return true end
  return card.skill ~= nil and (card.skill.name == "hanjin__inert"
    or card.skill.name == "hanjin__inert_equip")
end

function H.hejiPositions()
  local result = {}
  for _, position in ipairs(H.allPositions) do
    if position.heji then table.insert(result, position) end
  end
  return result
end

function H.assertConsistent()
  assert(H.baseSlotCount == 162, "HanJin base slot count must be 162")
  assert(#SlotData.base == 162, "HanJin base data must have 162 rows")
  assert(H.partitions.standard1 == 52 and H.partitions.standard2 == 52
    and H.partitions.shibei == 52 and H.partitions.ex == 6,
    "HanJin base partition sizes are wrong")
  local adaptationCount = 0
  local baseHejiCount = 0
  for _, position in ipairs(H.baseSlots) do
    assert(TYPE_BY_ID[position.card], "Missing card type for " .. position.card)
    if position.adaptation then adaptationCount = adaptationCount + 1 end
    if position.heji then baseHejiCount = baseHejiCount + 1 end
  end
  assert(adaptationCount == 35, "HanJin adaptation card count must be 35")
  assert(baseHejiCount == 12, "HanJin base 合纵 count must be 12")
  assert(#SlotData.replacements == 12, "HanJin replacement count must be 12")
  assert(#SlotData.factionTricks == 7, "HanJin faction trick count must be 7")
  assert(#SlotData.lordEquipment == 14, "HanJin lord equipment count must be 14")
  local replacements = 0
  local multi = 0
  for _, lord in ipairs(SlotData.lordEquipment) do
    assert(TYPE_BY_ID[lord.card], "Missing lord equipment type: " .. lord.card)
    if lord.replacementCard then
      replacements = replacements + 1
      assert(TYPE_BY_ID[lord.replacementCard],
        "Missing replacement type: " .. lord.replacementCard)
    end
    if #lord.kingdoms > 1 then multi = multi + 1 end
  end
  assert(replacements == 12, "HanJin lord equipment replacement count must be 12")
  assert(multi == 1, "Only 虚妄之冕 may have multiple kingdoms")
  for _, trick in ipairs(SlotData.factionTricks) do
    assert(TYPE_BY_ID[trick.card], "Missing faction trick type: " .. trick.card)
  end
  for _, position in ipairs(H.allPositions) do
    assert(TYPE_BY_ID[position.card], "Missing type for position " .. position.id)
  end
  return true
end

H.assertConsistent()
extension.hanjin_cards = H
extension.hanjin = H

H.reuseCounts = { reused = 0, multiple = 0, missing = 0 }
for name, reuse in pairs(H.reuse) do
  assert(TYPE_BY_ID[name], "Reuse entry has no card type: " .. name)
  assert(H.reuseCounts[reuse.status], "Unknown reuse status: " .. tostring(reuse.status))
  H.reuseCounts[reuse.status] = H.reuseCounts[reuse.status] + 1
end
for _, cardType in ipairs(CardData.types) do
  assert(H.reuse[cardType.id],
    "Missing reuse decision for card type: " .. cardType.id)
end

-- Engine adapter for local FreeKill implementations -----------------------
--
-- The HanJin package keeps its own card names and physical positions. For a
-- uniquely implemented local card we late-bind the upstream card skill (and,
-- for equipment, the upstream equip skills and install/uninstall hooks) after
-- every extension has loaded. Equipment skills whose upstream `attached_equip`
-- still names the upstream card are installed/removed explicitly here, so the
-- independent HanJin identity does not break their lifecycle.
local EquipTypes = require "ltk.core.card_type.equip"
local EquipCard = EquipTypes[1]

local function equipSkillNames(card, player)
  local names = {}
  for _, equipSkill in ipairs(card:getEquipSkills(player)) do
    if equipSkill and equipSkill.name then
      table.insertIfNeed(names, equipSkill.name)
    end
  end
  return names
end

local function patchReuseCard(card, reuse)
  if reuse.kind == "skill" then
    local upstream = Fk.all_card_types[reuse.upstream]
    local skill = Fk.skills[reuse.skill]
    if skill then card.skill = skill end
    if upstream then
      card.is_passive = upstream.is_passive
      card.is_damage_card = upstream.is_damage_card
      card.damage_type = upstream.damage_type
      card.multiple_targets = upstream.multiple_targets
      card.stackable_delayed = upstream.stackable_delayed
      card.special_skills = upstream.special_skills
    end
  elseif reuse.kind == "equip" then
    local upstream = Fk.all_card_types[reuse.upstream]
    if not upstream then return end
    card.skill = upstream.skill
    card.is_passive = upstream.is_passive
    card.is_damage_card = upstream.is_damage_card
    card.damage_type = upstream.damage_type
    card.multiple_targets = upstream.multiple_targets
    card.stackable_delayed = upstream.stackable_delayed
    card.special_skills = upstream.special_skills
    card.equip_skill = upstream.equip_skill
    card.equip_skills = upstream.equip_skills
    card.dynamicEquipSkills = upstream.dynamicEquipSkills
    local customInstall = rawget(upstream, "onInstall")
    local customUninstall = rawget(upstream, "onUninstall")
    card.onInstall = function(self, room, player)
      if customInstall then
        customInstall(self, room, player)
      else
        EquipCard.onInstall(self, room, player)
      end
      local names = equipSkillNames(self, player)
      if #names > 0 then room:handleAddLoseSkills(player, names, nil, false) end
    end
    card.onUninstall = function(self, room, player)
      local names = equipSkillNames(self, player)
      if customUninstall then
        customUninstall(self, room, player)
      else
        EquipCard.onUninstall(self, room, player)
      end
      if #names > 0 then
        local remove = table.map(names, function(name) return "-" .. name end)
        room:handleAddLoseSkills(player, remove, nil, false)
      end
    end
  end
end

local function copyUpstreamDescription(ourName, upstreamName)
  local description = Fk:translate(":" .. upstreamName)
  if type(description) == "string" and description ~= ":" .. upstreamName then
    Fk:loadTranslationTable { [":" .. ourName] = description }
  end
end

Fk:addPostLoadFunc(function()
  local pack = Fk.packages.hanjin_cards
  local patched = {}
  local function patch(card)
    if patched[card] then return end
    patched[card] = true
    local reuse = H.reuse[card.name]
    if not reuse or reuse.status ~= "reused" then return end
    patchReuseCard(card, reuse)
    if reuse.kind == "skill" or reuse.kind == "equip"
      or reuse.kind == "hanjin_skill" or reuse.kind == "hanjin_equip" then
      copyUpstreamDescription(card.name, reuse.upstream)
    end
  end
  for _, card in ipairs(pack.cards) do patch(card) end
  for _, prototype in pairs(Fk.all_card_types) do
    if prototype.package == pack then patch(prototype) end
  end
end)

-- Register the 合纵 positions with the upstream alliance marker. The runtime
-- policy may additionally use `extra_data.hanjin_heji`; both paths resolve the
-- concrete card, never a same-name card at another position.
Fk:addPostLoadFunc(function()
  local ok, Heg = pcall(require, "packages.hegemony.util")
  if not ok or type(Heg.addCardToAllianceCards) ~= "function" then return end
  for _, position in ipairs(H.hejiPositions()) do
    local exists = table.find(Heg.allianceCards or {}, function(entry)
      return entry[1] == position.card and entry[2] == position.suit
        and entry[3] == position.number
    end)
    if not exists then
      Heg.addCardToAllianceCards { position.card, position.suit, position.number }
    end
  end
end)

-- The runtime strategy table is maintained outside this package. Keep the
-- physical 顺手牵羊·合 position visible to it if that table predates the full
-- 13-position list; this is an idempotent interface shim, not a deck rule.
do
  local ok, Cards = pcall(require, "packages.hanjin.pkg.hanjin_mode.rules.cards")
  if ok and type(Cards.hejiSlots) == "table" then
    local supported = table.find(Cards.hejiSlots, function(entry)
      return entry.display == "顺手牵羊" and entry.suit == Card.Diamond
        and entry.number == 3
    end)
    if not supported then
      table.insert(Cards.hejiSlots, {
        display = "顺手牵羊", partition = "standard2",
        suit = Card.Diamond, number = 3,
      })
    end
  end
end

-- Translations --------------------------------------------------------------

local translations = {
  ["hanjin_cards"] = "紫乔汉晋·卡牌",
  ["hanjin__inert"] = "未实装牌",
  ["#hanjin__inert"] = "此牌为占位空壳；牌面效果尚未实装，不能使用",
  ["hanjin__inert_equip"] = "未实装装备",
  ["#hanjin__inert_equip"] = "此装备为占位空壳；装备效果尚未实装，不能使用",
  ["hanjin__thunder_slash_skill"] = "雷杀",
  ["#hanjin__thunder_slash_skill"] = "选择攻击范围内的一名角色，对其造成1点雷电伤害",
  ["#hanjin__thunder_slash_skill_multi"] = "选择攻击范围内的至多%arg名角色，对这些角色各造成1点雷电伤害",
}
for _, cardType in ipairs(CardData.types) do
  translations[cardType.id] = cardType.display
  translations[":" .. cardType.id] = cardDescription(cardType)
end
Fk:loadTranslationTable(translations)

return extension
