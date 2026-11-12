-- HanJin-specific adapter for 【勠力同心】.  The effect and the normal target
-- selection stay the local upstream implementation.  The only extra information
-- captured here is the group category chosen for this use (big/small), because
-- the card expands its group in on_use and the current target list may later be
-- reduced to zero; re-reading an empty `selected` would wrongly start a new
-- choice.
local H = require "packages.hegemony.util"
local ExtraTargets = require "packages.hanjin.pkg.hanjin_mode.rules.extra_targets"

local skill = fk.CreateSkill { name = "hanjin__fight_together_skill" }

local function upstream()
  local ret = Fk.skills["fight_together_skill"]
  assert(ret ~= nil, "HanJin fight_together requires the local fight_together_skill")
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
        big = H.isBigKingdomPlayer(first),
      }
    end
    return upstream():onUse(room, use)
  end,
  on_effect = function(self, room, effect)
    return upstream():onEffect(room, effect)
  end,
})

Fk:loadTranslationTable {
  ["hanjin__fight_together_skill"] = "勠力同心",
}

Fk:addPostLoadFunc(function()
  local loaded = Fk.skills["hanjin__fight_together_skill"]
  if loaded == nil then return end
  ExtraTargets.attach(loaded, {
    requires_selection = true,
    context = function(room, use) return contextOf(use) end,
    selected = function(room, use)
      local context = contextOf(use)
      return context and context.initial_targets or {}
    end,
    -- Keep the category fixed for this use.  Membership itself is always
    -- recomputed from the current alive kingdoms, so a player who becomes legal
    -- later can be added and one who becomes illegal cannot.
    filter = function(room, use, target)
      local context = contextOf(use)
      if context == nil or context.big == nil then return false end
      if context.big then
        return H.isBigKingdomPlayer(target)
      end
      return H.isSmallKingdomPlayer(target)
    end,
  })
end)

return skill
