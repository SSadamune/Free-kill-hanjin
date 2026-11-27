-- 正式可见技能/旗/公开牌堆的本地化完整性检查。
-- 只覆盖会在技能面板、旗状态栏或牌名中显示的键；内部规则/代理技能不强行配文案。
Testqiao_translation_completeness = {}

function Testqiao_translation_completeness:testSkillReferenceCatalog()
  local references = require "packages.qiao.pkg.qiao_mode.skill_references"
  local sameName = require "packages.qiao.pkg.qiao_mode.rules.same_name_skills"
  local ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
  local catalog = references.catalog()
  local skills, byId = {}, {}
  for _, skill in ipairs(catalog.skills) do
    lu.assertEquals(sameName.canonicalHistoryKey(skill.id), skill.id)
    skills[skill.title] = skill
    byId[skill.id] = skill
  end
  lu.assertEquals(catalog.skillAliases[sameName.instanceName(ci.CONSUME)], ci.CONSUME)
  lu.assertEquals(byId[ci.CONSUME].description, Fk:translate(":" .. ci.MARK))

  local banner = byId.qiao__skill_em_wu001_flag
  lu.assertEquals(banner.description, Fk:getDescription(banner.id))
  lu.assertEquals(banner.page, "banner")
  lu.assertNil(byId.qiao__wu_turn_effects_second_source, "没有正式说明的内部后续效果不能进入详情索引")
  lu.assertNil(skills["诏书"].page)
  lu.assertStrContains(skills["烽火"].description, "缘江烽火图")
  lu.assertEquals(skills["统领能力"].description, Fk:translate(":qiao_commander_ability"))
  lu.assertEquals(skills["野心家"].description, Fk:translate(":@!!wild"))
  lu.assertEquals(catalog.cards["杀"].id, "qiao__slash")
  lu.assertEquals(catalog.cards["赤霄剑"].description, Fk:translate(":qiao__chixiao_sword"))
  lu.assertNotNil(catalog.cards["洛水之誓"])
  lu.assertEquals(catalog.cards["挟天子"].id, "qiao__threaten_emperor")
  lu.assertEquals(catalog.cards["赋礼"].description, Fk:translate(":battle_royal_fuli"))
  lu.assertNotNil(skills["军令三"])
  lu.assertStrContains(catalog.variants["雷杀·孤军"][1].description, "应变·孤军")
  lu.assertStrContains(catalog.variants["挟天子以令诸侯·合纵"][1].description, "合纵")
  local pages = {}
  for _, entry in ipairs(catalog.generals) do
    pages[entry.title] = entry.page
  end
  lu.assertEquals(pages["并州狼骑"], "retinue")
  lu.assertEquals(pages["司马师"], "general")
  local liuBei = table.find(catalog.generals, function(entry) return entry.id == "qiao_heg__shu001" end)
  local jiangWei = table.find(catalog.generals, function(entry) return entry.id == "qiao_heg__shu012" end)
  lu.assertEquals(liuBei.lord, "qiao_heg__em_shu001")
  lu.assertStrContains(jiangWei.commander, "八阵兵")
end

function Testqiao_translation_completeness:testEmbeddedDescriptionsAreRegisteredForDisplayOnly()
  local references = require "packages.qiao.pkg.qiao_mode.skill_references"
  local ci = require "packages.qiao.pkg.qiao_generals.util.jin_ci"
  local qun = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"
  local related = {
    [ci.SKILL] = ci.CONSUME,
    [qun.BANNER_SKILL] = qun.ENTRY,
    qiao__skill_shu021_2 = "qiao__skill_shu021_3",
  }
  local originals = {}
  for parent in pairs(related) do originals[parent] = Fk:translate(":" .. parent) end

  local catalog = references.catalog()
  local byId = {}
  for _, skill in ipairs(catalog.skills) do byId[skill.id] = skill end
  for parent, target in pairs(related) do
    local omission = catalog.omissions[parent]
    lu.assertEquals(omission.target, target)
    lu.assertStrContains(originals[parent], omission.fragments[1])
    lu.assertEquals(Fk:translate(":" .. parent), originals[parent])
    lu.assertEquals(byId[parent].description, Fk:getDescription(parent))
    lu.assertStrContains(byId[target].description, Fk:translate(":" .. target))
  end
  lu.assertStrContains(byId[ci.CONSUME].description, "〖赐〗是一种国战标记：")
  local bannerTip = Fk:translate(":@!!" .. ci.SKILL)
  lu.assertNotStrContains(bannerTip, Fk:translate(":" .. ci.MARK))
  lu.assertStrContains(bannerTip, "置为“赐”")
  lu.assertStrContains(bannerTip, "交给其")
  lu.assertStrContains(bannerTip, "并防止之")
end

local PUBLIC_SKILLS = {
  "qiao__skill_em_han001_banner",
  "qiao__skill_em_han001_consume",
  "qiao__skill_em_jin001_banner",
  "qiao__skill_em_wei001_banner",
  "qiao__skill_em_wu001_flag_entry",
  "qiao__skill_em_wu001_flag",
  "qiao__gongxin",
  "qiao__em_qun010_banner",
}

