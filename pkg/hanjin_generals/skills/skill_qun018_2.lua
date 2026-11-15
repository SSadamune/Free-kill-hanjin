-- QUN018 邹氏 · 倾城
--
-- 出牌阶段限一次：选择一名手牌数小于等于你的其他男性角色，你与其交换全部
-- 手牌。交换的是双方当前的全部手牌，不要求双方都有牌；次数按本阶段记录，
-- 不能借由“没有可交换的牌”跳过限制后再发动。
-- 保留来源：使用一次移牌事件交换两边手牌，不逐张获得/交给。
local skill = fk.CreateSkill {
  name = "hanjin__skill_qun018_2",
}
skill.hanjinImplemented = true

---@param player ServerPlayer
---@return ServerPlayer[]
local function candidates(player)
  local room = player.room
  local handCount = #player:getCardIds("h")
  return table.filter(room.alive_players, function(p)
    return p ~= player and not p.dead and not p:isRemoved() and p:isMale()
      and #p:getCardIds("h") <= handCount
  end)
end

skill:addEffect("active", {
  anim_type = "control",
  target_num = 1,
  prompt = "#hanjin__skill_qun018_2-prompt",
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and table.contains(candidates(player), to_select)
  end,
  can_use = function(self, player)
    return player.phase == Player.Play
      and player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
      and #candidates(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local to = effect.tos and effect.tos[1]
    if player == nil or to == nil or player.dead or to.dead or to:isRemoved() then return end
    if not table.contains(candidates(player), to) then return end

    local mine = player:getCardIds("h")
    local theirs = to:getCardIds("h")
    local moves = {}
    if #mine > 0 then
      table.insert(moves, {
        ids = mine,
        from = player,
        to = to,
        toArea = Card.PlayerHand,
        moveReason = fk.ReasonExchange,
        skillName = skill.name,
        proposer = player,
      })
    end
    if #theirs > 0 then
      table.insert(moves, {
        ids = theirs,
        from = to,
        to = player,
        toArea = Card.PlayerHand,
        moveReason = fk.ReasonExchange,
        skillName = skill.name,
        proposer = player,
      })
    end
    if #moves > 0 then room:moveCards(table.unpack(moves)) end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_qun018_2"] = "倾城",
  [":hanjin__skill_qun018_2"] = "出牌阶段限一次，你可以选择一名手牌数小于等于你的其他男性角色，你与其交换手牌。",
  ["#hanjin__skill_qun018_2-prompt"] = "倾城：选择一名手牌数不大于你的其他男性角色，交换手牌",
}

return skill
