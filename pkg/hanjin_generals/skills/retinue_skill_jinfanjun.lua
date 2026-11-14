-- WU002 甘宁 · 翼从锦帆军
--
-- 每回合每颜色限一次：甘宁弃置任意角色的牌后，可以弃置一张其中包含的颜色的
-- 牌，然后摸两张牌。只认弃置事件（ReasonDiscard）且操作者为甘宁；技能自身
-- 支付颜色牌的第二次弃置不再触发。颜色次数用 -turn 标记，每种颜色各自一次。
local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_jinfanjun",
}
skill.hanjinImplemented = true

local RED_USED = "hanjin__retinue_skill_jinfanjun_red-turn"
local BLACK_USED = "hanjin__retinue_skill_jinfanjun_black-turn"
local OPT_RED = "#hanjin__retinue_skill_jinfanjun-red"
local OPT_BLACK = "#hanjin__retinue_skill_jinfanjun-black"

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

local function availableColors(player, data)
  local colors = discardedColors(player, data)
  local available = {}
  for _, color in ipairs({ Card.Red, Card.Black }) do
    if colors[color] and player:getMark(markFor(color)) == 0
      and #discardableOfColor(player, color) > 0 then
      table.insert(available, color)
    end
  end
  return available
end

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "drawcard",
  global = true,
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and not player.dead and player:hasSkill(skill.name)
      and #availableColors(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_jinfanjun-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local colors = availableColors(player, data)
    if #colors == 0 then return end

    local color = colors[1]
    if #colors > 1 then
      local option = room:askToChoice(player, {
        choices = { OPT_RED, OPT_BLACK },
        skill_name = skill.name,
        prompt = "#hanjin__retinue_skill_jinfanjun-color",
        cancelable = false,
      })
      color = option == OPT_RED and Card.Red or Card.Black
    end
    if #discardableOfColor(player, color) == 0 then return end

    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      pattern = color == Card.Red and ".|.|red" or ".|.|black",
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_jinfanjun-discard",
      cancelable = false,
    })
    if cards == nil or #cards ~= 1 then return end
    room:addPlayerMark(player, markFor(color), 1)
    player:drawCards(2, skill.name)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__retinue_skill_jinfanjun"] = "锦帆军",
  [":hanjin__retinue_skill_jinfanjun"] = "每回合每颜色限一次，你弃置任意角色的牌后，你可以弃置一张其中包含的颜色的牌，然后摸两张牌。",
  ["#hanjin__retinue_skill_jinfanjun-invoke"] = "锦帆军：你可以弃置一张其中包含的颜色的牌，然后摸两张牌",
  ["#hanjin__retinue_skill_jinfanjun-color"] = "锦帆军：选择一种包含的颜色",
  ["#hanjin__retinue_skill_jinfanjun-discard"] = "锦帆军：弃置一张该颜色的牌",
  [OPT_RED] = "红色",
  [OPT_BLACK] = "黑色",
}

return skill
