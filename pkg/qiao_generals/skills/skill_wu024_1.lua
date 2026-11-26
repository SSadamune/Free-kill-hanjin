-- WU024 吴国太 · 补益
-- 每回合限一次，与你势力相同的角色脱离濒死时，你可以对来源发起一次“军令”。
-- 若其不执行，该濒死角色回复1点体力。
local H = require "packages.hegemony.util"
local Junling = require "packages.qiao.pkg.qiao_mode.rules.junling"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu024_1",
}
skill.qiaoImplemented = true

skill:addEffect(fk.AfterDying, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    if not RemovedTargets.isPresent(player) or not player:hasSkill(skill.name) then return false end
    if player:usedSkillTimes(skill.name, Player.HistoryTurn) > 0 then return false end
    if target == nil or target.dead or target.hp < 1 or not RemovedTargets.isPresent(target) then
      return false
    end
    if not H.compareKingdomWith(target, player) then return false end
    local source = data and data.damage and data.damage.from
    return source ~= nil and RemovedTargets.isPresent(source)
  end,
  on_cost = function(self, event, target, player, data)
    local source = data.damage.from
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wu024_1-invoke:" .. source.id .. ":" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local source = data and data.damage and data.damage.from
    if player.dead or source == nil or not RemovedTargets.isPresent(source) then return end
    local executed = Junling.ask(player, source, skill.name)
    if not executed and RemovedTargets.isPresent(target) and target:isWounded() then
      room:recover {
        who = target,
        num = 1,
        recoverBy = player,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "补益",
  [":" .. skill.name] = "每回合限一次，与你势力相同的角色脱离濒死时，你可以对来源发起一次“军令”。若其不执行，该濒死角色回复1点体力。",
  ["#qiao__skill_wu024_1-invoke"] = "补益：是否对 %src 发起“军令”？（若不执行，%dest 回复1点体力）",
}

return skill
