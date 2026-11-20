-- JIN010 张春华 · 伤逝
--
-- 任一角色结束阶段，张春华选择：1. 若其手牌数大于张春华，将任意张张春华自己
-- 的手牌当一张冰【杀】对其使用；2. 摸牌至张春华已损失的体力值。目标由效果
-- 明确指定，使用显式目标策略，不叠加默认攻击距离。两项均不可执行时不发动。
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin010_1",
}
skill.qiaoImplemented = true

local ICE = "qiao__ice__slash"
local SLASH = "#qiao__skill_jin010_1-slash"
local DRAW = "#qiao__skill_jin010_1-draw"

local function lostHp(player)
  return math.max(0, player.maxHp - player.hp)
end

local function canUseIceSlash(player, target, cards)
  if target.dead or target:isRemoved() then return false end
  local card = Fk:cloneCard(ICE)
  card.skillName = skill.name
  card:addSubcards(cards)
  return not player:prohibitUse(card) and not player:isProhibited(target, card)
end

local function canSlash(player, target)
  if target.dead or target:isRemoved() then return false end
  local hand = player:getCardIds("h")
  if #target:getCardIds("h") <= #hand then return false end
  for _, id in ipairs(hand) do
    if canUseIceSlash(player, target, { id }) then return true end
  end
  -- 两张材料会改变冰杀的花色，单张均不可用时仍可能有合法组合。
  -- 当前牌面与材料限制下，再增加材料不会产生新的花色或解除对子集中的禁用。
  for i, id in ipairs(hand) do
    for j = i + 1, #hand do
      if canUseIceSlash(player, target, { id, hand[j] }) then return true end
    end
  end
  return false
end

local function canDraw(player)
  return lostHp(player) > #player:getCardIds("h")
end

local function validMaterials(player, cards)
  if cards == nil or #cards == 0 then return false end
  local hand = player:getCardIds("h")
  local seen = {}
  for _, id in ipairs(cards) do
    if seen[id] or not table.contains(hand, id) then return false end
    seen[id] = true
  end
  return true
end

skill:addEffect(fk.EventPhaseStart, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and not target.dead and not player.dead
      and target.phase == Player.Finish
      and player:hasSkill(skill.name)
      and (canSlash(player, target) or canDraw(player))
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local choices = {}
    if canSlash(player, target) then table.insert(choices, SLASH) end
    if canDraw(player) then table.insert(choices, DRAW) end
    if #choices == 0 then return false end
    local choice = room:askToChoice(player, {
      choices = choices,
      all_choices = { SLASH, DRAW },
      cancelable = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin010_1-choice::" .. target.id,
    })
    if choice == DRAW and canDraw(player) then
      event:setCostData(self, { choice = DRAW })
      return true
    end
    if choice ~= SLASH or not canSlash(player, target) then return false end

    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = #player:getCardIds("h"),
      skill_name = skill.name,
      prompt = "#qiao__skill_jin010_1-cards:" .. target.id,
      cancelable = true,
    })
    if not validMaterials(player, cards) or not canUseIceSlash(player, target, cards) then
      return false
    end
    event:setCostData(self, { choice = SLASH, cards = cards })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self)
    if cost.choice == DRAW then
      local need = lostHp(player) - #player:getCardIds("h")
      if need > 0 then player:drawCards(need, skill.name) end
    elseif canSlash(player, target) and validMaterials(player, cost.cards) then
      C.useVirtualCard(player.room, player, ICE, cost.cards, { target }, skill.name, true,
        { bypass_times = true }, C.explicit({}, { names = { ICE }, min_targets = 1, max_targets = 1 }))
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin010_1"] = "伤逝",
  ["#qiao__skill_jin010_1-choice"] = "伤逝：在 %dest 的结束阶段，你可以选择一项",
  ["#qiao__skill_jin010_1-slash"] = "将任意张手牌当冰【杀】对其使用",
  ["#qiao__skill_jin010_1-draw"] = "摸牌至已损失的体力值",
  ["#qiao__skill_jin010_1-cards"] = "伤逝：选择合成冰【杀】的手牌",
}

return skill
