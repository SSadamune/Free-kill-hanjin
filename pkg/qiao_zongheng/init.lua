-- 平行时空·纵横捭阖（空分包；暂未登记武将或卡牌）
local package = Package:new("qiao_zongheng", Package.GeneralPack)
package.extensionName = "qiao"
package.game_modes_whitelist = { "qiao_heg_mode" }

Fk:loadTranslationTable {
  ["qiao_zongheng"] = "纵横捭阖",
}

return package
