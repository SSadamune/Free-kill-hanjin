-- 平行时空·君临天下·兵情篇（空分包；暂未登记武将或卡牌）
local package = Package:new("hanjin_bingqing", Package.GeneralPack)
package.extensionName = "hanjin"
package.game_modes_whitelist = { "hanjin_heg_mode" }

Fk:loadTranslationTable {
  ["hanjin_bingqing"] = "君临天下·兵情篇",
}

return package
