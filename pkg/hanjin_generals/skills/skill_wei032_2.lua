-- WEI032 郭淮 · 疲攻
-- 主将技（☯️-1）：当你使用或打出基本牌时，可指定一名角色，其按座次
-- 将手牌交给其势力的其他角色各一张；不足时能给几张给几张。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "hanjin__skill_wei032_2",
  tags = { Skill.MainPlace },
}
skill.hanjinImplemented = true

local function isBasic(card)
  return card ~= nil and (card.type == Card.TypeBasic
    or table.contains({ "slash", "jink", "peach", "hanjin__jink", "hanjin__peach" }, card.trueName or card.name))
end

local function giveToAllies(room, target)
  if target == nil or target.dead then return end
  local allies = table.filter(room.alive_players, function(p)
    return p ~= target and not p:isRemoved() and H.compareKingdomWith(p, target)
  end)
  room:sortByAction(allies)
  for _, receiver in ipairs(allies) do
    if #target:getCardIds("h") == 0 then break end
    local id = room:askToChooseCard(target, {
      target = target,
      flag = "h",
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei032_2-give:" .. receiver.id,
    })
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
    return player.room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei032_2-invoke",
    })
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local chosen = room:askToChoosePlayers(player, {
      targets = room.alive_players,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#hanjin__skill_wei032_2-target",
    })
    local to = chosen and chosen[1]
    if to ~= nil then giveToAllies(room, to) end
  end,
}

skill:addEffect(fk.AfterCardUseDeclared, useSpec)
skill:addEffect(fk.CardResponding, useSpec)

Fk:loadTranslationTable {
  ["hanjin__skill_wei032_2"] = "疲攻",
  ["#hanjin__skill_wei032_2-invoke"] = "疲攻：你可以指定一名角色，其将手牌交给同势力其他角色",
  ["#hanjin__skill_wei032_2-target"] = "疲攻：选择一名角色",
  ["#hanjin__skill_wei032_2-give"] = "疲攻：选择一张手牌交出",
}

return skill
