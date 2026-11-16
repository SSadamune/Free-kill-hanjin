-- WU020 徐盛·疑城的回合末独立弃牌记录。
local skill = fk.CreateSkill { name = "hanjin__wu020_yicheng_rule" }
local PENDING = "hanjin_wu020_yicheng_pending"

local function turnId(room)
  local current = room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  return turn and turn.id or 0
end

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player)
    return player ~= nil and #(player.room:getTag(PENDING) or {}) > 0
  end,
  on_refresh = function(self, event, target, player)
    local room = player.room
    local turn, list = turnId(room), room:getTag(PENDING) or {}
    local rest = {}
    room:setTag(PENDING, {})
    for _, entry in ipairs(list) do
      if entry.turn ~= turn then
        table.insert(rest, entry)
      else
        local to = room:getPlayerById(entry.target)
        if to ~= nil and to:isAlive() and not to:isRemoved() then
          room:askToDiscard(to, {
            min_num = 1, max_num = 1, include_equip = true,
            skill_name = skill.name, cancelable = false,
            prompt = "#hanjin__skill_wu020_1-discard",
          })
        end
      end
    end
    if #rest > 0 then room:setTag(PENDING, rest) end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__wu020_yicheng_rule"] = "疑城回合末弃牌",
  ["#hanjin__skill_wu020_1-discard"] = "疑城：回合结束弃置一张牌",
}

return skill
