-- WU007 陆逊 · 度势
--
-- 你可以将本回合未置入过弃牌堆的花色的一张牌当【以逸待劳】使用，然后若
-- 均已置入过，你可以令一名小势力角色选择是否将X张红色牌当【火烧连营】
-- 使用（X为目标数）。
--
-- 花色历史由模式级公开标记提供（rules/wu_history.lua），客户端与服务端
-- 使用同一份数据；不在客户端读取服务端事件树。使用【以逸待劳】后，其
-- 子牌已进入弃牌堆，再检查四种花色是否均已置入过。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu007_2",
}
skill.hanjinImplemented = true

local H = require "packages.hanjin.pkg.hanjin_mode.rules.wu_history"
local W = require "packages.hanjin.pkg.hanjin_generals.util.wu_phases"
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"
local Heg = require "packages.hegemony.util"

local BURNING = "hanjin__burning_camps"

local function burningTargetsFor(player)
  local prev = player:getNextAlive()
  if prev == nil or prev == player then return {} end
  return table.filter(player.room.alive_players, function(p)
    return not p:isRemoved() and (p == prev or Heg.inFormationRelation(prev, p))
  end)
end

local function usableCards(player)
  return table.filter(player:getCardIds("he"), function(id)
    local card = Fk:getCardById(id)
    return (card.suit == Card.Spade or card.suit == Card.Heart
      or card.suit == Card.Club or card.suit == Card.Diamond)
      and not H.hasSuit(player, card.suit)
      and not player:prohibitUse(card)
  end)
end

local function redCards(player)
  return table.filter(player:getCardIds("he"), function(id)
    return Fk:getCardById(id).color == Card.Red
  end)
end

skill:addEffect("viewas", {
  anim_type = "drawcard",
  pattern = "hanjin__await_exhausted",
  prompt = "#hanjin__skill_wu007_2-prompt",
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".",
  },
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    return table.contains(usableCards(player), to_select)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard("hanjin__await_exhausted")
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play and #usableCards(player) > 0
  end,
  enabled_at_response = function()
    return false
  end,
  after_use = function(self, player, use)
    if player == nil or player.dead or use == nil or use.card == nil then return end
    if not H.allSuits(player) then return end
    local room = player.room
    local minors = table.filter(room.alive_players, function(p)
      return not p:isRemoved() and W.isSmallKingdom(p)
    end)
    if #minors == 0 then return end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = minors,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu007_2-minor",
      cancelable = true,
    })
    local target = chosen and chosen[1]
    if target == nil or target.dead or target:isRemoved() then return end

    local targets = burningTargetsFor(target)
    local x = #targets
    if x <= 0 or #redCards(target) < x then return end
    local picked = room:askToChooseCards(target, {
      target = target,
      flag = "he",
      min = x,
      max = x,
      pattern = ".|.|red",
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu007_2-burn:" .. x,
      cancelable = true,
    })
    if picked == nil or #picked ~= x then return end
    for _, id in ipairs(picked) do
      if Fk:getCardById(id).color ~= Card.Red then return end
    end
    -- 主效果是真实的【火烧连营】使用；目标已按该牌规则计算。
    local card = Fk:cloneCard(BURNING)
    card.skillName = skill.name
    card:addSubcards(Card:getIdList(picked))
    room:useCard(UseCardData:new {
      from = target,
      tos = targets,
      card = card,
      extraUse = true,
      extra_data = {},
    })
  end,
})

skill.burningTargetsFor = burningTargetsFor

Fk:loadTranslationTable {
  ["hanjin__skill_wu007_2"] = "度势",
  ["#hanjin__skill_wu007_2-prompt"] = "度势：将一张本回合未置入过弃牌堆的花色的牌当【以逸待劳】使用",
  ["#hanjin__skill_wu007_2-minor"] = "度势：选择一名小势力角色",
  ["#hanjin__skill_wu007_2-burn"] = "度势：你可以将 %arg 张红色牌当【火烧连营】使用",
}

return skill
