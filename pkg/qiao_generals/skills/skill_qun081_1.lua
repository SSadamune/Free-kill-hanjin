-- QUN081 徐荣 · 剽戮
--
-- 使用伤害牌指定目标后，选择其中一名目标，弃置自己或该目标一张坐骑/宝物，
-- 然后只令此牌对该目标伤害+1。加伤绑定本次 UseCardData 与所选目标，
-- 不改整张牌的全目标伤害。
local J = require "packages.qiao.pkg.qiao_generals.util.jin_adaptation"
local CardTargetSelection = require "packages.qiao.pkg.qiao_generals.util.card_target_selection"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun081_1",
}
skill.qiaoImplemented = true

local USED = "qiao_qun081_1_used"
local TARGET = "qiao_qun081_1_target"
local DONE = "qiao_qun081_1_done"
local SELECT = "#qiao__skill_qun081_1_select"

---@param player ServerPlayer
---@return integer[]
local function eligibleEquipments(player)
  return table.filter(player:getCardIds(Player.Equip), function(id)
    local card = Fk:getCardById(id)
    if card == nil or player:prohibitDiscard(id) then return false end
    return card.sub_type == Card.SubtypeOffensiveRide
      or card.sub_type == Card.SubtypeDefensiveRide
      or card.sub_type == Card.SubtypeTreasure
  end)
end

---@param player ServerPlayer
---@param use UseCardData
---@return ServerPlayer[]
local function eligibleTargets(player, use)
  local selfHas = #eligibleEquipments(player) > 0
  return table.filter(use.tos or {}, function(to)
    return to ~= nil and to:isAlive() and not to:isRemoved()
      and (selfHas or #eligibleEquipments(to) > 0)
  end)
end

CardTargetSelection.add(skill, SELECT, {
  expand_pile = function(self) return self._extra_data and self._extra_data.otherEquips or {} end,
})

skill:addEffect(fk.TargetSpecified, {
  anim_type = "offensive",
  can_trigger = function(self, event, target, player, data)
    return target == player and not player.dead and player:hasSkill(skill.name)
      and data ~= nil and data.use ~= nil and not data.use[USED]
      and J.isDamageCard(data.card) and #eligibleTargets(player, data.use) > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local use = data.use
    use[USED] = true
    local targets = eligibleTargets(player, use)
    if #targets == 0 then return false end
    local targetIds = table.map(targets, Util.IdMapper)
    local targetsByCard, otherEquips = {}, {}
    for _, id in ipairs(eligibleEquipments(player)) do
      targetsByCard[tostring(id)] = targetIds
    end
    for _, to in ipairs(targets) do
      if to ~= player then
        for _, id in ipairs(eligibleEquipments(to)) do
          targetsByCard[tostring(id)] = { to.id }
          table.insert(otherEquips, id)
        end
      end
    end
    local id, to = CardTargetSelection.ask(room, player, {
      skill_name = SELECT,
      prompt = "#qiao__skill_qun081_1-invoke",
      extra_data = {
        skillName = skill.name, targets = targetIds,
        targetsByCard = targetsByCard, otherEquips = otherEquips,
      },
    })
    if id == nil then return false end
    if not table.contains(eligibleTargets(player, use), to) then return false end
    local owner = room:getCardOwner(id)
    if (owner ~= player and owner ~= to) or not table.contains(eligibleEquipments(owner), id) then
      return false
    end
    event:setCostData(self, { to = to, owner = owner, card = id })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to, owner, id = cost.to, cost.owner, cost.card
    if to == nil or owner == nil or id == nil or player.dead then return end
    if not table.contains(owner:getCardIds(Player.Equip), id) then return end
    room:throwCard({ id }, skill.name, owner, player)
    data.use[TARGET] = to
  end,
})

-- 只改本次伤害牌对所选目标的伤害。
skill:addEffect(fk.DamageCaused, {
  global = true,
  priority = 1,
  can_trigger = function(self, event, target, player, data)
    if target ~= player or data == nil or data.from ~= player then return false end
    local use = J.currentUse(player.room)
    return use ~= nil and use[TARGET] == data.to and not use[DONE]
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local use = J.currentUse(player.room)
    if use == nil or use[DONE] then return end
    use[DONE] = true
    data:changeDamage(1)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun081_1"] = "剽戮",
  [":qiao__skill_qun081_1"] = "当你使用伤害牌指定目标后，你可以选择一个目标并弃置你或其一张坐骑或宝物牌，然后令此牌对其伤害+1。",
  ["#qiao__skill_qun081_1-invoke"] = "剽戮：选择此牌的一名目标，并选择你或其一张坐骑或宝物弃置",
}

return skill
