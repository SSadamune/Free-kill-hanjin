-- JIN013 王濬 · 乘流
--
-- 规则基线：rules/generals/jin013-wangjun.md、rules/adaptation.md、
-- docs/规则向FAQ文件.md 的“伤害牌”定义。
-- 王濬使用伤害牌时，本次使用获得〈富甲→改为雷电伤害〉。已明置时这是状态效果，
-- 自动赋条目；暗置时由玩家选择明置该武将后发动，走真实 TriggerSkill 流程，
-- 不能仅凭 hasSkill 给未明置技能效果。雷伤标记写在本次 use 上，由独立房间规则
-- 读取，不因本次使用中途失去乘流而撤销。结算后的横置是新的可选技能，按当时
-- 来源判断，且不要求富甲条目已经触发。
local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
local J = require "packages.hanjin.pkg.hanjin_generals.util.jin_adaptation"

local skill = fk.CreateSkill {
  name = "hanjin__skill_jin013_1",
}
skill.hanjinImplemented = true

local ENTRY_ID = "hanjin__skill_jin013_1_thunder"
local RULE_SKILL = "hanjin__jin_adaptation_rule"

local function ensureDamageRule(room)
  if room == nil or room:hasSkill(RULE_SKILL) then return end
  local rule = Fk.skills[RULE_SKILL]
  if rule ~= nil then room:addSkill(rule) end
end

local function isRevealedSkill(player)
  local actual = Fk.skills[skill.name]
  return actual == nil or not player:isFakeSkill(actual)
end

skill:addEffect(fk.PreCardUse, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and J.isDamageCard(data.card)
  end,
  on_cost = function(self, event, target, player, data)
    if isRevealedSkill(player) then return true end
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_jin013_1-reveal",
    })
  end,
  on_use = function(self, event, target, player, data)
    for _, entry in ipairs(A.getEntries(data.card, data)) do
      if entry.id == ENTRY_ID then return end
    end
    A.addEntry(data, {
      id = ENTRY_ID,
      condition = "fujia",
      effect = "thunder_damage",
    })
    ensureDamageRule(player.room)
  end,
})

skill:addEffect(fk.CardUseFinished, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and J.isDamageCard(data.card) and J.dealtDamage(data)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_jin013_1-turn-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local victims = {}
    for victim, num in pairs(data.damageDealt or {}) do
      if num > 0 and victim:isAlive() and not victim:isRemoved() and not victim.chained then
        table.insert(victims, victim)
      end
    end
    if #victims == 0 then return end
    room:sortByAction(victims)
    local chosen = room:askToChoosePlayers(player, {
      min_num = 0,
      max_num = #victims,
      targets = victims,
      skill_name = skill.name,
      prompt = "#hanjin__skill_jin013_1-turn",
      cancelable = true,
    })
    for _, victim in ipairs(chosen or {}) do
      if victim:isAlive() and not victim:isRemoved() and not victim.chained then
        victim:setChainState(true)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_jin013_1"] = "乘流",
  ["#hanjin__skill_jin013_1-reveal"] = "乘流：是否明置并提供此伤害牌的〈富甲→改为雷电伤害〉？",
  ["#hanjin__skill_jin013_1-turn-invoke"] = "乘流：你可以横置任意名受到此牌伤害的角色",
  ["#hanjin__skill_jin013_1-turn"] = "乘流：选择横置的实际受伤角色",
}

return skill
