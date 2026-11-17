-- 平行时空·君临天下·不臣篇（空分包；暂未登记武将或卡牌）
local package = Package:new("hanjin_buchen", Package.GeneralPack)
package.extensionName = "hanjin"
package.game_modes_whitelist = { "hanjin_heg_mode" }

Fk:loadTranslationTable {
  ["hanjin_buchen"] = "君临天下·不臣篇",
}

return package
