-- HAN016A 刘宠 · 威屯
--
-- 限定技。弃牌阶段开始前，若刘宠的手牌数为全场最多（并列最多也满足），
-- 可以跳过此阶段；随后对技能发动时选定的一组角色依次完整使用【桃园结义】
-- 和【五谷丰登】。两张牌共用同一组目标，不能分别重选。
-- 目标条件使用汉晋显式目标策略：允许自己、允许满血角色；独立的禁止使用、
-- 禁止指定仍由公共用牌入口复核。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__skill_han016_2",
  tags = { Skill.Limited },
}

local PEACH_GARDEN = "hanjin__god_salvation"
local HARVEST = "hanjin__amazing_grace"

local function handCount(player)
  return #player:getCardIds(Player.Hand)
end

--- 手牌最多（并列也算）。
---@param player ServerPlayer
---@return boolean
local function hasMostHandCards(player)
  local own = handCount(player)
  for _, p in ipairs(player.room.alive_players) do
    if p ~= player and handCount(p) > own then return false end
  end
  return true
end

--- 两张牌共同可指定的候选：显式目标允许自己/满血，独立禁用仍先排除。
---@param room Room
---@param player ServerPlayer
---@return ServerPlayer[]
local function candidateTargets(room, player)
  local garden = Fk:cloneCard(PEACH_GARDEN)
  local harvest = Fk:cloneCard(HARVEST)
  local ret = {}
  for _, p in ipairs(room.alive_players) do
    if p:isAlive() and not p:isRemoved()
      and not player:isProhibited(p, garden)
      and not player:isProhibited(p, harvest) then
      table.insert(ret, p)
    end
  end
  return ret
end

local function targetPolicy(cardName, count)
  return C.explicit({}, {
    names = { cardName },
    min_targets = count,
    max_targets = count,
  })
end

skill:addEffect(fk.EventPhaseChanging, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.phase == Player.Discard and not data.skipped and not player.dead
      and player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
      and hasMostHandCards(player)
      and #candidateTargets(player.room, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_han016_2-invoke",
    }) then
      return false
    end
    local targets = candidateTargets(room, player)
    if #targets == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = #targets,
      targets = targets,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han016_2-targets",
      cancelable = false,
    })
    if chosen == nil or #chosen == 0 then return false end
    event:setCostData(self, { tos = chosen })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local tos = cost.tos
    if player.dead or tos == nil or #tos == 0 then return end

    -- 跳过弃牌阶段；同一组目标随后分别用于两张牌。
    data.skipped = true

    C.useVirtualCard(room, player, PEACH_GARDEN, nil, tos, skill.name, true, nil,
      targetPolicy(PEACH_GARDEN, #tos))
    if player.dead then return end
    C.useVirtualCard(room, player, HARVEST, nil, tos, skill.name, true, nil,
      targetPolicy(HARVEST, #tos))
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han016_2"] = "威屯",
  [":hanjin__skill_han016_2"] = "限定技，弃牌阶段开始前，若你的手牌最多，你可以跳过此阶段，然后视为对任意名角色使用【桃园结义】和【五谷丰登】。",
  ["#hanjin__skill_han016_2-invoke"] = "威屯：你可以跳过弃牌阶段，并对一组角色使用【桃园结义】和【五谷丰登】",
  ["#hanjin__skill_han016_2-targets"] = "威屯：选择【桃园结义】和【五谷丰登】的共同目标",
}

skill.hanjinImplemented = true

return skill
