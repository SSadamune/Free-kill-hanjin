-- WEI018 曹洪 · 护援
--
-- 规则依据：docs/rules/generals/wei018-caohong.md。
-- 第一段：自己的回合内，任意牌实际置入一名角色的装备区后，可弃置该角色距离1
-- 的另一名角色区域里（含判定区）一张牌；距离从被装备角色计算。
-- 第二段：结束阶段，可将自己一张装备牌置入一名角色对应空栏，不是使用装备。
local Invoke = require "packages.qiao.pkg.qiao_generals.util.invoke_targets"
local AUX = "#qiao__skill_wei018_1_active"

local skill = fk.CreateSkill {
  name = "qiao__skill_wei018_1",
}
skill.qiaoImplemented = true

---@param player ServerPlayer
---@return integer[]
local function discardableArea(player)
  return table.filter(player:getCardIds("hej"), function(id)
    return not player:prohibitDiscard(id)
  end)
end

---@param data table
---@return ServerPlayer?
local function equippedBy(data)
  for _, move in ipairs(data or {}) do
    if move.toArea == Card.PlayerEquip and move.to ~= nil and not move.to.dead then
      return move.to
    end
  end
end

---@param room Room
---@param equipped ServerPlayer
---@return ServerPlayer[]
local function discardTargets(room, equipped)
  return table.filter(room:getPresentPlayers(), function(p)
    return p ~= equipped and not p.dead and not p:isRemoved()
      and equipped:distanceTo(p) == 1 and #discardableArea(p) > 0
  end)
end

skill:addAuxActiveSkill(AUX, {
  include_equip = true,
  min_card_num = 1,
  max_card_num = 1,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and Fk:getCardById(to_select).type == Card.TypeEquip
  end,
  target_num = 1,
  target_filter = function(self, player, to_select, selected, selected_cards)
    return #selected == 0 and #selected_cards == 1
      and to_select:canMoveCardIntoEquip(selected_cards[1], false)
  end,
})

-- 结束阶段置入装备与自己的回合内置入装备后的弃牌分别监听。
skill:addEffect(fk.EventPhaseStart, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and player.phase == Player.Finish
      and #player:getCardIds("he") > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local success, dat = room:askToUseActiveSkill(player, {
      skill_name = AUX,
      prompt = "#qiao__skill_wei018_1-place",
      cancelable = true,
    })
    if success and dat ~= nil then
      event:setCostData(self, { tos = dat.targets, cards = dat.cards })
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to = cost.tos and cost.tos[1]
    local cards = cost.cards or {}
    if to == nil or to.dead or #cards == 0 then return end
    if not table.every(cards, function(id)
      local card = Fk:getCardById(id)
      return card ~= nil and card.type == Card.TypeEquip
    end) then return end
    room:moveCardIntoEquip(to, cards, skill.name, false, player)
  end,
})

skill:addEffect(fk.AfterCardsMove, {
  anim_type = "control",
  global = true,
  can_trigger = function(self, event, target, player, data)
    if player == nil or player.dead or not player:hasSkill(skill.name) then
      return false
    end
    if player.room.current ~= player then return false end
    local equipped = equippedBy(data)
    return equipped ~= nil and #discardTargets(player.room, equipped) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local equipped = equippedBy(data)
    if equipped == nil then return false end
    local targets = discardTargets(room, equipped)
    if #targets == 0 then return false end
    local chosen = Invoke.ask(room, player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_wei018_1-target",
      invoke_prompt = "#qiao__skill_wei018_1-invoke",
    })
    local to = chosen and chosen[1]
    if to == nil or to.dead or to:isRemoved() then return false end
    event:setCostData(self, { to = to })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to = cost.to
    if to == nil or to.dead or to:isRemoved() then return end
    local ids = discardableArea(to)
    if #ids == 0 then return end
    local id = room:askToChooseCard(player, {
      target = to,
      flag = { card_data = { { "可弃置", ids } } },
      skill_name = skill.name,
      prompt = "#qiao__skill_wei018_1-card",
    })
    if id == nil or id == 0 then return end
    room:throwCard(id, skill.name, to, player)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_wei018_1"] = "护援",
  [":qiao__skill_wei018_1"] =
    "你的回合内，当牌置入一名角色的装备区后，你可以弃置其距离1的另一名角色区域里的一张牌。结束阶段，你可以将一张装备牌置于一名角色的装备区。",
  ["#qiao__skill_wei018_1-invoke"] = "护援：是否弃置被装备角色距离1的另一名角色一张牌？",
  ["#qiao__skill_wei018_1-target"] = "护援：选择被装备角色距离1的一名角色",
  ["#qiao__skill_wei018_1-card"] = "护援：选择其区域里的一张牌弃置",
  ["#qiao__skill_wei018_1-place"] = "护援：将一张装备牌置于一名角色的装备区",
}

return skill
