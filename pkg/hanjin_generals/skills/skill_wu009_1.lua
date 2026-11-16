-- WU009 孙坚 · 英魂
--
-- 规则基线：rules/standard-generals.md 吴区 WU009。
-- 准备阶段：选择一名其他角色并选择一项：
-- 1. 令其摸 X 张牌，然后弃置一张牌；
-- 2. 令其摸一张牌，然后弃置 X 张牌（X 为孙坚已损失的体力值）。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu009_1",
}
skill.hanjinImplemented = true

local DRAW = "#hanjin__skill_wu009_1-draw"
local DISCARD = "#hanjin__skill_wu009_1-discard"

--- 客户端没有 player.room；与服务端共用 Fk:currentRoom() 的只读房间。
---@param player ServerPlayer | ClientPlayer
---@return Room | Client
local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

---@param player ServerPlayer | ClientPlayer
---@return ServerPlayer[] | ClientPlayer[]
local function otherTargets(player)
  local room = currentRoom(player)
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name) and player.phase == Player.Start
      and #otherTargets(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local to = player.room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = otherTargets(player),
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu009_1-choose",
      cancelable = true,
    })
    if #to > 0 then
      event:setCostData(self, { tos = to })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = event:getCostData(self).tos[1]
    local n = player:getLostHp()
    local choice = room:askToChoice(player, {
      choices = { DRAW, DISCARD },
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu009_1-choice:::" .. n,
    })
    if choice == DRAW then
      if to.dead then return end
      to:drawCards(n, skill.name)
      if to:isAlive() then
        room:askToDiscard(to, {
          min_num = 1,
          max_num = 1,
          include_equip = true,
          skill_name = skill.name,
          cancelable = false,
        })
      end
    else
      if to.dead then return end
      to:drawCards(1, skill.name)
      if n > 0 and to:isAlive() then
        room:askToDiscard(to, {
          min_num = n,
          max_num = n,
          include_equip = true,
          skill_name = skill.name,
          cancelable = false,
        })
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wu009_1-choose"] = "英魂：选择一名其他角色",
  ["#hanjin__skill_wu009_1-choice"] = "英魂：令其摸X张牌后弃置一张，或摸一张后弃置X张（X为%arg）",
  [DRAW] = "令其摸X张牌，然后弃置一张牌",
  [DISCARD] = "令其摸一张牌，然后弃置X张牌",
}

return skill
