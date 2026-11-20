-- WU002 甘宁 · 翼从锦帆军
--
-- 每回合每颜色限一次：甘宁弃置任意角色的牌后，可以弃置一张其中包含的颜色的
-- 牌，然后摸两张牌。只认弃置事件（ReasonDiscard）且操作者为甘宁；技能自身
-- 支付颜色牌的第二次弃置不再触发。颜色次数用 -turn 标记，每种颜色各自一次。
local skill = fk.CreateSkill {
  name = "qiao__retinue_skill_jinfanjun",
}
skill.qiaoImplemented = true
local R = require "packages.qiao.pkg.qiao_generals.util.retinue_instances"

local RED_USED = "qiao__retinue_skill_jinfanjun_red-turn"
local BLACK_USED = "qiao__retinue_skill_jinfanjun_black-turn"

local function usedColors(player, instance)
  if instance ~= nil then
    instance.jinfanUsed = instance.jinfanUsed or {}
    return instance.jinfanUsed
  end
  return {
    [Card.Red] = player:getMark(RED_USED) > 0,
    [Card.Black] = player:getMark(BLACK_USED) > 0,
  }
end

local function markUsed(player, color, instance)
  if instance ~= nil then
    instance.jinfanUsed = instance.jinfanUsed or {}
    instance.jinfanUsed[color] = true
  else
    player.room:addPlayerMark(player, color == Card.Red and RED_USED or BLACK_USED, 1)
  end
end

local function markFor(color)
  return color == Card.Red and RED_USED or BLACK_USED
end

local function discardableOfColor(player, color)
  return table.filter(player:getCardIds("he"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and card.color == color and not player:prohibitDiscard(card)
  end)
end

--- 本次移动事件中，由甘宁弃置到弃牌堆的牌所包含的颜色。
local function discardedColors(player, data)
  local colors = {}
  for _, move in ipairs(data or {}) do
    if move.moveReason == fk.ReasonDiscard and move.toArea == Card.DiscardPile
      and move.proposer == player and move.skillName ~= skill.name then
      for _, info in ipairs(move.moveInfo or {}) do
        local card = Fk:getCardById(info.cardId)
        if card ~= nil and (card.color == Card.Red or card.color == Card.Black) then
          colors[card.color] = true
        end
      end
    end
  end
  return colors
end

local function availableColors(player, data, instance)
  local colors = discardedColors(player, data)
  local used = usedColors(player, instance)
  local available = {}
  for _, color in ipairs({ Card.Red, Card.Black }) do
    if colors[color] and not used[color] and #discardableOfColor(player, color) > 0 then
      table.insert(available, color)
    end
  end
  return available
end

local function triggerEach(self, event, target, player, data)
  if #R.instancesForSkill(player, skill.name) == 0 then
    return self:doCost(event, target, player, data)
  end
  return R.triggerEach(self, event, target, player, data)
end

skill:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target ~= nil and target.room ~= nil
  end,
  on_refresh = function(self, event, target, player)
    for _, owner in ipairs(player.room.players) do
      for _, instance in ipairs(R.instancesForSkill(owner, skill.name)) do
        instance.jinfanUsed = {}
      end
    end
  end,
})

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "drawcard",
  global = true,
  on_trigger = triggerEach,
  can_trigger = function(self, event, target, player, data)
    if player == nil or player.dead then return false end
    if not player:hasSkill(skill.name) then return false end
    if #R.instancesForSkill(player, skill.name) == 0 then
      return #availableColors(player, data, nil) > 0
    end
    for _, instance in ipairs(R.instancesForSkill(player, skill.name)) do
      if #availableColors(player, data, instance) > 0 then return true end
    end
    return false
  end,
  on_cost = function(self, event, target, player, data)
    local instance = R.currentForEvent(self, event)
    local colors = availableColors(player, data, instance)
    if #colors == 0 then return false end
    local ids = {}
    for _, color in ipairs(colors) do
      table.insertTable(ids, discardableOfColor(player, color))
    end
    if #ids == 0 then return false end
    local cards = player.room:askToDiscard(player, {
      min_num = 1, max_num = 1, include_equip = true,
      pattern = tostring(Exppattern { id = ids }),
      skill_name = skill.name,
      prompt = "#qiao__retinue_skill_jinfanjun-discard",
      cancelable = true,
      skip = true,
    })
    if #cards ~= 1 or not table.contains(ids, cards[1]) then return false end
    local color = Fk:getCardById(cards[1]).color
    event:setCostData(self, { card = cards[1], color = color, instance = instance })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local id, color, instance = cost.card, cost.color, cost.instance
    if not table.contains(discardableOfColor(player, color), id) then return end
    markUsed(player, color, instance)
    room:throwCard({ id }, skill.name, player, player)
    if not player.dead then player:drawCards(2, skill.name) end
  end,
})

Fk:loadTranslationTable {
  ["qiao__retinue_skill_jinfanjun"] = "锦帆军",
  [":qiao__retinue_skill_jinfanjun"] = "每回合每颜色限一次，你弃置任意角色的牌后，你可以弃置一张其中包含的颜色的牌，然后摸两张牌。",
  ["#qiao__retinue_skill_jinfanjun-discard"] = "锦帆军：弃置一张符合颜色条件的牌，然后摸两张牌",
}

return skill
