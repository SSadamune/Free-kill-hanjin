-- SHU020 沙摩柯 · 蒺藜
-- 当你于一回合内使用或打出第X张牌时，你可以摸X张牌（X为你的攻击范围）。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu020_1",
}
skill.qiaoImplemented = true

--- 统计当前回合内（含本次事件，截止当前事件 ID）沙摩柯累计使用和打出的牌数。
local function turnUseAndRespondCount(room, player)
  local logic = room.logic
  local current = logic:getCurrentEvent()
  if current == nil then return 0 end
  local turn = current:findParent(GameEvent.Turn, true)
  local startId = turn and turn.id or 0
  local limitId = current.id
  local count = 0
  for _, kind in ipairs({ GameEvent.UseCard, GameEvent.RespondCard }) do
    local list = logic.event_recorder[kind] or Util.DummyTable
    for i = #list, 1, -1 do
      local e = list[i]
      if e.id < startId then break end
      if e.id <= limitId and e.data ~= nil and e.data.from == player then
        count = count + 1
      end
    end
  end
  return count
end

local spec = {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player.dead or not player:hasSkill(skill.name) then return false end
    local range = player:getAttackRange()
    if range <= 0 then return false end
    return turnUseAndRespondCount(player.room, player) == range
  end,
  on_cost = function(self, event, target, player, data)
    local x = player:getAttackRange()
    if x <= 0 then return false end
    if player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu020_1-invoke:::" .. tostring(x),
    }) then
      event:setCostData(self, { n = x })
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local n = player:getAttackRange()
    if n > 0 and not player.dead then
      player:drawCards(n, skill.name)
    end
  end,
}

skill:addEffect(fk.CardUsing, spec)
skill:addEffect(fk.CardResponding, spec)

Fk:loadTranslationTable {
  [skill.name] = "蒺藜",
  [":" .. skill.name] = "当你于一回合内使用或打出第X张牌时，你可以摸X张牌（X为你的攻击范围）。",
  ["#qiao__skill_shu020_1-invoke"] = "蒺藜：是否摸 %arg 张牌",
}

return skill
