-- HAN011 唐姬 · 哀舞
--
-- 规则基线：rules/standard-generals.md 汉区 HAN011、rulebook/events/damage.md、
-- rulebook/terms/card-op-terms/discard.md。每回合限一次，当其他角色受到伤害
-- 后（按伤害事件一次，不按伤害点数多次），你可以弃置至少一张牌；然后其可以
-- 弃置至少一张牌。若你与其共计弃置至少三张，你与其各回复1点体力。
--
-- 你的弃牌是发动消耗：取消弃牌即不发动；其弃牌是后续可选效果。
local skill = fk.CreateSkill {
  name = "hanjin__skill_han011_1",
}
skill.hanjinImplemented = true

---@param player ServerPlayer
---@return integer[]
local function legalDiscardCards(player)
  return table.filter(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id)
  end)
end

---@param player ServerPlayer
---@return integer
local function discardableCount(player)
  return #legalDiscardCards(player)
end

skill:addEffect(fk.Damaged, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target ~= player
      and player:hasSkill(skill.name)
      and not player.dead
      and target:isAlive() and not target:isRemoved()
      and player:usedSkillTimes(skill.name, Player.HistoryTurn) == 0
      and discardableCount(player) > 0
      and data.damage ~= nil and data.damage > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    -- 只选择消耗牌，不在此移动；由 on_use 在技能明置后支付。
    local discarded = room:askToDiscard(player, {
      min_num = 1,
      max_num = discardableCount(player),
      include_equip = true,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han011_1-discard",
      cancelable = true,
      skip = true,
    })
    if #discarded == 0 then return false end
    event:setCostData(self, { cards = discarded })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local legal = legalDiscardCards(player)
    local paid = {}
    for _, id in ipairs(cost.cards or {}) do
      if table.contains(legal, id) and not table.contains(paid, id) then table.insert(paid, id) end
    end
    if #paid == 0 then return end
    room:throwCard(paid, skill.name, player, player)
    local total = #paid

    -- 受到伤害的角色可以再弃置至少一张；其取消不影响已经支付的消耗。
    if target:isAlive() and not target:isRemoved() then
      local count = discardableCount(target)
      if count > 0 then
        local discarded = room:askToDiscard(target, {
          min_num = 1,
          max_num = count,
          include_equip = true,
          skill_name = skill.name,
          prompt = "#hanjin__skill_han011_1-target_discard",
          cancelable = true,
        })
        total = total + #discarded
      end
    end

    if total >= 3 then
      if player:isAlive() and not player:isRemoved() then
        room:recover { who = player, num = 1, recoverBy = player, skillName = skill.name }
      end
      if target:isAlive() and not target:isRemoved() then
        room:recover { who = target, num = 1, recoverBy = player, skillName = skill.name }
      end
    end
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han011_1"] = "哀舞",
  [":hanjin__skill_han011_1"] = "每回合限一次，当其他角色受到伤害后，你可以弃置至少一张牌，然后其可以弃置至少一张牌，若你与其共计弃置的牌数达到三张，你与其各回复1点体力。",
  ["#hanjin__skill_han011_1-discard"] = "哀舞：弃置至少一张牌（发动消耗）",
  ["#hanjin__skill_han011_1-target_discard"] = "哀舞：你可以弃置至少一张牌",
}

return skill
