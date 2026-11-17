-- QUN012 蔡文姬 · 断肠
--
-- 锁定技，你死亡时，你令来源失去一张武将牌的技能。
-- 规则基线：docs/rules/standard-generals.md QUN012、
-- rulebook/topics/skill-effect-classification.md（已建立的延时效果不撤销）。
-- 来源选择、按牌失技与永久记录见 packages.qiao.pkg.qiao_mode.rules.qun_duanchang；
-- 该模块还向 general_exchange 注册来源过滤器，交换不会复原技能。
local Q = require "packages.qiao.pkg.qiao_mode.rules.qun_duanchang"

local skill = fk.CreateSkill {
  name = Q.SKILL,
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

skill:addEffect(fk.Death, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    -- 死亡已置 dead；技能本身用 ignoreAlive 检查，来源缺失/已死亡时不处理。
    return target == player
      and Q.ownerHasSkill(player)
      and Q.canUse(player, data)
  end,
  on_use = function(self, event, target, player, data)
    Q.resolve(player.room, player, data.killer)
  end,
})

Fk:loadTranslationTable {
  [Q.SKILL] = "断肠",
  [":" .. Q.SKILL] = "锁定技，你死亡时，你令来源失去一张武将牌的技能。",
  ["#" .. Q.SKILL .. "-ask"] = "断肠：令 %dest 失去一张武将牌的技能",
}

return skill
