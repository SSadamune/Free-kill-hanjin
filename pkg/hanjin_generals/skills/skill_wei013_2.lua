-- WEI013 荀彧 · 节命
--
-- 当你受到1点伤害后，你可以令一名角色摸牌至其体力上限（至多摸至五张）。
-- 以 trigger_times = data.damage 保留引擎对同一次伤害事件的逐点调度：
-- 每一点伤害分别询问发动和选择目标，不把伤害值拆成多次独立伤害事件，也不在
-- 一个 on_use 里循环处理全部点数。补牌目标为 min(体力上限, 5) 张手牌。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei013_2",
}
skill.hanjinImplemented = true

skill:addEffect(fk.Damaged, {
  anim_type = "support",
  trigger_times = function(self, event, target, player, data)
    return data.damage
  end,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local tos = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = room.alive_players,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei013_2-choose",
      cancelable = true,
    })
    local to = tos and tos[1]
    if to == nil then return false end
    event:setCostData(self, { to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self)
    local to = cost and cost.to
    if to == nil or to.dead then return end
    local num = math.min(to.maxHp, 5) - to:getHandcardNum()
    if num > 0 then
      to:drawCards(num, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wei013_2-choose"] = "节命：令一名角色摸牌至其体力上限（至多五张）",
}

return skill
