-- HAN012 蔡邕 · 博通
--
-- 规则基线：docs/rules/standard-generals.md 汉区、rulebook/events/use-card.md、
-- rulebook/terms/card-op-terms/give.md、rulebook/terms/card-terms/GameCard.md。
-- 可以将四种花色各一张牌，或基本牌/锦囊牌/装备牌各一张牌（共 4 或 3 张
-- 自己的手牌或装备牌）当任意一种基本牌使用。
--
-- 支持普通用牌和效果用牌请求，不支持单纯打出。多张实体牌构成
-- 的虚拟牌花色/点数由引擎 addSubcards 按普通多子牌规则确定，不在此手算。
--
-- 使用结算结束（fk.CardUseFinished）时，只询问是否将仍在处理区的
-- 全部实体子牌交给选定的一名其他角色。
local Invoke = require "packages.qiao.pkg.qiao_generals.util.invoke_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_han012_2",
}
skill.qiaoImplemented = true

--- 可作为转化目标的基本牌牌名（含属性【杀】）。
local BASIC_NAMES = {
  "qiao__slash",
  "qiao__fire__slash",
  "qiao__thunder__slash",
  "qiao__ice__slash",
  "qiao__jink",
  "qiao__peach",
  "qiao__analeptic",
}
local BASIC_PATTERN = "slash,jink,peach,analeptic|.|.|.|" .. table.concat(BASIC_NAMES, ",")

---@param id integer
---@return Card
local function rawCard(id)
  return Fk:getCardById(id, true)
end

--- 取一张牌在选择者处的有效牌面信息（应用锁视技的花色/类别转化）。
---@param player ServerPlayer | ClientPlayer
---@param id integer
---@return Card
local function effectiveCard(player, id)
  local room = Fk:currentRoom()
  return (room and room:filterCard(id, player)) or rawCard(id)
end

---@param player ServerPlayer | ClientPlayer
---@param ids integer[]
---@return boolean
local function distinctSuits(player, ids)
  local seen = {}
  for _, id in ipairs(ids) do
    local suit = effectiveCard(player, id).suit
    if seen[suit] then return false end
    seen[suit] = true
  end
  return true
end

---@param player ServerPlayer | ClientPlayer
---@param ids integer[]
---@return boolean
local function distinctTypes(player, ids)
  local seen = {}
  for _, id in ipairs(ids) do
    local cardType = effectiveCard(player, id).type
    if seen[cardType] then return false end
    seen[cardType] = true
  end
  return true
end

--- 4 张为四种花色各一张，或 3 张为三种类别各一张。
---@param player ServerPlayer | ClientPlayer
---@param ids integer[]
---@return boolean
local function isFormSet(player, ids)
  if #ids == 4 then return distinctSuits(player, ids) end
  if #ids == 3 then return distinctTypes(player, ids) end
  return false
end

--- 当前选择是否仍可能补成合法组合，用于避免选牌死路。
---@param player ServerPlayer | ClientPlayer
---@param ids integer[]
---@return boolean
local function canExtend(player, ids)
  if #ids > 4 then return false end
  return distinctSuits(player, ids) or (#ids <= 3 and distinctTypes(player, ids))
end

--- 可接收牌的其他存活角色。
---@param player ServerPlayer
---@return ServerPlayer[]
local function otherTargets(player)
  local room = player.room
  return table.filter(room:getPresentPlayers(), function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

skill:addEffect("viewas", {
  pattern = BASIC_PATTERN,
  include_equip = true,
  prompt = "#qiao__skill_han012_2-prompt",
  interaction = function(self, player)
    local choices = player:getViewAsCardNames(self.name, BASIC_NAMES)
    if #choices == 0 then return nil end
    return UI.CardNameBox { choices = choices, all_choices = BASIC_NAMES }
  end,
  card_filter = function(self, player, to_select, selected)
    if table.contains(selected or {}, to_select) then return false end
    if not table.contains(player:getCardIds("he"), to_select) then return false end
    return canExtend(player, table.connect(selected or {}, { to_select }))
  end,
  feasible = function(self, player, selected_targets, selected_cards)
    return isFormSet(player, selected_cards or {})
  end,
  view_as = function(self, player, cards)
    local name = self.interaction and self.interaction.data
    if name == nil or not table.contains(BASIC_NAMES, name) then return nil end
    if not isFormSet(player, cards or {}) then return nil end
    local card = Fk:cloneCard(name)
    card:addSubcards(cards)
    card.skillName = skill.name
    return card
  end,
  -- 博通只允许「使用」，不能作为响应打出。
  enabled_at_response = function(self, player, response) return not response end,
})

skill:addEffect(fk.CardUseFinished, {
  anim_type = "support",
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player or player:isRemoved() then return false end
    if data.card == nil then return false end
    if data.card.skillName ~= skill.name
      and not table.contains(data.card.skillNames or {}, skill.name) then
      return false
    end
    local left = player.room:getSubcardsByRule(data.card, { Card.Processing })
    return #left > 0 and #otherTargets(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local remaining = room:getSubcardsByRule(data.card, { Card.Processing })
    local targets = otherTargets(player)
    if #remaining == 0 or #targets == 0 then return false end

    local chosen = Invoke.ask(room, player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_han012_2-give",
      invoke_prompt = "#qiao__skill_han012_2-give-only::" .. targets[1].id,
    })
    if #chosen == 0 then return false end
    event:setCostData(self, { tos = chosen })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local to = event:getCostData(self).tos[1]
    if not table.contains(otherTargets(player), to) then return end
    local remaining = room:getSubcardsByRule(data.card, { Card.Processing })
    if #remaining > 0 then
      room:moveCardTo(remaining, Card.PlayerHand, to, fk.ReasonGive, skill.name, nil, true, player)
    end
  end,
})


Fk:loadTranslationTable {
  ["qiao__skill_han012_2"] = "博通",
  [":qiao__skill_han012_2"] = "你可以将四种花色或三种类别各一张牌当任意一种基本牌使用，然后你可以将这些牌交给其他角色。",
  ["#qiao__skill_han012_2-prompt"] = "博通：选择四张四种花色的牌，或三张基本/锦囊/装备牌",
  ["#qiao__skill_han012_2-give"] = "博通：选择一名其他角色，将这些牌交给其",
  ["#qiao__skill_han012_2-give-only"] = "博通：是否将这些牌交给 %dest？",
}

return skill
