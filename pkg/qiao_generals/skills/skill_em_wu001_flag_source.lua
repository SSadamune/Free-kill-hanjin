-- EM(WU001) 缘江烽火图的独立授技来源。
-- 只作为准备阶段临时技能的来源记账；旗消失、烽火减少都不连带撤销已建立
-- 的本次授予，到期时只按这一来源移除。
local skill = fk.CreateSkill {
  name = "qiao__skill_em_wu001_flag_source",
}

return skill
