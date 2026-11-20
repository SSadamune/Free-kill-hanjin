-- 扩展目录必须命名为 qiao（游戏内路径：packages/qiao）。
Fk:loadTranslationTable {
  ["qiao"] = "平行时空国战",
}

Fk:addPostLoadFunc(function()
  local standard = Fk.packages.standard
  for _, page in ipairs(standard and standard.customPages or {}) do
    if page.name == "Generals Overview" then
      page.qml = { url = "packages/qiao/pkg/qiao_mode/qml/QiaoGeneralsOverview.qml" }
      break
    end
  end

  -- GeneralsOverview uses this order for its extension list.
  -- Put qiao immediately after hegemony (国战).
  local names = Fk.extension_names
  local qiaoIndex, hegemonyIndex
  for i, name in ipairs(names) do
    if name == "qiao" then qiaoIndex = i end
    if name == "hegemony" then hegemonyIndex = i end
  end
  if qiaoIndex == nil or hegemonyIndex == nil then return end
  if qiaoIndex == hegemonyIndex + 1 then return end
  table.remove(names, qiaoIndex)
  if qiaoIndex < hegemonyIndex then hegemonyIndex = hegemonyIndex - 1 end
  table.insert(names, hegemonyIndex + 1, "qiao")
end)

return {
  (require "packages.qiao.pkg.qiao_generals"),
  (require "packages.qiao.pkg.qiao_bingqing"),
  (require "packages.qiao.pkg.qiao_buchen"),
  (require "packages.qiao.pkg.qiao_zongheng"),
  (require "packages.qiao.pkg.qiao_cards"),
  (require "packages.qiao.pkg.qiao_mode"),
}
