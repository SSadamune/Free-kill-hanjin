-- 平行时空·武将
--
-- 六势力各 15 张正式独立武将，另有 14 种翼从和 19 条统领来源。牌面数据全部
-- 来自 docs/rules/standard-generals.md 的已确认表。魏区 25 个技能与并州狼骑/虎卫军/
-- 牛金 3 个魏关联翼从技能已正式实装；汉区标准技能及 JIN001 等也已有实现；
-- 蜀区 26 个技能及周仓/白马义从/西凉精骑/象兵四翼从、
-- 吴区 27 个天生技能、涉猎及锦帆军/曲阿小将亦已实装。
-- 群区 27 条技能记录（马术复用蜀马超）及黄巾雷使均已实装。
-- 晋区29条技能记录及腹心死士/文虎亦已实装，应期复用魏司马懿的同一技能。
-- 已实装条目通过骨架的 qiaoImplemented 或下方 implemented 白名单
-- 登记，并在加载时断言确有 effect。偏将的「限一」只在这里登记牌面标记，每局
-- 唯一取得与限一统领能力由公共规则实现。
local extension = Package:new("qiao_generals")
extension.extensionName = "qiao"
extension.game_modes_whitelist = { "qiao_heg_mode" }

-- 阵/势包使用独立 Package，避免把新卡混入标准 90 将的包与计数；两种内容
-- 共用本目录的技能骨架、卡面数据和国战模式。独立包在模式创建后补登记白名单。
local zhenshi = Package:new("qiao_zhenshi")
zhenshi.extensionName = "qiao"
zhenshi.game_modes_whitelist = { "qiao_heg_mode" }

extension:loadSkillSkelsByPath("./packages/qiao/pkg/qiao_generals/skills")

local Standard = require "packages.qiao.pkg.qiao_generals.data.standard"
local ZhenShi = require "packages.qiao.pkg.qiao_generals.data.zhen_shi"
local Guest = require "packages.qiao.pkg.qiao_mode.rules.guest_factions"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"

local Formation = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_formation"
local Jin = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_jin"
local Jin2 = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_jin2"
local Wei = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_wei"
local Shu = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_shu"
local Qun = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_qun"
local Wu = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_wu"
local Retinues = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_retinues"

local Qun2 = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_qun2"

local LordShu = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_lord_shu"
local LordQun = require "packages.qiao.pkg.qiao_generals.data.zhen_shi_lord_qun"

local sources = {
  { package = zhenshi, data = LordShu },
  { package = zhenshi, data = LordQun },
  { package = zhenshi, data = Qun2 },
  { package = extension, data = Standard },
  { package = zhenshi, data = ZhenShi },
  -- 阵/势包同包 fragment：仍按一个正式包统计，不进入标准90将数据。
  { package = zhenshi, data = Formation },
  { package = zhenshi, data = Jin },
  { package = zhenshi, data = Jin2 },
  { package = zhenshi, data = Wei },
  { package = zhenshi, data = Shu },
  { package = zhenshi, data = Qun },
  { package = zhenshi, data = Wu },
  { package = zhenshi, data = Retinues },
}
local packagesById, retinuePackages, Data = {}, {}, {
  generals = {},
  retinues = {},
  commanders = {},
  kingdoms = {},
  generalCount = 0,
  retinueCount = 0,
  commanderCount = 0,
  skillCount = 0,
  retinueSkillCount = 0,
}
for _, source in ipairs(sources) do
  for _, data in ipairs(source.data.generals) do
    packagesById[data.id] = source.package
    table.insert(Data.generals, data)
  end
  for _, data in ipairs(source.data.retinues) do
    retinuePackages[data.id] = source.package
    table.insert(Data.retinues, data)
  end
  for _, data in ipairs(source.data.commanders) do table.insert(Data.commanders, data) end
  for _, kingdom in ipairs(source.data.kingdoms or {}) do
    table.insertIfNeed(Data.kingdoms, kingdom)
  end
  Data.generalCount = Data.generalCount + source.data.generalCount
  Data.retinueCount = Data.retinueCount + source.data.retinueCount
  Data.commanderCount = Data.commanderCount + source.data.commanderCount
  Data.skillCount = Data.skillCount + source.data.skillCount
  Data.retinueSkillCount = Data.retinueSkillCount + source.data.retinueSkillCount
