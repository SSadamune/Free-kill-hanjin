-- JIN023 马隆 · 锋械
-- 出牌阶段限一次：两名角色各一张装备先进入处理区，再进入对方装备区；
-- 若其中一名为自己，随后对另一名或其队列视为使用【杀】。
local H = require "packages.hegemony.util"
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local EquipmentExchange = require "packages.qiao.pkg.qiao_mode.rules.equipment_exchange"
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin023_1",
}
skill.qiaoImplemented = true

local SLASH = "qiao__slash"
local SINGLE = "qiao__skill_jin023_1-single"
local QUEUE = "qiao__skill_jin023_1-queue"

local function canExchangeWithSomeone(room, chooser, target)
  return table.find(room:getPresentPlayers(), function(other)
    return EquipmentExchange.canSwapOneEach(chooser, target, other)
  end) ~= nil
end

local function queueTargets(room, other, user, condition)
  local slash = Fk:cloneCard(SLASH)
  local result = { other }
  for _, p in ipairs(H.getFormationRelation(other) or {}) do
    if not p.dead and not p:isRemoved() and C.matchesCondition(room, user, slash, p, condition) then
      table.insertIfNeed(result, p)
    end
  end
  return result
end

skill:addEffect("active", {
  prompt = "#qiao__skill_jin023_1-prompt",
  target_num = 2,
  card_num = 0,
  max_phase_use_time = 1,
  can_use = function(self, player)
    if player.phase ~= Player.Play or player.dead then return false end
    local room = Fk:currentRoom()
    return table.find(room:getPresentPlayers(), function(target)
      return canExchangeWithSomeone(room, player, target)
    end) ~= nil
  end,
  target_filter = function(self, player, to_select, selected)
    if #selected >= 2 then return false end
    if #selected == 1 then return EquipmentExchange.canSwapOneEach(player, selected[1], to_select) end
    return canExchangeWithSomeone(Fk:currentRoom(), player, to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local targets = effect.tos or {}
    if player == nil or player.dead or #targets ~= 2 then return end
    local a, b = targets[1], targets[2]
    if not EquipmentExchange.swapOneEach(room, player, a, b, skill.name, "#qiao__skill_jin023_1-equip") then return end

    local other
    if a == player then other = b elseif b == player then other = a end
    if other == nil or other.dead or other:isRemoved() then return end

    local condition = {}
    local targetsForSlash = { other }
    local queue = queueTargets(room, other, player, condition)
    local options = { SINGLE, QUEUE }
    local choice = Selection.askOption(room, player, {
      choices = #queue > 1 and options or { SINGLE },
      all_choices = options,
      skill_name = skill.name,
      prompt = "#qiao__skill_jin023_1-target-group",
      cancelable = false,
    })
    if not choice then return end
    if choice == QUEUE then targetsForSlash = queue end

    local policy = C.explicit(condition, {
      names = { SLASH },
      min_targets = 1,
      max_targets = #targetsForSlash,
    })
    C.useVirtualCard(room, player, SLASH, nil, targetsForSlash, skill.name, nil, nil, policy)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin023_1"] = "锋械",
  ["#qiao__skill_jin023_1-prompt"] = "锋械：交换两名角色各一张装备牌，然后可对另一名或其队列使用【杀】",
  ["#qiao__skill_jin023_1-equip"] = "锋械：选择 %dest 一张装备牌",
  ["#qiao__skill_jin023_1-target-group"] = "锋械：选择【杀】的目标组",
  [SINGLE] = "视为对其使用【杀】",
  [QUEUE] = "视为对其队列使用【杀】",
}

return skill
