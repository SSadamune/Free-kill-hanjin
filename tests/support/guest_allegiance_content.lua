-- Test-only independent content for guest factions and wild allegiance.
-- Never synced or included by the release entry point.
if Fk.packages.qiao_test_guest_content then return end
__dofile("../../../tests/support/qiao_content.lua")

local pack = Package:new("qiao_test_guest_content", Package.CardPack)
pack.extensionName = "qiao"
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
pack.game_modes_whitelist = Modes.names
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
addGeneral("qiao_test__guest_dual_1", "wei", "shu")
addGeneral("qiao_test__guest_dual_2", "wei", "shu")
addGeneral("qiao_test__guest_dual_3", "wei", "shu")
addGeneral("qiao_test__guest_dual_4", "wei", "shu")
addGeneral("qiao_test__guest_partial", "wei", "wu")
addGeneral("qiao_test__guest_banned", "wei", "shu")
addGeneral("qiao_test__guest_multi_1", "wei", "shu")
addGeneral("qiao_test__guest_multi_2", "wei", "shu")

local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
Guest.registerGuest("qiao_test__wei_1", { "han" })
Guest.registerGuest("qiao_test__wei_2", { "han" })
Guest.registerGuest("qiao_test__guest_dual_1", { "han" })
Guest.registerGuest("qiao_test__guest_dual_2", { "han" })
Guest.registerGuest("qiao_test__guest_dual_3", { "han" })
Guest.registerGuest("qiao_test__guest_dual_4", { "han" })
Guest.registerGuest("qiao_test__guest_partial", { "qun" })
Guest.registerGuest("qiao_test__guest_banned", { "wei", "shu" })
Guest.registerGuest("qiao_test__guest_multi_1", { "han", "jin" })
Guest.registerGuest("qiao_test__guest_multi_2", { "han", "jin" })

-- Loyalty versions of wild-exclusive test generals. The shared version registry
-- is the one the in-game promotion implementation reads; this content must not
-- register a second mapping.
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local loyalty = {
  { "qiao_test__wild_1", "qiao_test__loyal_1", "wei" },
  { "qiao_test__wild_2", "qiao_test__loyal_2", "jin", "wei" },
  { "qiao_test__wild_3", "qiao_test__loyal_3", "wu" },
  { "qiao_test__wild_4", "qiao_test__loyal_4", "han" },
  { "qiao_test__wild_5", "qiao_test__loyal_5", "wei", "shu" },
  { "qiao_test__wild_6", "qiao_test__loyal_6", "qun" },
  { "qiao_test__wild__same", "qiao_test__loyal__same", "han" },
}
for _, spec in ipairs(loyalty) do
  addGeneral(spec[2], spec[3], spec[4])
end
addGeneral("qiao_test__wild__same", "wild")
for _, spec in ipairs(loyalty) do
  Versions.register { normal = spec[1], loyalty = spec[2] }
end

Fk:loadTranslationTable {
  ["qiao_test__guest_dual_1"] = "测试客将·甲",
  ["qiao_test__guest_dual_2"] = "测试客将·乙",
  ["qiao_test__guest_dual_3"] = "测试客将·丙",
  ["qiao_test__guest_dual_4"] = "测试客将·丁",
  ["qiao_test__guest_partial"] = "测试客将·部分",
  ["qiao_test__guest_banned"] = "测试客将·全禁",
  ["qiao_test__guest_multi_1"] = "测试客将·多势力甲",
  ["qiao_test__guest_multi_2"] = "测试客将·多势力乙",
  ["qiao_test__loyal_1"] = "测试效忠·魏",
  ["qiao_test__loyal_2"] = "测试效忠·晋",
  ["qiao_test__loyal_3"] = "测试效忠·吴",
  ["qiao_test__loyal_4"] = "测试效忠·汉",
  ["qiao_test__loyal_5"] = "测试效忠·魏蜀",
  ["qiao_test__loyal_6"] = "测试效忠·群",
  ["qiao_test__loyal__same"] = "测试效忠·同名",
  ["qiao_test__wild__same"] = "测试野心家·同名",
}

for _, mode in ipairs(Modes.names) do
  table.insert(Fk.game_modes[mode].whitelist, pack.name)
end
Fk:loadDisabled()
