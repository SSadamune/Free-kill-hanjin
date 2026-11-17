-- 平行时空·纵横捭阖（空分包；暂未登记武将或卡牌）
local package = Package:new("hanjin_zongheng", Package.GeneralPack)
package.extensionName = "hanjin"
package.game_modes_whitelist = { "hanjin_heg_mode" }

Fk:loadTranslationTable {
  ["hanjin_zongheng"] = "纵横捭阖",
}

return package