end

local translations = {
  ["qiao_generals"] = "标准包",
  ["qiao_zhenshi"] = "君临天下",
  ["qiao_prefix_std"] = "标",
  ["qiao_prefix_zhen"] = "阵",
  ["qiao_prefix_shi"] = "势",
}

-- 角标前缀。来源按 docs/rules/zhen-shi-generals.md 的“普通武将”“君主”两表：
-- 阵包 12 将 + 君刘备；势包 12 将 + 君张角。阵势包三种新翼从随其统领来源：
-- 八阵兵（姜维/马隆，阵）、青州精锐（臧霸，势）、庐江上甲（陈武&董袭，势）。
local prefixByGeneral = {}
for _, id in ipairs({
  "qiao_heg__han014", "qiao_heg__han015", "qiao_heg__wei018", "qiao_heg__wei032",
  "qiao_heg__shu012", "qiao_heg__shu018b", "qiao_heg__wu017", "qiao_heg__wu020",
  "qiao_heg__qun011", "qiao_heg__qun081", "qiao_heg__jin006", "qiao_heg__jin023",
  "qiao_heg__em_shu001",
}) do
  prefixByGeneral[id] = "qiao_prefix_zhen"
end
for _, id in ipairs({
  "qiao_heg__han019", "qiao_heg__han022", "qiao_heg__wei017", "qiao_heg__wei023",
  "qiao_heg__shu019", "qiao_heg__shu021", "qiao_heg__wu010", "qiao_heg__wu023",
  "qiao_heg__qun006", "qiao_heg__qun024", "qiao_heg__jin017", "qiao_heg__jin022b",
  "qiao_heg__em_qun010",
}) do
  prefixByGeneral[id] = "qiao_prefix_shi"
end
local prefixByRetinue = {
  ["qiao_heg__retinue_bazhenbing"] = "qiao_prefix_zhen",
  ["qiao_heg__retinue_qingzhou_jingrui"] = "qiao_prefix_shi",
  ["qiao_heg__retinue_lujiang_shangjia"] = "qiao_prefix_shi",
}
for _, general in ipairs(Data.generals) do
  translations[general.id] = general.displayName or general.name
  translations["#" .. general.id] = general.title
  for _, skill in ipairs(general.skills) do
    translations[skill.id] = skill.name
    translations[":" .. skill.id] = skill.text
  end
end
for _, retinue in ipairs(Data.retinues) do
  translations[retinue.id] = retinue.name
  translations["#" .. retinue.id] = retinue.title
  translations[retinue.skill.id] = retinue.skill.name
  translations[":" .. retinue.skill.id] = retinue.skill.text
end
Fk:loadTranslationTable(translations)

-- Formal generals -----------------------------------------------------------
for _, data in ipairs(Data.generals) do
  -- 第 6 个参数是 General.initialize 的 gender；缺省会令角色性别变为 nil，
  -- 使离间/倾城等「男性」目标条件错误。数据侧必须给出显式的 female/male。
  assert(data.gender == "female" or data.gender == "male",
    "Missing gender metadata for " .. data.id)
  local owner = assert(packagesById[data.id], "Missing data package for " .. data.id)
  local general = General:new(owner, data.id, data.kingdom, data.hp, nil,
    data.gender == "female" and General.Female or General.Male)
  -- Two printed versions can share a Chinese name (司马懿, 诸葛亮); the engine
  -- groups same-name conversion by `trueName`. The unique card id stays the key.
  general.trueName = data.name
  local prefix = prefixByGeneral[data.id]
  if prefix == nil then
    if owner == extension then
      prefix = "qiao_prefix_std"
    else
      error("Missing badge prefix metadata for " .. data.id)
    end
  end
  general.prefix = prefix
  general.mainMaxHpAdjustedValue = data.mainHpAdjust or 0
  general.deputyMaxHpAdjustedValue = data.deputyHpAdjust or 0
  for _, skill in ipairs(data.skills) do
    if skill.related then
      general:addRelatedSkill(skill.id)
    else
      general:addSkill(skill.id)
    end
  end
  general:addCompanions(data.companions)
  -- Preserve the original table's names even when the named partner is not one
  -- of these 90 cards (董卓/高览/张纮). They can never match a current general,
  -- but the printed relation stays visible and auditable.
  general:addCompanions(data.companionsUnresolved)
  if #data.guests > 0 then Guest.registerGuest(data.id, data.guests) end
