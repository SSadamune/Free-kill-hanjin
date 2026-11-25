-- 技能详情来源标签：只标注汉晋扩展中非武将牌来源的既有技能。
-- 标签注入技能骨架的动态描述入口（dynamicDesc，以及带 dynamic_desc 时
-- 遮蔽实例 getDynamicDescription 的原始函数），由
-- Fk:getDescription(name, nil, player) 在右键角色详情的技能描述中渲染。
-- 不写 dynamic_name：技能名会进入右下角 SkillButton，改变其宽度。
-- 不修改可见性、按钮、结算或房间状态；不读取他人标记明细。
local Han = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"
local Wei = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wei"
local Wu = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"
local Qun = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_qun"
local Commander = require "packages.qiao.pkg.qiao_mode.rules.commander_retinue"
local Flags = require "packages.qiao.pkg.qiao_mode.rules.lord_flag_display"
local Dying = require "packages.qiao.pkg.qiao_generals.util.qun_dying"
local Formation = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_formation"

local M = {}

local LABELS = {
  EDICT = "诏书",
  FLAG = "君主旗",
  COMMANDER = "统领",
  RETINUE = "翼从",
}
M.LABELS = LABELS

-- The engine writes the callback's actual skill ID into logs and broadcasts
-- it to the room. Delayed effects keep their IDs and display their source name.
local DISPLAY_NAME_SOURCES = {
  ["#qiao_jin017_cruise"] = "qiao__skill_jin017_2",
  qiao__han019_1_rule = "qiao__skill_han019_1",
  [Wu.RULE] = Wu.FLAG,
  qiao__wei023_hengjiang_rule = "qiao__skill_wei023_1",
  qiao__wu020_pojun_rule = "qiao__skill_wu020_2",
  qiao__wu_turn_effects = "qiao__skill_wu014_1",
  ["@@qiao_bazhen_viewas"] = "qiao__retinue_skill_bazhenbing_viewas",
  ["@[qiao_bingzhou_pairs]"] = "qiao__retinue_skill_bingzhou_distance",
  [Formation.FEIYING_LAYERS_MARK] = Formation.FEIYING_SKILL,
}

-- 用于幂等：并行维护处若已经给同一骨架加过标签，不重复包裹。
local MARKER = "qiaoSourceLabel"

local function labelTag(label)
  return "〔" .. label .. "〕"
end

--- 给描述文本加来源标签；已有标签时不重复，extra 只追加一次。
local function withLabel(self, text, label, extra, extraMarker, lang)
  if type(text) ~= "string" or text == "" then
    text = Fk:translate(":" .. self.name, lang)
  end
  local tag = labelTag(label)
  if not text:find(tag, 1, true) then
    text = "<b>" .. tag .. "</b> " .. text
  end
  if extra ~= nil and not text:find(extraMarker or extra, 1, true) then
    text = text .. extra
  end
  return text
end

--- 给一个技能骨架加来源标签；已有 dynamicDesc 时包裹而不是替换。
--- 注意：带 dynamic_desc 的骨架会在 initialize 中把原始函数同时写入
--- `dynamicDesc` 并遮蔽实例的 `getDynamicDescription`；两条取值路径都要包裹，
--- 否则 Fk:getDescription 会绕过标签直接调用原始 dynamic_desc。
--- @param name string
--- @param label string
--- @param extra? string 追加说明，仅用于“旗另带赐消费”这类独立部分
--- @param extraMarker? string 已存在该标记时不再追加
function M.decorate(name, label, extra, extraMarker)
  local skel = Fk.skill_skels[name]
  if skel == nil or skel[MARKER] ~= nil then return end

  local baseDynamic = skel.dynamicDesc
  local baseGet = rawget(skel, "getDynamicDescription")
  skel[MARKER] = label
  skel.dynamicDesc = function(self, player, lang)
    local text = baseDynamic and baseDynamic(self, player, lang)
    return withLabel(self, text, label, extra, extraMarker, lang)
  end
  if type(baseGet) == "function" then
    skel.getDynamicDescription = function(self, player, lang)
      local text = baseGet(self, player, lang)
      return withLabel(self, text, label, extra, extraMarker, lang)
    end
  end
