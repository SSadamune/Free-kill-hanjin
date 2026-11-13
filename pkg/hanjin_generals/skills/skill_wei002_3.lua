-- WEI002 司马懿 · 应期
--
-- 规则基线：rules/generals/wei002-simayi.md 与
-- rules/general-principles.md“配将体力贡献与武将状态”。“☯️+2”是 2 个半格的
-- 配将体力贡献修正，不是两枚可消耗的阴阳鱼标记；条件在开局配将时确定，不等待
-- 明置，也不因明暗置反复生效。通常交换、移除、替换不重算体力上限；升变按其
-- 公共流程重算。体力上限只在模式的开局 broadcastGeneral 单点计算；本效果仅登记
-- 本局含应期的配将组合，不重算体力，也不触发明置。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei002_3",
  tags = { Skill.Compulsory },
}

--- 模式模块在国战将包之后初始化，武将骨架加载时不能提前 require。
local function pairHp()
  return require "packages.hanjin.pkg.hanjin_mode.rules.pair_hp"
end

skill:addEffect(fk.GameStart, {
  priority = 100,
  can_trigger = function(self, event, target, player)
    if not player:hasSkill(skill.name) then return false end
    local P = pairHp()
    return P.yinyang(P.actual_main(player), P.actual_deputy(player)) > 0
  end,
  on_trigger = function(self, event, target, player)
    pairHp().register_start(player.room, player)
  end,
})

skill.hanjinImplemented = true
return skill
