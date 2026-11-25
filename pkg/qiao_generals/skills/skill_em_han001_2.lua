-- EM(HAN001) 君刘协 · 转蓬
-- 成为伤害牌唯一目标后：普通分支交给使用者一张牌令此牌对自己无效；
-- 若刘协已使用过使用者当前势力锦囊，改为使用者交给刘协一张牌，否则此牌无效。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_han"
local Cards = require "packages.qiao.pkg.qiao_mode.rules.cards"

local skill = fk.CreateSkill { name = P.ZHUANPENG }
skill.qiaoImplemented = true

local USED = "qiao_em_han001_used_tricks"

-- 正向是发动消耗，执行给牌即可。反向效果明文要求对方交付，须核对收牌记录。
local function giveCard(room, from, to, cards, requireDelivery)
  if not cards or #cards ~= 1 or not table.contains(from:getCardIds("he"), cards[1]) then
    return false
  end
  local start = room.logic.current_event_id
  room:obtainCard(to, cards, false, fk.ReasonGive, from, skill.name)
  if not requireDelivery then return true end

  local moves = room.logic:getEventsByRule(GameEvent.MoveCards, 1, function(e)
    if e.interrupted then return false end
    return table.find(e.data, function(move)
      return move.from == from and move.to == to and move.toArea == Card.PlayerHand
        and move.moveReason == fk.ReasonGive and move.skillName == skill.name
        and table.find(move.moveInfo, function(info) return info.cardId == cards[1] end)
    end)
  end, start)
  return #moves > 0
end

local function usedTrick(room, player, kingdom)
  local list = room:getTag(USED) or {}
  local entry = list[player.id]
  return entry ~= nil and entry[kingdom] == true
end

local function markUsed(room, player, kingdom)
  local list = table.simpleClone(room:getTag(USED) or {})
  list[player.id] = list[player.id] or {}
  list[player.id][kingdom] = true
  room:setTag(USED, list)
end

skill:addEffect(fk.CardUsing, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local card = data and data.card
    return card ~= nil and Cards.tricks[card.name] ~= nil and target == player
  end,
  on_refresh = function(self, event, target, player, data)
    markUsed(player.room, target, Cards.tricks[data.card.name])
  end,
})

skill:addEffect(fk.TargetConfirmed, {
  can_trigger = function(self, event, target, player, data)
    local user = data.from
    return target == player and not player.dead and player:hasSkill(skill.name)
      and user ~= nil and not user.dead
      and data.card ~= nil and data.card.is_damage_card and data:isOnlyTarget(target)
      and (usedTrick(player.room, player, user.kingdom) or not player:isNude())
  end,
  on_cost = function(self, event, target, player, data)
    local room, user = player.room, data.from
    if usedTrick(room, player, user.kingdom) then
      if not room:askToSkillInvoke(player, {
        skill_name = skill.name, prompt = "#qiao__han001_zhuanpeng-invoke",
      }) then return false end
      event:setCostData(self, { reversed = true })
      return true
    end

    local cards = room:askToCards(player, {
      min_num = 1, max_num = 1, include_equip = true,
      skill_name = skill.name, prompt = "#qiao__han001_zhuanpeng-pay", cancelable = true,
    })
    if #cards ~= 1 or not table.contains(player:getCardIds("he"), cards[1]) then return false end
    event:setCostData(self, { cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local user = data.from
    if user == nil or user.dead then return end
    local cost = event:getCostData(self) or {}
    if cost.reversed then
      local cards = room:askToCards(user, {
        min_num = 1, max_num = 1, include_equip = true,
        skill_name = skill.name, prompt = "#qiao__han001_zhuanpeng-give", cancelable = true,
      })
      if not giveCard(room, user, player, cards, true) then data:setNullified(player) end
    elseif giveCard(room, player, user, cost.cards, false) then
      data:setNullified(player)
    end
  end,
})

Fk:loadTranslationTable {
  [P.ZHUANPENG] = "转蓬",
  [":" .. P.ZHUANPENG] = "当你成为伤害牌的唯一目标后，你可以交给使用者一张牌并令此牌对你无效；若你已使用过其势力锦囊，改为其需交给你一张牌，否则此牌对你无效。",
  ["#qiao__han001_zhuanpeng-invoke"] = "转蓬：是否发动",
  ["#qiao__han001_zhuanpeng-pay"] = "转蓬：交给使用者一张牌",
  ["#qiao__han001_zhuanpeng-give"] = "转蓬：交给君刘协一张牌",
}

return skill
