-- HanJin-specific adapter for 【联军盛宴】.  The effect and normal target
-- selection stay the local upstream implementation.  The chosen other kingdom
-- is captured for this use so that reducing the target list (even to zero)
-- cannot silently start a new kingdom choice.
local H = require "packages.hegemony.util"
local ExtraTargets = require "packages.qiao.pkg.qiao_mode.rules.extra_targets"

local skill = fk.CreateSkill { name = "qiao__alliance_feast_skill" }

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
  return (use.extra_data or {}).qiao_extra_target_context
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
      use.extra_data.qiao_extra_target_context = {
        initial_targets = table.simpleClone(use.tos),
        representative = first,
        kingdom = H.getKingdom(first),
      }
    end
    return upstream():onUse(room, use)
  end,
  on_effect = function(self, room, effect)
    local from, to = effect.from, effect.to
    if from == nil or to == nil then return end
    if to ~= from then
      if to.dead then return end
      to:drawCards(1, skill.name)
      if to.chained then to:setChainState(false) end
      return
    end

    -- 使用者的效果改为按其他最终目标数逐次选择并执行。
    local others = 0
    for _, target in ipairs(effect.tos or {}) do
      if target ~= from then others = others + 1 end
    end
    for index = 1, others do
      if from.dead then return end
      local choice = room:askToChoice(from, {
        choices = { "alliance_feast_recover:::1", "alliance_feast_draw:::1" },
        skill_name = "alliance_feast_skill",
        prompt = "#qiao__alliance_feast-choice:::" .. (others - index + 1),
      })
      if choice == nil then return end
      if choice:startsWith("alliance_feast_recover") then
        room:recover {
          who = from,
          recoverBy = from,
          card = effect.card,
          num = 1,
          skillName = skill.name,
        }
      else
        from:drawCards(1, skill.name)
      end
    end
  end,
})

-- 使用者必须先结算自己的 X 次选择，再按座次结算其他目标。引擎按
-- use.tos 顺序生效，额外目标在 on_use 之后才加入，因此在 CardUsing
-- （AfterCardTargetDeclared 之后、实际生效之前）重排。
skill:addEffect(fk.CardUsing, {
  global = true,
  mute = true,
  priority = -200,
  can_trigger = function(self, event, target, player, data)
    return target == player and data.card ~= nil
      and data.card.name == "qiao__alliance_feast"
  end,
  on_cost = Util.TrueFunc,
  on_use = function(self, event, target, player, data)
    local from = data.from
    local selfTargeted = false
    local others = {}
    for _, to in ipairs(data.tos or {}) do
      if to == from then
        selfTargeted = true
      else
        table.insert(others, to)
      end
    end
    if not selfTargeted then return end
    Fk:currentRoom():sortByAction(others, from)
    local ordered = { from }
    for _, to in ipairs(others) do table.insert(ordered, to) end
    data.tos = ordered
  end,
})

Fk:loadTranslationTable {
  ["qiao__alliance_feast_skill"] = "联军盛宴",
  ["#qiao__alliance_feast-choice"] = "联军盛宴：选择一项（剩余%arg次）：回复1点体力或摸一张牌",
}

Fk:addPostLoadFunc(function()
  local loaded = Fk.skills["qiao__alliance_feast_skill"]
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
