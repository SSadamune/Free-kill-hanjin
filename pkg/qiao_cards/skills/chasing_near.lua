local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local skill = fk.CreateSkill { name = "qiao__chasing_near_skill" }

Fk:loadTranslationTable {
  ["qiao__chasing_near_skill"] = "逐近弃远",
  ["#qiao__chasing_near_skill"] = "选择一名其他角色",
  ["#qiao__chasing_near-prey"] = "获得牌",
  ["#qiao__chasing_near-discard"] = "弃置牌",
  ["#qiao__chasing_near-choose-prey"] = "逐近弃远：选择 %dest 的一张牌获得",
  ["#qiao__chasing_near-choose-discard"] = "逐近弃远：选择 %dest 的一张牌弃置",
}

local function currentUse(room)
  local event = room.logic:getCurrentEvent()
  local useEvent = event and event:findParent(GameEvent.UseCard)
  return useEvent and useEvent.data or nil
end

skill:addEffect("cardskill", {
  prompt = "#qiao__chasing_near_skill",
  target_num = 1,
  target_tip = function(self, player, to_select)
    if player:distanceTo(to_select) == 1 then
      return "#qiao__chasing_near-prey"
    elseif player:distanceTo(to_select) > 1 then
      return "#qiao__chasing_near-discard"
    end
  end,
  mod_target_filter = function(self, player, to_select)
    return to_select ~= player
  end,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    local from, to = effect.from, effect.to
    if from.dead or to.dead or to:isAllNude() then return end
    local use = currentUse(room)
    local both = use and A.hasEffect(use, "execute_both")
    local firstPrompt = (both or from:distanceTo(to) > 1)
      and "#qiao__chasing_near-choose-discard" or "#qiao__chasing_near-choose-prey"
    local first = room:askToChooseCard(from, {
      target = to,
      flag = "hej",
      skill_name = skill.name,
      prompt = firstPrompt .. "::" .. to.id .. ":" .. skill.name,
    })
    if both then
      -- HanJin adaptation: discard first, then obtain from the remaining area.
      room:throwCard(first, skill.name, to, from)
      if from.dead or to.dead or to:isAllNude() then return end
      local second = room:askToChooseCard(from, {
        target = to,
        flag = "hej",
        skill_name = skill.name,
        prompt = "#qiao__chasing_near-choose-prey::" .. to.id .. ":" .. skill.name,
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
