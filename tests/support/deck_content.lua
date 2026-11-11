-- Full-table shells for deck-policy tests only. They are not formal HanJin
-- content, are never added to the mode whitelist, and therefore never enter a
-- real room's draw pile. They let the deck builder be exercised end-to-end
-- while pkg/hanjin_cards is still being completed.
if Fk.packages.hanjin_deck_test_content then return end
local pack = Package:new("hanjin_deck_test_content", Package.CardPack)
pack.extensionName = "hanjin"
Fk.packages[pack.name] = pack
table.insert(Fk.package_names, pack.name)

local Cards = require "packages.hanjin.pkg.hanjin_mode.rules.cards"
-- Resolve formal identities first so test-only registrations cannot shadow them.
Cards.installCardMetadata()

local function key(partition, suit, number)
  return partition .. "/" .. suit .. "/" .. number
end

local specialByKey, hejiByKey, adaptationByKey = {}, {}, {}
for _, spec in ipairs(Cards.lordEquipmentTable) do
  specialByKey[key(spec.partition, spec.slot.suit, spec.slot.number)] = spec
end
for _, slot in ipairs(Cards.hejiSlots) do
  hejiByKey[key(slot.partition, slot.suit, slot.number)] = slot
end
for _, group in ipairs(Cards.adaptationGroups) do
  for _, slot in ipairs(group.slots) do
    adaptationByKey[key(slot[1], slot[2], slot[3])] = group
  end
end

local counter = 0
local function nextName(prefix)
  counter = counter + 1
  return "hanjin_deck_test__" .. prefix .. "_" .. counter
end

local function add(prefix, display, ctype, subtype, suit, number, extra)
  local name = nextName(prefix)
  local spec = { name = name, type = ctype, sub_type = subtype or Card.SubtypeNone }
  if subtype == Card.SubtypeWeapon then spec.attack_range = 1 end
  local prototype = fk.CreateCard(spec):createCardPrototype()
  prototype.package = pack
  local card = prototype:clone(suit, number)
  card.package = pack
  card.extra_data = extra and table.simpleClone(extra) or nil
  pack:addCard(card)
  Fk:addCard(card)
  Fk:loadTranslationTable { [name] = display }
  return card
end

local baseIds, replacementIds, trickIds = {}, {}, {}

for _, position in ipairs(Cards.basePositions) do
  local k = key(position.partition, position.suit, position.number)
  local special, heji, group = specialByKey[k], hejiByKey[k], adaptationByKey[k]
  local display = special and special.display or heji and heji.display or group and group.display
    or ("测试牌位" .. k)
  local extra = {}
  local marked = false
  if special then
    marked = table.find(Cards.hejiSlots, function(slot)
      return slot.partition == position.partition and slot.suit == position.suit
        and slot.number == position.number and slot.display == special.display
    end) ~= nil
  elseif heji then
    marked = true
  end
  if marked then extra[Cards.HEJI_KEY] = true end
  if group then
    extra.hanjin_adaptation = { { condition = group.condition, effect = group.effect } }
  end
  local card = add("base", display, special and Card.TypeEquip or Card.TypeBasic,
    special and Card.SubtypeWeapon or Card.SubtypeNone, position.suit, position.number, extra)
  table.insert(baseIds, card.id)
  if special then
    Cards.registerEquipment(card.name, special.kingdoms, nil)
    if special.replacement then
      local replacementDisplay = special.replacement
      local replacementExtra = {}
      if replacementDisplay == "惊帆" then replacementExtra[Cards.HEJI_KEY] = true end
      local replacement = add("replacement", replacementDisplay, Card.TypeEquip, Card.SubtypeArmor,
        position.suit, position.number, replacementExtra)
      Cards.equipment[card.name].replacement = replacement.name
      table.insert(replacementIds, replacement.id)
    end
  end
end

for _, spec in ipairs(Cards.factionTrickTable) do
  local trick = add("trick", spec.display, Card.TypeTrick, Card.SubtypeNone, Card.Heart, 1)
  Cards.registerTrick(trick.name, spec.kingdom)
  table.insert(trickIds, trick.id)
end

local M = {
  pack = pack,
  baseIds = baseIds,
  replacementIds = replacementIds,
  trickIds = trickIds,
}
function M.drawIds()
  local ids = table.simpleClone(baseIds)
  table.insertTable(ids, replacementIds)
  table.insertTable(ids, trickIds)
  return ids
end
-- Keep these shells out of every real mode room's draw pile.
Fk:loadDisabled()
return M
