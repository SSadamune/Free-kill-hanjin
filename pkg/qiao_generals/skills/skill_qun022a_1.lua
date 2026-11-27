-- QUN022A 李傕 · 凶算
-- 限定技，出牌阶段，你可以弃置一张手牌并对一名与你势力相同的角色造成1点伤害，
-- 然后摸三张牌，回合结束时复原其一个限定技。
local H = require "packages.hegemony.util"
local RemovedTargets = require "packages.qiao.pkg.qiao_mode.rules.removed_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun022a_1",
  tags = { Skill.Limited },
}
skill.qiaoImplemented = true

local XIONGSUAN_TAG = "qiao_qun022a_xiongsuan_pending"

local function hasDiscardableHand(player)
  return table.find(player:getCardIds("h"), function(id)
    return not player:prohibitDiscard(id)
  end) ~= nil
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_qun022a_1-prompt",
  max_game_use_time = 1,
  card_num = 1,
  target_num = 1,
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryGame) == 0
      and hasDiscardableHand(player)
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0
      and table.contains(player:getCardIds("h"), to_select)
      and not player:prohibitDiscard(to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    return #selected == 0 and to_select ~= nil and not to_select.dead
      and not to_select:isRemoved() and H.compareKingdomWith(to_select, player)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    if player == nil or player.dead or target == nil or not RemovedTargets.isPresent(target) then return end
    if not H.compareKingdomWith(target, player) or #(effect.cards or {}) ~= 1 then return end
    -- 按通用消耗裁定：执行弃置即支付消耗。
    room:throwCard(effect.cards, skill.name, player, player)
    if RemovedTargets.isPresent(target) then
      room:damage {
        from = player,
        to = target,
        damage = 1,
        skillName = skill.name,
      }
    end
    if not player.dead and not player:isRemoved() then
      player:drawCards(3, skill.name)
    end
    local pending = room:getTag(XIONGSUAN_TAG) or {}
    table.insert(pending, { source_id = player.id, target_id = target.id })
    room:setTag(XIONGSUAN_TAG, pending)
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "凶算",
  [":" .. skill.name] = "限定技，出牌阶段，你可以弃置一张手牌并对一名与你势力相同的角色造成1点伤害，然后摸三张牌，回合结束时复原其一个限定技。",
  ["#qiao__skill_qun022a_1-prompt"] = "凶算：弃置一张手牌，对一名与你势力相同的角色造成1点伤害并摸三张牌",
}

return skill
