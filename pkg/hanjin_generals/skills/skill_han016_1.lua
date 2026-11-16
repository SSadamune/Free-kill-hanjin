-- HAN016A 刘宠 · 劲弩
--
-- 出牌阶段结束时，若本阶段使用过牌且全部为【杀】，或本阶段至少使用过两张
-- 牌且最后两张均不为【杀】，可以视为使用一张无距离限制的【杀】。
-- “使用历史”直接读取本阶段真实发生的 GameEvent.UseCard 事件，按事件 id
-- 排序：包括技能在非空闲时点使用的牌，也不受额外使用/不计次数影响。
-- 纯“打出”（GameEvent.RespondCard，例如响应决斗打出【杀】）不是“使用”，
-- 不进入本条件；使用【闪】这类真正的使用仍会生成 UseCard 事件。
-- 零用牌不满足任一分支。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__skill_han016_1",
}

local SLASH = "hanjin__slash"

--- 本阶段按真实事件顺序排列的、由 player 使用的牌。只统计 UseCard；
--- RespondCard 是打出，不是使用。
---@param room Room
---@param player ServerPlayer
---@return Card[]
local function phaseCardSequence(room, player)
  local events = room.logic:getEventsOfScope(GameEvent.UseCard, math.huge, function(event)
    return event.data ~= nil and event.data.from == player and event.data.card ~= nil
  end, Player.HistoryPhase)
  local cards = {}
  for _, event in ipairs(events) do
    table.insert(cards, event.data.card)
  end
  return cards
end

local function triggersFor(cards)
  if #cards == 0 then return false end
  local all_slash = true
  for _, card in ipairs(cards) do
    if card.trueName ~= "slash" then
      all_slash = false
      break
    end
  end
  if all_slash then return true end
  if #cards >= 2
    and cards[#cards].trueName ~= "slash"
    and cards[#cards - 1].trueName ~= "slash" then
    return true
  end
  return false
end

local function targetPolicy()
  return C.bypassDistance({ names = { SLASH } })
end

local function legalTargets(room, player)
  -- 这是技能视为使用，不占通常出杀次数；候选查询同样带上 bypass_times，
  -- 否则本阶段已出过【杀】时会被普通次数限制误挡。
  return C.candidates(room, player, Fk:cloneCard(SLASH), targetPolicy(), {
    bypass_times = true,
  })
end

skill:addEffect(fk.EventPhaseEnd, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.phase == Player.Play and not player.dead
      and triggersFor(phaseCardSequence(player.room, player))
      and #legalTargets(player.room, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han016_1-invoke",
    }) then
      return false
    end
    local targets = legalTargets(room, player)
    if #targets == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = targets,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han016_1-target",
      cancelable = false,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return false end
    event:setCostData(self, { to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to = cost.to
    if player.dead or to == nil or to.dead or to:isRemoved() then return end
    -- 技能视为使用不占通常出杀次数：目标校验与实际使用都带 bypass_times，
    -- 否则本阶段已出过【杀】时会在 targetFilter 的组合校验处被误挡。
    C.useVirtualCard(room, player, SLASH, nil, { to }, skill.name, true,
      { bypass_times = true }, targetPolicy())
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han016_1"] = "劲弩",
  [":hanjin__skill_han016_1"] = "出牌阶段结束时，若你此阶段使用过的牌均为【杀】，或使用的最后两张牌均不为【杀】，你可以视为使用一张无距离限制的【杀】。",
  ["#hanjin__skill_han016_1-invoke"] = "劲弩：你可以视为使用一张无距离限制的【杀】",
  ["#hanjin__skill_han016_1-target"] = "劲弩：选择【杀】的目标",
}

skill.hanjinImplemented = true

return skill
