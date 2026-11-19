-- HAN018 蹇硕 · 集兵
--
-- 摸牌阶段可多摸 X（发动时同势力角色数，含自己）；回合结束时比较本回合
-- 造成的伤害值，低于该次发动锁定的 X 则失去 1 点体力。X 在发动时锁定；
-- 伤害在 TurnEnd 时从本回合实际 GameEvent.Damage 历史查询，因此包括摸牌前
-- 与获得集兵前的伤害，也不会把整局历史误当本回合。
local skill = fk.CreateSkill {
  name = "qiao__skill_han018_1",
}
skill.qiaoImplemented = true

local X_MARK = "qiao__skill_han018_1_x-turn"

-- 房间级延迟结算。只有集兵发动/获得后才安装；即使集兵在回合结束前失去，
-- 该独立技能仍能完成 TurnEnd 惩罚。技能对象缓存，不重复 createSkill 同名。
local helper = fk.CreateSkill {
  name = "qiao__skill_han018_1_turnend&",
}
local helper_skill

local function ensureHelper(room)
  if helper_skill == nil then
    helper_skill = helper:createSkill()
    Fk.skills[helper_skill.name] = helper_skill
  end
  room:addSkill(helper_skill)
end

--- 本回合实际由 player 造成的伤害总和。只统计当前 Turn 事件范围内的 Damage。
local function damageThisTurn(player)
  local events = player.room.logic:getActualDamageEvents(math.huge, function(event)
    return event.data.from == player
  end, Player.HistoryTurn)
  local total = 0
  for _, event in ipairs(events) do
    total = total + event.data.damage
  end
  return total
end

helper:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "negative",
  priority = 0,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    local x = player:getMark(X_MARK)
    return x > 0 and damageThisTurn(player) < x
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local x = player:getMark(X_MARK)
    local damage = damageThisTurn(player)
    room:setPlayerMark(player, X_MARK, 0)
    if damage < x and not player.dead then
      room:loseHp(player, 1, skill.name)
    end
  end,
})

local function sameKingdomCount(player)
  local kingdom = player.kingdom
  local count = 0
  for _, other in ipairs(player.room:getPresentPlayers()) do
    if other == player then
      count = count + 1
    elseif kingdom ~= "unknown" and kingdom ~= "wild" and other.kingdom == kingdom then
      count = count + 1
    end
  end
  return count
end

skill:addAcquireEffect(function(self, player)
  ensureHelper(player.room)
end)

skill:addEffect(fk.DrawNCards, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_han018_1-invoke:::" .. sameKingdomCount(player),
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    ensureHelper(room)
    local x = sameKingdomCount(player)
    room:setPlayerMark(player, X_MARK, x)
    data.n = data.n + x
  end,
})

Fk:loadTranslationTable {
  [helper.name] = "集兵",
  ["#qiao__skill_han018_1-invoke"] = "集兵：你可以多摸 %arg 张牌",
}

return skill
