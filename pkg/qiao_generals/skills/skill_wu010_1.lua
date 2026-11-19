-- WU010 孙策 · 激昂
--
-- 自己指定或成为【决斗】或红色【杀】的目标后，可以摸一张；若该牌是转化牌，
-- 改为摸两张且本回合激昂失效。逐目标触发；按汉晋转化牌定义，须为含实体子牌的虚拟牌，
-- 不把所有虚拟牌或仅带 skillName 的牌都当作转化。
local skill = fk.CreateSkill {
  name = "qiao__skill_wu010_1",
}
skill.qiaoImplemented = true

local DISABLED_MARK = "qiao__skill_wu010_1-disabled-turn"

---@param card Card
---@return boolean
local function isTargetCard(card)
  if card == nil then return false end
  if card.trueName == "duel" then return true end
  return card.trueName == "slash" and card.color == Card.Red
end

---@param card Card
---@return boolean
local function isConverted(card)
  return card ~= nil and card:isVirtual() and #(card.subcards or {}) > 0
end

---@param player ServerPlayer
---@return integer
local function currentTurnId(player)
  local current = player.room.logic:getCurrentEvent()
  local turn = current and current:findParent(GameEvent.Turn, true)
  return turn and turn.id or 0
end

local function canTrigger(player, data)
  if not player:hasSkill(skill.name) or player.dead then return false end
  if not isTargetCard(data and data.card) then return false end
  return player:getMark(DISABLED_MARK) ~= currentTurnId(player)
end

local function invoke(self, player, data)
  local room = player.room
  local converted = isConverted(data.card)
  if converted then
    room:setPlayerMark(player, DISABLED_MARK, currentTurnId(player))
  end
  if player.dead then return end
  player:drawCards(converted and 2 or 1, skill.name)
end

-- 自己指定目标后：逐目标产生机会。
skill:addEffect(fk.TargetSpecified, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and canTrigger(player, data)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wu010_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    invoke(self, player, data)
  end,
})

-- 自己成为目标后。
skill:addEffect(fk.TargetConfirmed, {
  anim_type = "drawcard",
  can_trigger = function(self, event, target, player, data)
    return target == player and canTrigger(player, data)
  end,
  on_cost = function(self, event, target, player, data)
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_wu010_1-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    invoke(self, player, data)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu010_1"] = "激昂",
  [":qiao__skill_wu010_1"] = "当你指定或成为【决斗】或红色【杀】的目标后，你可以摸一张牌（若为转化牌，则多摸一张牌且本回合此技能失效）。",
  ["#qiao__skill_wu010_1-invoke"] = "激昂：你可以摸一张牌",
}

return skill
