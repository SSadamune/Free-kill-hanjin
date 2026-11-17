-- 扩展目录必须命名为 hanjin（游戏内路径：packages/hanjin）。
Fk:loadTranslationTable {
  ["hanjin"] = "平行时空国战",
}

-- GeneralsOverview builds its left-side extension list from
-- Fk.extension_names in raw order. Move hanjin immediately after the actual
-- 国战 extension (hegemony), preserving every other extension's order.
Fk:addPostLoadFunc(function()
  local names = Fk.extension_names
  local hanjinIndex, hegemonyIndex
  for i, name in ipairs(names) do
    if name == "hanjin" then hanjinIndex = i end
    if name == "hegemony" then hegemonyIndex = i end
  end
  if hanjinIndex == nil or hegemonyIndex == nil then return end
  if hanjinIndex == hegemonyIndex + 1 then return end
  table.remove(names, hanjinIndex)
  if hanjinIndex < hegemonyIndex then hegemonyIndex = hegemonyIndex - 1 end
  table.insert(names, hegemonyIndex + 1, "hanjin")
end)

return {
  (require "packages.hanjin.pkg.hanjin_generals"),
  (require "packages.hanjin.pkg.hanjin_bingqing"),
  (require "packages.hanjin.pkg.hanjin_buchen"),
  (require "packages.hanjin.pkg.hanjin_zongheng"),
  (require "packages.hanjin.pkg.hanjin_cards"),
  (require "packages.hanjin.pkg.hanjin_mode"),
}
