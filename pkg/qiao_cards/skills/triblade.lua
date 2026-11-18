-- 三尖两刃刀：使用【杀】对实际目标造成伤害后，弃置一张手牌，对该目标距离 1
-- 的另一名其他角色造成 1 点伤害。伤害必须确由本次【杀】对该目标的效果造成，
-- 且后续伤害以本次弃置实际完成的移动记录为准。
local skill = fk.CreateSkill {
  name = "qiao__triblade_skill",
  attached_equip = "qiao__triblade",
}

--- 本次伤害是否由本次【杀】对“当前实际生效”的目标造成；排除连环传导与
--- 转移到另一个原始目标的波及（此时父 CardEffect 的当前目标不是受害者）。
local function slashDamageEffect(room, damage, target, player)
  if damage == nil or damage.chain or damage.card == nil then return nil end
  if damage.from ~= player or damage.card.trueName ~= "slash" then return nil end
  if not room.logic:damageByCardEffect(true) then return nil end
  local damageEvent = room.logic:getCurrentEvent():findParent(GameEvent.Damage, true)
  local effectEvent = damageEvent and damageEvent:findParent(GameEvent.CardEffect, false, 2)
  local effect = effectEvent and effectEvent.data
  if effect == nil or effect.card ~= damage.card or effect.from ~= player then return nil end
  if effect.to ~= target then return nil end
  return effect
end

--- 本次技能是否真的完成了一次“弃置手牌”的移动。
-- 以当次移动记录为准，不能仅凭已选牌或当下区域判断。
local function discardedThisTime(room, skillName, ids)
  local wanted = {}
  for _, id in ipairs(ids) do wanted[id] = true end
  local events = room.logic:getEventsByRule(GameEvent.MoveCards, 1, function(e)
    if e.interrupted then return false end
    for _, move in ipairs(e.data or {}) do
      if move.toArea == Card.DiscardPile and move.moveReason == fk.ReasonDiscard
        and move.skillName == skillName then
        local hit = 0
        for _, info in ipairs(move.moveInfo or {}) do
          if wanted[info.cardId] and info.fromArea == Card.PlayerHand then
            hit = hit + 1
          end
        end
        if hit == #ids then return true end
      end
    end
    return false
  end)
  return events[1] ~= nil
end

--- 距离被【杀】伤害的目标 1 的另一名其他角色。
local function legalTargets(room, player, damaged)
  return table.filter(room.alive_players, function(p)
    return p ~= player and p ~= damaged and damaged:distanceTo(p) == 1
  end)
end

skill:addEffect(fk.Damage, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.to ~= nil and not data.to.dead
      and slashDamageEffect(player.room, data, data.to, player) ~= nil
      and not player:isKongcheng()
      and #legalTargets(player.room, player, data.to) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = legalTargets(room, player, data.to)
    if #targets == 0 then return false end
    local cards = table.filter(player:getCardIds("h"), function(id)
      return not player:prohibitDiscard(id)
    end)
    if #cards == 0 then return false end
    local to, card = room:askToChooseCardsAndPlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      pattern = tostring(Exppattern { id = cards }),
      min_card_num = 1,
      max_card_num = 1,
      prompt = "#qiao__triblade-invoke::" .. data.to.id,
      cancelable = true,
    })
    if #to > 0 and #card > 0 then
      event:setCostData(self, { tos = to, cards = card })
      return true
    end
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local cards = cost.cards
    room:throwCard(cards, skill.name, player, player)
    -- 实际完成本次弃置后，才执行后续伤害。
    if not discardedThisTime(room, skill.name, cards) then return end
    local to = cost.tos[1]
    if to == nil or to.dead then return end
    room:damage {
      from = player,
      to = to,
      damage = 1,
      skillName = skill.name,
    }
  end,
})

Fk:loadTranslationTable {
  ["qiao__triblade_skill"] = "三尖两刃刀",
  ["#qiao__triblade-invoke"] = "三尖两刃刀：你可以弃置一张手牌，对 %dest 距离 1 的另一名其他角色造成 1 点伤害",
}

return skill
