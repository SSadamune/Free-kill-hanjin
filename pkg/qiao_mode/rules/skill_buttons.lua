local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local GeneralCardSkills = require "packages.qiao.pkg.qiao_mode.rules.general_card_skills"

local M = {}

-- 仅用于技能栏。完整技能名称仍供详情、战报和其他询问使用。
local aliases = {
  qiao__skill_em_shu001_flag = "六师",
  qiao__retinue_skill_bingzhou_langqi = "并州骑",
  qiao__retinue_skill_qingzhou_jingrui = "青州兵",
  qiao__retinue_skill_lujiang_shangjia = "庐江兵",
  qiao__retinue_skill_wudang_feijun = "无当军",
  qiao__luminous_pearl_skill = "夜明珠",
  qiao__sihai_liuqian_skill = "流钱",
  qiao__five_elements_fan_skill = "五行扇",
  qiao__spear_skill = "丈八矛",
  qiao__xuehai_mowangzun_skill = "魔王樽",
  qiao__halberd_skill = "方天戟",
  qiao__blade_skill = "青龙刀",
  qiao__triblade_skill = "三尖刀",
  qiao__black_chain_skill = "乌铁链",
  qiao__crossbow_skill = "诸葛弩",
  qiao__dragon_phoenix_skill = "龙凤剑",
  qiao__shenshou_sizhao_skill = "思召剑",
  qiao__xuwang_zhimian_skill = "虚妄冕",
  qiao__jinxiu_zhengpao_skill = "锦绣袍",
  qiao__zhoujun_lingbingyin_skill = "领兵印",
}

local function isGeneralSkill(skill, player)
  local granted = player and (player.derivative_skills or {})[GeneralCardSkills.SOURCE]
  if granted and table.contains(granted, skill) then return true end

  -- 翼从也注册为 General 以复用展示，但该登记不构成普通武将技能来源。
  for name, general in pairs(Fk.generals) do
    if not Commander.isRetinue(name) and table.contains(general:getSkillNameList(true), skill.name) then
      return true
    end
  end
  return false
end

function M.label(skill, label, prelight, player)
  if not skill then return label end
  local han = {}
  for _, code in utf8.codes(label) do
    if (code >= 0x3400 and code <= 0x4DBF) or (code >= 0x4E00 and code <= 0x9FFF)
      or (code >= 0xF900 and code <= 0xFAFF) or (code >= 0x20000 and code <= 0x323AF) then
      han[#han + 1] = utf8.char(code)
      if #han == 4 then break end
    end
  end
  if #han < 4 then return label end

  local alias = aliases[skill.name]
  if alias then return alias end
  local skeleton = skill:getSkeleton()
  if prelight or skill:isInstanceOf(ActiveSkill) or skill:isInstanceOf(ViewAsSkill)
    or skill.attached_equip or (skeleton and skeleton.attached_equip)
    or isGeneralSkill(skill, player) then
    return table.concat(han, "", 1, 3)
  end
  return false
end

return M
