-- JIN018 陈骞 · 武督
-- 出牌阶段限一次，你可以弃置一张牌并令一名有手牌的角色选择一项：
-- 1.其手牌对所有角色可见直到其回合结束；2.你对其造成1点伤害。
local Selection = require "packages.qiao.pkg.qiao_mode.rules.trigger_selection"
local Visibility = require "packages.qiao.pkg.qiao_mode.rules.card_visibility"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin018_2",
}
skill.qiaoImplemented = true

local OPT_OPEN = "#qiao__skill_jin018_2-open"
local OPT_DAMAGE = "#qiao__skill_jin018_2-damage"

local function discardableCards(player)
  return table.filter(player:getCardIds("he"), function(id)
    return not player:prohibitDiscard(id)
  end)
end

--- 判断在选定 cardId 弃置后，target 是否仍满足“有手牌的角色”（兼容选陈骞自己）。
local function validTargetForCard(player, target, cardId)
  if target == nil or target.dead or target:isRemoved() then return false end
  local handCount = target:getHandcardNum()
  if handCount == 0 then return false end
  if target == player and cardId ~= nil and table.contains(player:getCardIds("h"), cardId) then
    return handCount >= 2
  end
  return true
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_jin018_2-prompt",
  max_phase_use_time = 1,
  card_num = 1,
  target_num = 1,
  can_use = function(self, player)
    if player:usedSkillTimes(skill.name, Player.HistoryPhase) > 0 then return false end
    local cards = discardableCards(player)
    if #cards == 0 then return false end
    local room = Fk:currentRoom()
    if room == nil then return false end
    for _, p in ipairs(room:getPresentPlayers()) do
      for _, id in ipairs(cards) do
        if validTargetForCard(player, p, id) then return true end
      end
    end
    return false
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and not player:prohibitDiscard(to_select)
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    if #selected > 0 then return false end
    local cardId = selected_cards and selected_cards[1]
    if cardId ~= nil then
      return validTargetForCard(player, to_select, cardId)
    end
    for _, id in ipairs(discardableCards(player)) do
      if validTargetForCard(player, to_select, id) then return true end
    end
    return false
  end,
  feasible = function(self, player, selected, selected_cards)
    return #selected == 1 and #selected_cards == 1
      and validTargetForCard(player, selected[1], selected_cards[1])
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    local cardId = effect.cards and effect.cards[1]
    if player == nil or player.dead or cardId == nil or not validTargetForCard(player, target, cardId) then
      return
    end
    -- 按通用消耗裁定：执行弃置即支付消耗。
    room:throwCard({ cardId }, skill.name, player, player)
    if not RemovedTargets.isPresent(target) then return end
    local choice = Selection.askOption(room, target, {
      choices = { OPT_OPEN, OPT_DAMAGE },
      skill_name = skill.name,
      prompt = "#qiao__skill_jin018_2-choose:" .. player.id,
      cancelable = false,
    })
    if choice == OPT_OPEN then
      room:setPlayerMark(target, Visibility.WUDU_OPEN, 1)
    elseif choice == OPT_DAMAGE and RemovedTargets.isPresent(target) then
      room:damage {
        from = player,
        to = target,
        damage = 1,
        skillName = skill.name,
      }
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "武督",
  [":" .. skill.name] = "出牌阶段限一次，你可以弃置一张牌并令一名有手牌的角色选择一项：1.其手牌对所有角色可见直到其回合结束；2.你对其造成1点伤害。",
  ["#qiao__skill_jin018_2-prompt"] = "武督：弃置一张牌，令一名有手牌的角色选择明牌至回合结束或受到1点伤害",
  ["#qiao__skill_jin018_2-choose"] = "武督：选择一项（发动者 %src）",
  [OPT_OPEN] = "手牌对所有角色可见直到你回合结束",
  [OPT_DAMAGE] = "受到1点伤害",
}

return skill
