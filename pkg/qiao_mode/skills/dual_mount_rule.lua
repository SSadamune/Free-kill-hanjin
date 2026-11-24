-- 双副类别坐骑的移动规则：正常使用时的替换与直接置入的空栏要求。
--
-- 装备栏占用由 pkg/qiao_cards/init.lua 的公共查询统一表达（一张双副类别牌
-- 同时出现在两个坐骑栏的检索结果中）。本规则只处理牌移动中引擎按单一
-- `sub_type` 无法覆盖的两处：
--   * 正常使用双副类别坐骑时，另一个坐骑栏里原有的单坐骑也要被替换；
--   * 主动置入允许替换；未获替换授权的移动仍需相关空栏。
-- 只删除/追加本次移动中的目标牌，不丢弃同批的其他牌。
local DUAL = {
  ["qiao__liulongcanjia"] = true,
  ["qiao__linxiao_yuyu"] = true,
  ["qiao__feiyun_gaihai"] = true,
}

local RIDE = {
  [Card.SubtypeOffensiveRide] = true,
  [Card.SubtypeDefensiveRide] = true,
}

local skill = fk.CreateSkill { name = "qiao__dual_mount_rule" }
local Placement = require "packages.qiao.pkg.qiao_mode.rules.mount_placement"

local function mayReplace(move)
  return move.extra_data and move.extra_data[Placement.REPLACE] == true
end

local function cardOf(info)
  return info.beforeCard or Fk:getCardById(info.cardId)
end

local function isDual(card)
  return card ~= nil and DUAL[card.name] == true
end

local function isRide(card)
  if card == nil or card.type ~= Card.TypeEquip then return false end
  if RIDE[card.sub_type] then return true end
  for _, subtype in ipairs(card.subtypes or {}) do
    if RIDE[subtype] then return true end
  end
  return false
end

local function rideCards(player)
  local list = {}
  for _, id in ipairs(player:getCardIds(Player.Equip)) do
    local card = player:getVirtualEquip(id) or Fk:getCardById(id)
    if isRide(card) then table.insert(list, { id = id, card = card }) end
  end
  return list
end

local function slotOccupied(player, subtype)
  for _, ride in ipairs(rideCards(player)) do
    if isDual(ride.card) or ride.card.sub_type == subtype then return true end
  end
  return false
end

--- 正常使用双副类别坐骑要求两个对应栏均存在且未封印；已有坐骑仍可被正常替换。
local function rideSlotsAvailable(player)
  return #player:getAvailableEquipSlots(Card.SubtypeOffensiveRide) > 0
    and #player:getAvailableEquipSlots(Card.SubtypeDefensiveRide) > 0
end

--- 直接置入的空栏要求：双副类别需要两个坐骑栏都空且可用。
local function canPlace(player, card)
  local function free(subtype)
    return #player:getAvailableEquipSlots(subtype) > 0
      and not slotOccupied(player, subtype)
  end
  if isDual(card) then
    return free(Card.SubtypeOffensiveRide) and free(Card.SubtypeDefensiveRide)
  end
  return free(card.sub_type)
end

--- 本次移动中已经离开原区域的牌，不计入替换候选。
local function leavingIds(data)
  local ids = {}
  for _, move in ipairs(data or {}) do
    for _, info in ipairs(move.moveInfo or {}) do
      if info.fromArea == Card.PlayerEquip then ids[info.cardId] = true end
    end
  end
  return ids
end

local function discardData(owner, ids, incoming)
  local moveInfo = {}
  for _, id in ipairs(ids) do
    table.insert(moveInfo, {
      cardId = id,
      fromArea = Card.PlayerEquip,
      beforeCard = Fk:getCardById(id),
    })
  end
  return {
    moveInfo = moveInfo,
    from = owner,
    toArea = Card.DiscardPile,
    moveReason = fk.ReasonPutIntoDiscardPile,
    skillName = skill.name,
    moveVisible = true,
    proposer = owner,
    extra_data = incoming and { [Placement.REPLACEMENT_CARD] = incoming } or nil,
  }
end