local PUBLIC_PROMPTS = {
  "#qiao__skill_han002_1-invoke",
  "#qiao__skill_han018_1-invoke",
  "#qiao__skill_em_wu001_flag-grant",
  "#qiao__skill_em_wu001_flag-remove",
  "#qiao__gongxin-prompt",
  "#qiao__gongxin-panel",
  "#qiao__gongxin-discard",
  "#qiao__gongxin-top",
  "#qiao__gongxin-end",
  "#qiao_adaptation_add_target",
  "#qiao_adaptation_remove_target",
  "#qiao_adaptation_discard_equip",
  "#qiao_adaptation_ignore",
  "#InvokeSkillQiaoAdaptation",
  "#qiao_retinue_skill_mushun_delay",
  "#qiao__skill_jin013_2_effect",
  "qiao__zouyu_fan_delay",
  "#qiao_vine_nullifies",
  "#qiao__halberd_active",
  "#qiao_temporary_effect_ended",
  "#QiaoChuanxinReveal1",
  "#QiaoChuanxinReveal2",
  "#QiaoChuanxinReveal3",
  "#qiao__skill_shu015_2-card",
}

local PUBLIC_PILES = {
  (require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han").PILE,
  "qiao_em_wu001_fenghuo",
  "qiao_em_qun010_tianbing",
  "$sa_carriage",
  "@[qiao_luanji_suits]",
  "@[qiao_kannan_damage]-turn",
  "@[qiao_keqing]",
  "@[qiao_bingzhou_pairs]",
  "@@qiao_bazhen_viewas",
  "@@qiao_feiying_layers",
}

function Testqiao_translation_completeness:testPublicSkillsHaveNameAndDescription()
  for _, name in ipairs(PUBLIC_SKILLS) do
    local shown = Fk:translate(name)
    local desc = Fk:translate(":" .. name)
    lu.assertNotEquals(shown, name, "可见技能缺名称：" .. name)
    lu.assertNotEquals(desc, ":" .. name, "可见技能缺说明：" .. name)
    lu.assertTrue(#desc > 0, "可见技能说明为空：" .. name)
  end
end

function Testqiao_translation_completeness:testPublicPromptsAreTranslated()
  for _, key in ipairs(PUBLIC_PROMPTS) do
    lu.assertNotEquals(Fk:translate(key), key, "请求提示缺本地化：" .. key)
  end
end

function Testqiao_translation_completeness:testPublicPilesAndMarksHaveReadableText()
  for _, name in ipairs(PUBLIC_PILES) do
    lu.assertNotEquals(Fk:translate(name), name, "公开牌堆缺本地化：" .. name)
  end
  local retinues = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"
  lu.assertEquals(Fk:translate(retinues.PUBLIC_MARK, "zh_CN"), "翼从")
  lu.assertEquals(Fk:translate(retinues.PUBLIC_MARK:sub(3), "zh_CN"), "翼从")
  for _, name in ipairs({ "qiao_use_target_policy", "qiao_commander_sources" }) do
    local spec = assert(Fk.qml_marks[name], "缺少 QML 标记注册：" .. name)
    lu.assertEquals(spec.how_to_show(), "#hidden", "内部标记应隐藏：" .. name)
  end
end

function Testqiao_translation_completeness:testFormalContentHasText()
  local missing = {}
  local published = Fk.extensions.qiao
  local function check(key)
    local text = Fk:translate(key, "zh_CN")
    if text == key or text == "" then missing[#missing + 1] = key end
  end

  lu.assertEquals(Fk:translate("jin", "zh_CN"), "晋")
  for id, general in pairs(Fk.generals) do
    if table.contains(published, general.package.name) then
      check(id)
      check(general.kingdom)
      if general.subkingdom and general.subkingdom ~= "" then check(general.subkingdom) end
      if general.prefix and general.prefix ~= "" then check(general.prefix) end
      for _, skill in ipairs(general:getSkillNameList(true, true)) do
        check(skill)
        check(":" .. skill)
      end
    end
  end
  for id, card in pairs(Fk.all_card_types) do
    if card.package and table.contains(published, card.package.name) then
      check(id)
      check(":" .. id)
    end
  end
  lu.assertEquals(#missing, 0, "正式内容缺少可见文案：" .. table.concat(missing, ", "))
end

function Testqiao_translation_completeness:testDelayedEffectsHaveTheirSourceName()
  for key, expected in pairs {
    ["#qiao_jin017_cruise"] = "遄征",
    qiao__han019_1_rule = "烈医",
    qiao__skill_em_wu001_rule = "缘江烽火图",
    qiao__wei023_hengjiang_rule = "横江",
    qiao__wu020_pojun_rule = "破军",
    qiao__wu_turn_effects = "好施",
  } do
    lu.assertEquals(Fk:translate(key, "zh_CN"), expected, key)
    for _, effect in ipairs(Fk.skill_skels[key].effect_names) do
      lu.assertEquals(Fk:translate(effect, "zh_CN"), expected, effect)
    end
  end
end

return { name = "qiao_translation_completeness" }