end

--- 在 qiao_generals 的 postLoad 调用；此时所有包已安装，骨架已可查。
--- @param retinues? table Data.retinues（实际声明的翼从技能来源）
function M.register(retinues)
  local translations = {}
  for key, name in pairs(DISPLAY_NAME_SOURCES) do
    local label = Fk:translate(name, "zh_CN")
    translations[key] = label
    local skeleton = Fk.skill_skels[key]
    -- The engine snapshots these names before postLoad. They can also show
    -- up in the trigger-order chooser when two effects can resolve together.
    for _, effect in ipairs(skeleton and skeleton.effect_names or {}) do
      local previous = Fk:translate(effect, "zh_CN")
      if previous == key or previous == effect then translations[effect] = label end
    end
  end
  translations[Formation.FEIYING_MARK] = "飞影来源"
  for name in pairs(Flags.flags) do
    local mark = "@!!" .. name
    translations[mark] = Fk:translate(name, "zh_CN")
    translations[":" .. mark] = Fk:translate(":" .. name, "zh_CN")
  end
  for name, skel in pairs(Fk.skill_skels) do
    if name:startsWith("qiao__") and table.contains(skel.tags, Skill.Limited) then
      local first, second = "$" .. name .. "1", "$" .. name .. "2"
      if Fk:translate(first, "zh_CN") == first and Fk:translate(second, "zh_CN") == second then
        translations[first] = Fk:translate(name, "zh_CN")
      end
    end
  end
  Fk:loadTranslationTable(translations)

  local getDescription = Fk.getDescription
  function Fk:getDescription(name, lang, player)
    local text = getDescription(self, name, lang, player)
    if name == Dying.JISHI_SKILL then
      return Dying.formatJishiDescription(text, self:currentRoom())
    end
    if name == "qiao__skill_jin013_1" then
      return (text:gsub("<富甲→改为雷电伤害>", "&lt;富甲→改为雷电伤害&gt;"))
    end
    return text
  end

  M.decorate(Han.BANNER, LABELS.EDICT)
  M.decorate(Han.CONSUME, LABELS.EDICT)

  M.decorate(Wei.BANNER, LABELS.FLAG)
  M.decorate(Wu.FLAG, LABELS.FLAG)
  M.decorate(Wu.ENTRY, LABELS.FLAG)
  M.decorate(Qun.BANNER_SKILL, LABELS.FLAG)
  -- 黄巾天兵符的第二段入口由旗授予，不是武将牌技能；按钮名保持精简“天兵”。
  M.decorate(Qun.ENTRY, LABELS.FLAG)
  -- 六师率义旗、诸王敕封册没有独立 util 常量；保持与技能文件同名。
  M.decorate(Flags.shuFlag, LABELS.FLAG)
  -- 诸王敕封册本体是旗，另管理“赐”的独立消费；太康等武将技不在此标。
  M.decorate("qiao__skill_em_jin001_banner", LABELS.FLAG,
    "<br/><b>〔赐〕</b> 本技能另有“赐”的消耗入口。", "〔赐〕")

  M.decorate(Commander.ABILITY_SKILL, LABELS.COMMANDER)

  for _, data in ipairs(retinues or {}) do
    local skill = data.skill
    if skill ~= nil then M.decorate(skill.id, LABELS.RETINUE) end
  end
  -- 两个可见的内部派生效果也由翼从产生；不是独立的武将牌技能。
  M.decorate("qiao__retinue_skill_bingzhou_distance", LABELS.RETINUE)
  M.decorate("qiao__retinue_skill_bazhenbing_viewas", LABELS.RETINUE)
end

return M
