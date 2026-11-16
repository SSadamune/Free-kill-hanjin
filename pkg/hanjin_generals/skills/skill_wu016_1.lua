-- WU016 丁奉 · 短兵
--
-- 你使用【杀】可以多指定一名距离1的角色为目标。当你使用【杀】指定距离1
-- 的角色为目标后，此牌需多一张【闪】才能被其抵消。
--
-- 额外目标在多目标声明后加入，目标条件明确为“距离1”，不再叠加原【杀】
-- 的攻击范围条件。额外【闪】按每个目标分别写入 AimData 的响应张数，
-- 因此只影响距离1的目标；多目标【杀】的其他目标仍只需求一张【闪】。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu016_1",
}
skill.hanjinImplemented = true

local function distanceOneCandidates(player, data)
  return table.filter(data:getExtraTargets(), function(p)
    return p:isAlive() and not p:isRemoved() and player:distanceTo(p) == 1
  end)
end

skill:addEffect(fk.AfterCardTargetDeclared, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or data.from ~= player then return false end
    if data.card == nil or data.card.trueName ~= "slash" then return false end
    return #distanceOneCandidates(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local tos = distanceOneCandidates(player, data)
    if #tos == 0 then return false end
    local chosen = player.room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = tos,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu016_1-extra",
      cancelable = true,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return false end
    event:setCostData(self, { to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local to = event:getCostData(self) and event:getCostData(self).to
    if to == nil or not to:isAlive() or to:isRemoved() then return end
    -- 复核仍是本次的额外目标候选：拒绝重复/伪造的过时回复。
    if not table.contains(distanceOneCandidates(player, data), to) then return end
    data:addTarget(to)
  end,
})

-- 与锁定无双相同的接口：TargetSpecified 的事件目标是使用者本人，
-- 具体目标在 data.to；按目标记录所需【闪】数。
skill:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "slash"
      and data.to ~= nil and data.to ~= player
      and player:distanceTo(data.to) == 1
  end,
  -- 原文第二句是必然效果，不是“可以”；默认 trigger cost 会询问发动，这里显式跳过。
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data:setResponseTimes((data:getResponseTimes(data.to) or 1) + 1, data.to)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu016_1"] = "短兵",
  ["#hanjin__skill_wu016_1-extra"] = "短兵：可以额外指定一名距离1的角色为目标",
}

return skill
