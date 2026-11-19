-- 平行时空·君临天下·兵情篇
-- 独立包：登记 EM(JIN001) 君司马炎；其余内容仍为空。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local package = Package:new("qiao_bingqing", Package.GeneralPack)
package.extensionName = "qiao"
package.game_modes_whitelist = Modes.names

local Jin = require "packages.qiao.pkg.qiao_bingqing.data.bingqing_lord_jin"
local Han = require "packages.qiao.pkg.qiao_bingqing.data.bingqing_lord_han"
local Sources = { Jin, Han }
for _, data in ipairs(Sources) do
  assert(type(data) == "table" and type(data.generals) == "table",
    "bingqing data fragment missing generals")
end

local translations = {
  ["qiao_bingqing"] = "君临天下·兵情篇",
  ["qiao_prefix_nu"] = "弩",
  ["qiao_prefix_shi_vec"] = "矢",
}
for _, data in ipairs(Sources) do
  for _, general in ipairs(data.generals) do
    translations[general.id] = general.displayName or general.name
    translations["#" .. general.id] = general.title
    for _, skill in ipairs(general.skills) do
      translations[skill.id] = skill.name
      translations[":" .. skill.id] = skill.text
    end
  end
end
Fk:loadTranslationTable(translations)

for _, data in ipairs(Sources) do
  for _, general in ipairs(data.generals) do
    assert(general.gender == "female" or general.gender == "male",
      "Missing gender metadata for " .. general.id)
    local generalObj = General:new(package, general.id, general.kingdom, general.hp, nil,
      general.gender == "female" and General.Female or General.Male)
    generalObj.trueName = general.name
    generalObj.prefix = general.id == "qiao_heg__em_han001" and "qiao_prefix_shi_vec" or "qiao_prefix_nu"
    generalObj.mainMaxHpAdjustedValue = general.mainHpAdjust or 0
    generalObj.deputyMaxHpAdjustedValue = general.deputyHpAdjust or 0
    for _, skill in ipairs(general.skills) do
      if skill.related then generalObj:addRelatedSkill(skill.id) else generalObj:addSkill(skill.id) end
    end
  end
end

Fk:addPostLoadFunc(function()
  local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
  for _, data in ipairs(Sources) do
    for _, version in ipairs(data.versions or {}) do Versions.register(version) end
  end
end)

return package
