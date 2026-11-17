-- HAN022 刘虞 · 安境
--
-- 每回合限一次：与刘虞势力相同的角色受到伤害后，令当时同势力角色各摸一张。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_han022_2",
}
skill.qiaoImplemented = true

skill:addEffect(fk.Damaged, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and not player.dead and player:hasSkill(skill.name)
      and target ~= nil and not target.dead
      and player:usedSkillTimes(skill.name, Player.HistoryTurn) == 0
      and H.compareKingdomWith(player, target)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_han022_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local tos = table.filter(room.alive_players, function(p)
      return p:isAlive() and not p:isRemoved() and H.compareKingdomWith(player, p)
    end)
    room:sortByAction(tos)
    for _, p in ipairs(tos) do
      if p:isAlive() and not p:isRemoved() then p:drawCards(1, skill.name) end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_han022_2"] = "安境",
  [":qiao__skill_han022_2"] = "每回合限一次，与你势力相同的角色受到伤害后，你可以令与你势力相同的角色各摸一张牌。",
  ["#qiao__skill_han022_2-invoke"] = "安境：令同势力角色各摸一张牌",
}

return skill
