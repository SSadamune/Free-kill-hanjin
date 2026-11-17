-- 庐江上甲的“本阶段使用【杀】次数+1”独立静态规则。
--
-- 该加成是实际弃牌后建立的阶段状态，翼从技能失去后仍然有效；因此不能写在
-- 庐江技能骨架的关联 targetmod 里（失去主技能会连带清 derivative_skills，
-- 且原 targetmod 还会检查 player:hasSkill）。本规则只读取公开的
-- -phase 标记，不检查翼从技能是否仍在。
--
-- 安装方式：zhen_shi_retinues.ensureBonusRule(room) 把本状态技加入当前房间，
-- 不改全局技能表、不跨模式挂载；正式入口后续接入。
local skill = fk.CreateSkill {
  name = "qiao__zhen_shi_retinue_bonus",
}

local SLASH_BONUS = "qiao_lujiang_shangjia_slash_bonus-phase"

skill:addEffect("targetmod", {
  residue_func = function(self, player, card_skill, scope, card)
    if scope == Player.HistoryPhase and card ~= nil and card.trueName == "slash" then
      return player:getMark(SLASH_BONUS)
    end
  end,
})

return skill
