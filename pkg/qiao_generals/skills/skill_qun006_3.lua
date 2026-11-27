-- QUN006 董卓 · 崩坏
--
-- 结束阶段体力值不为最小时，选择减体力上限或失去体力。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun006_3",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local LOSE_HP = "qiao__skill_qun006_3-lose-hp"
local LOSE_MAX = "qiao__skill_qun006_3-lose-max"

---@param player ServerPlayer
---@return boolean
local function notMinimumHp(player)
  local min = math.huge
  for _, p in ipairs(player.room:getPresentPlayers()) do
    if p:isAlive() and not p:isRemoved() then min = math.min(min, p.hp) end
  end
  return min < math.huge and player.hp > min
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "negative",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.phase == Player.Finish and notMinimumHp(player)
  end,
  on_cost = function(self, event, target, player, data)
    local choice = Selection.askOption(player.room, player, {
      choices = { LOSE_MAX, LOSE_HP },
      skill_name = skill.name,
      prompt = "#qiao__skill_qun006_3-choice",
      cancelable = false,
    })
    if not choice then return false end
    event:setCostData(self, { choice = choice })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = (event:getCostData(self) or {}).choice
    if choice == LOSE_MAX then
      room:changeMaxHp(player, -1)
    elseif choice == LOSE_HP then
      room:loseHp(player, 1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun006_3"] = "崩坏",
  [":qiao__skill_qun006_3"] = "锁定技，结束阶段，若你的体力值不为最小，你减1点体力上限或失去1点体力。",
  ["#qiao__skill_qun006_3-choice"] = "崩坏：选择一项",
  [LOSE_HP] = "失去1点体力",
  [LOSE_MAX] = "减1点体力上限",
}

return skill
