-- 平行时空·君临天下·兵情篇
-- 兵情篇的普通武将和君主共用包开关。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local package = Package:new("qiao_bingqing", Package.GeneralPack)
package.extensionName = "qiao"
package.game_modes_whitelist = Modes.names

local Jin = require "packages.qiao.pkg.qiao_bingqing.data.bingqing_lord_jin"
local Han = require "packages.qiao.pkg.qiao_bingqing.data.bingqing_lord_han"
local Shi = require "packages.qiao.pkg.qiao_bingqing.data.shi_vector"
local Sources = { Jin, Han, Shi }
package:loadSkillSkelsByPath("./packages/qiao/pkg/qiao_bingqing/skills")
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
    generalObj.prefix = data ~= Jin and "qiao_prefix_shi_vec" or "qiao_prefix_nu"
    generalObj.mainMaxHpAdjustedValue = general.mainHpAdjust or 0
    generalObj.deputyMaxHpAdjustedValue = general.deputyHpAdjust or 0
    generalObj:addCompanions(general.companions or {})
    if #general.guests > 0 then Guest.registerGuest(general.id, general.guests) end
    for _, skill in ipairs(general.skills) do
      if skill.related then generalObj:addRelatedSkill(skill.id) else generalObj:addSkill(skill.id) end
    end
  end
end

Fk:addPostLoadFunc(function()
  -- 客将珠联随本局替换状态判定。引擎只查询调用方的关系函数，两端均需登记。
  for _, entry in ipairs(Shi.generals) do
    local owner = Fk.generals[entry.id]
    for _, id in ipairs(entry.guestCompanions or {}) do
      local partner = assert(Fk.generals[id])
      local function paired(a, b)
        if not ((a == owner and b == partner) or (a == partner and b == owner)) then return false end
        local room = Fk:currentRoom()
        if not room or not room.getBanner or not Guest.replacementEnabled(room) then return false end
        local allowed = room:getBanner("all_kingdoms")
        if type(allowed) ~= "table" or #allowed == 0 then return false end
        local first = Guest.resolve(owner.name, allowed, true)
        local second = Guest.resolve(partner.name, allowed, true)
        return first and second and (first.guest or second.guest) or false
      end
      owner:addCompanionRule(paired)
      partner:addCompanionRule(paired)
    end
  end
  for _, data in ipairs(Sources) do
    for _, version in ipairs(data.versions or {}) do Versions.register(version) end
  end
end)

return package
