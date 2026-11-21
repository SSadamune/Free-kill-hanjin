-- WU017 蒋钦 · 尚义
--
-- 规则依据：docs/rules/generals/wu017-jiangqin.md。
-- 两个入口：
--   * 出牌阶段限一次：令一名其他角色观看你的手牌，然后你观看其所有暗置武将牌
--     和手牌，可弃其黑桃、梅花手牌至多各一张；
--   * 当你响应其他角色的牌后：目标改为该牌的使用者，其余相同。
-- 不采用“二选一查看”或交换手牌的版本；响应入口与使用／打出两条引擎路径
-- 都接入（fk.CardUseFinished 与 fk.CardRespondFinished）。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu017_1",
}
skill.qiaoImplemented = true

local ACTIVE_MARK = "qiao__skill_wu017_1_active-phase"

local DISCARD = "#qiao__skill_wu017_1-confirm-discard"
local END_CHOICE = "#qiao__skill_wu017_1-end"

local function isBlackSuit(suit)
  return suit == Card.Spade or suit == Card.Club
end

skill.extra = {
  choiceFilter = function(cards, choice, extra_data)
    if choice == END_CHOICE then return true end
    if choice ~= DISCARD or #cards < 1 or #cards > 2 then return false end
    local spades = extra_data.spades
    return #cards == 1 or table.contains(spades, cards[1]) ~= table.contains(spades, cards[2])
  end,
}

--- 先由目标看发动者的手牌，再由发动者看目标的暗将并在手牌面板中决定弃牌。
---@param player ServerPlayer
---@param target ServerPlayer
local function resolveShangyi(player, target)
  local room = player.room
  if player.dead or target == nil or target == player
    or target.dead or target:isRemoved() then
    return
  end

  local myHand = player:getCardIds("h")
  if #myHand > 0 then
    room:viewCards(target, {
      cards = myHand,
      skill_name = skill.name,
      prompt = "#qiao__skill_wu017_1-myhand:" .. player.id,
    })
  end

  local mainHidden = target.general == "anjiang"
  local deputyHidden = target.deputyGeneral == "anjiang"
  if mainHidden or deputyHidden then
    H.viewGeneral(player, target, skill.name, mainHidden, deputyHidden)
  end

  if player.dead or target.dead or target:isRemoved() then return end
  local hand = target:getCardIds(Player.Hand)
  if #hand == 0 then return end
  local candidates, spades = {}, {}
  for _, id in ipairs(hand) do
    local suit = Fk:getCardById(id).suit
    if isBlackSuit(suit) and not target:prohibitDiscard(id) then
      table.insert(candidates, id)
      if suit == Card.Spade then table.insert(spades, id) end
    end
  end

  local chosen, choice = room:askToChooseCardsAndChoice(player, {
    cards = candidates,
    all_cards = hand,
    choices = { END_CHOICE, DISCARD },
    min_num = 0, max_num = math.min(2, #candidates),
    skill_name = skill.name,
    prompt = "#qiao__skill_wu017_1-discard:" .. target.id,
    filter_skel_name = skill.name,
    extra_data = { spades = spades },
  })
  if choice ~= DISCARD or not chosen or #chosen < 1 or #chosen > 2
    or player.dead or target.dead or target:isRemoved() then return end

  local currentHand = target:getCardIds(Player.Hand)
  local seen = {}
  for _, id in ipairs(chosen) do
    if not table.contains(candidates, id) or not table.contains(currentHand, id)
      or target:prohibitDiscard(id) then return end
    local suit = Fk:getCardById(id).suit
    if not isBlackSuit(suit) or seen[suit] then return end
    seen[suit] = true
  end
  room:throwCard(chosen, skill.name, target, player)
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__skill_wu017_1-prompt",
  target_num = 1,
  card_num = 0,
  card_filter = Util.FalseFunc,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and not to_select.dead and not to_select:isRemoved()
  end,
  can_use = function(self, player)
    if player == nil or player.dead or player.phase ~= Player.Play then return false end
    if not player:hasSkill(skill.name) then return false end
    if player:getMark(ACTIVE_MARK) ~= 0 then return false end
    local room = Fk:currentRoom()
    return room ~= nil and table.find(room:getPresentPlayers(), function(other)
      return other ~= player
    end) ~= nil
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or player.dead or target == nil then return end
    room:addPlayerMark(player, ACTIVE_MARK, 1)
    resolveShangyi(player, target)
  end,
})

--- 响应其他角色的牌后：响应事件的 from 即目标。
---@param player ServerPlayer
---@param data table
---@return ServerPlayer?
local function responseSource(player, data)
  if data == nil or data.card == nil then return nil end
  local respond = data.responseToEvent
  local source = respond and respond.from or nil
  if source == nil or source == player or source.dead or source:isRemoved() then
    return nil
  end
  return source
end

local function canRespond(self, event, target, player, data)
  return target == player and player:hasSkill(skill.name)
    and responseSource(player, data) ~= nil
end

local function onRespondCost(self, event, target, player, data)
  return player.room:askToSkillInvoke(player, {
    skill_name = skill.name,
    prompt = "#qiao__skill_wu017_1-response",
  })
end

local function onRespondUse(self, event, target, player, data)
  local source = responseSource(player, data)
  if source ~= nil then resolveShangyi(player, source) end
end

skill:addEffect(fk.CardUseFinished, {
  can_trigger = canRespond,
  on_cost = onRespondCost,
  on_use = onRespondUse,
})

skill:addEffect(fk.CardRespondFinished, {
  can_trigger = canRespond,
  on_cost = onRespondCost,
  on_use = onRespondUse,
})

Fk:loadTranslationTable {
  ["qiao__skill_wu017_1"] = "尚义",
  [":qiao__skill_wu017_1"] =
    "出牌阶段限一次/当你响应其他角色的牌后，你可以令一名其他角色/其观看你的手牌，然后你观看其所有暗置武将牌和手牌，且你可以弃置其中每种黑色花色的手牌至多各一张。",
  ["#qiao__skill_wu017_1-prompt"] = "尚义：选择一名其他角色观看你的手牌",
  ["#qiao__skill_wu017_1-myhand"] = "尚义：观看 %src 的手牌",
  ["#qiao__skill_wu017_1-discard"] = "尚义：观看 %src 的手牌，可弃置其中黑桃、梅花各至多一张",
  [DISCARD] = "弃置",
  [END_CHOICE] = "结束观看",
  ["#qiao__skill_wu017_1-response"] = "尚义：是否观看其暗置武将牌和手牌？",
}

return skill
