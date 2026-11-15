-- QUN007 贾诩 · 完杀
--
-- 规则基线：rules/standard-generals.md QUN007 技能原文。
-- 其他角色于贾诩回合内进入濒死时，除濒死角色外的角色于本次濒死结算中不能
-- 对其使用【桃】；贾诩本人也无豁免。限定只针对本次濒死，不沿用旧版“除你
-- 以外”的贾诩豁免。
--
-- 本技能只负责在时机成立时设置标记；禁止效果与结束清理放在模式级独立来源
-- qun_dying_rule，避免贾诩在濒死中失技/死亡后限制消失或残留。
local Q = require "packages.hanjin.pkg.hanjin_generals.util.qun_dying"

local skill = fk.CreateSkill {
  name = "hanjin__skill_qun007_1",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

skill:addEffect(fk.EnterDying, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target ~= player and not target.dead
      and not player.dead and player:hasSkill(skill.name)
      and player.room:getCurrent() == player
  end,
  -- 锁定技必然触发，不能走默认的发动询问。
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    player.room:setPlayerMark(target, Q.WANSHA_MARK, 1)
  end,
})

return skill
