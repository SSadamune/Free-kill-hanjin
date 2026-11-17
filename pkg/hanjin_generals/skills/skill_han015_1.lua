-- HAN015 卢植 · 用良
--
-- 出牌阶段限一次：弃置自己一张牌，视为仅对一名其他角色使用【敕令】。
-- 目标条件明确无视，但禁止使用/禁止指定等独立规则仍由目标策略复核。
local C = require "packages.hanjin.pkg.hanjin_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "hanjin__skill_han015_1",
}
skill.hanjinImplemented = true

local IMPERIAL = "hanjin__imperial_order"

local function currentRoom(player)
  return player.room or Fk:currentRoom()
end

--- 可支付成本的牌；客户端也可只读自己的牌区。
---@param player ServerPlayer | ClientPlayer
---@return integer[]
local function discardableCards(player)
  return table.filter(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id)
  end)
end

--- 先过滤独立禁止；目标条件由显式策略替换，但禁止指定仍有效。
---@param player ServerPlayer | ClientPlayer
---@return ServerPlayer[]
local function legalTargets(player)
  local room = currentRoom(player)
  local card = Fk:cloneCard(IMPERIAL)
  if room == nil or card == nil or player:prohibitUse(card) then return {} end
  return table.filter(room.alive_players, function(p)
    return p ~= player and p:isAlive() and not p:isRemoved()
      and not player:isProhibited(p, card)
  end)
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#hanjin__skill_han015_1-prompt",
  target_num = 1,
  max_phase_use_time = 1,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and table.contains(legalTargets(player), to_select)
  end,
  can_use = function(self, player)
    return self:withinTimesLimit(player, Player.HistoryPhase)
      and #discardableCards(player) > 0 and #legalTargets(player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or target == nil or player.dead or target.dead or target:isRemoved() then return end
    if not table.contains(legalTargets(player), target) then return end
    local cards = room:askToDiscard(player, {
      min_num = 1,
      max_num = 1,
      include_equip = true,
      skill_name = skill.name,
      prompt = "#hanjin__skill_han015_1-discard",
      cancelable = false,
    })
    if cards == nil or #cards == 0 then return end
    if target.dead or target:isRemoved() or player.dead then return end
    if not table.contains(legalTargets(player), target) then return end
    C.useVirtualCard(room, player, IMPERIAL, nil, { target }, skill.name, false, nil,
      C.explicit({ other_roles = true }, {
        names = { IMPERIAL }, min_targets = 1, max_targets = 1,
      }))
  end,
})

Fk:loadTranslationTable {
  ["hanjin__skill_han015_1"] = "用良",
  [":hanjin__skill_han015_1"] = "出牌阶段限一次，你可以弃置一张牌并视为仅对一名其他角色使用【敕令】（无视目标条件限制）。",
  ["#hanjin__skill_han015_1-prompt"] = "用良：弃置一张牌，视为对一名其他角色使用【敕令】",
  ["#hanjin__skill_han015_1-discard"] = "用良：弃置一张牌",
}

return skill
