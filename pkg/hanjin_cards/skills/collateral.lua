-- HanJin-specific adapter for 【借刀杀人】.  The effect itself stays the local
-- upstream implementation; this wrapper only adds a structured extra-target
-- rule: a new main target must have a weapon of its own and must be able to
-- choose its own legal 【杀】 target.  It never inherits the first target's
-- sub target.
local ExtraTargets = require "packages.hanjin.pkg.hanjin_mode.rules.extra_targets"

local skill = fk.CreateSkill { name = "hanjin__collateral_skill" }

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
  target_num = 2,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return upstream():modTargetFilter(player, to_select, selected, card, extra_data)
  end,
  target_filter = function(self, player, to_select, selected, selected_cards, card, extra_data)
    return upstream():targetFilter(player, to_select, selected, selected_cards, card, extra_data)
  end,
  on_use = function(self, room, use)
    return upstream():onUse(room, use)
  end,
  on_effect = function(self, room, effect)
    return upstream():onEffect(room, effect)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__collateral_skill"] = "借刀杀人",
}

Fk:addPostLoadFunc(function()
  local loaded = Fk.skills["hanjin__collateral_skill"]
  if loaded == nil then return end
  ExtraTargets.attach(loaded, {
    -- Main targets are chosen before any attached target exists.  The card's
    -- own modTargetFilter reads #selected==0 as "a weapon holder".
    selected = function() return {} end,
    -- For each new main target, ask the card's own condition which sub targets
    -- it could attack.  This is the same structural condition the normal use
    -- selection uses (collateral_skill:modTargetFilter with selected={main}).
    sub_candidates = function(room, use, main)
      local result = {}
      for _, candidate in ipairs(room.alive_players) do
        if candidate ~= main
          and upstream():modTargetFilter(use.from, candidate, { main }, use.card, use.extra_data) then
          table.insert(result, candidate)
        end
      end
      return result
    end,
  })
end)

return skill
