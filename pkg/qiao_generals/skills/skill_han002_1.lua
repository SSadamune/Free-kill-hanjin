-- HAN002 刘辩 · 诗怨
--
-- 成为其他角色使用牌的目标后，按来源与自己的体力比较两档，每回合各限一次。
-- 两档使用独立的 -turn 标记，由引擎统一清理，武将交换时按技能前缀迁移。
local skill = fk.CreateSkill {
  name = "qiao__skill_han002_1",
}
skill.qiaoImplemented = true

local GREATER_MARK = "qiao__skill_han002_1-greater-turn"
local NOT_GREATER_MARK = "qiao__skill_han002_1-not-greater-turn"

local function drawBranch(source, player)
  if source.hp > player.hp then return GREATER_MARK, 2 end
  return NOT_GREATER_MARK, 1
end

skill:addEffect(fk.TargetConfirmed, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.card == nil or data.from == nil or data.from == player then return false end
    local mark = drawBranch(data.from, player)
    return player:getMark(mark) == 0
  end,
  on_cost = function(self, event, target, player, data)
    local mark, count = drawBranch(data.from, player)
    if not player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_han002_1-invoke:::" .. count,
    }) then return false end
    event:setCostData(self, { mark = mark, count = count })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    room:setPlayerMark(player, cost.mark, 1)
    if not player.dead then
      player:drawCards(cost.count, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_han002_1-invoke"] = "诗怨：你可以摸 %arg 张牌",
}

return skill