end

-- Formal retinues -----------------------------------------------------------
-- A retinue is granted only by the commander rules. `registerRetinue` hides it
-- from the normal pool and registers it with the exchange module as a soldier.
for _, data in ipairs(Data.retinues) do
  -- 翼从武将归其数据来源包；标准翼从仍属标准扩展，新阵势翼从归 zhenshi。
  local owner = retinuePackages[data.id] or extension
  local general = General:new(owner, data.id, "unknown", 4)
  general.trueName = data.name
  local prefix = prefixByRetinue[data.id]
  if prefix == nil then
    if owner == extension then
      prefix = "qiao_prefix_std"
    else
      error("Missing badge prefix metadata for " .. data.id)
    end
  end
  general.prefix = prefix
  general:addSkill(data.skill.id)
end

extension.standard = Standard
zhenshi.standard = ZhenShi
extension.zhen_shi = ZhenShi

-- 扩展根 init.lua 把本文件作为一个 Package 返回，无法同时返回第二个 Package；
-- 由本文件安装独立阵/势包，postLoad 时再补进 qiao 扩展的包列表。
zhenshi:install(Fk)

-- Registration needs the installed engine (Fk.generals / Fk.all_card_types), so
-- it runs after all packages are installed but before the mode package creates
-- the game mode (see init.lua require order).
Fk:addPostLoadFunc(function()
  local group = Fk.extensions["qiao"]
  if group ~= nil and not table.contains(group, zhenshi.name) then
    -- GeneralsOverview reads the group order directly; keep the merged
    -- 阵/势 package immediately after the standard package, not appended last.
    local index = #group + 1
    for i, name in ipairs(group) do
      if name == extension.name then
        index = i + 1
        break
      end
    end
    table.insert(group, index, zhenshi.name)
  end
  local Sources = require "packages.qiao.pkg.qiao_generals.util.retinue_instance_sources"
  for _, retinue in ipairs(Data.retinues) do
    Commander.registerRetinue(retinue.id, {
      name = retinue.name,
      limited = retinue.limited,
    })
    Sources.registerRetinue(retinue.id, retinue.skill.id)
  end
  local Versions = require "packages.qiao.pkg.qiao_mode.rules.general_versions"
  for _, source in ipairs(sources) do
    for _, version in ipairs(source.data.versions or {}) do Versions.register(version) end
  end
  local limitedCommanders = {}
  for _, data in ipairs(Data.generals) do
    if data.commander then
      limitedCommanders[data.id] = data.commander.limited == true
    end
  end
  for _, source in ipairs(Data.commanders) do
    Commander.registerCommander(source.general, {
      card = source.card,
      suit = source.suit,
      bypass_distances = source.bypass_distances,
      adaptation = source.adaptation,
      card_text = source.cardText,
      source_text = source.sourceText,
      retinues = { source.retinue },
      limited = limitedCommanders[source.general] == true,
    })
  end

  -- Fail loudly if the generated data and the installed content drift apart.
  -- Skills that have been formally implemented are the only display entries
  -- allowed to carry effects; all remaining entries stay display-only shells.
  local implemented = {
    ["qiao__skill_han001_1"] = true,
    ["qiao__skill_han001_2"] = true,
    ["qiao__skill_jin001_1"] = true,
    ["qiao__skill_jin001_2"] = true,
  }
  --- 新的正式技能在自身骨架上显式赋 `qiaoImplemented = true`；
  --- 旧白名单继续保留，避免破坏既有实装登记。两者都必须确有 effect。
  local function isImplemented(skel)
    return implemented[skel.name] == true or skel.qiaoImplemented == true
  end
  local formal, retinues, retinue_skills, commanders, skills = 0, 0, 0, 0, 0
  for _, data in ipairs(Data.generals) do
    local general = assert(Fk.generals[data.id], "Missing formal general: " .. data.id)
    assert(general.package == packagesById[data.id], "Wrong package for " .. data.id)
    assert(general.maxHp == data.hp, "Wrong hp for " .. data.id)
    assert(general.mainMaxHpAdjustedValue == (data.mainHpAdjust or 0),
      "Wrong main hp adjustment for " .. data.id)
    assert(general.deputyMaxHpAdjustedValue == (data.deputyHpAdjust or 0),
      "Wrong deputy hp adjustment for " .. data.id)
    for _, companion in ipairs(data.companions) do
      assert(table.contains(general.companions, companion),
        "Missing companion relation for " .. data.id)
    end
    for _, companion in ipairs(data.companionsUnresolved) do
      assert(table.contains(general.companions, companion),
        "Missing printed companion name for " .. data.id)
    end
    if data.commander then
      local source = assert(Commander.commanders[data.id],
        "Missing commander registration for " .. data.id)
      assert(source.card == data.commander.card, "Wrong commander card for " .. data.id)
      assert(source.card_text == data.commander.cardText,
        "Wrong commander card text for " .. data.id)
      assert(source.source_text == data.commander.sourceText,
        "Wrong commander source text for " .. data.id)
      assert(table.contains(source.retinues, data.commander.retinue),
        "Wrong commander retinue for " .. data.id)
      -- 来源能力自身的限一与偏将/翼从限一是独立登记。
      assert(source.limited == (data.commander.limited == true),
        "Wrong limited ability flag for " .. data.id)
    end
    for _, skill in ipairs(data.skills) do
      local skel = assert(Fk.skill_skels[skill.id], "Missing skill skeleton: " .. skill.id)
      if isImplemented(skel) then
        assert(#skel.effects > 0, "Implemented skill must have an effect: " .. skill.id)
      else
        assert(#skel.effects == 0, "Formal display skill must have no effect: " .. skill.id)
      end
      skills = skills + 1
    end
    formal = formal + 1
  end
  for _, data in ipairs(Data.retinues) do
    assert(Commander.isRetinue(data.id), "Unregistered retinue: " .. data.id)
    local general = assert(Fk.generals[data.id], "Missing retinue general: " .. data.id)
    assert(general.hidden, "Retinue must be hidden: " .. data.id)
    local skill = assert(Fk.skill_skels[data.skill.id], "Missing retinue skill: " .. data.skill.id)
    if skill.qiaoImplemented == true then
      assert(#skill.effects > 0, "Implemented retinue skill must have an effect: " .. data.skill.id)
    else
      assert(#skill.effects == 0, "Retinue display skill must have no effect: " .. data.skill.id)
    end
    retinues = retinues + 1
    retinue_skills = retinue_skills + 1
  end
  for _, source in ipairs(Data.commanders) do
    assert(Commander.isCommander(source.general), "Unregistered commander: " .. source.general)
    assert(Fk.all_card_types[source.card], "Missing commander card type: " .. source.card)
    local data = Commander.commanders[source.general]
    assert(data.card_text == source.cardText, "Wrong commander card text: " .. source.general)
    assert(data.source_text == source.sourceText, "Wrong commander source text: " .. source.general)
    commanders = commanders + 1
  end
  assert(formal == Data.generalCount, "Formal general count mismatch")
  assert(retinues == Data.retinueCount, "Retinue count mismatch")
  assert(retinue_skills == Data.retinueSkillCount, "Retinue skill count mismatch")
  assert(commanders == Data.commanderCount, "Commander source count mismatch")
  assert(skills == Data.skillCount, "Formal skill count mismatch")

  -- qiao_heg_mode 由 qiao_mode 的 postLoad 函数在本函数之后创建，早于本
  -- 函数执行的白名单映射合并看不到它。这里追加一个后置函数，在模式创建后把
  -- 独立包加入白名单并重算禁用包，避免正式包在国战中被整体禁用。
  Fk:addPostLoadFunc(function()
    local mode = assert(Fk.game_modes.qiao_heg_mode,
      "Missing qiao_heg_mode after postLoad")
    if type(mode.whitelist) == "table" then
      table.insertIfNeed(mode.whitelist, zhenshi.name)
      Fk:loadDisabled()
    end
  end)
end)

return extension
