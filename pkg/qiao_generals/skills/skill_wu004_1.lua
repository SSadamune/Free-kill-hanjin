-- WU004 黄盖 · 苦肉
--
-- 出牌阶段限一次：失去 1 点体力，然后可以交给一名其他角色一张牌。
-- “失去体力”走 loseHp，因此会触发诈降（HpLost），与受到伤害严格分开。
local skill = fk.CreateSkill {
  name = "qiao__skill_wu004_1",
}
skill.qiaoImplemented = true

local function otherPlayers(room, player)
  return table.filter(room:getPresentPlayers(), function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

skill:addEffect("active", {
  anim_type = "masochism",
  prompt = "#qiao__skill_wu004_1-prompt",
  card_num = 0,
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

    -- 失去体力及其触发先结算，再从此时实际拥有的牌和在场角色选择。
    if #player:getCardIds("he") == 0 then return end
    local targets = otherPlayers(room, player)
    if #targets == 0 then return end
    local tos, cards = room:askToChooseCardsAndPlayers(player, {
      targets = targets,
      min_num = 1, max_num = 1,
      min_card_num = 1, max_card_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_wu004_1-give",
      cancelable = true,
    })
    local to, card = tos[1], cards[1]
    if player.dead or to == nil or to.dead or to:isRemoved() or not table.contains(targets, to)
      or #cards ~= 1 or #tos ~= 1 or not table.contains(player:getCardIds("he"), card) then return end
    room:moveCardTo({ card }, Card.PlayerHand, to, fk.ReasonGive, skill.name, nil, true, player)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu004_1"] = "苦肉",
  [":qiao__skill_wu004_1"] = "出牌阶段限一次，你可以失去1点体力，然后你可以交给一名其他角色一张牌。",
  ["#qiao__skill_wu004_1-prompt"] = "苦肉：失去1点体力，然后可以交给一名其他角色一张牌",
  ["#qiao__skill_wu004_1-give"] = "苦肉：选择一张牌和一名其他角色（可取消）",
}

return skill
