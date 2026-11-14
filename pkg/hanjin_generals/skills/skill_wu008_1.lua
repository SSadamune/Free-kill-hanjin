-- WU008 孙尚香 · 结姻
--
-- 规则基线：rules/standard-generals.md 吴区 WU008、
-- rules/equipment-movement.md。
-- 出牌阶段限一次：选择一名其他男性角色，弃置一张手牌，或将一张装备牌
-- 置于其空置的对应装备栏；然后二人中体力值较大者摸一张牌，较小者回复
-- 1 点体力。装备牌可来自手牌或装备区；置入不是使用装备牌，不替换原装备。
-- 体力值相等时既非“较大”也非“较小”，本轮不结算摸牌或回复。
local skill = fk.CreateSkill {
  name = "hanjin__skill_wu008_1",
}
skill.hanjinImplemented = true

local DISCARD = "#hanjin__skill_wu008_1-discard"
local PLACE = "#hanjin__skill_wu008_1-place"

--- 客户端没有 player.room；与服务端共用 Fk:currentRoom() 的只读房间。
---@param player ServerPlayer | ClientPlayer
---@return Room | Client
local function currentRoom(player)
  return player.room or Fk:currentRoom()
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
  local room = currentRoom(player)
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved() and p:isMale()
  end)
end

--- 只列出可置入目标空栏的装备牌，拆成手牌区与装备区两个候选堆。
---@param player ServerPlayer
---@param target ServerPlayer
---@return table
local function placeableCardData(player, target)
  local hand, equip = {}, {}
  for _, id in ipairs(placeableEquipments(player, target)) do
    if table.contains(player:getCardIds(Player.Hand), id) then
      table.insert(hand, id)
    else
      table.insert(equip, id)
    end
  end
  local data = {}
  if #hand > 0 then table.insert(data, { "$Hand", hand }) end
  if #equip > 0 then table.insert(data, { "$Equip", equip }) end
  return data
end

skill:addEffect("active", {
  anim_type = "support",
  prompt = "#hanjin__skill_wu008_1-prompt",
  max_phase_use_time = 1,
  target_num = 1,
  min_card_num = 0,
  max_card_num = 0,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and table.find(maleTargets(player), function(p) return canPay(player, p) end) ~= nil
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= player
      and to_select:isAlive() and not to_select:isRemoved()
      and to_select:isMale() and canPay(player, to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead then return end
    if not canPay(player, target) then return end

    local hand = discardableHand(player)
    local equipments = placeableEquipments(player, target)
    local mode
    if #hand > 0 and #equipments > 0 then
      mode = room:askToChoice(player, {
        choices = { DISCARD, PLACE },
        skill_name = skill.name,
        prompt = "#hanjin__skill_wu008_1-mode",
      })
    elseif #hand > 0 then
      mode = DISCARD
    else
      mode = PLACE
    end

    if mode == DISCARD then
      local candidates = discardableHand(player)
      if #candidates == 0 then return end
      local chosen = room:askToChooseCards(player, {
        target = player,
        flag = { card_data = { { "$Hand", candidates } } },
        min = 1,
        max = 1,
        skill_name = skill.name,
        prompt = "#hanjin__skill_wu008_1-choose-hand",
        cancelable = false,
      })
      local id = chosen and chosen[1]
      if id == nil or not table.contains(candidates, id) then return end
      room:throwCard({ id }, skill.name, player, player)
    else
      local candidates = placeableEquipments(player, target)
      local data = placeableCardData(player, target)
      if #candidates == 0 or #data == 0 then return end
      local chosen = room:askToChooseCards(player, {
        target = player,
        flag = { card_data = data },
        min = 1,
        max = 1,
        skill_name = skill.name,
        prompt = "#hanjin__skill_wu008_1-choose-equip",
        cancelable = false,
      })
      local id = chosen and chosen[1]
      if id == nil or not table.contains(candidates, id) then return end
      -- 不替换原装备：只置入空置的对应栏。
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
  ["#hanjin__skill_wu008_1-prompt"] = "结姻：选择一名其他男性角色，弃置一张手牌或置入一张装备牌",
  ["#hanjin__skill_wu008_1-mode"] = "结姻：选择发动方式",
  [DISCARD] = "弃置一张手牌",
  [PLACE] = "将一张装备牌置入其空置装备栏",
  ["#hanjin__skill_wu008_1-choose-hand"] = "结姻：选择弃置一张手牌",
  ["#hanjin__skill_wu008_1-choose-equip"] = "结姻：选择一张可置入其空置装备栏的装备牌",
}

return skill
