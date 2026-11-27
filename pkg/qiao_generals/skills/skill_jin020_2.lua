-- JIN020 荀勖 · 拨律
-- 出牌阶段限一次，你可以选择一名角色并重铸一张手牌，根据花色修改其使用下张应变牌的应变条件：
-- 黑桃~富甲；红桃~残躯；梅花~助战；方片~空巢。
local A = require "packages.qiao.pkg.qiao_mode.rules.adaptation"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin020_2",
}
skill.qiaoImplemented = true

local SUIT_TO_CONDITION = {
  [Card.Spade] = "fujia",
  [Card.Heart] = "canqu",
  [Card.Club] = "zhuzhan",
  [Card.Diamond] = "kongchao",
}

skill:addEffect("active", {
  anim_type = "support",
  prompt = "#qiao__skill_jin020_2-prompt",
  max_phase_use_time = 1,
  card_num = 1,
  target_num = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
      and not player:isKongcheng()
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and table.contains(player:getCardIds("h"), to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= nil and not to_select.dead and not to_select:isRemoved()
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    local cardId = effect.cards and effect.cards[1]
    if player == nil or player.dead or target == nil or cardId == nil then return end
    if not table.contains(player:getCardIds("h"), cardId) then return end
    local card = Fk:getCardById(cardId)
    local cond = card and SUIT_TO_CONDITION[card.suit] or nil
    room:recastCard({ cardId }, player, skill.name)
    if cond ~= nil and RemovedTargets.isPresent(target) then
      room:setPlayerMark(target, A.BOLU_MARK, "qiao_condition_" .. cond)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "拨律",
  [":" .. skill.name] = "出牌阶段限一次，你可以选择一名角色并重铸一张手牌，根据花色修改其使用下张应变牌的应变条件：黑桃~富甲；红桃~残躯；梅花~助战；方片~空巢。",
  ["#qiao__skill_jin020_2-prompt"] = "拨律：重铸一张手牌，修改一名角色下张应变牌的条件（♠富甲、♥残躯、♣助战、♦空巢）",
}

return skill
