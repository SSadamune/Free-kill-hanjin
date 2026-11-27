local S = require "packages.qiao.pkg.qiao_bingqing.nu"
local skill = fk.CreateSkill { name = "qiao__retinue_skill_hubaoqi" }
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local FIRST = "qiao_hubaoqi_first-turn"
skill:addEffect(fk.PreCardUse, {
  global = true,
  can_refresh = function(self, event, target, p, data)
    return target == p and data.card.trueName == "slash" and p:hasSkill(skill.name, true)
      and p.room.current and p.room.current:getMark(FIRST) == 0
  end,
  on_refresh = function(self, event, target, p, data) data.qiao_hubaoqi_candidate = true end,
})
skill:addEffect(fk.BeforeCardUseEffect, {
  global = true,
  can_refresh = function(self, event, target, p, data) return target == p and data.qiao_hubaoqi_candidate end,
  on_refresh = function(self, event, target, p, data) data.qiao_hubaoqi_targets_set = true end,
})

skill:addEffect(fk.CardUseFinished, {
  global = true,
  can_refresh = function(self, event, target, p, data)
    return target == p and data.qiao_hubaoqi_candidate and p.room.current:getMark(FIRST) == 0
  end,
  on_refresh = function(self, event, target, p, data)
    local to = #data.tos == 1 and data.tos[1] or data.qiao_hubaoqi_nested
    if not to then return end
    -- 先宣告的外层杀优先。其目标还可能增减时，暂存首个已结算的候选。
    local use = p.room.logic:getCurrentEvent():findParent(GameEvent.UseCard, true)
    local ancestor = use.parent
    while ancestor and ancestor.event ~= GameEvent.Turn do
      if ancestor.event == GameEvent.UseCard then
        local outer = ancestor.data
        if outer.qiao_hubaoqi_candidate and (not outer.qiao_hubaoqi_targets_set or #outer.tos == 1 or outer.qiao_hubaoqi_nested) then
          outer.qiao_hubaoqi_nested = outer.qiao_hubaoqi_nested or to
          return
        end
      end
      ancestor = ancestor.parent
    end
    p.room:setPlayerMark(p.room.current, FIRST, 1)
    data.qiao_hubaoqi_target = to
  end,
  on_trigger = S.each,
  can_trigger = function(self, event, target, p, data)
    return data.qiao_hubaoqi_target and p:hasSkill(skill.name) and S.present(data.qiao_hubaoqi_target)
  end,
  on_cost = function(self, event, target, p, data)
    local to = data.qiao_hubaoqi_target
    local use = C.askToUseCard(p.room, p, { names = C.concreteNames("slash"), pattern = "slash", cancelable = true, skill_name = skill.name,
      policy = C.bypassDistance(), extra_data = { exclusive_targets = { to.id } } })
    if use and #use.tos == 1 and use.tos[1] == to then event:setCostData(self, { use = use }); return true end
    return false
  end,
  on_use = function(self, event, target, p)
    p.room:useCard(event:getCostData(self).use)
    if S.present(p) then p:drawCards(1, skill.name) end
  end,
})
return skill
