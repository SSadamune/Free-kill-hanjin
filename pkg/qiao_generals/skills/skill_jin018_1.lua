-- JIN018 陈骞 · 忽辱
-- 每回合限一次，当你造成或受到伤害时，你可以同时展示来源和受伤角色各一张手牌，
-- 若：花色相同，你获得之；类别相同，此伤害-1。
local skill = fk.CreateSkill {
  name = "qiao__skill_jin018_1",
}
skill.qiaoImplemented = true

local function eligible(player, data, isInflicted)
  if player.dead or not player:hasSkill(skill.name) then return false end
  if player:usedSkillTimes(skill.name, Player.HistoryTurn) > 0 then return false end
  if data == nil or data.from == nil or data.to == nil then return false end
  -- 自伤时仅在 DamageCaused 触发一次，避免同一伤害事件重复询问。
  if isInflicted and data.from == player then return false end
  if data.from == data.to then
    return #player:getCardIds(Player.Hand) >= 2
  end
  return not data.from:isKongcheng() and not data.to:isKongcheng()
end

local function makeEffect(isInflicted)
  return {
    anim_type = "control",
    can_trigger = function(self, event, target, player, data)
      return target == player and eligible(player, data, isInflicted)
    end,
    on_cost = function(self, event, target, player, data)
      return player.room:askToSkillInvoke(player, {
        skill_name = skill.name,
        prompt = "#qiao__skill_jin018_1-invoke",
      })
    end,
    on_use = function(self, event, target, player, data)
      local room = player.room
      local from, to = data.from, data.to
      if from == nil or to == nil then return end

      local idA, idB, other
      if from == to then
        if #player:getCardIds(Player.Hand) < 2 then return end
        local cards = room:askToCards(player, {
          min_num = 2,
          max_num = 2,
          include_equip = false,
          skill_name = skill.name,
          prompt = "#qiao__skill_jin018_1-self",
          cancelable = false,
        })
        if type(cards) ~= "table" or #cards ~= 2 then return end
        idA, idB = cards[1], cards[2]
        player:showCards({ idA, idB })
      else
        other = (from == player) and to or from
        if player:isKongcheng() or other:isKongcheng() then return end
        local myCards = room:askToCards(player, {
          min_num = 1,
          max_num = 1,
          include_equip = false,
          skill_name = skill.name,
          prompt = "#qiao__skill_jin018_1-own",
          cancelable = false,
        })
        if type(myCards) ~= "table" or #myCards ~= 1 then return end
        idA = myCards[1]
        idB = room:askToChooseCard(player, {
          target = other,
          flag = "h",
          skill_name = skill.name,
          prompt = "#qiao__skill_jin018_1-other::" .. other.id,
        })
        if idB == nil then return end
        -- 同时展示双方各一张手牌：按各自牌主过锁视、记牌、发战报与亮牌动画，并合并为一次 fk.CardShown 触发。
        Fk:filterCard(idA, player)
        Fk:filterCard(idB, other)
        room:sendLog { type = "#ShowCard", from = player.id, card = { idA } }
        room:sendLog { type = "#ShowCard", from = other.id, card = { idB } }
        for _, p in ipairs(room.players) do
          p.card_tracker:setCardKnown(idA, player, Card.PlayerHand)
          p.card_tracker:setCardKnown(idB, other, Card.PlayerHand)
        end
        local eventId = 0
        local current = room.logic:getCurrentEvent()
        if current ~= nil and current.event == GameEvent.SkillEffect then
          eventId = current.id
        end
        room:doBroadcastNotify("ShowCard", { { idA }, player.id, eventId })
        room:doBroadcastNotify("ShowCard", { { idB }, other.id, eventId })
        room.logic:trigger(fk.CardShown, player, {
          cardIds = { idA, idB },
          from = player,
        })
      end

      local cardA, cardB = Fk:getCardById(idA), Fk:getCardById(idB)
      if cardA == nil or cardB == nil then return end
      local sameSuit = cardA.suit ~= Card.NoSuit and cardA.suit == cardB.suit
      local sameType = cardA.type == cardB.type

      if sameSuit and other ~= nil and not player.dead
        and table.contains(other:getCardIds(Player.Hand), idB) then
        room:obtainCard(player, idB, true, fk.ReasonPrey, player, skill.name)
      end
      if sameType then
        if data.damage <= 1 then
          data:preventDamage()
        else
          data:changeDamage(-1)
        end
      end
    end,
  }
end

skill:addEffect(fk.DamageCaused, makeEffect(false))
skill:addEffect(fk.DamageInflicted, makeEffect(true))

Fk:loadTranslationTable {
  [skill.name] = "忽辱",
  [":" .. skill.name] = "每回合限一次，当你造成或受到伤害时，你可以同时展示来源和受伤角色各一张手牌，若：花色相同，你获得之；类别相同，此伤害-1。",
  ["#qiao__skill_jin018_1-invoke"] = "忽辱：是否同时展示来源与受伤角色各一张手牌",
  ["#qiao__skill_jin018_1-own"] = "忽辱：选择要展示的一张手牌",
  ["#qiao__skill_jin018_1-other"] = "忽辱：选择展示 %dest 的一张手牌",
  ["#qiao__skill_jin018_1-self"] = "忽辱：选择要展示的两张手牌",
}

return skill
