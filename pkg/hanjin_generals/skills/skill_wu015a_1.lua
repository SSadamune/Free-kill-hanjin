-- WU015A 张昭 · 直谏
--
-- 规则基线：rules/standard-generals.md 吴区 WU015A、
-- rules/generals/wu015a-zhangzhao.md、rules/equipment-movement.md。
-- 出牌阶段：将一张装备牌置入一名其他角色空置的对应装备栏；装备牌来自
-- 张昭手牌时张昭摸一张，来自张昭装备区时该角色摸一张。不是使用装备牌，
-- 不替换目标已有装备。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu015a_1",
}
skill.hanjinImplemented = true

--- 客户端没有 player.room；与服务端共用 Fk:currentRoom() 的只读房间。
---@param player ServerPlayer | ClientPlayer
---@return Room | Client
local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

--- 其他存活角色（客户端使用公共房间副本）。
---@param player ServerPlayer | ClientPlayer
---@return ServerPlayer[] | ClientPlayer[]
local function otherTargets(player)
  local room = currentRoom(player)
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
  end)
end

--- 目标是否有可接收某张装备牌的空置对应栏。
---@param player ServerPlayer
---@param target ServerPlayer
---@param id integer
---@return boolean
local function canPlace(player, target, id)
  return Fk:getCardById(id).type == Card.TypeEquip
    and player:canMoveCardInBoardTo(target, id)
end

--- 是否存在可执行的“牌 + 其他角色”组合。
---@param player ServerPlayer | ClientPlayer
---@return boolean
local function hasLegalMove(player)
  return table.find(otherTargets(player), function(target)
    return table.find(player:getCardIds("he"), function(id)
      return canPlace(player, target, id)
    end) ~= nil
  end) ~= nil
end

--- 目标是否至少能接收一张张昭的装备牌。
---@param player ServerPlayer | ClientPlayer
---@param target ServerPlayer | ClientPlayer
---@return boolean
local function canPlaceAny(player, target)
  return table.find(player:getCardIds("he"), function(id)
    return canPlace(player, target, id)
  end) ~= nil
end

skill:addEffect("active", {
  anim_type = "support",
  prompt = "#hanjin__skill_wu015a_1-prompt",
  target_num = 1,
  min_card_num = 1,
  max_card_num = 1,
  include_equip = true,
  can_use = function(self, player)
    return hasLegalMove(player)
  end,
  card_filter = function(self, player, to_select, selected, selected_targets)
    if Fk:getCardById(to_select).type ~= Card.TypeEquip then return false end
    local targets = selected_targets or {}
    if #targets > 0 then
      return canPlace(player, targets[1], to_select)
    end
    return table.find(otherTargets(player), function(target)
      return canPlace(player, target, to_select)
    end) ~= nil
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    if #selected > 0 or to_select == player then return false end
    if not to_select:isAlive() or to_select:isRemoved() then return false end
    if selected_cards and #selected_cards > 0 then
      return canPlace(player, to_select, selected_cards[1])
    end
    return canPlaceAny(player, to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    local card = effect.cards and effect.cards[1]
    if player == nil or target == nil or card == nil then return end
    if player.dead or target.dead or target:isRemoved() then return end
    if not table.contains(player:getCardIds("he"), card) then return end
    if not canPlace(player, target, card) then return end

    local fromHand = table.contains(player:getCardIds(Player.Hand), card)
    local moved = room:moveCardIntoEquip(target, card, skill.name, false, player)
    if moved == nil or #moved == 0 then return end

    -- 斜线按顺序一一对应：手牌区来源 -> 你摸；装备区来源 -> 其摸。
    if fromHand then
      if not player.dead then player:drawCards(1, skill.name) end
    else
      if not target.dead then target:drawCards(1, skill.name) end
    end
  end,
})

Fk:loadTranslationTable {
  ["#hanjin__skill_wu015a_1-prompt"] = "直谏：将一张装备牌置入一名其他角色的空置装备栏",
}

return skill
