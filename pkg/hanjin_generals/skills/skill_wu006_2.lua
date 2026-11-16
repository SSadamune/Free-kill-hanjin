-- WU006 大乔 · 流离
--
-- 当你成为其他角色使用【杀】的目标时，你可以弃置一张牌并将此【杀】转移
-- 给攻击范围内的另一名其他角色。
--
-- 转移目标只要求在大乔的攻击范围内，不要求在使用者的攻击范围内；排除
-- 【杀】的使用者本人。弃牌为发动消耗，取消选牌即不发动。目标变更通过
-- AimData:cancelCurrentTarget / addTarget 完成，是真实的目标转移。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu006_2",
}
skill.hanjinImplemented = true

local W = require "packages.hanjin.pkg.hanjin_generals.util.wu_phases"

local function candidates(player, data, excludeIds)
  return table.filter(W.currentRoom(player).alive_players, function(p)
    return p ~= player and p ~= data.from and not p:isRemoved()
      -- 转移目标不能是本次【杀】已指定的任何角色；这里不是追加目标。
      and not table.contains(data.use and data.use.tos or {}, p)
      -- 预判弃置该牌后的攻击范围（武器/坐骑）后再选目标，不先付费试探。
      and player:inMyAttackRange(p, nil, excludeIds)
      and not data.from:isProhibited(p, data.card)
  end)
end

local function discardableCards(player)
  return table.filter(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id)
  end)
end

--- 只有弃置后仍存在合法转移目标的牌才进入费用候选，取消不消耗。
local function eligibleCards(player, data)
  return table.filter(discardableCards(player), function(id)
    return #candidates(player, data, { id }) > 0
  end)
end

skill:addEffect(fk.TargetConfirming, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.cancelled or data.card == nil or data.card.trueName ~= "slash" then return false end
    if data.from == nil or data.from == player then return false end
    return #eligibleCards(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu006_2-invoke",
    }) then
      return false
    end

    local eligible = eligibleCards(player, data)
    if #eligible == 0 then return false end
    local cardId = room:askToChooseCard(player, {
      target = player,
      flag = "he",
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu006_2-card",
    })
    if cardId == nil or not table.contains(eligible, cardId) then return false end

    -- 先完成目标选择，再在 on_use 支付费用；取消选人不弃牌。
    local tos = candidates(player, data, { cardId })
    if #tos == 0 then return false end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1,
      max_num = 1,
      targets = tos,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu006_2-target",
      cancelable = true,
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return false end
    event:setCostData(self, { card = cardId, to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self) or {}
    local cardId, to = cost.card, cost.to
    if cardId == nil or to == nil or to.dead or to:isRemoved() then return end
    if not table.contains(discardableCards(player), cardId) then return end
    if not table.contains(candidates(player, data, { cardId }), to) then return end
    player.room:throwCard({ cardId }, skill.name, player, player)
    if player.dead then return end
    if data:cancelCurrentTarget() then
      data:addTarget(to)
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_wu006_2"] = "流离",
  ["#hanjin__skill_wu006_2-invoke"] = "流离：弃置一张牌，将此【杀】转移给攻击范围内的另一名其他角色",
  ["#hanjin__skill_wu006_2-card"] = "流离：弃置一张牌",
  ["#hanjin__skill_wu006_2-target"] = "流离：选择转移目标（你攻击范围内的另一名其他角色）",
}

return skill
