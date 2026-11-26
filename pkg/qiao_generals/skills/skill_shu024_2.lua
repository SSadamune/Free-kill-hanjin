-- SHU024 法正 · 恩怨
-- 锁定技，其他角色交给你至少两张牌后，令其摸一张牌；
-- 当你受到其他角色的伤害后，令其需展示并交给你一张红桃牌，否则失去1点体力。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_shu024_2",
  tags = { Skill.Compulsory },
}
skill.qiaoImplemented = true

local function collectGivers(player, data)
  local counts = {}
  local order = {}
  for _, move in ipairs(data or {}) do
    if move.to == player and move.moveReason == fk.ReasonGive and #(move.moveInfo or {}) > 0 then
      local giver = move.from or move.proposer
      if giver ~= nil and giver ~= player then
        if counts[giver] == nil then
          counts[giver] = 0
          table.insert(order, giver)
        end
        counts[giver] = counts[giver] + #move.moveInfo
      end
    end
  end
  local result = {}
  for _, giver in ipairs(order) do
    if counts[giver] >= 2 and RemovedTargets.isPresent(giver) then
      table.insert(result, giver)
    end
  end
  return result
end

-- 恩：其他角色一次交给你至少两张牌后，令其摸一张牌。
skill:addEffect(fk.AfterCardsMove, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return RemovedTargets.isPresent(player) and player:hasSkill(skill.name)
      and #collectGivers(player, data) > 0
  end,
  on_trigger = function(self, event, target, player, data)
    local givers = collectGivers(player, data)
    player.room:sortByAction(givers)
    for _, giver in ipairs(givers) do
      if not RemovedTargets.isPresent(player) or not player:hasSkill(skill.name) then break end
      if RemovedTargets.isPresent(giver) then
        event:setCostData(self, { giver = giver })
        self:doCost(event, target, player, data)
      end
    end
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local cost = event:getCostData(self) or {}
    if RemovedTargets.isPresent(cost.giver) then
      cost.giver:drawCards(1, skill.name)
    end
  end,
})

-- 怨：受到其他角色的伤害后（每次伤害事件触发一次），令来源展示并交一张红桃牌，否则失去 1 点体力。
skill:addEffect(fk.Damaged, {
  anim_type = "masochism",
  can_trigger = function(self, event, target, player, data)
    return target == player and RemovedTargets.isPresent(player) and player:hasSkill(skill.name)
      and data.from ~= nil and data.from ~= player and RemovedTargets.isPresent(data.from)
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local from = data.from
    if not RemovedTargets.isPresent(from) or not RemovedTargets.isPresent(player) then return end
    local hearts = table.filter(from:getCardIds("he"), function(id)
      local c = Fk:getCardById(id)
      return c ~= nil and c.suit == Card.Heart
    end)
    local chosen
    if #hearts > 0 then
      chosen = room:askToCards(from, {
        min_num = 1,
        max_num = 1,
        include_equip = true,
        pattern = ".|.|heart",
        skill_name = skill.name,
        prompt = "#qiao__skill_shu024_2-heart::" .. player.id,
        cancelable = true,
      })
    end
    if type(chosen) == "table" and #chosen == 1 and table.contains(hearts, chosen[1]) then
      from:showCards(chosen)
      if RemovedTargets.isPresent(player) and RemovedTargets.isPresent(from)
        and table.contains(from:getCardIds("he"), chosen[1]) then
        room:obtainCard(player, chosen, true, fk.ReasonGive, from, skill.name)
      end
    elseif RemovedTargets.isPresent(from) then
      room:loseHp(from, 1, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "恩怨",
  [":" .. skill.name] = "锁定技，其他角色交给你至少两张牌后，令其摸一张牌；当你受到其他角色的伤害后，令其需展示并交给你一张红桃牌，否则失去1点体力。",
  ["#qiao__skill_shu024_2-heart"] = "恩怨：请展示并交给 %dest 一张红桃牌，否则失去1点体力",
}

return skill
