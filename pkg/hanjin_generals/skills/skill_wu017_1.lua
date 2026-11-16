-- WU017 蒋钦 · 尚义
--
-- 规则依据：rules/generals/wu017-jiangqin.md。
-- 两个入口：
--   * 出牌阶段限一次：令一名其他角色观看你的手牌，然后你观看其所有暗置武将牌
--     和手牌，可弃其黑桃、梅花手牌至多各一张；
--   * 当你响应其他角色的牌后：目标改为该牌的使用者，其余相同。
-- 不采用“二选一查看”或交换手牌的版本；响应入口与使用／打出两条引擎路径
-- 都接入（fk.CardUseFinished 与 fk.CardRespondFinished）。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "hanjin__skill_wu017_1",
}
skill.hanjinImplemented = true

local ACTIVE_MARK = "hanjin__skill_wu017_1_active-phase"

---@param target ServerPlayer
---@return integer[]
local function blackSuitHand(target)
  return table.filter(target:getCardIds("h"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and (card.suit == Card.Spade or card.suit == Card.Club)
  end)
end

--- 先由 target 观看发动者手牌，再由发动者观看 target 的暗将和手牌，最后弃牌。
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
      prompt = "#hanjin__skill_wu017_1-myhand:" .. player.id,
    })
  end

  local mainHidden = target.general == "anjiang"
  local deputyHidden = target.deputyGeneral == "anjiang"
  if mainHidden or deputyHidden then
    H.viewGeneral(player, target, skill.name, mainHidden, deputyHidden)
  end

  local theirHand = target:getCardIds("h")
  if #theirHand > 0 then
    room:viewCards(player, {
      cards = theirHand,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wu017_1-theirhand:" .. target.id,
    })
  end

  local eligible = blackSuitHand(target)
  if #eligible == 0 then return end
  local chosen = room:askToChooseCards(player, {
    target = target,
    flag = { card_data = { { "可弃置", eligible } } },
    min = 0,
    max = math.min(2, #eligible),
    skill_name = skill.name,
    prompt = "#hanjin__skill_wu017_1-discard:" .. target.id,
    cancelable = true,
  }) or {}
  local seen, discard = {}, {}
  for _, id in ipairs(chosen) do
    local card = Fk:getCardById(id)
    if card ~= nil and table.contains(eligible, id) then
      local key = card.suit == Card.Spade and "spade" or "club"
      if not seen[key] then
        seen[key] = true
        table.insert(discard, id)
      end
    end
  end
  if #discard > 0 then room:throwCard(discard, skill.name, target, player) end
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#hanjin__skill_wu017_1-prompt",
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
    return room ~= nil and #room:getOtherPlayers(player, false) > 0
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
    prompt = "#hanjin__skill_wu017_1-response",
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
  ["hanjin__skill_wu017_1"] = "尚义",
  [":hanjin__skill_wu017_1"] =
    "出牌阶段限一次/当你响应其他角色的牌后，你可以令一名其他角色/其观看你的手牌，然后你观看其所有暗置武将牌和手牌，且你可以弃置其中每种黑色花色的手牌至多各一张。",
  ["#hanjin__skill_wu017_1-prompt"] = "尚义：选择一名其他角色观看你的手牌",
  ["#hanjin__skill_wu017_1-myhand"] = "尚义：观看 %src 的手牌",
  ["#hanjin__skill_wu017_1-theirhand"] = "尚义：观看 %src 的手牌",
  ["#hanjin__skill_wu017_1-discard"] = "尚义：可弃置 %src 黑桃、梅花手牌各至多一张",
  ["#hanjin__skill_wu017_1-response"] = "尚义：是否观看其暗置武将牌和手牌？",
}

return skill
