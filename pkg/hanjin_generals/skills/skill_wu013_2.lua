-- WU013 周泰 · 奋激
--
-- 每回合结束时，可以令一名本回合失去过所有手牌的角色摸两张牌，然后周泰失去
-- 1 点体力。是否“失去过所有手牌”由本回合真实的手牌移动历史记录：手牌因使用、
-- 打出、弃置、交给等离开后变为 0 才标记；本来就没有手牌不算。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu013_2",
}
skill.hanjinImplemented = true

local LOST_MARK = "hanjin__skill_wu013_2_lost-turn"

--- 本事件是否让该角色从有手牌变为空手。
---@param move MoveCardsData
---@return boolean
local function emptiedHand(move)
  local p = move.from
  if p == nil or not p:isAlive() then return false end
  if #p:getCardIds(Player.Hand) > 0 then return false end
  for _, info in ipairs(move.moveInfo or {}) do
    if info.fromArea == Player.Hand then return true end
  end
  return false
end

skill:addEffect(fk.AfterCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    if player == nil or not player:hasSkill(skill.name) then return false end
    for _, move in ipairs(data or {}) do
      if emptiedHand(move) then return true end
    end
    return false
  end,
  on_refresh = function(self, event, target, player, data)
    for _, move in ipairs(data or {}) do
      local p = move.from
      if emptiedHand(move) then
        player.room:setPlayerMark(p, LOST_MARK, 1)
      end
    end
  end,
})

local function candidates(player)
  return table.filter(player.room.alive_players, function(p)
    return p:isAlive() and not p:isRemoved() and p:getMark(LOST_MARK) > 0
  end)
end

skill:addEffect(fk.TurnEnd, {
  anim_type = "support",
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and not player.dead and player:hasSkill(skill.name)
      and #candidates(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu013_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local tos = candidates(player)
    if #tos == 0 then return end
    local chosen = room:askToChoosePlayers(player, {
      targets = tos,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu013_2-target",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return end
    to:drawCards(2, skill.name)
    if not player.dead then
      room:loseHp(player, 1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu013_2"] = "奋激",
  [":hanjin__skill_wu013_2"] = "每回合结束时，你可以令一名本回合失去过所有手牌的角色摸两张牌，然后你失去1点体力。",
  ["#hanjin__skill_wu013_2-invoke"] = "奋激：你可以令一名本回合失去过所有手牌的角色摸两张牌",
  ["#hanjin__skill_wu013_2-target"] = "奋激：选择一名本回合失去过所有手牌的角色",
}

return skill
