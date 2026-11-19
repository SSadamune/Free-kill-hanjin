-- WEI011 曹仁 · 励战
--
-- 规则基线：docs/rules/standard-generals.md 魏区 WEI011。
-- 结束阶段，令任意名已受伤的角色各摸一张牌。目标包含自己；至少选择一名
-- 已受伤角色。全部摸牌在同一效果结算内完成。
--
-- 发动确认与选人合并为同一个可取消窗口：选定至少一名合法角色即发动，取消即
-- 不发动；技能使用次数由实际使用（技能使用事件）记录，取消不计次。
local skill = fk.CreateSkill {
  name = "qiao__skill_wei011_2",
}

---@param room Room
---@return ServerPlayer[]
local function woundedPlayers(room)
  return table.filter(room:getPresentPlayers(), function(p)
    return not p:isRemoved() and p:isWounded()
  end)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
      and player.phase == Player.Finish and #woundedPlayers(player.room) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = woundedPlayers(room)
    if #targets == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = #targets,
      targets = targets,
      skill_name = skill.name,
      prompt = "#qiao__skill_wei011_2-target",
      cancelable = true,
    })
    if #chosen == 0 then return false end
    event:setCostData(self, { tos = chosen })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self)
    for _, to in ipairs(cost and cost.tos or {}) do
      if to:isAlive() and not to:isRemoved() then
        to:drawCards(1, skill.name)
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei011_2"] = "励战",
  [":qiao__skill_wei011_2"] = "结束阶段，你可以令任意名已受伤的角色各摸一张牌。",
  ["#qiao__skill_wei011_2-target"] = "励战：选择已受伤的角色",
}

skill.qiaoImplemented = true

return skill
