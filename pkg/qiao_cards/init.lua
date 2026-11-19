-- 平行时空·卡牌
--
-- This package owns the formal, independent HanJin card identities. It defines
-- all 162 physical base positions from docs/rules/card-deck.md, the twelve lord-
-- equipment replacement materials, and the seven faction tricks that stay
-- outside the default deck. All seven printed Thunder Slash positions share one
-- identity and the real thunder-damage effect. Card usability follows
-- data/reuse.lua: a type whose registry status is "reused" installs that
-- implementation, while a non-reused status keeps the inert shell declared in
-- data/cards.lua.
--
-- The runtime policy side reads the same identities through the HanJin card
-- name and through extra_data. The public interface is exposed as
-- `Fk.packages.qiao_cards.qiao_cards` (also `.qiao`).

local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local extension = Package:new("qiao_cards", Package.CardPack)
extension.extensionName = "qiao"
extension.game_modes_whitelist = Modes.names
-- 与锁定应变参考包 variation_cards/init.lua 保持同一冰冻伤害登记；
-- 缺失登记会令正式冰杀跳过 ChangeHp 的重置及连环处理。
Fk:addDamageNature(fk.IceDamage, "ice_damage")
extension:loadSkillSkelsByPath("./packages/qiao/pkg/qiao_cards/skills")

local CardData = require "packages.qiao.pkg.qiao_cards.data.cards"
local SlotData = require "packages.qiao.pkg.qiao_cards.data.slots"
local ReuseData = require "packages.qiao.pkg.qiao_cards.data.reuse"
local EquipmentText = require "packages.qiao.pkg.qiao_cards.data.equipment_text"

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

local function cardDescriptionWithHeader(cardType, printedText)
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
  table.insert(lines, printedText or "<b>状态</b>：正式牌位已登记，牌面效果尚未实装；本牌不能使用。")
  return table.concat(lines, "<br/>")
end

local THUNDER_SLASH_DESCRIPTION = "基本牌<br/><b>时机</b>：出牌阶段<br/>"
  .. "<b>目标</b>：攻击范围内的一名角色<br/>"
  .. "<b>效果</b>：对目标角色造成1点雷电伤害。"

-- 势备 ♠9/♠10 的雷杀孤军卡面原文。只由该实体牌位自身的应变条目动态追加，
-- 其余雷杀牌位及虚拟牌不继承。
local THUNDER_GUJUN_DESCRIPTION = "<b>应变·孤军</b>：此牌无视次数。"

