-- JIN009 司马懿 · 应期
--
-- 规则基线：rules/generals/jin009-simayi.md 引用 rules/generals/wei002-simayi.md，
-- 同名同文。☯️+2 是 2 个半格的配将体力贡献修正，不是两枚可消耗阴阳鱼标记；
-- 开局配将时即确定，不待明置。体力上限只在模式的开局 broadcastGeneral 单点
-- 计算一次；本效果仅登记本局含应期的配将组合，不重算体力，也不触发明置。
-- 升变走 ascension.lua 的公共流程。
local skill = fk.CreateSkill {
  name = "hanjin__skill_jin009_3",
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
