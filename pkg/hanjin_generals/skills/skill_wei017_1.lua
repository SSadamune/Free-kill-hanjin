-- WEI017 李典 · 恂恂
--
-- 每回合首次摸牌前可以发动；自己回合内卜算4且恰好两张置底，回合外卜算2。
-- “首次摸牌”读取本回合真实摸牌历史，因此包括技能未取得或未明置时的摸牌；
-- 卜算本身使用置牌移动，不产生摸牌事件，不会递归触发。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wei017_1",
}
skill.hanjinImplemented = true

--- 本回合是否已有实际摸牌。
---@param player ServerPlayer
---@return boolean
local function hasDrawnThisTurn(player)
  local logic = player.room.logic
  if logic == nil then return false end
  local events = logic:getEventsOfScope(GameEvent.MoveCards, math.huge, function(event)
    for _, move in ipairs(event.data or {}) do
      if move.to == player and move.toArea == Card.PlayerHand
        and move.moveReason == fk.ReasonDraw and #(move.moveInfo or {}) > 0 then
        return true
      end
    end
    return false
  end, Player.HistoryTurn)
  return #events > 0
end

skill:addEffect(fk.BeforeDrawCard, {
  anim_type = "control",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and not hasDrawnThisTurn(player)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei017_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if room.current == player then
      room:askToGuanxing(player, {
        cards = room:getNCards(4),
        top_limit = { 2, 2 },
        bottom_limit = { 2, 2 },
        skill_name = skill.name,
      })
    else
      room:askToGuanxing(player, {
        cards = room:getNCards(2),
        skill_name = skill.name,
      })
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wei017_1"] = "恂恂",
  [":hanjin__skill_wei017_1"] = "你每回合首次摸牌前，你可以卜算2，若为回合内，改为卜算4（须将其中两张置于牌堆底）。",
  ["#hanjin__skill_wei017_1-invoke"] = "恂恂：你可以卜算",
}

return skill
