local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
local skill = fk.CreateSkill { name = "hanjin__chasing_near_skill" }

Fk:loadTranslationTable {
  ["hanjin__chasing_near_skill"] = "逐近弃远",
  ["#hanjin__chasing_near_skill"] = "选择一名区域里有牌的其他角色，若距离为1则获得其区域里一张牌，若距离大于1则弃置其区域里一张牌",
  ["#hanjin__chasing_near-prey"] = "获得牌",
  ["#hanjin__chasing_near-discard"] = "弃置牌",
}

local function currentUse(room)
  local event = room.logic:getCurrentEvent()
  local useEvent = event and event:findParent(GameEvent.UseCard)
  return useEvent and useEvent.data or nil
end

skill:addEffect("cardskill", {
  prompt = "#hanjin__chasing_near_skill",
  target_num = 1,
  target_tip = function(self, player, to_select)
    if player:distanceTo(to_select) == 1 then
      return "#hanjin__chasing_near-prey"
    elseif player:distanceTo(to_select) > 1 then
      return "#hanjin__chasing_near-discard"
    end
  end,
  mod_target_filter = function(self, player, to_select)
    return to_select ~= player and not to_select:isAllNude()
  end,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    local from, to = effect.from, effect.to
    if from.dead or to.dead or to:isAllNude() then return end
    local use = currentUse(room)
    local both = use and A.hasEffect(use, "execute_both")
    local first = room:askToChooseCard(from, {
      target = to,
      flag = "hej",
      skill_name = skill.name,
    })
    if both then
      -- HanJin adaptation: discard first, then obtain from the remaining area.
      room:throwCard(first, skill.name, to, from)
      if from.dead or to.dead or to:isAllNude() then return end
      local second = room:askToChooseCard(from, {
        target = to,
        flag = "hej",
        skill_name = skill.name,
      })
      room:obtainCard(from, second, false, fk.ReasonPrey, from, skill.name)
    elseif from:distanceTo(to) > 1 then
      room:throwCard(first, skill.name, to, from)
    elseif from:distanceTo(to) == 1 then
      room:obtainCard(from, first, false, fk.ReasonPrey, from, skill.name)
    end
  end,
})

return skill
