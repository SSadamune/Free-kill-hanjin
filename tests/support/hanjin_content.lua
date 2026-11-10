-- Test-only independent objects. Never synced or included by the release entry point.
if Fk.packages.hanjin_test_content then return end
local pack = Package:new("hanjin_test_content", Package.CardPack)
pack.extensionName = "hanjin"
pack.game_modes_whitelist = { "hanjin_heg_mode" }
Fk.packages[pack.name] = pack
table.insert(Fk.package_names, pack.name)

for _, kingdom in ipairs({ "wei", "shu", "wu", "qun", "han", "jin", "wild" }) do
  for index = 1, 10 do
    local name = "hanjin_test__" .. kingdom .. "_" .. index
    local general = General:new(pack, name, kingdom, 4)
    Fk.generals[name] = general
  end
end

local function add(name, cardType, subtype, suit, number, copies)
  local spec = { name = name, type = cardType, sub_type = subtype }
  if subtype == Card.SubtypeWeapon then spec.attack_range = 2 end
  local prototype = fk.CreateCard(spec):createCardPrototype()
  prototype.package = pack
  for _ = 1, copies or 1 do
    local card = prototype:clone(suit, number)
    pack:addCard(card)
    Fk:addCard(card)
  end
end

add("hanjin_test__blank_basic", Card.TypeBasic, Card.SubtypeNone, Card.Spade, 7, 64)
local Cards = require "packages.hanjin.pkg.hanjin_mode.rules.cards"
local definitions = table.clone(Cards.equipment)
for name, spec in pairs(definitions) do
  local subtype = ({ wei = Card.SubtypeDefensiveRide, jin = Card.SubtypeDefensiveRide,
    qun = Card.SubtypeArmor, wu = Card.SubtypeTreasure })[spec.kingdom] or Card.SubtypeWeapon
  local testName = name:gsub("^hanjin__", "hanjin_test__")
  local replacement = spec.replacement and spec.replacement:gsub("^hanjin__", "hanjin_test__")
  add(testName, Card.TypeEquip, subtype, Card.Spade, 2)
  if replacement then add(replacement, Card.TypeEquip, subtype, Card.Spade, 2) end
  Cards.registerEquipment(testName, spec.kingdom, replacement)
end
add("hanjin_test__faction_trick", Card.TypeTrick, Card.SubtypeNone, Card.Heart, 3)
Cards.registerTrick("hanjin_test__faction_trick", "wei")
table.insert(Fk.game_modes.hanjin_heg_mode.whitelist, pack.name)
Fk:loadDisabled()
