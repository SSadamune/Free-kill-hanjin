-- HAN022 刘虞 · 绥抚
--
-- 每回合结束时（含自己回合）：存活角色中至少两名小势力角色本回合受过伤害时，
-- 可令当前回合角色将所有手牌置于牌堆顶，再由刘虞指定起点使用五谷丰登。
local H = require "packages.hegemony.util"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_han022_1",
}
skill.qiaoImplemented = true

local AG = "qiao__amazing_grace"
local ORDER = "qiao_han022_suifu_order"
local ORDER_RULE = "qiao__han022_suifu_order_rule"

local function smallDamagedCount(room)
  local events = room.logic:getActualDamageEvents(math.huge, function(event)
    local to = event.data and event.data.to
    return to ~= nil and to:isAlive() and not to:isRemoved()
      and H.isSmallKingdomPlayer(to) == true
  end, Player.HistoryTurn)
  local seen, count = {}, 0
  for _, event in ipairs(events) do
    local id = event.data.to.id
    if not seen[id] then seen[id] = true; count = count + 1 end
  end
  return count
end

local function orderFrom(start)
  local room = start.room
  local alive = table.filter(room.alive_players, function(p)
    return p:isAlive() and not p:isRemoved()
  end)
  table.sort(alive, function(a, b) return a.seat < b.seat end)
  local index = 1
  for i, p in ipairs(alive) do if p == start then index = i break end end
  local result = {}
  for i = 0, #alive - 1 do table.insert(result, alive[(index - 1 + i) % #alive + 1]) end
  return result
end

skill:addEffect(fk.TurnEnd, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and not player.dead and player:hasSkill(skill.name)
      and target ~= nil and not target.dead and #target:getCardIds(Player.Hand) > 0
      and smallDamagedCount(player.room) >= 2
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    if not room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_han022_1-invoke",
    }) then
      return false
    end
    local chosen = room:askToChoosePlayers(player, {
      min_num = 1, max_num = 1, targets = orderFrom(player),
      skill_name = skill.name, prompt = "#qiao__skill_han022_1-start",
      cancelable = false,
    })
    local start = chosen and chosen[1]
    if start == nil then return false end
    event:setCostData(self, { start = start })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local start = (event:getCostData(self) or {}).start
    if start == nil or target.dead or player.dead then return end
    local hand = target:getCardIds(Player.Hand)
    if #hand == 0 then return end
    room:moveCards {
      ids = hand, from = target, toArea = Card.DrawPile,
      moveReason = fk.ReasonPut, proposer = target,
      drawPilePosition = 1, moveVisible = false,
    }
    if not room:hasSkill(ORDER_RULE) then room:addSkill(ORDER_RULE) end
    local tos = orderFrom(start)
    C.useVirtualCard(room, player, AG, nil, tos, skill.name, false,
      { [ORDER] = { start_id = start.id } },
      C.explicit({}, { names = { AG }, min_targets = #tos, max_targets = #tos }))
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_han022_1"] = "绥抚",
  [":qiao__skill_han022_1"] = "每回合结束时，若存活角色之中有至少两名小势力角色于本回合受到过伤害，你可以令当前回合角色将所有手牌置于牌堆顶，你视为使用一张由你指定结算起点的【五谷丰登】。",
  ["#qiao__skill_han022_1-invoke"] = "绥抚：将当前回合角色手牌置于牌堆顶，并使用五谷丰登",
  ["#qiao__skill_han022_1-start"] = "绥抚：指定五谷丰登的结算起点",
}

return skill
