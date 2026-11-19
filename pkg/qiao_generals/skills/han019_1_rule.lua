-- HAN019 吉平·烈医的已建立防伤状态。
-- 只有烈医实际回复成功后写入记录；规则本身全局监听，但无记录时绝不防伤。
local TAG = "qiao_han019_1_prevent"

local function turnId(room)
  local current = room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  return turn and turn.id or 0
end

local skill = fk.CreateSkill { name = "qiao__han019_1_rule" }

skill:addEffect(fk.DamageCaused, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player or data == nil or data.from ~= player then return false end
    local rec = player.room:getTag(TAG)
    return rec ~= nil and rec.player == player.id and rec.turn == turnId(player.room)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    data:preventDamage()
  end,
})

return skill
