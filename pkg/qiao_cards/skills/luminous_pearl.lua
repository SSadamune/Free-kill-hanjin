-- 定澜夜明珠：出牌阶段限一次，弃置 1 至当前体力上限张自己的合法手牌或装备，
-- 然后按实际弃置张数摸牌。此牌本身不能用于该次弃置；与武将的制衡各自计次。
local skill = fk.CreateSkill {
  name = "qiao__luminous_pearl_skill",
  attached_equip = "qiao__luminous_pearl",
}

--- 只读取本次 throwCard 对应的 MoveCards 事件；即使弃牌随后被其他效果拿走，
--- moveInfo 仍记录真实移入弃牌堆的牌数，而不是现时弃牌堆。
local function actualDiscarded(room, from)
  local events = room.logic:getEventsByRule(GameEvent.MoveCards, 1, function(e)
    for _, move in ipairs(e.data or {}) do
      if move.from == from and move.skillName == skill.name then return true end
    end
    return false
  end)
  if #events == 0 then return 0 end
  local count = 0
  for _, move in ipairs(events[1].data or {}) do
    if move.from == from and move.skillName == skill.name then
      count = count + #(move.moveInfo or {})
    end
  end
  return count
end

local function equippedPearlId(player)
  for _, id in ipairs(player:getCardIds(Player.Equip)) do
    local card = Fk:getCardById(id)
    if card ~= nil and card.name == skill.attached_equip then return id end
  end
end

skill:addEffect("active", {
  anim_type = "drawcard",
  max_phase_use_time = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
  end,
  target_num = 0,
  min_card_num = 1,
  max_card_num = function(self, player) return player.maxHp end,
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    if #selected >= player.maxHp then return false end
    local pearl = equippedPearlId(player)
    if pearl ~= nil and to_select == pearl then return false end
    return not player:prohibitDiscard(Fk:getCardById(to_select))
  end,
  on_use = function(self, room, effect)
    local from = effect.from
    local cards = effect.cards or {}
    if from == nil or from.dead or #cards == 0 then return end
    room:throwCard(cards, skill.name, from, from)
    local moved = actualDiscarded(room, from)
    if moved > 0 and not from.dead then from:drawCards(moved, skill.name) end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "定澜夜明珠",
  [":qiao__luminous_pearl_skill"] = "出牌阶段限一次，你可以弃置1至X张自己的手牌或装备"
    .. "（X为你的体力上限，此牌本身不能用于该次弃置），然后摸等量的牌。",
}

return skill
