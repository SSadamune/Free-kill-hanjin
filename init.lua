-- 扩展目录必须命名为 hanjin（游戏内路径：packages/hanjin）。
Fk:loadTranslationTable {
  ["hanjin"] = "紫乔汉晋",
}

return {
  (require "packages.hanjin.pkg.hanjin_generals"),
  (require "packages.hanjin.pkg.hanjin_cards"),
  (require "packages.hanjin.pkg.hanjin_mode"),
}