local function hasWork(data)
  for _, move in ipairs(data or {}) do
    if move.toArea == Card.PlayerEquip and move.to ~= nil then
      if mayReplace(move) then return true end
      if move.moveReason == fk.ReasonUse then
        for _, info in ipairs(move.moveInfo or {}) do
          if isDual(cardOf(info)) then return true end
        end
      else
        for _, info in ipairs(move.moveInfo or {}) do
          if isRide(cardOf(info)) and not canPlace(move.to, cardOf(info)) then
            return true
          end
        end
      end
    end
  end
  return false
end

-- 使用源头只拦双副类别坐骑：任一坐骑栏被封印/不存在时不可使用。
-- 普通坐骑和其他模式不受影响。
skill:addEffect("prohibit", {
  prohibit_use = function(self, player, card)
    return isDual(card) and not rideSlotsAvailable(player)
  end,
  is_prohibited = function(self, from, to, card)
    return isDual(card) and not rideSlotsAvailable(to)
  end,
})

skill:addEffect(fk.BeforeCardsMove, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    if room:getTag("qiao_dual_mount_after") == event.id then return false end
    return hasWork(data)
  end,
  on_refresh = function(self, event, target, player, data)
    local room = Fk:currentRoom()
    if room:getTag("qiao_dual_mount_after") == event.id then return end
    room:setTag("qiao_dual_mount_after", event.id)
    local leaving = leavingIds(data)
    local additions = {}
    for _, move in ipairs(data or {}) do
      if move.toArea == Card.PlayerEquip and move.to ~= nil then
        if mayReplace(move) then
          local usable = {}
          for _, info in ipairs(move.moveInfo or {}) do
            local card = cardOf(info)
            if isRide(card) and Placement.canPut(move.to, info.cardId) then
              table.insert(usable, info)
              local replaced = {}
              for _, subtype in ipairs({ Card.SubtypeOffensiveRide, Card.SubtypeDefensiveRide }) do
                if (isDual(card) or card.sub_type == subtype) and not move.to:hasEmptyEquipSlot(subtype) then
                  local old = table.find(move.to:getEquipments(subtype), function(id) return not leaving[id] end)
                  if old then
                    leaving[old] = true
                    table.insert(replaced, old)
                  end
                end
              end
              if #replaced > 0 then
                table.insert(additions, discardData(move.to, replaced, info.cardId))
              end
            end
          end
          move.moveInfo = usable
        elseif move.moveReason == fk.ReasonUse then
          -- 结算端复核两个坐骑栏；被封印/不存在的栏位不能装备该牌。
          local usable = {}
          for _, info in ipairs(move.moveInfo or {}) do
            if not (isDual(cardOf(info)) and not rideSlotsAvailable(move.to)) then
              table.insert(usable, info)
            end
          end
          if #usable ~= #(move.moveInfo or {}) then move.moveInfo = usable end
          -- 双副类别坐骑顶替任意坐骑；引擎已按原生栏位追加的替换牌除外。
          local replaced, seen = {}, {}
          for _, info in ipairs(usable) do
            if isDual(cardOf(info)) then
              for _, ride in ipairs(rideCards(move.to)) do
                if not leaving[ride.id] and not seen[ride.id] then
                  seen[ride.id] = true
                  table.insert(replaced, ride.id)
                end
              end
            end
          end
          if #replaced > 0 then
            table.insert(additions, discardData(move.to, replaced))
          end
        else
          -- 直接置入不是使用装备牌：相关栏位有占用时不移动该牌，也不替换。
          local keep = {}
          for _, info in ipairs(move.moveInfo or {}) do
            local card = cardOf(info)
            if isRide(card) and not canPlace(move.to, card) then
              -- 丢弃这一条 moveInfo，不影响同 move 或同批的其他牌。
            else
              table.insert(keep, info)
            end
          end
          move.moveInfo = keep
        end
      end
    end
    for _, addition in ipairs(additions) do table.insert(data, addition) end
  end,
})

Fk:loadTranslationTable { [skill.name] = "坐骑替换" }

return skill
