-- SHU005 赵云 · 突阵
--
-- 规则基线：rules/standard-generals.md 蜀区 SHU005。
-- 当你对其他角色使用的红色牌被其抵消后，你可以对另一名其他角色造成1点伤害。
-- “被其抵消”限定为牌的目标本人实际抵消；其他角色用【无懈可击】抵消不属于
-- “其”抵消，不触发。伤害目标排除自己与抵消者。
local S = require "packages.hanjin.pkg.hanjin_generals.util.cancel_source"

local skill = fk.CreateSkill {
  name = "hanjin__skill_shu005_2",
}
skill.hanjinImplemented = true

skill:addEffect(fk.CardEffectCancelledOut, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) or data.card == nil then return false end
    -- 延时锦囊由目标抵消时可能没有本次 UseCard 数据，回落到效果来源。
    local user = data.use and data.use.from or data.from
    if user ~= player or data.to == nil or data.to == player then return false end
    if data.card.color ~= Card.Red then return false end
    local by = S.canceller(player.room, data)
    if by == nil or by ~= data.to then return false end
    return table.find(player.room.alive_players, function(p)
      return p ~= player and p ~= data.to and not p:isRemoved()
    end) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_shu005_2-invoke",
    }) then
      return false
    end
    local candidates = table.filter(room.alive_players, function(p)
      return p ~= player and p ~= data.to and not p:isRemoved()
    end)
    if #candidates == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = candidates,
      skill_name = skill.name,
      prompt = "#hanjin__skill_shu005_2-target",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return false end
    event:setCostData(self, { to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local to = (event:getCostData(self) or {}).to
    if to == nil or to.dead or to:isRemoved() or player.dead then return end
    player.room:damage {
      from = player,
      to = to,
      damage = 1,
      skillName = skill.name,
    }
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_shu005_2"] = "突阵",
  [":hanjin__skill_shu005_2"] = "当你对其他角色使用的红色牌被其抵消后，你可以对另一名其他角色造成1点伤害。",
  ["#hanjin__skill_shu005_2-invoke"] = "突阵：你可以对另一名其他角色造成1点伤害",
  ["#hanjin__skill_shu005_2-target"] = "突阵：选择一名其他角色（不含抵消者）",
}

return skill
