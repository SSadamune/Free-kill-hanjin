-- HanJin-specific adapter for 【联军盛宴】.  The effect and normal target
-- selection stay the local upstream implementation.  The chosen other kingdom
-- is captured for this use so that reducing the target list (even to zero)
-- cannot silently start a new kingdom choice.
local H = require "packages.hegemony.util"
local ExtraTargets = require "packages.hanjin.pkg.hanjin_mode.rules.extra_targets"

local skill = fk.CreateSkill { name = "hanjin__alliance_feast_skill" }

local function upstream()
  local ret = Fk.skills["alliance_feast_skill"]
  assert(ret ~= nil, "HanJin alliance_feast requires the local alliance_feast_skill")
  return ret
end

local function upstreamValue(name, ...)
  local value = upstream()[name]
  if type(value) == "function" then return value(upstream(), ...) end
  return value
end

local function contextOf(use)
  return (use.extra_data or {}).hanjin_extra_target_context
end

skill:addEffect("cardskill", {
  prompt = function(self, ...) return upstreamValue("prompt", ...) end,
  target_num = 1,
  target_tip = function(self, ...) return upstreamValue("targetTip", ...) end,
  mod_target_filter = function(self, player, to_select, selected, card, extra_data)
    return upstream():modTargetFilter(player, to_select, selected, card, extra_data)
  end,
  target_filter = function(self, player, to_select, selected, selected_cards, card, extra_data)
    return upstream():targetFilter(player, to_select, selected, selected_cards, card, extra_data)
  end,
  can_use = function(self, player, card, extra_data)
    return upstream():canUse(player, card, extra_data)
  end,
  on_use = function(self, room, use)
    local first = use.tos and use.tos[1]
    if first ~= nil then
      use.extra_data = use.extra_data or {}
      use.extra_data.hanjin_extra_target_context = {
        initial_targets = table.simpleClone(use.tos),
        representative = first,
        kingdom = H.getKingdom(first),
      }
    end
    return upstream():onUse(room, use)
  end,
  on_effect = function(self, room, effect)
    return upstream():onEffect(room, effect)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__alliance_feast_skill"] = "联军盛宴",
}

Fk:addPostLoadFunc(function()
  local loaded = Fk.skills["hanjin__alliance_feast_skill"]
  if loaded == nil then return end
  ExtraTargets.attach(loaded, {
    requires_selection = true,
    context = function(room, use) return contextOf(use) end,
    selected = function(room, use)
      local context = contextOf(use)
      return context and context.initial_targets or {}
    end,
    -- The user is always a target of this card.  Other new targets must belong
    -- to the other kingdom chosen for this use.  The choice is captured in the
    -- context and stays fixed for the whole use even if the original target is
    -- removed or later changes kingdom; candidates themselves are recomputed
    -- from the current alive players.
    filter = function(room, use, target)
      local context = contextOf(use)
      if context == nil or context.kingdom == nil or context.kingdom == "unknown" then
        return false
      end
      if target == use.from then return use.from.kingdom ~= "unknown" end
      if H.getKingdom(target) ~= context.kingdom then return false end
      -- Keep 构逆 (relation-based enmity) when the representative still belongs
      -- to the captured kingdom; otherwise the fixed kingdom alone decides.
      if context.representative ~= nil
        and H.getKingdom(context.representative) == context.kingdom then
        return H.compareKingdomWith(target, context.representative)
      end
      return true
    end,
  })
end)

return skill
