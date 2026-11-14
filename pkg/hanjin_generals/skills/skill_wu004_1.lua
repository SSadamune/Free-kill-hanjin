-- WU004 黄盖 · 苦肉
--
-- 出牌阶段限一次：失去 1 点体力，然后可以交给一名其他角色一张牌。
-- “失去体力”走 loseHp，因此会触发诈降（HpLost），与受到伤害严格分开。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu004_1",
}
skill.hanjinImplemented = true

local function otherPlayers(player)
  return table.filter(player.room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

skill:addEffect("active", {
  anim_type = "masochism",
  prompt = "#hanjin__skill_wu004_1-prompt",
  target_num = 0,
  max_phase_use_time = 1,
  can_use = function(self, player)
    return player.hp >= 1 and self:withinTimesLimit(player, Player.HistoryPhase)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    if player == nil or player.dead then return end

    room:loseHp(player, 1, skill.name)
    if player.dead then return end

    -- 交给一张牌是可选的；没有收牌者或没有牌时只结算失去体力。
    if #otherPlayers(player) == 0 or #player:getCardIds("he") == 0 then return end
    local tos = room:askToChoosePlayers(player, {
      targets = otherPlayers(player),
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu004_1-target",
      cancelable = true,
    })
    local to = tos and tos[1]
    if to == nil or to.dead or to:isRemoved() or player.dead then return end

    local card = room:askToChooseCard(player, {
      target = player,
      flag = "he",
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu004_1-card",
    })
    if card == nil or card == -1 or not table.contains(player:getCardIds("he"), card) then return end
    room:moveCardTo({ card }, Card.PlayerHand, to, fk.ReasonGive, skill.name, nil, true, player)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu004_1"] = "苦肉",
  [":hanjin__skill_wu004_1"] = "出牌阶段限一次，你可以失去1点体力，然后你可以交给一名其他角色一张牌。",
  ["#hanjin__skill_wu004_1-prompt"] = "苦肉：失去1点体力，然后可以交给一名其他角色一张牌",
  ["#hanjin__skill_wu004_1-target"] = "苦肉：选择一名其他角色（取消则不交牌）",
  ["#hanjin__skill_wu004_1-card"] = "苦肉：选择交给其的一张牌",
}

return skill
