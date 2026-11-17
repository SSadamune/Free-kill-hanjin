-- 平行时空·君临天下·兵情篇（空分包；暂未登记武将或卡牌）
local package = Package:new("qiao_bingqing", Package.GeneralPack)
package.extensionName = "qiao"
package.game_modes_whitelist = { "qiao_heg_mode" }

Fk:loadTranslationTable {
  ["qiao_bingqing"] = "君临天下·兵情篇",
}

return package
