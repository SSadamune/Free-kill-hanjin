-- WU017 蒋钦 · 鸟翔
--
-- 规则依据：rules/generals/wu017-jiangqin.md。阵法技：自己是围攻角色时，
-- 本围攻关系中的围攻角色（可为自己或另一围攻者）使用【杀】指定被围攻角色后，
-- 该角色的响应需求在原有基础上 +1 张【闪】；不固定为2，不限红色【杀】。
-- 围攻关系只经 hegemony public relation 判断。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "hanjin__skill_wu017_2",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

skill:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if target == nil or data == nil or data.card == nil or data.to == nil then
      return false
    end
    return player:hasShownSkill(skill.name)
      and data.card.trueName == "slash"
      and H.inSiegeRelation(target, player, data.to)
  end,
  on_use = function(self, event, target, player, data)
    local to = data.to
    if to == nil or to.dead then return end
    -- 在已有响应次数上追加一张【闪】，不覆盖其他技能已设置的要求。
    data:setResponseTimes(data:getResponseTimes(to) + 1, to)
  end,
})

-- 阵法召唤：汉晋 FAQ 采用出牌阶段限一次；围攻身份/效果不因人数少而失效。
skill:addEffect("arraysummon", {
  array_type = "siege",
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu017_2"] = "鸟翔",
  [":hanjin__skill_wu017_2"] =
    "阵法技，若你是围攻角色，被你围攻的角色需多一张【闪】才能抵消围攻角色的【杀】。",
}

return skill
