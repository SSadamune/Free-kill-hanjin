-- JIN023 马隆 · 锥形
-- 阵法技：只按真实围攻方向修正【杀】伤害；不按敌友或相邻猜测。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "hanjin__skill_jin023_2",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

skill:addEffect(fk.DamageCaused, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil or player == nil or data == nil or data.card == nil then
      return false
    end
    if player.dead or not player:hasShownSkill(skill.name) then return false end
    if data.card.trueName ~= "slash" or data.to == nil then return false end
    if target == player then
      -- 自己为被围攻者，围攻自己的角色对自己出杀：只有实际围攻方向成立。
      return H.inSiegeRelation(data.to, data.to, player) == true
    elseif data.to == player then
      -- 自己为围攻者，被自己围攻的角色对自己出杀。
      return H.inSiegeRelation(player, player, target) == true
    end
    return false
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local source, victim = target, data.to
    if victim == nil or victim.dead then return end
    if source == player and H.inSiegeRelation(victim, victim, player) then
      data.damage = (data.damage or 0) + 1
    elseif victim == player and H.inSiegeRelation(player, player, source) then
      data.damage = math.max(0, (data.damage or 0) - 1)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_jin023_2"] = "锥形",
  [":hanjin__skill_jin023_2"] =
    "阵法技，若你为围攻角色，被你围攻的角色对你使用【杀】伤害-1；若你为被围攻角色，你对围攻你的角色使用【杀】伤害+1。",
}

return skill
