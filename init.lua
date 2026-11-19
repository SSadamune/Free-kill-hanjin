-- 扩展目录必须命名为 qiao（游戏内路径：packages/qiao）。

-- With the packages/freekill-core layout, ModManager restores the working
-- directory into the core package before postLoad callbacks run. Run qiao's
-- callbacks from the extension root instead, then restore the engine's cwd.
local extension_root = FileIO.pwd()
local post_load_cwd

Fk:loadTranslationTable {
  ["qiao"] = "平行时空国战",
}

-- GeneralsOverview builds its left-side extension list from
-- Fk.extension_names in raw order. Move qiao immediately after the actual
-- 国战 extension (hegemony), preserving every other extension's order.
Fk:addPostLoadFunc(function()
  post_load_cwd = FileIO.pwd()
  FileIO.cd(extension_root)

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

local packages = {
  (require "packages.qiao.pkg.qiao_generals"),
  (require "packages.qiao.pkg.qiao_bingqing"),
  (require "packages.qiao.pkg.qiao_buchen"),
  (require "packages.qiao.pkg.qiao_zongheng"),
  (require "packages.qiao.pkg.qiao_cards"),
  (require "packages.qiao.pkg.qiao_mode"),
}

-- Registered after the subpackages so it runs after every qiao postLoad
-- callback, before callbacks from packages loaded later (e.g. utility).
Fk:addPostLoadFunc(function()
  if post_load_cwd then
    FileIO.cd(post_load_cwd)
    post_load_cwd = nil
  end
end)

return packages
