-- 平行时空·君临天下·兵情篇
-- 兵情篇普通武将、君主与翼从共用包开关。
local Modes = require "packages.qiao.pkg.qiao_mode.modes"
local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local package = Package:new("qiao_bingqing", Package.GeneralPack)
package.extensionName = "qiao"
package.game_modes_whitelist = Modes.names

local Jin = require "packages.qiao.pkg.qiao_bingqing.data.bingqing_lord_jin"
local Han = require "packages.qiao.pkg.qiao_bingqing.data.bingqing_lord_han"
local Nu = require "packages.qiao.pkg.qiao_bingqing.data.nu"
local Sources = { Jin, Han, Nu }
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
for _, r in ipairs(Nu.retinues) do
  translations[r.id] = r.name
  translations[r.skill.id] = r.name
  translations[":" .. r.skill.id] = r.skill.text
  local general = General:new(package, r.id, "unknown", 4)
  general.trueName, general.prefix = r.name, "qiao_prefix_nu"
  general:addSkill(r.skill.id)
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
    generalObj:addCompanions(general.companions or {})
    if #general.guests > 0 then Guest.registerGuest(general.id, general.guests) end
    for _, skill in ipairs(general.skills) do
      if skill.related then generalObj:addRelatedSkill(skill.id) else generalObj:addSkill(skill.id) end
    end
  end
end

Fk:addPostLoadFunc(function()
  local commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
  local sources = require "packages.qiao.pkg.qiao_generals.util.retinue_instance_sources"
  for _, r in ipairs(Nu.retinues) do
    commander.registerRetinue(r.id, { name = r.name, limited = false })
    sources.registerRetinue(r.id, r.skill.id)
  end
  require("packages.qiao.pkg.qiao_mode.rules.skill_source_labels").register(Nu.retinues)
  for _, g in ipairs(Nu.generals) do
    local c = g.commander
    if c then
      commander.registerCommander(g.id, { card = c.card, card_text = c.cardText,
        source_text = c.name .. " | " .. c.cardText, retinues = { c.retinue }, limited = false })
    end
  end
  local yang, xu = Fk.generals.qiao_heg__han043, Fk.generals.qiao_heg__wei010
  local function guestPair(a, b)
    if not ((a == yang and b == xu) or (a == xu and b == yang)) then return false end
    local room = Fk:currentRoom()
    if not room or not Guest.replacementEnabled(room) then return false end
    local factions = room:getBanner("all_kingdoms")
    if type(factions) ~= "table" or #factions == 0 then return false end
    local guest = Guest.resolve(xu.name, factions, true)
    return guest ~= nil and guest.guest and table.contains(guest.kingdoms, "han")
  end
  yang:addCompanionRule(guestPair)
  xu:addCompanionRule(guestPair)
  for _, data in ipairs(Sources) do
    for _, version in ipairs(data.versions or {}) do Versions.register(version) end
  end
end)

return package
