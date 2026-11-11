local A = require "packages.hanjin.pkg.hanjin_mode.rules.adaptation"
local skill = fk.CreateSkill { name = "hanjin__drowning_skill" }

Fk:loadTranslationTable {
  ["hanjin__drowning_skill"] = "水淹七军",
  ["hanjin__drowning_throw"] = "弃置装备区里的所有牌",
  ["hanjin__drowning_damage"] = "受到%src造成的1点雷电伤害",
  ["#hanjin__drowning_skill"] = "选择一名装备区里有牌的其他角色，其选择：1.弃置装备区里的所有牌；2.受到你造成的1点雷电伤害",
}

local function currentUse(room)
  local event = room.logic:getCurrentEvent()
  local useEvent = event and event:findParent(GameEvent.UseCard)
  return useEvent and useEvent.data or nil
end

local function dealThunder(room, skillName, from, to, card)
  if from.dead or to.dead then return end
  room:damage {
    from = from,
    to = to,
    card = card,
    damage = 1,
    damageType = fk.ThunderDamage,
    skillName = skillName,
  }
end

skill:addEffect("cardskill", {
  prompt = "#hanjin__drowning_skill",
  target_num = 1,
  mod_target_filter = function(self, player, to_select)
    return to_select ~= player and #to_select:getCardIds("e") > 0
  end,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    local from, to = effect.from, effect.to
    if from.dead or to.dead then return end
    local use = currentUse(room)
    local both = use and A.hasEffect(use, "execute_both")
    if both then
      -- HanJin 助战: discard equipment first, then deal thunder damage.
      if #to:getCardIds("e") > 0 then to:throwAllCards("e") end
      dealThunder(room, skill.name, from, to, effect.card)
      return
    end
    local allChoices = { "hanjin__drowning_throw", "hanjin__drowning_damage:" .. from.id }
    local choices = table.clone(allChoices)
    if #to:getCardIds("e") == 0 then table.remove(choices, 1) end
    local choice = room:askToChoice(to, {
      choices = choices, all_choices = allChoices,
      skill_name = "hanjin__drowning", cancelable = false,
    })
    if choice == "hanjin__drowning_throw" then
      to:throwAllCards("e")
    else
      dealThunder(room, skill.name, from, to, effect.card)
    end
  end,
})

return skill
