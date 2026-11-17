-- WEI024 常令（军令）
-- 准备阶段：将一张手牌交给一名其他势力角色，对其发起一次军令。其执行则
-- 自己摸一张；不执行则本回合摸牌阶段多摸三张。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill { name = "qiao__skill_wei024_1" }
skill.qiaoImplemented = true

local EXTRA = "qiao_wei024_extra_draw"

local function knownKingdom(kingdom)
  return type(kingdom) == "string" and kingdom ~= "" and kingdom ~= "unknown"
end

local function otherFaction(player, target)
  return target ~= nil and not target.dead and not target:isRemoved()
    and target ~= player and knownKingdom(player.kingdom) and knownKingdom(target.kingdom)
    and not H.compareKingdomWith(player, target)
end

skill:addEffect(fk.EventPhaseStart, {
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player.phase == Player.Start
      and not player:isKongcheng()
      and table.find(player.room.alive_players, function(p) return otherFaction(player, p) end) ~= nil
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local tos = room:askToChoosePlayers(player, {
      targets = table.filter(room.alive_players, function(p) return otherFaction(player, p) end),
      min_num = 1, max_num = 1, skill_name = skill.name,
      prompt = "#qiao__wei024_ask_target", cancelable = true,
    })
    if tos == nil or #tos == 0 then return false end
    local cards = room:askToCards(player, {
      min_num = 1, max_num = 1, include_equip = false,
      skill_name = skill.name, prompt = "#qiao__wei024_ask_card", cancelable = true,
    })
    if cards == nil or #cards == 0 then return false end
    event:setCostData(self, { to = tos[1], card = cards[1] })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self)
    local to = cost.to
    if to == nil or to.dead then return end
    room:obtainCard(to, cost.card, true, fk.ReasonGive, player, skill.name)
    local executed = H.askToCommand(player, {
      tos = { to },
      skill_name = skill.name,
    })
    if executed then
      if not player.dead then player:drawCards(1, skill.name) end
    else
      room:addPlayerMark(player, EXTRA, 3)
    end
  end,
})

skill:addEffect(fk.DrawNCards, {
  can_refresh = function(self, event, target, player, data)
    return target == player and player:getMark(EXTRA) > 0
  end,
  on_refresh = function(self, event, target, player, data)
    data.n = data.n + player:getMark(EXTRA)
  end,
})

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return target == player and player:getMark(EXTRA) > 0
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:setPlayerMark(player, EXTRA, 0)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei024_1"] = "常令",
  [":qiao__skill_wei024_1"] = "准备阶段，你可以将一张手牌交给一名其他势力角色，对其发起一次“军令”。若其执行，你摸一张牌；若其不执行，你于本回合摸牌阶段多摸三张牌。",
  ["#qiao__wei024_ask_target"] = "常令：选择一名其他势力角色",
  ["#qiao__wei024_ask_card"] = "常令：选择一张手牌交给其",
}

return skill
