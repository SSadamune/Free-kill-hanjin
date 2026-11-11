-- Test-only independent content for guest factions and wild allegiance.
-- Never synced or included by the release entry point.
if Fk.packages.hanjin_test_guest_content then return end
__dofile("../../../tests/support/hanjin_content.lua")

local pack = Package:new("hanjin_test_guest_content", Package.CardPack)
pack.extensionName = "hanjin"
pack.game_modes_whitelist = { "hanjin_heg_mode" }
Fk.packages[pack.name] = pack
table.insert(Fk.package_names, pack.name)

local function addGeneral(name, kingdom, subkingdom)
  local general = General:new(pack, name, kingdom, 4)
  general.subkingdom = subkingdom
  Fk.generals[name] = general
  return general
end

-- Normal generals whose printed factions can all be banned. Their registered
-- guest faction is then the only usable one for this game.
addGeneral("hanjin_test__guest_dual_1", "wei", "shu")
addGeneral("hanjin_test__guest_dual_2", "wei", "shu")
addGeneral("hanjin_test__guest_dual_3", "wei", "shu")
addGeneral("hanjin_test__guest_dual_4", "wei", "shu")
addGeneral("hanjin_test__guest_partial", "wei", "wu")
addGeneral("hanjin_test__guest_banned", "wei", "shu")
addGeneral("hanjin_test__guest_multi_1", "wei", "shu")
addGeneral("hanjin_test__guest_multi_2", "wei", "shu")

local Guest = require "packages.hanjin.pkg.hanjin_mode.rules.guest_factions"
Guest.registerGuest("hanjin_test__wei_1", { "han" })
Guest.registerGuest("hanjin_test__wei_2", { "han" })
Guest.registerGuest("hanjin_test__guest_dual_1", { "han" })
Guest.registerGuest("hanjin_test__guest_dual_2", { "han" })
Guest.registerGuest("hanjin_test__guest_dual_3", { "han" })
Guest.registerGuest("hanjin_test__guest_dual_4", { "han" })
Guest.registerGuest("hanjin_test__guest_partial", { "qun" })
Guest.registerGuest("hanjin_test__guest_banned", { "wei", "shu" })
Guest.registerGuest("hanjin_test__guest_multi_1", { "han", "jin" })
Guest.registerGuest("hanjin_test__guest_multi_2", { "han", "jin" })

-- Loyalty versions of wild-exclusive test generals. The shared version registry
-- is the one the in-game promotion implementation reads; this content must not
-- register a second mapping.
local Versions = require "packages.hanjin.pkg.hanjin_mode.rules.general_versions"
local loyalty = {
  { "hanjin_test__wild_1", "hanjin_test__loyal_1", "wei" },
  { "hanjin_test__wild_2", "hanjin_test__loyal_2", "jin", "wei" },
  { "hanjin_test__wild_3", "hanjin_test__loyal_3", "wu" },
  { "hanjin_test__wild_4", "hanjin_test__loyal_4", "han" },
  { "hanjin_test__wild_5", "hanjin_test__loyal_5", "wei", "shu" },
  { "hanjin_test__wild_6", "hanjin_test__loyal_6", "qun" },
  { "hanjin_test__wild__same", "hanjin_test__loyal__same", "han" },
}
for _, spec in ipairs(loyalty) do
  addGeneral(spec[2], spec[3], spec[4])
end
addGeneral("hanjin_test__wild__same", "wild")
for _, spec in ipairs(loyalty) do
  Versions.register { normal = spec[1], loyalty = spec[2] }
end

Fk:loadTranslationTable {
  ["hanjin_test__guest_dual_1"] = "测试客将·甲",
  ["hanjin_test__guest_dual_2"] = "测试客将·乙",
  ["hanjin_test__guest_dual_3"] = "测试客将·丙",
  ["hanjin_test__guest_dual_4"] = "测试客将·丁",
  ["hanjin_test__guest_partial"] = "测试客将·部分",
  ["hanjin_test__guest_banned"] = "测试客将·全禁",
  ["hanjin_test__guest_multi_1"] = "测试客将·多势力甲",
  ["hanjin_test__guest_multi_2"] = "测试客将·多势力乙",
  ["hanjin_test__loyal_1"] = "测试效忠·魏",
  ["hanjin_test__loyal_2"] = "测试效忠·晋",
  ["hanjin_test__loyal_3"] = "测试效忠·吴",
  ["hanjin_test__loyal_4"] = "测试效忠·汉",
  ["hanjin_test__loyal_5"] = "测试效忠·魏蜀",
  ["hanjin_test__loyal_6"] = "测试效忠·群",
  ["hanjin_test__loyal__same"] = "测试效忠·同名",
  ["hanjin_test__wild__same"] = "测试野心家·同名",
}

table.insert(Fk.game_modes.hanjin_heg_mode.whitelist, pack.name)
Fk:loadDisabled()
