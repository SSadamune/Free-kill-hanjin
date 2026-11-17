-- QUN006 董卓 · 崩坏
--
-- 锁定技：结束阶段，若自己的体力值不为最小（并列最小不触发），选择一至两项：
-- 失去1点体力、减1点体力上限；选择两项时执行一个额外摸牌阶段。
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
  for _, p in ipairs(player.room.alive_players) do
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
    local picked = player.room:askToChoices(player, {
      choices = { LOSE_HP, LOSE_MAX },
      min_num = 1,
      max_num = 2,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun006_3-choice",
      cancelable = false,
    })
    if picked == nil or #picked == 0 then return false end
    event:setCostData(self, { picked = picked })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local picked = (event:getCostData(self) or {}).picked or {}
    local loseHp = table.contains(picked, LOSE_HP)
    local loseMax = table.contains(picked, LOSE_MAX)
    if loseHp then room:loseHp(player, 1, skill.name) end
    if loseMax and not player.dead then room:changeMaxHp(player, -1) end
    if loseHp and loseMax and not player.dead then
      player:gainAnExtraPhase(Player.Draw, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun006_3"] = "崩坏",
  [":qiao__skill_qun006_3"] = "锁定技，结束阶段，若你的体力值不为最小，你选择一至两项：1.失去1点体力；2.减1点体力上限。若你选择两项，你执行一个额外摸牌阶段。",
  ["#qiao__skill_qun006_3-choice"] = "崩坏：选择一至两项",
  [LOSE_HP] = "失去1点体力",
  [LOSE_MAX] = "减1点体力上限",
}

return skill
