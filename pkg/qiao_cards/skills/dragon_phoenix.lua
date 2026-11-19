-- 飞龙夺凤：使用【杀】指定目标后令其自弃一张牌；本次【杀】的实际目标因
-- 该伤害进入濒死时，在求桃前获得其一张手牌。两次发动分别询问。
local skill = fk.CreateSkill {
  name = "qiao__dragon_phoenix_skill",
  attached_equip = "qiao__dragon_phoenix",
}

skill:addEffect(fk.TargetSpecified, {
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.card ~= nil and data.card.trueName == "slash"
      and data.to ~= nil and not data.to:isNude()
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__dragon_phoenix-slash::" .. data.to.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    player.room:askToDiscard(data.to, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      cancelable = false,
      prompt = "#qiao__dragon_phoenix-discard",
    })
  end,
})

--- 最近的伤害是否由本次【杀】对实际目标造成；排除连环传导与转移波及。
local function slashDamageEffect(room, damage, target, player)
  if damage == nil or damage.chain or damage.card == nil then return nil end
  if damage.from ~= player or damage.card.trueName ~= "slash" then return nil end
  if not room.logic:damageByCardEffect(true) then return nil end
  local damageEvent = room.logic:getCurrentEvent():findParent(GameEvent.Damage, true)
  local effectEvent = damageEvent and damageEvent:findParent(GameEvent.CardEffect, false, 2)
  local effect = effectEvent and effectEvent.data
  if effect == nil or effect.card ~= damage.card or effect.from ~= player then return nil end
  if not table.contains(effect.tos or {}, target) then return nil end
  return effect
end

skill:addEffect(fk.EnterDying, {
  can_trigger = function(self, event, target, player, data)
    if not player:hasSkill(skill.name) then return false end
    local effect = slashDamageEffect(player.room, data.damage, target, player)
    return effect ~= nil and #target:getCardIds(Player.Hand) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__dragon_phoenix-dying::" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local card = room:askToChooseCard(player, {
      target = target,
      flag = "h",
      skill_name = skill.name,
      prompt = "#qiao__dragon_phoenix-hand::" .. target.id,
    })
    if card == nil then return end
    room:obtainCard(player, card, false, fk.ReasonPrey)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "飞龙夺凤",
  ["#qiao__dragon_phoenix-slash"] = "飞龙夺凤：是否令 %dest 弃置一张牌",
  ["#qiao__dragon_phoenix-discard"] = "飞龙夺凤：弃置一张自己的牌",
  ["#qiao__dragon_phoenix-dying"] = "飞龙夺凤：是否获得 %dest 的一张手牌",
  ["#qiao__dragon_phoenix-hand"] = "飞龙夺凤：选择一张手牌交给飞龙夺凤的装备者",
}

return skill
