-- HAN015 卢植 · 备寇
--
-- 主将技（☯️-1）。每名角色整局限一次：一名角色明置后已无暗置武将牌时，
-- 卢植可以令其摸两张或弃两张。包含卢植自己；已用对象按技能来源记录在卢植身上。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"

local skill = fk.CreateSkill {
  name = "qiao__skill_han015_2",
  tags = { Skill.MainPlace },
}
skill.qiaoImplemented = true

local USED = "qiao__skill_han015_2-used"
local DRAW = "qiao__skill_han015_2-draw"
local DISCARD = "qiao__skill_han015_2-discard"

---@param target ServerPlayer
---@return boolean
local function fullyRevealed(target)
  return target.general ~= "anjiang" and target.deputyGeneral ~= "anjiang"
end

skill:addEffect(fk.GeneralRevealed, {
  global = true,
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return player ~= nil and player:hasSkill(skill.name) and not player.dead
      and target ~= nil and not target.dead and fullyRevealed(target)
      and not table.contains(player:getTableMark(USED), target.id)
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local choices = { DRAW }
    if table.find(target:getCardIds("he"), function(id) return not target:prohibitDiscard(id) end) then
      table.insert(choices, DISCARD)
    end
    local choice = Selection.askOption(room, player, {
      choices = choices,
      all_choices = { DRAW, DISCARD },
      skill_name = skill.name,
      prompt = "#qiao__skill_han015_2-choice::" .. target.id,
    })
    if choice ~= DRAW and choice ~= DISCARD then return false end
    event:setCostData(self, { choice = choice })
    return true
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local choice = (event:getCostData(self) or {}).choice
    if target == nil or target.dead or target:isRemoved() then return end
    room:addTableMarkIfNeed(player, USED, target.id)
    if choice == DRAW then
      target:drawCards(2, skill.name)
    elseif #target:getCardIds("he") > 0 then
      room:askToDiscard(target, {
        min_num = 2,
        max_num = 2,
        include_equip = true,
        skill_name = skill.name,
        prompt = "#qiao__skill_han015_2-discard",
        cancelable = false,
      })
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_han015_2"] = "备寇",
  [":qiao__skill_han015_2"] = "主将技（☯️-1），每名角色限一次，当一名角色的武将牌明置后，若其已没有暗置的武将牌，你可以令其摸两张牌或弃置两张牌。",
  ["#qiao__skill_han015_2-choice"] = "备寇：你可以令 %dest 摸两张牌或弃置两张牌",
  ["#qiao__skill_han015_2-discard"] = "备寇：弃置两张牌",
  [DRAW] = "令其摸两张牌",
  [DISCARD] = "令其弃置两张牌",
}

return skill
