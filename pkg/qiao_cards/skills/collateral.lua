-- HanJin-specific adapter for 【借刀杀人】.  The effect itself stays the local
-- upstream implementation; this wrapper adds the HanJin settlement rules:
--   * one main target is enough when that weapon holder's attack range has no
--     other character (the printed effect then just asks for the weapon);
--   * a new main target must have a weapon of its own and must be able to
--     choose its own legal 【杀】 target (it never inherits the first target's
--     sub target);
--   * when the target does not use 【杀】, exactly one weapon card is handed
--     over instead of every weapon card in its equipment area.
-- The 富甲 "不可响应" entry is applied by the adaptation layer and must keep
-- covering both the trick's 无懈 window and the inner 【杀】 request, so the
-- effect data is passed through unchanged.
local ExtraTargets = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"

local skill = fk.CreateSkill { name = "qiao__collateral_skill" }

local function upstream()
  local ret = Fk.skills["collateral_skill"]
  assert(ret ~= nil, "HanJin collateral requires the local collateral_skill")
  return ret
end

local function upstreamValue(name, ...)
  local value = upstream()[name]
  if type(value) == "function" then return value(upstream(), ...) end
  return value
end

skill:addEffect("cardskill", {
  prompt = function(self, ...) return upstreamValue("prompt", ...) end,
  -- 保留最多两个主目标；只选一个主目标的情形由下方 feasible 限制为
  -- “该武器持有者的攻击范围内没有其他角色”，而不是允许随时跳过次目标。
  min_target_num = 1,
  max_target_num = 2,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return upstream():modTargetFilter(player, to_select, selected, card, extra_data)
  end,
  target_filter = function(self, player, to_select, selected, selected_cards, card, extra_data)
    return upstream():targetFilter(player, to_select, selected, selected_cards, card, extra_data)
  end,
  on_use = function(self, room, use)
    -- 目标按“主目标 + 其副目标”成对写入；无范围目标时只有主目标，
    -- 不能把空表当成一个副目标传下去。
    local tos = table.simpleClone(use.tos)
    use:removeAllTargets()
    for i = 1, #tos, 2 do
      local main = tos[i]
      local sub = tos[i + 1]
      if sub ~= nil then
        use:addTarget(main, { sub })
      else
        use:addTarget(main)
        -- 不沿用其他主目标的副目标。
        use.subTos[#use.tos] = {}
      end
    end
  end,
  on_effect = function(self, room, effect)
    local from = effect.from
    local to = effect.to
    if from == nil or to == nil or to.dead then return end

    -- “其将装备区里的一张武器牌交给你”：由交牌的目标角色选择其中一张。
    local function giveOneWeapon()
      if from.dead then return end
      local weapons = to:getEquipments(Card.SubtypeWeapon)
      if #weapons == 0 then return end
      local card = weapons[1]
      if #weapons > 1 then
        card = room:askToChooseCard(to, {
          target = to,
          flag = { card_data = { { "$Equip", weapons } } },
          skill_name = self.name,
          prompt = "#qiao__collateral-weapon",
          cancelable = false,
        })
      end
      if card == nil then return end
      -- 以实际仍在目标装备区里的那张武器牌为准。
      if room:getCardOwner(card) ~= to or room:getCardArea(card) ~= Card.PlayerEquip then
        return
      end
      room:moveCardTo({ card }, Card.PlayerHand, from, fk.ReasonGive,
        self.name, nil, true, to)
    end

    local subTargets = effect.subTargets or {}
    if #subTargets == 0 then
      giveOneWeapon()
      return
    end

    -- 有次目标时，即使结算前已经失去武器，目标仍可选择是否使用【杀】；
    -- event_data 保持为本次效果，富甲的不可响应两个层次才都成立。
    local prompt = "#collateral-slash:" .. from.id .. ":" .. subTargets[1].id
    if #subTargets > 1 then prompt = nil end
    local extra_data = {
      must_targets = table.map(subTargets, Util.IdMapper),
    }
    local use = room:askToUseCard(to, {
      skill_name = "slash",
      pattern = "slash",
      prompt = prompt,
      cancelable = true,
      extra_data = extra_data,
      event_data = effect,
    })
    if use then
      room:useCard(use)
    else
      giveOneWeapon()
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__collateral_skill"] = "借刀杀人",
  ["#qiao__collateral-weapon"] = "借刀杀人：选择一张装备区里的武器牌交给使用者",
}

Fk:addPostLoadFunc(function()
  local loaded = Fk.skills["qiao__collateral_skill"]
  if loaded == nil then return end
  ExtraTargets.attach(loaded, {
    -- Main targets are chosen before any attached target exists.  The card's
    -- own modTargetFilter reads #selected==0 as "a weapon holder".
    selected = function() return {} end,
    -- 新增主目标允许攻击范围内没有其他角色：此时该目标只需交出武器，
    -- 不再要求它有可用于【杀】的次目标。
    allow_no_sub = true,
    -- For each new main target, ask the card's own condition which sub targets
    -- it could attack.  This is the same structural condition the normal use
    -- selection uses (collateral_skill:modTargetFilter with selected={main}).
    sub_candidates = function(room, use, main)
      local result = {}
      for _, candidate in ipairs(room:getPresentPlayers()) do
        if candidate ~= main
          and upstream():modTargetFilter(use.from, candidate, { main }, use.card, use.extra_data) then
          table.insert(result, candidate)
        end
      end
      return result
    end,
  })

  -- 通用可行条件只比较最小／最大目标数；这里补上“单主目标只适用于攻击范围内
  -- 没有其他角色的武器持有者”，避免在有合法次目标时跳过次目标直接交武器。
  local baseFeasible = loaded.feasible
  if type(baseFeasible) == "function" then
    loaded.feasible = function(self, player, selected, selected_cards, card)
      if #selected == 1 and selected[1] ~= nil and card ~= nil then
        local main = selected[1]
        local room = Fk:currentRoom()
        for _, candidate in ipairs(room and room:getPresentPlayers() or {}) do
          if candidate ~= main
            and upstream():modTargetFilter(player, candidate, { main }, card) then
            return false
          end
        end
      end
      return baseFeasible(self, player, selected, selected_cards, card)
    end
  end
end)

return skill
