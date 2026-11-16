-- JIN012 羊徽瑜 · 弘训
--
-- 规则基线：rules/generals/jin012-yanghuiyu.md。
-- 锁定技：与你势力相同的角色的结束阶段，已受伤则摸一张，已横置则重置并
-- 摸一张。两项分别检查，可都执行；重置是定向操作，不调用翻面/连环翻转。
-- 势力相同复用 hegemony 公共比较，合法情况下包含自己。
local B = require "packages.hanjin.pkg.hanjin_generals.util.jin_basic"

local skill = fk.CreateSkill {
  name = "hanjin__skill_jin012_2",
  tags = { Skill.Compulsory },
}

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  -- 触发对象可能是同势力的其他角色，须作为全局触发再由 can_trigger 筛选。
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and not target.dead and not player.dead
      and player:hasSkill(skill.name)
      and data.phase == Player.Finish
      and B.sameKingdom(target, player)
      and (target:isWounded() or target.chained)
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if target.dead or target:isRemoved() then return end
    if target:isWounded() then
      target:drawCards(1, skill.name)
    end
    if not target.dead and not target:isRemoved() and target.chained then
      target:setChainState(false)
      target:drawCards(1, skill.name)
    end
  end,
})

skill.hanjinImplemented = true

return skill
