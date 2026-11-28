local Heg = require "packages.hegemony.util"
local Exchange = require "packages.qiao.pkg.qiao_mode.rules.general_exchange"

local M = {}

local playStages = {
  qiao__skill_han007_1 = "draw", -- 敏思
  qiao__skill_wu001_1 = "draw", -- 制衡
  qiao__luminous_pearl_skill = "draw",
  qiao__skill_qun001_2 = "disrupt", -- 除疠
  qiao__skill_wu006_1 = { disrupt = true, delayed = true }, -- 国色
  qiao__skill_wu004_1 = "draw", -- 苦肉与诈降
  qiao__skill_qun013_2 = "draw", -- 雄异
  qiao__retinue_skill_lujiang_shangjia = { draw = true, attack_prep = true },
  qiao__skill_wu008_1 = "support", -- 结姻
  qiao__skill_wu015a_1 = "support", -- 直谏
  qiao__skill_jin013_2 = "disrupt", -- 克清
  qiao__skill_qun018_1 = "disrupt", -- 祸水
  qiao__skill_wu012_1 = "attack_prep", -- 天义
  qiao__skill_wei012_1 = "damage", -- 强袭
  qiao__skill_wei013_1 = "damage", -- 驱虎
  qiao__skill_han013_1 = "attack_prep", -- 奋钺
  qiao__skill_qun007_2 = "damage", -- 乱武
  qiao__retinue_skill_qingzhou_jingrui = "damage",
  qiao__skill_shu001_1 = "support", -- 仁德
  qiao__skill_shu012_1 = "disrupt", -- 挑衅
  qiao__skill_qun003_1 = "damage", -- 离间
  qiao__skill_jin006_1 = "draw", -- 三陈
  qiao__skill_jin016_2 = "last", -- 风物
  qiao__skill_shu010_1_recast = "recast",
  qiao__skill_jin011_1 = "disrupt", -- 果毅
  qiao__skill_em_qun010_3 = "setup", -- 问道
  qiao__skill_qun021_1 = "disrupt", -- 庸肆
  qiao__skill_shu022_1 = "damage",
  qiao__skill_jin018_2 = "disrupt",
  qiao__retinue_skill_feixiongjun = "damage",
  qiao__skill_wei020_1 = "draw",
  qiao__skill_wei021b_1 = "disrupt",
  qiao__skill_wei021b_2 = "last",
  qiao__skill_shu023_1 = "draw",
  qiao__skill_qun022a_1 = "draw",
  qiao__skill_jin020_2 = "last",
  qiao__skill_wu021_2 = "disrupt",
  qiao__skill_wu024_2 = "disrupt",
  qiao__skill_em_wei001_2 = "draw",
  qiao__skill_wei035_1 = "disrupt",
  qiao__skill_han051_1 = "disrupt",
  qiao__skill_qun033_2 = "support",
  qiao__skill_shu091_1 = "last",
  ["qiao__chuming_other&"] = "disrupt",
  qiao__skill_em_han001_banner = "last",
  qiao__skill_qun139_2 = "last",
  qiao__skill_wu028_1 = "attack_prep",
  qiao__skill_wu028_2 = "draw",
  qiao__skill_wu048_1 = "disrupt",
  qiao__retinue_skill_jiefanwei = "support",
  qiao__skill_em_jin001_consume = { draw = true, last = true },
}

function M.playsAt(name, stage)
  local assigned = playStages[name]
  return assigned == stage or (type(assigned) == "table" and assigned[stage])
end

local longdan, wuku, xiewei = "qiao__skill_shu005_1", "qiao__skill_jin006_3", "qiao__skill_qun139_1"
M.viewAs = {
  slash = { "qiao__skill_shu002_1", longdan, wuku, xiewei, "qiao__skill_shu054_1", "qiao_battle_royal&" },
  dismantlement = { "qiao__skill_wu002_1" }, -- 奇袭
  supply_shortage = { "qiao__skill_wei010_1" },
  jink = { "qiao__skill_wei007_1", longdan, wuku, xiewei, "qiao_battle_royal&" },
  peach = { longdan, "qiao__skill_qun001_1", wuku },
  nullification = { "qiao__skill_shu011_3", "qiao__retinue_skill_bazhenbing_viewas", wuku },
  iron_chain = { "qiao__skill_shu010_1" },
  fire_attack = { "qiao__skill_shu011_2" },
  duel = { "qiao__qun_cards_state", wuku },
  unexpectation = { "qiao__skill_jin006_2", wuku },
}

M.pindian = {
  "qiao__skill_han008_1", "qiao__skill_han010_1", "qiao__skill_han013_1", "qiao__skill_han017_1",
  "qiao__skill_han017_2", "qiao__skill_jin008_2", "qiao__skill_qun015_1", "qiao__skill_shu015_2",
  "qiao__skill_wei013_1", "qiao__skill_wu010_2", "qiao__skill_wu012_1", "qiao__skill_wu012_2",
}

M.retrial = {
  qiao__skill_wei002_2 = "hand", -- 鹰视
  qiao__skill_qun010_2 = "black_hand_or_equip", -- 鬼道
}

-- These skills change the engine's Slash allowance. The AI queries the native
-- target modifiers to account for their current marks and target restrictions.
M.extraSlash = {
  "qiao__skill_shu003_1", "qiao__skill_wu012_1", "qiao__skill_wu004_2", "#crossbow_skill",
}

M.ignoreSlashArmor = { "#qinggang_sword_skill" }
M.extraJink = {
  qiao__skill_qun002_1 = true,
  qiao__skill_wu016_1 = true,
  qiao__skill_wu017_2 = true,
}

local function hasGeneral(target, deputy)
  local name = Exchange.publicGeneral(target, deputy)
  return name == "anjiang" or (Fk.generals[name] ~= nil and not Exchange.isSoldier(name))
end

-- Evaluate only information available to the attacker before choosing a target.
M.forceSlashHit = {
  qiao__skill_qun002_1 = Util.TrueFunc, -- 无双
  qiao__skill_wu016_1 = function(source, target) return source:distanceTo(target) == 1 end, -- 短兵
  qiao__skill_wu017_2 = function(source, target) -- 鸟翔
    return source:hasShownSkill("qiao__skill_wu017_2") and Heg.inSiegeRelation(source, source, target)
  end,
  qiao__skill_shu006_2 = function(_, target) -- 铁骑
    return hasGeneral(target, false) or hasGeneral(target, true)
  end,
  qiao__skill_shu008_1 = function(source, target) -- 烈勇
    return target:getHandcardNum() <= source:getHandcardNum() or target.hp >= source.hp
  end,
  qiao__skill_qun008_2 = function(_, target) -- 猛撼
    return table.find(target:getCardIds("e"), function(id) return not target:prohibitDiscard(id) end) ~= nil
  end,
  qiao__skill_shu036_1 = function(_, target) -- 越险
    return not target:isWounded() or target:getHandcardNum() >= 2
  end,
  qiao__chixiao_sword_skill = function(source, target)
    return (Heg.isBigKingdomPlayer(source) and Heg.isSmallKingdomPlayer(target))
      or (Heg.isSmallKingdomPlayer(source) and Heg.isBigKingdomPlayer(target))
  end,
}

return M
