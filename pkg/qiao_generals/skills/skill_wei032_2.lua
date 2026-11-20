-- WEI032 郭淮 · 疲攻
-- 主将技（☯️-1）：当你使用或打出基本牌时，可指定一名角色，其按座次
-- 将手牌交给其势力的其他角色各一张；不足时能给几张给几张。
local Invoke = require "packages.qiao.pkg.qiao_generals.util.invoke_targets"
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_wei032_2",
  tags = { Skill.MainPlace },
}
skill.qiaoImplemented = true

local function isBasic(card)
  return card ~= nil and (card.type == Card.TypeBasic
    or table.contains({ "slash", "jink", "peach", "qiao__jink", "qiao__peach" }, card.trueName or card.name))
end

local function giveToAllies(room, target)
  if target == nil or target.dead then return end
  local allies = table.filter(room:getPresentPlayers(), function(p)
    return p ~= target and not p:isRemoved() and H.compareKingdomWith(p, target)
  end)
  room:sortByAction(allies)
  for _, receiver in ipairs(allies) do
    if #target:getCardIds("h") == 0 then break end
    local id = room:askToCards(target, {
      min_num = 1, max_num = 1, cancelable = false,
      skill_name = skill.name,
      prompt = "#qiao__skill_wei032_2-give:" .. receiver.id,
    })[1]
    if id == nil or id == -1 or not table.contains(target:getCardIds("h"), id) then break end
    room:obtainCard(receiver, id, true, fk.ReasonGive, target, skill.name)
  end
end

local function triggerSpec(self, event, target, player, data)
  return target == player and not player.dead and player:hasSkill(skill.name)
    and isBasic(data.card)
end

local useSpec = {
  global = true,
  can_trigger = triggerSpec,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local chosen = Invoke.ask(room, player, {
      targets = room:getPresentPlayers(),
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_wei032_2-target",
      invoke_prompt = "#qiao__skill_wei032_2-invoke",
    })
    if #chosen == 0 then return false end
    event:setCostData(self, { tos = chosen })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local chosen = event:getCostData(self).tos
    local to = chosen and chosen[1]
    if to ~= nil then giveToAllies(room, to) end
  end,
}

skill:addEffect(fk.AfterCardUseDeclared, useSpec)
skill:addEffect(fk.CardResponding, useSpec)

Fk:loadTranslationTable {
  ["qiao__skill_wei032_2"] = "疲攻",
  ["#qiao__skill_wei032_2-invoke"] = "疲攻：你可以指定一名角色，其将手牌交给同势力其他角色",
  ["#qiao__skill_wei032_2-target"] = "疲攻：选择一名角色",
  ["#qiao__skill_wei032_2-give"] = "疲攻：选择一张手牌交出",
}

return skill
