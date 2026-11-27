-- WU014 鲁肃 · 缔盟
--
-- 出牌阶段限一次：选择两名其他角色，弃置等同于其手牌数差的牌，令其交换
-- 手牌；然后可以对其中手牌未增加的角色纵横“好施”，直到其下一个回合结束。
-- 手牌数相等时可以选择两名角色，直接交换，不产生弃牌事件。
-- “纵横好施”由预注册静态技能 `qiao__wu_dimeng_expiry` 在目标自己的下一个
-- 回合结束时按来源移除，不会因授予时所在回合（含额外回合）提前清理。
local skill = fk.CreateSkill {
  name = "qiao__skill_wu014_2",
}
skill.qiaoImplemented = true

local HAOSHI = "qiao__skill_wu014_1"
local EXPIRY = "qiao__wu_dimeng_expiry"
local GRANT_MARK = "qiao_wu_dimeng_granted"

local function ensureExpiry(room)
  if room == nil then return end
  if not room:hasSkill(EXPIRY) then
    room:addSkill(EXPIRY)
  end
end

local function others(player)
  local room = Fk:currentRoom()
  return table.filter(room:getPresentPlayers(), function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

local function canDiscard(player, id)
  return table.contains(player:getCardIds("he"), id) and not player:prohibitDiscard(id)
end

local function discardableCount(player)
  return #table.filter(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id)
  end)
end

local function handGap(a, b)
  return math.abs(a:getHandcardNum() - b:getHandcardNum())
end

local function canPay(a, b, minCards, maxCards)
  local diff = handGap(a, b)
  return a ~= b and diff >= minCards and diff <= maxCards
end

local function canPayAnyPair(player)
  local list = others(player)
  local owned = discardableCount(player)
  for i = 1, #list do
    for j = i + 1, #list do
      if canPay(list[i], list[j], 0, owned) then return true end
    end
  end
  return false
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__skill_wu014_2-prompt",
  target_num = 2,
  min_card_num = 0,
  max_card_num = function(self, player) return discardableCount(player) end,
  include_equip = true,
  max_phase_use_time = 1,
  card_filter = function(self, player, to_select, selected, targets)
    if not canDiscard(player, to_select) then return false end
    return #targets < 2 or #selected < handGap(targets[1], targets[2])
  end,
  target_filter = function(self, player, to_select, selected, cards)
    if to_select == player or not to_select:isAlive() or to_select:isRemoved() or #selected >= 2 then
      return false
    end
    local minCards, maxCards = #cards, discardableCount(player)
    if #selected == 1 then return canPay(selected[1], to_select, minCards, maxCards) end
    return table.find(others(player), function(other)
      return canPay(to_select, other, minCards, maxCards)
    end) ~= nil
  end,
  feasible = function(self, player, targets, cards)
    return #targets == 2 and #cards == handGap(targets[1], targets[2])
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase) and canPayAnyPair(player)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local tos = effect.tos or {}
    local a, b = tos[1], tos[2]
    if player == nil or player.dead or #tos ~= 2 or a == nil or b == nil
      or a == b or a == player or b == player then return end
    if not a:isAlive() or not b:isAlive() or a:isRemoved() or b:isRemoved() then return end

    local beforeA, beforeB = a:getHandcardNum(), b:getHandcardNum()
    local diff = math.abs(beforeA - beforeB)
    local costCards = effect.cards or {}
    if #costCards ~= diff then return end
    local seen = {}
    for _, id in ipairs(costCards) do
      if seen[id] or not canDiscard(player, id) then return end
      seen[id] = true
    end
    if #costCards > 0 then room:throwCard(costCards, skill.name, player, player) end
    if player.dead or a.dead or b.dead or a:isRemoved() or b:isRemoved() then return end

    room:swapAllCards(player, { a, b }, skill.name)
    if a.dead or b.dead then return end

    local eligible = {}
    if a:getHandcardNum() <= beforeA and not a:hasSkill(HAOSHI) then table.insert(eligible, a) end
    if b:getHandcardNum() <= beforeB and not b:hasSkill(HAOSHI) then table.insert(eligible, b) end
    if #eligible == 0 then return end

    local chosen = room:askToChoosePlayers(player, {
      targets = eligible,
      min_num = 1,
      max_num = #eligible,
      skill_name = skill.name,
      prompt = "#qiao__skill_wu014_2-target",
      cancelable = true,
    })
    for _, grantTo in ipairs(chosen or {}) do
      if table.contains(eligible, grantTo) and grantTo:isAlive() and not grantTo:isRemoved()
        and not grantTo:hasSkill(HAOSHI) then
        ensureExpiry(room)
        room:handleAddLoseSkills(grantTo, HAOSHI, skill.name, false, true)
        room:addPlayerMark(grantTo, GRANT_MARK, 1)
      end
    end
  end,
})

skill:addAcquireEffect(function(self, player)
  ensureExpiry(player.room or Fk:currentRoom())
end)

Fk:loadTranslationTable {
  ["qiao__skill_wu014_2"] = "缔盟",
  [":qiao__skill_wu014_2"] = "出牌阶段限一次，你可以选择两名其他角色并弃置等同其手牌数差的牌，令其交换手牌，你可以对其中手牌未增加的角色纵横“好施”。",
  ["#qiao__skill_wu014_2-prompt"] = "缔盟：选择两名其他角色及等同于其手牌数之差的弃牌",
  ["#qiao__skill_wu014_2-target"] = "缔盟：你可以对手牌未增加的角色纵横“好施”",
}

return skill
