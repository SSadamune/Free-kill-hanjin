-- WU024 吴国太 · 甘露
-- 出牌阶段限一次，你可以选择两名装备区牌数差小于等于X的角色（X为你已损失体力值），
-- 令这些角色交换装备区的所有牌。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local EquipmentExchange = require "packages.qiao.pkg.qiao_mode.rules.equipment_exchange"

local skill = fk.CreateSkill {
  name = "qiao__skill_wu024_2",
}
skill.qiaoImplemented = true


local function isValidPair(player, a, b)
  if a == nil or b == nil or a == b or a:isRemoved() or b:isRemoved() then return false end
  local ea, eb = #a:getCardIds(Player.Equip), #b:getCardIds(Player.Equip)
  if ea == 0 and eb == 0 then return false end
  return math.abs(ea - eb) <= player:getLostHp()
end

local function hasPartner(player, first)
  local room = Fk:currentRoom()
  if room == nil then return false end
  for _, other in ipairs(room:getPresentPlayers()) do
    if isValidPair(player, first, other) then return true end
  end
  return false
end

local function hasAnyValidPair(player)
  local room = Fk:currentRoom()
  if room == nil then return false end
  local players = room:getPresentPlayers()
  for i = 1, #players do
    for j = i + 1, #players do
      if isValidPair(player, players[i], players[j]) then return true end
    end
  end
  return false
end


skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__skill_wu024_2-prompt",
  max_phase_use_time = 1,
  can_use = function(self, player)
    return player:usedEffectTimes(self.name, Player.HistoryPhase) == 0
      and hasAnyValidPair(player)
  end,
  card_num = 0,
  card_filter = Util.FalseFunc,
  target_num = 2,
  target_filter = function(self, player, to_select, selected)
    if to_select == nil or to_select:isRemoved() then return false end
    if #selected == 0 then
      return hasPartner(player, to_select)
    elseif #selected == 1 then
      return isValidPair(player, selected[1], to_select)
    end
    return false
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local a, b = effect.tos[1], effect.tos[2]
    if not RemovedTargets.isPresent(a) or not RemovedTargets.isPresent(b) then return end
    if not isValidPair(player, a, b) then return end

    EquipmentExchange.swapEquips(room, player, a, b, a:getCardIds(Player.Equip), b:getCardIds(Player.Equip), skill.name)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "甘露",
  [":" .. skill.name] = "出牌阶段限一次，你可以选择两名装备区牌数差小于等于X的角色（X为你已损失体力值），令这些角色交换装备区的所有牌。",
  ["#qiao__skill_wu024_2-prompt"] = "甘露：选择两名装备数之差不超过你已损失体力值的角色，交换其装备区所有牌",
}

return skill
