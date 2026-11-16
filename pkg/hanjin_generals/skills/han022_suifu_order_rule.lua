-- HAN022 刘虞·绥抚的本次五谷结算顺序。
-- 只在 `BeforeCardUseEffect` 重排实际效果循环，不提前/伪造目标时机；
-- marker 由本次绥抚 use.extra_data 携带，普通五谷不受影响。
local ORDER = "hanjin_han022_suifu_order"

local function rotate(tos, start)
  local index
  for i, p in ipairs(tos) do
    if p == start then index = i break end
  end
  if index == nil or index == 1 then return table.simpleClone(tos) end
  local result = {}
  for i = index, #tos do table.insert(result, tos[i]) end
  for i = 1, index - 1 do table.insert(result, tos[i]) end
  return result
end

local skill = fk.CreateSkill { name = "hanjin__han022_suifu_order_rule" }

skill:addEffect(fk.BeforeCardUseEffect, {
  global = true,
  is_delay_effect = true,
  can_refresh = function(self, event, target, player, data)
    local marker = data and data.extra_data and data.extra_data[ORDER]
    return type(marker) == "table" and not marker.used
      and data.card ~= nil and data.card.name == "hanjin__amazing_grace"
  end,
  on_refresh = function(self, event, target, player, data)
    local marker = data.extra_data[ORDER]
    marker.used = true
    local room = data.from and data.from.room
    local start = room and room:getPlayerById(marker.start_id or 0)
    if start == nil or not table.contains(data.tos, start) then return end
    local tos = rotate(data.tos, start)
    local subTos = {}
    for i, p in ipairs(tos) do
      local oldIndex = table.indexOf(data.tos, p)
      subTos[i] = data.subTos and oldIndex and data.subTos[oldIndex] or {}
    end
    data.tos = tos
    data.subTos = subTos
  end,
})

return skill
