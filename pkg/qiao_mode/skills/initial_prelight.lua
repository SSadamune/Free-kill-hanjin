local skill = fk.CreateSkill { name = "#qiao_initial_prelight" }
local duration = 3000

skill:addEffect(fk.AfterDrawInitialCards, {
  late_refresh = true,
  can_refresh = function(self, event, target, player)
    if player.seat ~= 1 then return false end
    local current = player.room.logic:getCurrentEvent()
    local draw = current and current:findParent(GameEvent.DrawInitial, true)
    return draw ~= nil and target == draw.data.who[#draw.data.who]
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    -- 独立房间通知只负责显示，预亮仍走引擎的原生 PushRequest。
    room:doBroadcastNotify("QiaoInitialPrelight", { duration })
    room:delay(duration)
  end,
})

Fk:loadTranslationTable {
  ["qiao_initial_prelight"] = "调整技能预亮",
}

return skill
