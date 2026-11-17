-- QUN002 吕布 · 无双
--
-- 规则基线：rules/standard-generals.md 群区 QUN002、
-- rules/generals/qun002-lvbu.md。
-- 「多一张」按当前响应张数累加，不写死为 2；短兵等其他增量先写入时仍在
-- 其基础上 +1。已写入某次用牌的数量不因随后暗置、失技而撤销（AimData 保存）。
local skill = fk.CreateSkill {
  name = "qiao__skill_qun002_1",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local function addOne(data, target)
  if target == nil then return end
  data:setResponseTimes((data:getResponseTimes(target) or 1) + 1, target)
end

-- 使用【杀】指定目标后：该目标需多一张【闪】。
skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "slash"
      and data.to ~= nil and data.to ~= player
  end,
  on_use = function(self, event, target, player, data)
    addOne(data, data.to)
  end,
})

-- 使用【决斗】指定目标后：对方（目标）每次需多打出一张【杀】。
skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "duel"
      and data.to ~= nil and data.to ~= player
  end,
  on_use = function(self, event, target, player, data)
    addOne(data, data.to)
  end,
})

-- 成为【决斗】的目标后：对方（使用者）每次需多打出一张【杀】。
skill:addEffect(fk.TargetConfirmed, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "duel"
      and data.from ~= nil and data.from ~= player
  end,
  on_use = function(self, event, target, player, data)
    addOne(data, data.from)
  end,
})

return skill
