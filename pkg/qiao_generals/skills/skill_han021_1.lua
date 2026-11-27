-- HAN021 曹节 · 守玺
-- 与你势力相同的角色装备区的一张牌被其他势力角色不因弃置而移动时，
-- 你可以弃置一张同花色的牌并防止之。
-- 多张同势力装备牌同时不因弃置而移动时，逐张判定并可分别弃置同花色牌防止。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill {
  name = "qiao__skill_han021_1",
}
skill.qiaoImplemented = true

local function moveActor(move, parent, cardId)
  if move.moveReason == fk.ReasonPrey then
    return move.to or move.proposer
  end
  if move.proposer then return move.proposer end
  -- 引擎将用牌／打出的材料移至处理区时省略 proposer。只认该次动作本身的材料。
  if move.toArea == Card.Processing and parent
    and ((move.moveReason == fk.ReasonUse and parent.event == GameEvent.UseCard)
      or (move.moveReason == fk.ReasonResponse and parent.event == GameEvent.RespondCard))
    and table.contains(Card:getIdList(parent.data.card), cardId) then
    return parent.data.customFrom or parent.data.from
  end
end

local function hasSuitDiscardable(player, suit)
  if suit == nil or suit == Card.NoSuit then return false end
  return table.find(player:getCardIds("he"), function(id)
    local card = Fk:getCardById(id)
    return card ~= nil and card.suit == suit and not player:prohibitDiscard(id)
  end) ~= nil
end

local function collectEntries(player, data)
  local entries = {}
  local moving = player.room.logic:getCurrentEvent():findParent(GameEvent.MoveCards, true)
  for _, move in ipairs(data or {}) do
    if move.from ~= nil and move.moveReason ~= fk.ReasonDiscard
      and H.compareKingdomWith(move.from, player) then
      for _, info in ipairs(move.moveInfo or {}) do
        if info.fromArea == Card.PlayerEquip then
          local actor = moveActor(move, moving and moving.parent, info.cardId)
          if actor and not H.compareKingdomWith(actor, player) then
            local card = move.from:getVirtualEquip(info.cardId) or Fk:getCardById(info.cardId)
            if card ~= nil and card.suit ~= Card.NoSuit then
              table.insert(entries, {
                move = move,
                from = move.from,
                cardId = info.cardId,
                suit = card.suit,
                suitString = card:getSuitString(),
                logString = card:toLogString(),
              })
            end
          end
        end
      end
    end
  end
  return entries
end

skill:addEffect(fk.BeforeCardsMove, {
  anim_type = "defensive",
  can_trigger = function(self, event, target, player, data)
    if player.dead or not player:hasSkill(skill.name) then return false end
    for _, entry in ipairs(collectEntries(player, data)) do
      if hasSuitDiscardable(player, entry.suit) then return true end
    end
    return false
  end,
  on_trigger = function(self, event, target, player, data)
    local entries = collectEntries(player, data)
    for _, entry in ipairs(entries) do
      if player.dead or not player:hasSkill(skill.name) then break end
      local stillQueued = table.find(entry.move.moveInfo or {}, function(info)
        return info.cardId == entry.cardId and info.fromArea == Card.PlayerEquip
      end) ~= nil
      if stillQueued and entry.from:isAlive()
        and table.contains(entry.from:getCardIds(Player.Equip), entry.cardId)
        and hasSuitDiscardable(player, entry.suit) then
        event:setCostData(self, entry)
        self:doCost(event, target, player, data)
      end
    end
  end,
  on_cost = function(self, event, target, player, data)
    local entry = event:getCostData(self)
    if entry == nil or not hasSuitDiscardable(player, entry.suit) then return false end
    local room = player.room
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      pattern = ".|.|" .. entry.suitString,
      skill_name = skill.name,
      prompt = "#qiao__skill_han021_1-discard::" .. entry.from.id .. ":" .. entry.logString,
      cancelable = true,
    })
    return type(cards) == "table" and #cards > 0
  end,
  on_use = function(self, event, target, player, data)
    local entry = event:getCostData(self)
    if entry == nil then return end
    player.room:cancelMove(data, nil, function(move, info)
      return move == entry.move and info.cardId == entry.cardId
    end)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "守玺",
  [":" .. skill.name] = "与你势力相同的角色装备区的一张牌被其他势力角色不因弃置而移动时，你可以弃置一张同花色的牌并防止之。",
  ["#qiao__skill_han021_1-discard"] = "守玺：你可以弃置一张同花色的牌，防止 %dest 装备区的 %arg 被移动",
}

return skill
