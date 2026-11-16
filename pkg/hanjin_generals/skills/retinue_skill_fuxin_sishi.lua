-- 晋关联翼从 · 腹心死士
--
-- 规则基线：rules/generals/jin002-simashi.md“腹心死士专属技能”。
-- 同势力角色回合结束时，两项条件分别检查、可都执行：
--   1. 其仍有未发动的限定技：翼从持有者摸一张牌，然后交给其一张牌；
--   2. 其本回合发动过限定技：视为对其攻击范围内一名角色使用【杀】。
-- 限定技按真实技能标签与每次发动历史判断；本回合历史由模式级
-- jin_resources_rule 记录，不使用统领能力的全局限一记录。第二项目标范围
-- 属于当前回合角色（其攻击范围），不是翼从持有者；接入显式目标策略。
local B = require "packages.hanjin.pkg.hanjin_generals.util.jin_basic"
local R = require "packages.hanjin.pkg.hanjin_generals.util.jin_resources"
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local SLASH = "slash"
local skill = fk.CreateSkill {
  name = "hanjin__retinue_skill_fuxin_sishi",
}

--- 当前回合角色攻击范围内、可作为【杀】目标的角色。
---@param anchor ServerPlayer
---@param player ServerPlayer
---@return ServerPlayer[]
local function slashCandidates(anchor, player)
  local room = player.room
  if room == nil then return {} end
  return table.filter(room.alive_players, function(p)
    return p ~= player and p ~= anchor and not p.dead and not p:isRemoved()
      and anchor:inMyAttackRange(p)
      and not player:isProhibited(p, Fk:cloneCard(SLASH))
  end)
end

-- 条件一：摸一张牌，然后交给当前回合角色一张自己的牌。
skill:addEffect(fk.TurnEnd, {
  anim_type = "support",
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and not target.dead and not player.dead
      and player:hasSkill(skill.name)
      and B.sameKingdom(target, player)
      and R.hasUnusedLimitedSkill(target)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_fuxin_sishi-give-invoke:" .. target.id,
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    if target.dead then return end
    player:drawCards(1, skill.name)
    if player.dead or target.dead then return end
    -- 目标就是持有者时不能把牌交给自己；只执行可执行的摸一张。
    if target == player then return end
    local id = room:askToChooseCard(player, {
      target = player,
      flag = "he",
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_fuxin_sishi-give",
    })
    if id == nil or id == -1 or not table.contains(player:getCardIds("he"), id) then return end
    room:moveCardTo({ id }, Card.PlayerHand, target, fk.ReasonGive,
      skill.name, nil, false, player)
  end,
})

-- 条件二：本回合发动过限定技，视为对其攻击范围内一名角色使用【杀】。
skill:addEffect(fk.TurnEnd, {
  anim_type = "offensive",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if target == nil or target.dead or player.dead or not player:hasSkill(skill.name) then
      return false
    end
    if not B.sameKingdom(target, player) then return false end
    if #R.limitedUsedThisTurn(target) == 0 then return false end
    return #slashCandidates(target, player) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_fuxin_sishi-slash-invoke:" .. target.id,
    }) then
      return false
    end
    local candidates = slashCandidates(target, player)
    if #candidates == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = candidates,
      skill_name = skill.name,
      prompt = "#hanjin__retinue_skill_fuxin_sishi-slash",
      cancelable = true,
    })
    local to = chosen and chosen[1]
    if to == nil or not table.contains(candidates, to) then return false end
    event:setCostData(self, { to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local to = (event:getCostData(self) or {}).to
    if to == nil or player.dead or to.dead or to:isRemoved() then return end
    -- 显式条件：目标须在当前回合角色的攻击范围内，而不是翼从持有者。
    C.useVirtualCard(player.room, player, SLASH, nil, { to }, skill.name, true, nil,
      C.explicit({ in_attack_range_of = target.id, other_roles = true },
        { names = { SLASH } }))
  end,
})

skill.hanjinImplemented = true

Fk:loadTranslationTable {
  ["#hanjin__retinue_skill_fuxin_sishi-give-invoke"] = "腹心死士：其有未发动的限定技，你可以摸一张牌并交给其一张牌",
  ["#hanjin__retinue_skill_fuxin_sishi-give"] = "腹心死士：选择交给其的一张牌",
  ["#hanjin__retinue_skill_fuxin_sishi-slash-invoke"] = "腹心死士：其本回合发动过限定技，你可以视为对其攻击范围内一名角色使用【杀】",
  ["#hanjin__retinue_skill_fuxin_sishi-slash"] = "腹心死士：选择其攻击范围内的一名角色",
}

return skill
