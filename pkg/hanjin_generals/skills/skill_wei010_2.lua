-- WEI010 徐晃 · 长驱
--
-- 规则基线：rules/standard-generals.md WEI010。锁定技：你对本回合未受到过你
-- 伤害的角色使用牌无距离限制。
-- “本回合受到过你伤害”由模式级全局记录器写入同步玩家标记（见
-- rules/wei_history.lua 与 skills/wei_damage_history.lua），客户端与服务器
-- 读同一份公开数据；本技能只按该集合 bypass 使用牌距离，不修改距离本身。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei010_2",
  tags = { Skill.Compulsory },
}

local H = require "packages.hanjin.pkg.hanjin_mode.rules.wei_history"

skill:addEffect("targetmod", {
  bypass_distances = function(self, player, skill_, card, to)
    if player == nil or to == nil or not player:hasSkill(skill.name) then return false end
    return not H.damaged(player, to.id)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei010_2"] = "长驱",
  [":hanjin__skill_wei010_2"] = "锁定技，你对本回合未受到过你伤害的角色使用牌无距离限制。",
}

skill.hanjinImplemented = true
return skill
