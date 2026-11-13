-- HAN012 蔡邕 · 博通
--
-- 规则基线：rules/standard-generals.md 汉区、rulebook/events/use-card.md、
-- rulebook/terms/card-op-terms/give.md、rulebook/terms/card-terms/GameCard.md。
-- 可以将四种花色各一张牌，或基本牌/锦囊牌/装备牌各一张牌（共 4 或 3 张
-- 自己的手牌或装备牌）当任意一种基本牌使用。
--
-- 仅支持使用，不支持单纯打出（enabled_at_response=false）。多张实体牌构成
-- 的虚拟牌花色/点数由引擎 addSubcards 按普通多子牌规则确定，不在此手算。
--
-- 使用结算结束（fk.CardUseFinished）时，实体牌仍在处理区；此技能可将仍
-- 留在处理区的子牌分配给任意名其他角色。一次 doYiji 完成一次正常给牌移动，
-- 不保留标记，也不永久占用这些牌。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han012_2",
}
skill.hanjinImplemented = true

--- 可作为转化目标的基本牌牌名（含属性【杀】）。
local BASIC_NAMES = {
  "hanjin__slash",
  "hanjin__fire__slash",
  "hanjin__thunder__slash",
  "hanjin__ice__slash",
  "hanjin__jink",
  "hanjin__peach",
  "hanjin__analeptic",
}
local BASIC_PATTERN = table.concat(BASIC_NAMES, ",")

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
  local room = player.room or Fk:currentRoom()
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
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

skill:addEffect("viewas", {
  pattern = BASIC_PATTERN,
  include_equip = true,
  prompt = "#hanjin__skill_han012_2-prompt",
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
  enabled_at_response = function() return false end,
})

skill:addEffect(fk.CardUseFinished, {
  anim_type = "support",
  is_delay_effect = true,
  can_trigger = function(self, event, target, player, data)
    if target ~= player then return false end
    if data.card == nil then return false end
    if data.card.skillName ~= skill.name
      and not table.contains(data.card.skillNames or {}, skill.name) then
      return false
    end
    local left = player.room:getSubcardsByRule(data.card, { Card.Processing })
    return #left > 0 and #otherTargets(player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han012_2-give-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local remaining = room:getSubcardsByRule(data.card, { Card.Processing })
    if #remaining == 0 then return end

    local targets = otherTargets(player)
    if #targets == 0 then return end

    -- 接受给牌后须把当前可给的子牌全部分配完；不允许只给一部分后取消。
    -- 每次选择一名其他角色及其获得的牌，最后统一一次 doYiji 完成一次正常
    -- 给牌移动。
    local list = {}
    while #remaining > 0 and #targets > 0 do
      local tos, chosen, ok = room:askToChooseCardsAndPlayers(player, {
        min_num = 1,
        max_num = 1,
        min_card_num = 1,
        max_card_num = #remaining,
        targets = targets,
        pattern = ".",
        skill_name = skill.name,
        prompt = "#hanjin__skill_han012_2-give",
        cancelable = false,
        expand_pile = remaining,
      })
      if not ok or #tos == 0 or #chosen == 0 then break end

      local to = tos[1]
      local valid = {}
      for _, id in ipairs(chosen) do
        if table.contains(remaining, id) and not table.contains(valid, id) then
          table.insert(valid, id)
        end
      end
      if #valid == 0 then break end

      list[to.id] = list[to.id] or {}
      table.insertTable(list[to.id], valid)
      for _, id in ipairs(valid) do table.removeOne(remaining, id) end
    end

    if next(list) ~= nil then
      room:doYiji(list, player, skill.name)
    end
  end,
})


Fk:loadTranslationTable {
  ["hanjin__skill_han012_2"] = "博通",
  [":hanjin__skill_han012_2"] = "你可以将四种花色或三种类别各一张牌当任意一种基本牌使用，然后你可以将这些牌交给其他角色。",
  ["#hanjin__skill_han012_2-prompt"] = "博通：选择四张四种花色的牌，或三张基本/锦囊/装备牌",
  ["#hanjin__skill_han012_2-give-invoke"] = "博通：你可以将以此法使用的牌交给其他角色",
  ["#hanjin__skill_han012_2-give"] = "博通：选择其他角色和要交给其的牌",
}

return skill
