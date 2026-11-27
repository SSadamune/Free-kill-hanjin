-- WEI022 卞夫人 · 挽危
-- 每回合限一次，当确定与你势力相同的角色因其他势力角色的获得或弃置而移动的牌时，
-- 你可以将此次移动的牌改为你的一张牌。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_wei022_1",
}
skill.qiaoImplemented = true

local function candidateIds(player, moveReason)
  return table.filter(player:getCardIds("he"), function(id)
    if moveReason == fk.ReasonDiscard then
      return not player:prohibitDiscard(id)
    end
    return true
  end)
end

local function matchMove(player, move)
  if move == nil or move.from == nil then return false end
  local actor
  if move.moveReason == fk.ReasonPrey then
    -- 获得牌的执行者是获得牌的一方（如【巧变】的 proposer 为原牌主，to 才是敌方获得者）。
    actor = move.to or move.proposer
  elseif move.moveReason == fk.ReasonDiscard then
    actor = move.proposer
  else
    return false
  end
  if actor == nil then return false end
  if not H.compareKingdomWith(move.from, player) then return false end
  -- 其他势力角色：含未确定势力角色（与同势力互补），队友之间获得或弃置不触发。
  if H.compareKingdomWith(actor, player) then return false end
  local hasHe = false
  for _, info in ipairs(move.moveInfo or {}) do
    if info.fromArea == Card.PlayerHand or info.fromArea == Card.PlayerEquip then
      hasHe = true
      break
    end
  end
  if not hasHe then return false end
  return #candidateIds(player, move.moveReason) > 0
end

local function matchingIndices(player, data)
  local list = {}
  for index, move in ipairs(data or {}) do
    if matchMove(player, move) then table.insert(list, index) end
  end
  return list
end

skill:addEffect(fk.BeforeCardsMove, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if player.dead or not player:hasSkill(skill.name) then return false end
    if player:usedSkillTimes(skill.name, Player.HistoryTurn) > 0 then return false end
    return #matchingIndices(player, data) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local indices = matchingIndices(player, data)
    if #indices == 0 then return false end
    local moveIndex = indices[1]
    if #indices > 1 then
      local choices = table.map(indices, function(i) return data[i].from end)
      local uniqueTargets = {}
      for _, p in ipairs(choices) do table.insertIfNeed(uniqueTargets, p) end
      if #uniqueTargets > 1 then
        local chosen = room:askToChoosePlayers(player, {
          targets = uniqueTargets,
          min_num = 1,
          max_num = 1,
          skill_name = skill.name,
          prompt = "#qiao__skill_wei022_1-target",
          cancelable = true,
        })
        if not chosen or #chosen ~= 1 then return false end
        for _, idx in ipairs(indices) do
          if data[idx].from == chosen[1] then moveIndex = idx; break end
        end
      end
    end
    local move = data[moveIndex]
    local valid = candidateIds(player, move.moveReason)
    if #valid == 0 then return false end
    local cards = room:askToCards(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#qiao__skill_wei022_1-card::" .. move.from.id,
      cancelable = true,
    })
    if type(cards) ~= "table" or #cards ~= 1 or not table.contains(valid, cards[1]) then
      return false
    end
    event:setCostData(self, { index = moveIndex, card = cards[1] })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local move = data and data[cost.index]
    local cardId = cost.card
    if move == nil or cardId == nil then return end
    local area = room:getCardArea(cardId)
    if room:getCardOwner(cardId) ~= player or (area ~= Card.PlayerHand and area ~= Card.PlayerEquip) then
      return
    end
    local replacement = {
      cardId = cardId,
      beforeCard = player:getVirtualEquip(cardId) or Fk:getCardById(cardId),
      fromArea = area,
    }
    -- 替代牌的移动可见性按替代牌实际来源与去向判定：
    -- 移至弃牌堆或来自装备区为公开；来自手牌区时置 moveVisible = false，
    -- 交由引擎按每位观察者的 isBuddy 及 VisibilitySkill（含旁观开关）各自判定，
    -- 避免把局部可见或受旁观限制的明牌提升为全局公开。
    local replacementVisible = (move.toArea == Card.DiscardPile or area == Card.PlayerEquip)
    -- 保留原移动中不属于手牌/装备区的条目（如混杂判定区牌）；全部手牌/装备条目统一替换为卞夫人的 1 张牌。
    local nonHe = {}
    for _, info in ipairs(move.moveInfo or {}) do
      if info.fromArea ~= Card.PlayerHand and info.fromArea ~= Card.PlayerEquip then
        table.insert(nonHe, info)
      end
    end
    if #nonHe == 0 then
      move.from = player
      move.moveInfo = { replacement }
      move.moveVisible = replacementVisible
      move.specialVisible = nil
      move.visiblePlayers = nil
    else
      move.moveInfo = nonHe
      table.insert(data, {
        moveInfo = { replacement },
        from = player,
        to = move.to,
        toArea = move.toArea,
        moveReason = move.moveReason,
        proposer = move.proposer,
        skillName = move.skillName,
        moveVisible = replacementVisible,
        specialName = move.specialName,
      })
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "挽危",
  [":" .. skill.name] = "每回合限一次，当确定与你势力相同的角色因其他势力角色的获得或弃置而移动的牌时，你可以将此次移动的牌改为你的一张牌。",
  ["#qiao__skill_wei022_1-target"] = "挽危：选择要为其替代失牌的同势力角色",
  ["#qiao__skill_wei022_1-card"] = "挽危：选择你的一张牌，替代 %dest 即将被获得或弃置的全部牌",
}

return skill
