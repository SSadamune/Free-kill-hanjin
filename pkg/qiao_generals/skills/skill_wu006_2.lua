-- WU006 大乔 · 流离
--
-- 当你成为其他角色使用【杀】的目标时，你可以弃置一张牌并将此【杀】转移
-- 给攻击范围内的另一名其他角色。
--
-- 转移目标只要求在大乔的攻击范围内，不要求在使用者的攻击范围内；排除
-- 【杀】的使用者本人。弃牌为发动消耗，取消选牌即不发动。目标变更通过
-- AimData:cancelCurrentTarget / addTarget 完成，是真实的目标转移。
local skill = fk.CreateSkill {
  name = "qiao__skill_wu006_2",
}
skill.qiaoImplemented = true

local W = require "packages.qiao.pkg.qiao_generals.util.wu_phases"

local function candidates(player, data, excludeIds)
  return table.filter(W.currentRoom(player):getPresentPlayers(), function(p)
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

local SELECT = "#qiao__skill_wu006_2_select"

local function allows(extra, card, to)
  local targets = extra and extra.targetsByCard[tostring(card)]
  return targets ~= nil and (to == nil or table.contains(targets, to.id))
end

skill:addAuxActiveSkill(SELECT, {
  card_num = 1,
  target_num = 1,
  include_equip = true,
  card_filter = function(self, player, id, selected, targets)
    return #selected == 0 and allows(self._extra_data, id, targets[1])
  end,
  target_filter = function(self, player, to_select, selected, cards)
    if #selected > 0 or #cards ~= 1 then return false end
    return allows(self._extra_data, cards[1], to_select)
  end,
})

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
    local targetsByCard = {}
    for _, id in ipairs(discardableCards(player)) do
      local targets = candidates(player, data, { id })
      if #targets > 0 then targetsByCard[tostring(id)] = table.map(targets, Util.IdMapper) end
    end
    if next(targetsByCard) == nil then return false end
    local ok, ret = room:askToUseActiveSkill(player, {
      skill_name = SELECT,
      prompt = "#qiao__skill_wu006_2-invoke",
      cancelable = true,
      extra_data = { skillName = skill.name, targetsByCard = targetsByCard },
    })
    if not ok or not ret or #ret.cards ~= 1 or #ret.targets ~= 1 then return false end
    local cardId, to = ret.cards[1], ret.targets[1]
    if not table.contains(discardableCards(player), cardId)
      or not table.contains(candidates(player, data, { cardId }), to) then return false end
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
  ["qiao__skill_wu006_2"] = "流离",
  ["#qiao__skill_wu006_2-invoke"] = "流离：弃置一张牌，将此【杀】转移给攻击范围内的另一名其他角色",
}

return skill
