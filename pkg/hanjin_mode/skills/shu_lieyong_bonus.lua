-- 烈勇已建立的“本次【杀】对某目标伤害+1”持续结算。
-- 模式级无条件记录：不依赖烈勇是否仍在，也不消费一次性标记；仅匹配该次
-- 使用、该来源、该目标、同一张牌造成的伤害，避免给嵌套的其他伤害加成。
local skill = fk.CreateSkill { name = "hanjin__shu_lieyong_bonus" }

local DMG = "hanjin__skill_shu008_1_damage"

skill:addEffect(fk.DamageCaused, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if player ~= data.from or data.card == nil or data.to == nil then return false end
    local current = player.room.logic:getCurrentEvent()
    local useEvent = current and current:findParent(GameEvent.UseCard, true)
    local use = useEvent and useEvent.data
    return use ~= nil and type(use[DMG]) == "table"
      and use[DMG][data.to.id] == true
      and data.card == use.card and data.from == use.from
  end,
  on_refresh = function(self, event, target, player, data)
    data.damage = data.damage + 1
  end,
})

return skill
