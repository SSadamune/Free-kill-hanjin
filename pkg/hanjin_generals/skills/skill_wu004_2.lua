-- WU004 黄盖 · 诈降
--
-- 锁定技，当你失去体力后：摸三张牌，本回合使用【杀】的次数 +1，且使用红色
-- 【杀】无距离限制。每失去一次体力累计一层次数；效果由预注册的静态模式技能
-- `hanjin__wu_turn_effects` 读取公开标记，失去诈降后已建立的回合效果仍生效。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu004_2",
  tags = { Skill.Compulsory },
}
skill.hanjinImplemented = true

local TURN_EFFECTS = "hanjin__wu_turn_effects"
local ZHAXIANG_TIMES = "hanjin_wu004_zhaxiang_times-turn"

local function ensureTurnEffects(room)
  if room == nil then return end
  if not room:hasSkill(TURN_EFFECTS) then
    room:addSkill(TURN_EFFECTS)
  end
end

skill:addEffect(fk.HpLost, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and not player.dead
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    ensureTurnEffects(room)
    room:addPlayerMark(player, ZHAXIANG_TIMES, 1)
    player:drawCards(3, skill.name)
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureTurnEffects(player.room or Fk:currentRoom())
end)

Fk:loadTranslationTable {
  ["hanjin__skill_wu004_2"] = "诈降",
  [":hanjin__skill_wu004_2"] = "锁定技，当你失去体力后，你摸三张牌，本回合你使用【杀】的次数+1且使用红色【杀】无距离限制。",
}

return skill
