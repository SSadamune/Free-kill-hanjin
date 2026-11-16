-- WU012 太史慈 · 翼从曲阿小将
--
-- 每回合限一次：当你使用牌后，若此牌目标与你本回合上一张使用牌的目标不完全
-- 相同，可以对这两张牌的重合目标各造成1点伤害。
-- “上一张使用牌”取服务器真实 UseCard 声明事件历史中、当前使用之前最后一次
-- 由该角色发起的 UseCard；不依赖技能持有期间自行记录，因此同回合获得技能前
-- 的使用也能找到；按事件 id 而非结算完成顺序判断，嵌套用牌不会误认相邻。
local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_quaxiaojiang",
}
skill.hanjinImplemented = true

local USED_MARK = "hanjin_quaxiao_used-turn"

local function targetIds(data)
  local ids = {}
  for _, p in ipairs(data and data.tos or {}) do
    if p ~= nil and not table.contains(ids, p.id) then table.insert(ids, p.id) end
  end
  return ids
end

local function sameTargets(a, b)
  if #a ~= #b then return false end
  local count = {}
  for _, id in ipairs(a) do count[id] = (count[id] or 0) + 1 end
  for _, id in ipairs(b) do
    if (count[id] or 0) <= 0 then return false end
    count[id] = count[id] - 1
  end
  return true
end

local function overlapTargets(room, a, b)
  local result = {}
  for _, id in ipairs(a) do
    local p = room:getPlayerById(id)
    if p ~= nil and p:isAlive() and table.contains(b, id) then
      table.insert(result, p)
    end
  end
  return result
end

--- 当前 UseCard 之前、该角色最后一次真实 UseCard 声明数据。
---@param player ServerPlayer
---@return UseCardData?
local function previousUse(player, currentData)
  local logic = player.room.logic
  local events = logic and logic.event_recorder[GameEvent.UseCard] or {}
  -- 当前本次 UseCard 已写入 recorder；按数据对象排除它，再取该角色更早一条。
  for i = #events, 1, -1 do
    local event = events[i]
    if event.data ~= nil and event.data ~= currentData
      and event.data.from == player then
      return event.data
    end
  end
end

skill:addEffect(fk.CardUseFinished, {
  anim_type = "offensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player == nil or player.dead or not player:hasSkill(skill.name) then
      return false
    end
    if player:getMark(USED_MARK) > 0 then return false end
    local prev = previousUse(player, data)
    if prev == nil then return false end
    local old, current = targetIds(prev), targetIds(data)
    if sameTargets(old, current) then return false end
    return #overlapTargets(player.room, old, current) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_quaxiaojiang-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local prev = previousUse(player, data)
    if prev == nil then return end
    local tos = overlapTargets(room, targetIds(prev), targetIds(data))
    if #tos == 0 then return end
    room:addPlayerMark(player, USED_MARK, 1)
    for _, p in ipairs(tos) do
      if p:isAlive() and not p.dead and not player.dead then
        room:damage {
          from = player,
          to = p,
          damage = 1,
          skillName = skill.name,
        }
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_quaxiaojiang"] = "曲阿小将",
  [":hanjin__retinue_skill_quaxiaojiang"] = "每回合限一次，当你使用牌后，若此牌目标与你本回合上一张使用牌的目标不完全相同，你可以对这两张牌的重合目标各造成1点伤害。",
  ["#hanjin__retinue_skill_quaxiaojiang-invoke"] = "曲阿小将：你可以对这两张牌的重合目标各造成1点伤害",
}

return skill
