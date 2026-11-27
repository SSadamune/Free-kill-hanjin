-- HAN021 曹节 · 悬壶
-- 每回合结束时，若本回合你的红色牌置入过弃牌堆，你可以令一名角色摸或弃置一张牌，
-- 然后若其手牌数等于体力值，其回复1点体力。
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"
local TriggerSelection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Quan = require "packages.qiao.pkg.qiao_generals.util.quan_common"

local skill = fk.CreateSkill {
  name = "qiao__skill_han021_2",
}
skill.qiaoImplemented = true

local DRAW = "#qiao__skill_han021_2-draw"
local DISCARD = "#qiao__skill_han021_2-discard"

local function hasDiscardable(target)
  return table.find(target:getCardIds("he"), function(id)
    return not target:prohibitDiscard(id)
  end) ~= nil
end

skill:addEffect(fk.TurnEnd, {
  anim_type = "support",
  can_trigger = function(self, event, target, player, data)
    return RemovedTargets.isPresent(player) and player:hasSkill(skill.name)
      and player:getMark(Quan.XUANHU_RED_MARK) > 0
      and #player.room:getPresentPlayers() > 0
  end,
  on_cost = function(self, event, target, player, data)
    local room = player.room
    local targets = room:getPresentPlayers()
    local chosen = room:askToChoosePlayers(player, {
      targets = targets,
      min_num = 1,
      max_num = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_han021_2-target",
      cancelable = true,
    })
    if chosen and #chosen == 1 then
      event:setCostData(self, { to = chosen[1] })
      return true
    end
    return false
  end,
  on_use = function(self, event, target, player, data)
    local room = player.room
    local cost = event:getCostData(self) or {}
    local to = cost.to
    if not RemovedTargets.isPresent(to) then return end
    local choices = { DRAW }
    if hasDiscardable(to) then table.insert(choices, DISCARD) end
    local choice = DRAW
    if #choices > 1 then
      choice = TriggerSelection.askOption(room, player, {
        choices = choices,
        all_choices = { DRAW, DISCARD },
        cancelable = false,
        buttons = true,
        skill_name = skill.name,
        prompt = "#qiao__skill_han021_2-choice::" .. to.id,
      }) or DRAW
    end
    if choice == DISCARD and hasDiscardable(to) then
      room:askToDiscard(to, {
        min_num = 1,
        max_num = 1,
        include_equip = true,
        skill_name = skill.name,
        prompt = "#qiao__skill_han021_2-do-discard",
        cancelable = false,
      })
    else
      to:drawCards(1, skill.name)
    end
    if RemovedTargets.isPresent(to) and to:getHandcardNum() == to.hp and to:isWounded() then
      room:recover {
        who = to,
        num = 1,
        recoverBy = player,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "悬壶",
  [":" .. skill.name] = "每回合结束时，若本回合你的红色牌置入过弃牌堆，你可以令一名角色摸或弃置一张牌，然后若其手牌数等于体力值，其回复1点体力。",
  ["#qiao__skill_han021_2-target"] = "悬壶：选择一名角色，令其摸一张牌或弃置一张牌",
  ["#qiao__skill_han021_2-choice"] = "悬壶：选择令 %dest 执行的一项",
  [DRAW] = "令其摸一张牌",
  [DISCARD] = "令其弃置一张牌",
  ["#qiao__skill_han021_2-do-discard"] = "悬壶：请弃置一张牌",
}

return skill
