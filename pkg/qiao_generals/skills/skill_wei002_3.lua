-- WEI002 司马懿 · 应期
--
-- JIN009 司马懿的同名同文应期直接引用本技能 ID，不另设骨架；效果只注册一份，
-- 与武将来源无关。
--
-- 规则基线：docs/rules/generals/wei002-simayi.md 与
-- docs/rules/general-principles.md“配将体力贡献与武将状态”。“☯️+2”是 2 个半格的
-- 配将体力贡献修正，不是两枚可消耗的阴阳鱼标记；条件在开局配将时确定，不等待
-- 明置，也不因明暗置反复生效。通常交换、移除、替换不重算体力上限；升变按其
-- 公共流程重算。体力上限只在模式的开局 broadcastGeneral 单点计算；本技能只提供
-- 牌面与配将计算所需的技能 ID，不注册 GameStart 触发——在这里登记开局效果会让
-- 暗置武将的技能在开局被假触发而预亮。
local skill = fk.CreateSkill {
  name = "qiao__skill_wei002_3",
  tags = { Skill.Compulsory },
}

skill.qiaoImplemented = true
return skill
