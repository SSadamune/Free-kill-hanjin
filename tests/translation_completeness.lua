-- 正式可见技能/旗/公开牌堆的本地化完整性检查。
-- 只覆盖会在技能面板、旗状态栏或牌名中显示的键；内部规则/代理技能不强行配文案。
Testqiao_translation_completeness = {}

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
}

local PUBLIC_PILES = {
  (require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han").PILE,
  "qiao_em_wu001_fenghuo",
  "qiao_em_qun010_tianbing",
  "$sa_carriage",
  "@[qiao_luanji_suits]",
  "@[qiao_kannan_damage]-turn",
  "@[qiao_keqing]",
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

function Testqiao_translation_completeness:testEveryFormalGeneralSkillHasText()
  local missing = {}
  for id, general in pairs(Fk.generals) do
    if id:startsWith("qiao_heg__") then
      for _, skill in ipairs(general:getSkillNameList()) do
        if Fk.skills[skill] ~= nil then
          if Fk:translate(skill) == skill then table.insert(missing, id .. ":" .. skill .. ":name") end
          if Fk:translate(":" .. skill) == ":" .. skill then table.insert(missing, id .. ":" .. skill .. ":desc") end
        end
      end
    end
  end
  lu.assertEquals(#missing, 0, "正式武将技能缺少可见文案：" .. table.concat(missing, ", "))
end

return { name = "qiao_translation_completeness" }
