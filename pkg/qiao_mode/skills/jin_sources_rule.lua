-- 晋来源批次：复礼承诺与花色限制的房间级后续。
--
-- 复礼在 DrawNCards 只把“本次摸牌 + 来源张华”追加到房间承诺列表；AfterDrawNCards
-- 由本规则逐份兑现展示、限用、交给，不依赖复礼是否仍被持有。承诺按份保存，多个
-- 张华来源不会共用 target 的一个 bool。无手牌时整份清理，不把承诺留到以后。
local PROMISES = "qiao_jin016_1_promises"
local FULI = "qiao__skill_jin016_1"
local suitMark = require("packages.qiao.pkg.qiao_mode.skill_status").fuliSuitMark

local skill = fk.CreateSkill {
  name = "qiao__jin_sources_rule",
  tags = { Skill.Compulsory },
}

local function prohibited(player, card)
  return player ~= nil and card ~= nil and player:getMark(suitMark(card.suit)) > 0
end

local function promisesFor(room, target)
  local result = {}
  for _, promise in ipairs(room:getTag(PROMISES) or {}) do
    if promise.target == target.id then table.insert(result, promise) end
  end
  return result
end

local function takePromises(room, target)
  local mine, rest = {}, {}
  for _, promise in ipairs(room:getTag(PROMISES) or {}) do
    if promise.target == target.id then table.insert(mine, promise)
    else table.insert(rest, promise) end
  end
  if #mine > 0 then room:setTag(PROMISES, rest) end
  return mine
end

local function resolvePromises(room, target)
  local mine = takePromises(room, target)
  if #mine == 0 or target.dead or target:isRemoved() then return end
  for _, promise in ipairs(mine) do
    if target.dead or target:isRemoved() or #target:getCardIds("h") == 0 then return end
    local source = room:getPlayerById(promise.source)
    if source == nil or source.dead or source:isRemoved() then
      -- 来源已离场：仍按已展示的承诺处理限用，但没有可交给的对象。
      local id = room:askToCards(target, {
        min_num = 1, max_num = 1, cancelable = false, skill_name = FULI,
        prompt = "#qiao__skill_jin016_1-card",
      })[1]
      if id == nil or not table.contains(target:getCardIds("h"), id) then return end
      local card = Fk:getCardById(id)
      if card == nil then return end
      room:showCards({ id }, target)
      room:setPlayerMark(target, suitMark(card.suit), 1)
    else
      local id = room:askToCards(target, {
        min_num = 1, max_num = 1, cancelable = false, skill_name = FULI,
        prompt = "#qiao__skill_jin016_1-card",
      })[1]
      if id == nil or not table.contains(target:getCardIds("h"), id) then return end
      local card = Fk:getCardById(id)
      if card == nil then return end
      room:showCards({ id }, target)
      room:setPlayerMark(target, suitMark(card.suit), 1)
      if source ~= target and table.contains(target:getCardIds("h"), id) then
        room:obtainCard(source, id, true, fk.ReasonGive, target, FULI)
      end
    end
  end
end

skill:addEffect(fk.AfterDrawNCards, {
  global = true,
  can_trigger = function(self, event, target, player, data)
    return target ~= nil and target == player and #promisesFor(player.room, target) > 0
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    resolvePromises(player.room, target)
  end,
})

skill:addEffect(fk.TurnStart, {
  global = true,
  can_refresh = function(self, event, target, player)
    return target == player and player.seat == 1
  end,
  on_refresh = function(self, event, target, player)
    player.room:setTag(PROMISES, {})
  end,
})

skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    return prohibited(player, card)
  end,
  prohibit_response = function(self, player, card)
    return prohibited(player, card)
  end,
})

Fk:loadTranslationTable {
  ["qiao__jin_sources_rule"] = "晋来源限制",
}

return skill
