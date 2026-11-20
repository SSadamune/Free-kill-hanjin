-- WU008 孙尚香 · 结姻
--
-- 规则基线：docs/rules/standard-generals.md 吴区 WU008、
-- docs/rules/equipment-movement.md。
-- 出牌阶段限一次：选择一名其他男性角色，弃置一张手牌，或将一张装备牌
-- 置于其空置的对应装备栏；然后二人中体力值较大者摸一张牌，较小者回复
-- 1 点体力。装备牌可来自手牌或装备区；置入不是使用装备牌，不替换原装备。
-- 体力值相等时既非“较大”也非“较小”，本轮不结算摸牌或回复。
local skill = fk.CreateSkill {
  name = "qiao__skill_wu008_1",
}
skill.qiaoImplemented = true

local DISCARD = "#qiao__skill_wu008_1-discard"
local PLACE = "#qiao__skill_wu008_1-place"

--- 客户端没有 player.room；与服务端共用 Fk:currentRoom() 的只读房间。
---@param player ServerPlayer | ClientPlayer
---@return Room | Client
local function currentRoom()
  return Fk:currentRoom()
end

--- 可作为弃置成本的手牌。
---@param player ServerPlayer
---@return integer[]
local function discardableHand(player)
  return table.filter(player:getCardIds(Player.Hand), function(id)
    return not player:prohibitDiscard(id)
  end)
end

--- 可置入目标空置对应装备栏的装备牌（手牌或自己的装备区）。
---@param player ServerPlayer
---@param target ServerPlayer
---@return integer[]
local function placeableEquipments(player, target)
  return table.filter(player:getCardIds("he"), function(id)
    return Fk:getCardById(id).type == Card.TypeEquip
      and player:canMoveCardInBoardTo(target, id)
  end)
end

---@param player ServerPlayer
---@param target ServerPlayer
---@return boolean
local function canPay(player, target)
  return #discardableHand(player) > 0 or #placeableEquipments(player, target) > 0
end

--- 其他存活的男性角色（客户端使用公共房间副本）。
---@param player ServerPlayer | ClientPlayer
---@return ServerPlayer[] | ClientPlayer[]
local function maleTargets(player)
  local room = currentRoom()
  return table.filter(room:getPresentPlayers(), function(p)
    return p ~= player and p:isAlive() and not p:isRemoved() and p:isMale()
  end)
end

local function canPayWith(player, target, id, mode)
  if mode == DISCARD then return table.contains(discardableHand(player), id) end
  if mode == PLACE then return table.contains(placeableEquipments(player, target), id) end
  return false
end

skill:addEffect("active", {
  anim_type = "support",
  prompt = "#qiao__skill_wu008_1-prompt",
  max_phase_use_time = 1,
  target_num = 1,
  card_num = 1,
  include_equip = true,
  interaction = function(self, player)
    local choices = {}
    if #discardableHand(player) > 0 then table.insert(choices, DISCARD) end
    if table.find(maleTargets(player), function(target)
      return #placeableEquipments(player, target) > 0
    end) then
      table.insert(choices, PLACE)
    end
    return UI.ComboBox { choices = choices, all_choices = { DISCARD, PLACE } }
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and table.find(maleTargets(player), function(p) return canPay(player, p) end) ~= nil
  end,
  card_filter = function(self, player, id, selected, selected_targets)
    if #selected > 0 then return false end
    local mode = self.interaction.data
    local target = selected_targets and selected_targets[1]
    if target then return canPayWith(player, target, id, mode) end
    return table.find(maleTargets(player), function(p)
      return canPayWith(player, p, id, mode)
    end) ~= nil
  end,
  target_filter = function(self, player, target, selected, cards)
    if #selected > 0 or not table.contains(maleTargets(player), target) then return false end
    local mode = self.interaction.data
    if cards[1] then return canPayWith(player, target, cards[1], mode) end
    if mode == DISCARD then return #discardableHand(player) > 0 end
    if mode == PLACE then return #placeableEquipments(player, target) > 0 end
    return false
  end,
  on_use = function(self, room, effect)
    local player, target = effect.from, effect.tos and effect.tos[1]
    local cards = effect.cards or {}
    local id, mode = cards[1], effect.interaction_data
    if player.dead or #cards ~= 1 or not table.contains(maleTargets(player), target)
      or not canPayWith(player, target, id, mode) then return end

    if mode == DISCARD then
      room:throwCard({ id }, skill.name, player, player)
    else
      local moved = room:moveCardIntoEquip(target, id, skill.name, false, player)
      if moved == nil or #moved == 0 then return end
    end

    if player.dead or target.dead then return end
    if player.hp > target.hp then
      player:drawCards(1, skill.name)
      room:recover({
        who = target,
        num = 1,
        recoverBy = player,
        skillName = skill.name,
      })
    elseif player.hp < target.hp then
      target:drawCards(1, skill.name)
      room:recover({
        who = player,
        num = 1,
        recoverBy = player,
        skillName = skill.name,
      })
    end
  end,
})

Fk:loadTranslationTable {
  ["#qiao__skill_wu008_1-prompt"] = "结姻：选择一名其他男性角色，弃置一张手牌或置入一张装备牌",
  [DISCARD] = "弃置一张手牌",
  [PLACE] = "将一张装备牌置入其空置装备栏",
}

return skill
