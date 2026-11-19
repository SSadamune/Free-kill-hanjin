-- 平行时空·君临天下·不臣篇（空分包；暂未登记武将或卡牌）
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local package = Package:new("qiao_buchen", Package.GeneralPack)
package.extensionName = "qiao"
package.game_modes_whitelist = Modes.names

Fk:loadTranslationTable {
  ["qiao_buchen"] = "君临天下·不臣篇",
}

return package
