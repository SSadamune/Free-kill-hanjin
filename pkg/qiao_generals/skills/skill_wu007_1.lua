-- WU007 陆逊 · 谦逊
--
-- 锁定技，你每回合首次成为锦囊牌的目标时，若此牌有未指定的合法目标，
-- 取消之。
--
-- “取消之”取消的是当前目标（不是整张牌）；“有未指定的合法目标”要求除
-- 当前目标外，仍存在按牌面条件合法、且尚未在本次目标列表中的角色。因此
-- 群体锦囊已指定所有合法目标时不会取消。首次事实由房间在成为目标时记录。
local TrickTargets = require "packages.qiao.pkg.qiao_mode.rules.trick_targets"
local skill = fk.CreateSkill {
  name = "qiao__skill_wu007_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

skill:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and data.qiao_first_trick_target and not data.cancelled
      and player:hasSkill(skill.name) and TrickTargets.hasUnspecifiedLegalTarget(player, data)
  end,
  on_use = function(self, event, target, player, data)
    data:cancelCurrentTarget()
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu007_1"] = "谦逊",
}

return skill