-- Reference implementations adapted into HanJin skills. These descriptions are
-- the confirmed local 应变 card texts, not invented effects.
local DESCRIPTION_OVERRIDES = {
  ["qiao__ice__slash"] = "基本牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：攻击范围内的一名角色<br/>"
    .. "<b>效果</b>：对目标角色造成1点冰冻伤害。<br/>"
    .. "（一名角色造成不为连环伤害的冰冻伤害时，若受到此伤害的角色有牌，来源可防止此伤害，然后依次弃置其两张牌）。",
  ["qiao__foresight"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：你<br/>"
    .. "<b>效果</b>：目标角色卜算2（观看牌堆顶的两张牌，将其中任意张以任意顺序置于牌堆顶，其余以任意顺序置于牌堆底），然后摸两张牌。",
  ["qiao__chasing_near"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一名其他角色<br/>"
    .. "<b>效果</b>：若你与其的距离大于1，你弃置其区域里一张牌；"
    .. "若你与其的距离为1，你获得其区域里一张牌。",
  ["qiao__befriend_attacking"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一名与你势力不同的其他角色<br/>"
    .. "<b>效果</b>：目标角色摸一张牌。若此牌对任意目标生效过，你摸三张牌。",
  ["qiao__alliance_feast"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：你和一个不同势力的所有角色<br/>"
    .. "<b>效果</b>：目标角色各摸一张牌且重置。对你的效果改为选择X次"
    .. "（X为除你以外的目标数）：1.回复1点体力；2.摸一张牌。",
  ["qiao__unexpectation"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一名有手牌的其他角色<br/>"
    .. "<b>效果</b>：你展示目标角色的一张手牌，若该牌与此【出其不意】花色不同，你对其造成1点伤害。",
  ["qiao__lure_tiger"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一至两名其他角色<br/><b>效果</b>：目标角色本回合移出游戏。",
  ["qiao__threaten_emperor"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：若你是大势力角色且此时是你额定回合，对你使用<br/>"
    .. "<b>效果</b>：目标角色结束其出牌阶段，然后于此回合结束时弃置一张手牌并获得一个额外的回合。",
  ["qiao__imperial_order"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：所有未确定势力的角色<br/>"
    .. "<b>效果</b>：目标角色各选择一项：1.明置一张武将牌并摸一张牌；2.弃置一张装备牌；3.失去1点体力。"
    .. "此牌置入弃牌堆的回合结束时：若此牌未触发效果，未确定势力的角色执行此牌的效果；"
    .. "若所有角色均确定势力，此牌移出游戏，当前回合角色获得“诏书”。",
  ["qiao__iron_chain"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一至两名角色<br/>"
    .. "<b>效果</b>：目标角色横置或重置。<br/>"
    .. "<b>重铸</b>：出牌阶段，将此牌置入弃牌堆，然后摸一张牌。",
  ["qiao__known_both"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一名有手牌或暗置武将牌的其他角色<br/>"
    .. "<b>效果</b>：你观看目标角色手牌或一张暗置武将牌。<br/>"
    .. "<b>重铸</b>：出牌阶段，将此牌置入弃牌堆，然后摸一张牌。",
  ["qiao__fight_together"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：所有大势力角色或所有小势力角色<br/>"
    .. "<b>效果</b>：目标角色横置，若其已横置，则摸一张牌。<br/>"
    .. "<b>重铸</b>：出牌阶段，将此牌置入弃牌堆，然后摸一张牌。",
  ["qiao__snatch"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一名距离1且区域里有牌的其他角色<br/>"
    .. "<b>效果</b>：你获得目标角色区域里的一张牌。",
  ["qiao__savage_assault"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：所有其他角色<br/>"
    .. "<b>效果</b>：目标角色依次选择一项：1.打出一张【杀】；2.你对其造成1点伤害。",
  ["qiao__archery_attack"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：所有其他角色<br/>"
    .. "<b>效果</b>：目标角色依次选择一项：1.打出一张【闪】；2.你对其造成1点伤害。",
  ["qiao__lightning"] = "延时锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：你<br/>"
    .. "<b>效果</b>：目标角色判定，若为黑桃2～9，其受到3点无来源雷电伤害；"
    .. "若不为黑桃2～9或此牌被抵消，此牌移动给其下家。",
  ["qiao__collateral"] = "锦囊牌<br/><b>时机</b>：出牌阶段<br/>"
    .. "<b>目标</b>：一名装备着武器牌的其他角色<br/>"
    .. "<b>效果</b>：除非目标角色对其攻击范围内由你选择的另一名角色使用一张【杀】，"
    .. "否则其将装备区里的一张武器牌交给你。",
  ["qiao__danggu_zhihuo"] = "出牌阶段，对所有其他角色使用。你暗置目标角色各一张武将牌，且其不能明置武将牌直到你下回合开始或你死亡。"
    .. "<br/>若使用者为汉势力角色，则汉势力角色成为此牌的目标后，其可以交给你一张牌，然后令此牌对其无效。",
  ["qiao__command_world"] = "出牌阶段，对一名体力值不是最小的角色使用。除目标角色外的角色均可以选择一项：1.弃置一张手牌并视为对其使用一张【杀】；2.弃置其一张牌。"
    .. "<br/>若使用者为魏势力角色，则魏势力角色选择1时跳过弃置牌的步骤，选择2时获得弃置的牌。",
  ["qiao__restore_heartland"] = "出牌阶段，对任意名角色使用。目标角色各选择一项：1.视为使用一张【杀】；2.摸一张牌。"
    .. "<br/>若使用者为蜀势力角色，则蜀势力角色选择1时使用【杀】伤害+1，选择2时改为摸两张牌。",
  ["qiao__strengthen_state"] = "出牌阶段，对你使用。目标角色摸八张牌，然后弃置至少六张手牌。"
    .. "<br/>若使用者为吴势力角色，则你可以将以此法弃置的牌交给其他吴势力角色（每名角色至多两张）。",
  ["qiao__luanwu_chaos"] = "出牌阶段，对所有角色使用。目标角色各展示手牌并令你选择一项：1.其弃置两张类别各不同的手牌；2.你弃置其中一张牌。"
    .. "<br/>若使用者为群势力角色，则群势力角色结算后，若其没有手牌，其摸牌至体力值。",
  ["qiao__sihai_guiping"] = "出牌阶段，对你使用。目标角色结束其出牌阶段，然后获得弃牌堆中此阶段置入的每种花色各一张牌。"
    .. "<br/>若使用者为晋势力角色，则你可以将这些牌交给其他晋势力角色各一张，且晋势力角色依次可以使用一张牌。",
  ["qiao__luoshui_zhishi"] = "出牌阶段，对一名角色使用。目标角色判定：若不为黑桃2～9，本回合下个阶段开始前，其将【洛水之誓】置回判定区，该阶段改为判定阶段；若为黑桃2～9且其为野心家，其对一名角色造成3点雷电伤害。"
    .. "<br/>若使用者为野心家且对自己使用此牌，则立即结算。",
}

local function cardDescription(cardType)
  if cardType.id == "qiao__thunder__slash" then return THUNDER_SLASH_DESCRIPTION end
  local override = DESCRIPTION_OVERRIDES[cardType.id]
  if override then return override end
  return cardDescriptionWithHeader(cardType, EquipmentText[cardType.id])
end

local function adaptationDescription(self, entry)
  if self.name == "qiao__thunder__slash" and entry.condition == "gujun"
    and entry.effect == "ignore_times" then
    return THUNDER_GUJUN_DESCRIPTION
  end
  local condition = CONDITION_TEXT[entry.condition] or entry.condition
  local effect = EFFECT_TEXT[entry.effect] or entry.effect
  return "<b>应变·" .. condition .. "</b>：" .. effect
end

local function dynamicDescription(self, player, lang)
  local base = Fk:translate(":" .. self.name, lang)
  local data = self.extra_data or {}
  local lines = {}
  if data.qiao_heji or data.qiao_hezong then
    table.insert(lines, "<b>合纵</b>")
  end
  for _, entry in ipairs(data.qiao_adaptation or {}) do
    table.insert(lines, adaptationDescription(self, entry))
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
      qiao_package = "qiao_cards",
      qiao_type = cardType.type,
      qiao_inert = inert,
      qiao_national = true,
    },
  }
  if cardType.subtypes then
    spec.extra_data.qiao_subtypes = table.clone(cardType.subtypes)
    spec.ui_name = cardType.id
  end
  if cardType.type == "basic" then
    spec.type = Card.TypeBasic
    spec.is_damage_card = cardType.is_damage == true
    spec.damage_type = cardType.damage
  elseif cardType.type == "trick" then
    spec.type = Card.TypeTrick
    if cardType.delayed then spec.sub_type = Card.SubtypeDelayedTrick end
    spec.is_damage_card = cardType.is_damage == true
    spec.multiple_targets = cardType.multiple_targets == true
  else
    spec.type = Card.TypeEquip
    spec.sub_type = cardType.subtype
    spec.attack_range = cardType.range
    spec.equip_skill = cardType.equip_skill
    spec.on_install = cardType.on_install
    spec.on_uninstall = cardType.on_uninstall
  end
  if cardType.skill then spec.skill = cardType.skill end
  if cardType.special_skills then spec.special_skills = cardType.special_skills end
  if not cardType.fixed_desc then spec.dynamic_desc = dynamicDescription end
  table.insert(prototypes, fk.CreateCard(spec))
end
extension:loadCardSkels(prototypes)

-- Physical slot metadata ----------------------------------------------------

local HData = {
  version = 1,
  mode = "qiao_heg_mode",
  package = "qiao_cards",
  hejiKey = "qiao_heji",
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
  -- Keep the existing public entry id of the 势备 ♠9/♠10 孤军 positions.
  if key == "shibei/S/9" or key == "shibei/S/10" then
    return "qiao_thunder_slash_gujun"
  end
  return "qiao_adapt_" .. key:gsub("/", "_")
end

local function buildBaseExtra(row, s, n)
  local id = positionId(row.partition, row.suit, row.number)
  local extra = {
    qiao_package = "qiao_cards",
    qiao_slot = id,
    qiao_partition = row.partition,
    qiao_suit = s,
    qiao_number = n,
    qiao_display = row.display,
    qiao_card = row.card,
    qiao_national = true,
    qiao_guozhan = true,
    qiao_variant = "base",
    qiao_inert = not (H.reuse[row.card] and H.reuse[row.card].status == "reused"),
  }
  local cardType = TYPE_BY_ID[row.card]
  if cardType and cardType.subtypes then
    extra.qiao_subtypes = table.clone(cardType.subtypes)
  end
  local adaptation = SlotData.adaptation[id]
  if adaptation then
    extra.qiao_adaptation = {
      {
        id = adaptationId(row.partition, row.suit, row.number),
        condition = adaptation.condition,
        effect = adaptation.effect,
      },
    }
  end
  if SlotData.heji[id] then
    extra.qiao_heji = true
    extra.qiao_hezong = true
  end
  local lord = LORD_BY_CARD[row.card]
  if lord then
    extra.qiao_variant = "lord_equipment"
    extra.qiao_lord_equipment = {
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
    extra.qiao_variant = "guozhan"
    extra.qiao_guozhan_card = true
  end
  return extra
end

for _, row in ipairs(SlotData.base) do
  local s, n = suit(row.suit), rank(row.number)
  local extra = buildBaseExtra(row, s, n)
  extension:addCardSpec(row.card, s, n, extra)
  addPosition {
    id = extra.qiao_slot,
    category = "base",
    partition = row.partition,
    suit = s,
    number = n,
    rank = row.number,
    display = row.display,
    card = row.card,
    inert = row.inert == true,
    heji = extra.qiao_heji == true,
    adaptation = extra.qiao_adaptation,
    lordEquipment = extra.qiao_lord_equipment,
    extra = extra,
  }
end

for _, row in ipairs(SlotData.replacements) do
  local s, n = suit(row.suit), rank(row.number)
  local shared = positionId(row.partition, row.suit, row.number)
  local extra = {
    qiao_package = "qiao_cards",
    qiao_slot = "replacement/" .. shared,
    qiao_partition = row.partition,
    qiao_suit = s,
    qiao_number = n,
    qiao_display = row.display,
    qiao_card = row.card,
    qiao_national = true,
    qiao_guozhan = true,
    qiao_variant = "replacement",
    qiao_inert = not (H.reuse[row.card] and H.reuse[row.card].status == "reused"),
    qiao_replacement = true,
    qiao_shared_slot = shared,
    qiao_replacement_for = REPLACEMENT_BY_CARD[row.card] and REPLACEMENT_BY_CARD[row.card].card or nil,
  }
  if row.display == "惊帆" then
    extra.qiao_heji = true
    extra.qiao_hezong = true
  end
  if not row.printOnly then
    extension:addCardSpec(row.card, s, n, extra)
  end
  addPosition {
    id = extra.qiao_slot,
    category = "replacement",
    partition = row.partition,
    suit = s,
    number = n,
    rank = row.number,
    display = row.display,
    card = row.card,
    inert = true,
    heji = extra.qiao_heji == true,
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
    position = extra.qiao_slot,
    replacementFor = extra.qiao_replacement_for,
  }
end

for _, row in ipairs(SlotData.factionTricks) do
  local s, n = suit(row.suit), rank(row.number)
  local implemented = H.reuse[row.card] and H.reuse[row.card].status == "reused"
  local extra = {
    qiao_package = "qiao_cards",
    qiao_slot = "faction_trick/" .. row.suit .. "/" .. row.number,
    qiao_partition = "faction_trick",
    qiao_suit = s,
    qiao_number = n,
    qiao_display = row.display,
    qiao_card = row.card,
    qiao_national = true,
    qiao_guozhan = true,
    qiao_variant = "faction_trick",
    qiao_inert = not implemented,
    qiao_deck_policy = "special_only",
    qiao_faction_trick = row.kingdom,
    qiao_kingdom = row.kingdom,
  }
  extension:addCardSpec(row.card, s, n, extra)
  addPosition {
    id = extra.qiao_slot,
    category = "faction_trick",
    partition = "faction_trick",
    suit = s,
    number = n,
    rank = row.number,
    display = row.display,
    card = row.card,
    inert = not implemented,
    kingdom = row.kingdom,
    extra = extra,
  }
  H.factionTricks[row.card] = {
    card = row.card,
    display = row.display,
    kingdom = row.kingdom,
    suit = s,
    number = n,
    position = extra.qiao_slot,
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
  if template.qiao_adaptation then
    extra.qiao_adaptation = {}
    for _, entry in ipairs(template.qiao_adaptation) do
      table.insert(extra.qiao_adaptation, table.clone(entry))
    end
  end
  if template.qiao_lord_equipment then
    extra.qiao_lord_equipment = table.clone(template.qiao_lord_equipment)
    extra.qiao_lord_equipment.kingdoms =
      table.clone(template.qiao_lord_equipment.kingdoms)
  end
  if template.qiao_subtypes then
    extra.qiao_subtypes = table.clone(template.qiao_subtypes)
  end
  return extra
end

function H.getSlot(value)
  if type(value) == "string" then return H.slotById[value] end
  if type(value) ~= "table" then return nil end
  local data = value.extra_data or {}
  if data.qiao_slot and H.slotById[data.qiao_slot] then
    return H.slotById[data.qiao_slot]
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

function H.isQiaoCard(card)
  return card ~= nil and card.package ~= nil and card.package.name == "qiao_cards"
end

function H.isHeji(card)
  local data = card and card.extra_data
  return type(data) == "table" and (data.qiao_heji == true or data.qiao_hezong == true)
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
  if data.qiao_inert == true then return true end
  return card.skill ~= nil and (card.skill.name == "qiao__inert"
    or card.skill.name == "qiao__inert_equip")
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

-- 双副类别坐骑的公共栏位语义 ------------------------------------------------
-- 一张双副类别坐骑同时占用进攻、防御两个坐骑栏。引擎只按 `sub_type` 检索
-- 单个栏位，因此在这里把“占用”扩展为公共查询：两个坐骑栏都能检索到同一张
-- 双副类别牌，且该牌只计为一处占用。正常用牌的替换仍由引擎按这些查询完成。
local DUAL_MOUNTS = {
  ["qiao__liulongcanjia"] = true,
  ["qiao__linxiao_yuyu"] = true,
  ["qiao__feiyun_gaihai"] = true,
}
local RIDE_SUBTYPES = {
  [Card.SubtypeOffensiveRide] = true,
  [Card.SubtypeDefensiveRide] = true,
}

local function isRideSubtype(subtype)
  return RIDE_SUBTYPES[subtype] == true
end

function H.isDualMount(value)
  local name = type(value) == "string" and value
    or (type(value) == "table" and value.name)
  return name ~= nil and DUAL_MOUNTS[name] == true
end

function H.isRideCard(card)
  if card == nil or card.type ~= Card.TypeEquip then return false end
  if isRideSubtype(card.sub_type) then return true end
  for _, subtype in ipairs(card.subtypes or {}) do
    if isRideSubtype(subtype) then return true end
  end
  return false
end

if not Player.__qiao_dual_mount_slots then
  Player.__qiao_dual_mount_slots = true
  local baseGetEquipments = Player.getEquipments
  local baseGetEquipment = Player.getEquipment
  local baseCanMoveIntoEquip = Player.canMoveCardIntoEquip
  local baseCanMoveBoardTo = Player.canMoveCardInBoardTo

  -- 双副类别坐骑同时出现在两个坐骑栏的检索结果中，但物理上仍是一张牌。
  function Player:getEquipments(cardSubtype)
    if not isRideSubtype(cardSubtype) then
      return baseGetEquipments(self, cardSubtype)
    end
    local cardIds = {}
    for _, cardId in ipairs(self.player_cards[Player.Equip]) do
      local card = self:getVirtualEquip(cardId) or Fk:getCardById(cardId)
      if card ~= nil and (card.sub_type == cardSubtype or H.isDualMount(card)) then
        table.insert(cardIds, cardId)
      end
    end
    return cardIds
  end

  function Player:getEquipment(cardSubtype)
    if not isRideSubtype(cardSubtype) then
      return baseGetEquipment(self, cardSubtype)
    end
    return self:getEquipments(cardSubtype)[1]
  end

  -- 直接置入双副类别坐骑必须两栏均空且可用（`convert` 为替换许可）。
  function Player:canMoveCardIntoEquip(cardId, convert)
    if not baseCanMoveIntoEquip(self, cardId, convert) then return false end
    local card = type(cardId) == "number" and Fk:getCardById(cardId) or cardId
    if card ~= nil and H.isDualMount(card) then
      return self:hasEmptyEquipSlot(Card.SubtypeOffensiveRide)
        and self:hasEmptyEquipSlot(Card.SubtypeDefensiveRide)
    end
    return true
  end

  function Player:canMoveCardInBoardTo(to, id)
    if not baseCanMoveBoardTo(self, to, id) then return false end
    local card = self:getVirtualEquip(id) or Fk:getCardById(id)
    if card ~= nil and H.isDualMount(card) then
      return to:hasEmptyEquipSlot(Card.SubtypeOffensiveRide)
        and to:hasEmptyEquipSlot(Card.SubtypeDefensiveRide)
    end
    return true
  end
end

extension.qiao_cards = H
extension.qiao = H

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
  local pack = Fk.packages.qiao_cards
  local patched = {}
  local function patch(card)
    if patched[card] then return end
    patched[card] = true
    local reuse = H.reuse[card.name]
    if not reuse or reuse.status ~= "reused" then return end
    patchReuseCard(card, reuse)
    if not EquipmentText[card.name] and reuse.desc ~= false and (reuse.kind == "skill" or reuse.kind == "equip"
      or reuse.kind == "qiao_skill" or reuse.kind == "qiao_equip") then
      copyUpstreamDescription(card.name, reuse.upstream)
    end
  end
  for _, card in ipairs(pack.cards) do patch(card) end
  for _, prototype in pairs(Fk.all_card_types) do
    if prototype.package == pack then patch(prototype) end
  end

  -- Passive equipment skills are always-on rules, not clickable buttons. Keep
  -- their trigger/status wiring, but hide them from the ordinary skill area like
  -- native attached-equipment skills. Active/ViewAs equipment skills (e.g. 丈八
  -- 蛇矛、木牛、制衡) remain visible and usable. The shared inert skill is a
  -- card/equipment shell and must not appear as a skill either.
  for _, cardType in ipairs(CardData.types) do
    local equipSkill = cardType.equip_skill and Fk.skills[cardType.equip_skill]
    if equipSkill ~= nil then
      local active = equipSkill:isInstanceOf(ActiveSkill)
        or equipSkill:isInstanceOf(ViewAsSkill)
      equipSkill.visible = active
    end
  end
  local inertEquip = Fk.skills["qiao__inert_equip"]
  if inertEquip ~= nil then inertEquip.visible = false end
end)

-- Register the 合纵 positions with the upstream alliance marker. The runtime
-- policy may additionally use `extra_data.qiao_heji`; both paths resolve the
-- concrete card, never a same-name card at another position.
local hasHegUtil, Heg = pcall(require, "packages.hegemony.util")
Fk:addPostLoadFunc(function()
  if not hasHegUtil or type(Heg.addCardToAllianceCards) ~= "function" then return end
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
  local ok, Cards = pcall(require, "packages.qiao.pkg.qiao_mode.rules.cards")
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
  ["qiao_cards"] = "国战平行时空",
  ["qiao__inert"] = "未实装牌",
  ["#qiao__inert"] = "此牌为占位空壳；牌面效果尚未实装，不能使用",
  ["qiao__inert_equip"] = "未实装装备",
  ["#qiao__inert_equip"] = "此装备为占位空壳；装备效果尚未实装，不能使用",
  ["qiao__thunder_slash_skill"] = "雷杀",
  ["#qiao__thunder_slash_skill"] = "选择攻击范围内的一名角色，对其造成1点雷电伤害",
  ["#qiao__thunder_slash_skill_multi"] = "选择攻击范围内的至多%arg名角色，对这些角色各造成1点雷电伤害",
}
for _, cardType in ipairs(CardData.types) do
  translations[cardType.id] = cardType.display
  local description = cardDescription(cardType)
  translations[":" .. cardType.id] = description
  if cardType.faction_trick then
    translations[":" .. cardType.skill] = description
  end
  local reuse = ReuseData.cards[cardType.id]
  if EquipmentText[cardType.id] and reuse and reuse.kind == "qiao_equip" then
    translations[":" .. reuse.skill] = EquipmentText[cardType.id]
  end
end
Fk:loadTranslationTable(translations)

return extension
