-- HAN002 刘辩 · 诗怨
--
-- 成为其他角色使用牌的目标后，按来源与自己的体力比较两档，每回合各限一次。
-- 两档使用独立的本回合标记；每个回合开始时清除。来源体力在触发时锁定比较。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han002_1",
}
skill.hanjinImplemented = true

local GREATER_MARK = "hanjin__skill_han002_1-greater-turn"
local NOT_GREATER_MARK = "hanjin__skill_han002_1-not-greater-turn"

-- 每回合开始时用 refresh 逐个清除持有者的两档标记；不通过 on_use
-- 对每名角色重复触发。`技能名-...` 命名使武将交换时由 Exchange 自动携带。
skill:addEffect(fk.TurnStart, {
  global = true,
  mute = true,
  can_refresh = function(self, event, target, player)
    return player.room ~= nil
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    room:setPlayerMark(player, GREATER_MARK, 0)
    room:setPlayerMark(player, NOT_GREATER_MARK, 0)
  end,
})

skill:addEffect(fk.TargetConfirmed, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.card == nil or data.from == nil or data.from == player then return false end
    local mark = data.from.hp > player.hp and GREATER_MARK or NOT_GREATER_MARK
    return player:getMark(mark) == 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han002_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local greater = data.from.hp > player.hp
    local mark = greater and GREATER_MARK or NOT_GREATER_MARK
    room:setPlayerMark(player, mark, 1)
    if not player.dead then
      player:drawCards(greater and 2 or 1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han002_1-invoke"] = "诗怨：你可以发动诗怨",
}

return skill
