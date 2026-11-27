-- WEI022 卞夫人 · 约俭
-- 轮次技，与你势力相同的角色准备阶段，你可令其本回合手牌上限为X（X为其体力上限），
-- 弃牌阶段结束时若其未弃置牌，其摸一张牌。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_wei022_2",
}
skill.qiaoImplemented = true

local YUEJIAN_MARK = "qiao_wei022_yuejian-turn"

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target.phase == Player.Start
      and not target.dead and not target:isRemoved()
      and player:hasSkill(skill.name)
      and player:usedSkillTimes(skill.name, Player.HistoryRound) == 0
      and H.compareKingdomWith(target, player)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wei022_2-invoke::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    room:doIndicate(player.id, { target.id })
    room:setPlayerMark(target, YUEJIAN_MARK, 1)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "约俭",
  [":" .. skill.name] = "轮次技，与你势力相同的角色准备阶段，你可令其本回合手牌上限为X（X为其体力上限），弃牌阶段结束时若其未弃置牌，其摸一张牌。",
  ["#qiao__skill_wei022_2-invoke"] = "约俭：是否令 %dest 本回合手牌上限初值为其体力上限，且弃牌阶段未弃牌则摸一张牌",
}

return skill
