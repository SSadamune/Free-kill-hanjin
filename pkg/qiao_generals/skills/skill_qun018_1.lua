-- QUN018 邹氏 · 祸水
--
-- 规则基线：docs/development/implementation/generals/qun-standard.md 的 QUN018
-- 条目、docs/rules/only-as.md 同类来源写法；卡面文本见 data/standard.lua。
--
-- 本技能只负责主动段：
--   出牌阶段，弃置一张黑色牌并暗置一名“双将均明置”的其他角色一张武将牌，
--   然后其交给你一张牌。未写“限一次”，所以不加次数限制（每阶段可反复发动，
--   只要仍有合法目标与黑色牌）。
-- 暗置走 Q.hideGeneral → 上游公共 doHideGeneral：主副将选择、统领能力迁移与
-- 翼从来源保留由既有公共流程处理，本技能不重复实现。
--
-- 被动段“你的回合内，其他角色不能明置其武将牌”由房间级
-- qun_control_rule + util/qun_control 按来源维护；本技能不在自身触发里
-- 另写一份，避免中途明置与暗置/失技撤销出现两个状态来源。
local Q = require "packages.qiao.pkg.qiao_generals.util.qun_control"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun018_1",
}
skill.qiaoImplemented = true

--- 双将均明置的其他存活角色：主动段的合法目标。
--- 直接遍历公开的存活列表，不依赖 Room:getOtherPlayers：客户端（ClientPlayer）
--- 也会执行 can_use，而 ClientPlayer 没有 room 字段，公共房间经 Fk:currentRoom()。
local function hideTargets(room, player)
  local ret = {}
  if room == nil then return ret end
  for _, target in ipairs(room.alive_players or {}) do
    if target ~= player and target:isAlive() and not target:isRemoved()
      and Q.allGeneralsRevealed(target) then
      table.insert(ret, target)
    end
  end
  return ret
end

--- 可用于支付的黑牌：只在自己的手牌或装备区，且未被禁止弃置。
--- 弃一张黑牌是发动消耗，不能用别人的牌，也不能用禁弃的牌支付。
local function payableCards(player)
  local ret = {}
  for _, id in ipairs(player:getCardIds("he")) do
    local card = Fk:getCardById(id)
    if card ~= nil and card.color == Card.Black and not player:prohibitDiscard(card) then
      table.insert(ret, id)
    end
  end
  return ret
end

skill:addEffect("active", {
  anim_type = "control",
  prompt = "#qiao__skill_qun018_1",
  card_num = 1,
  target_num = 1,
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    return #selected < 1 and table.contains(payableCards(player), to_select)
  end,
  target_filter = function(self, player, to_select, selected, selected_cards)
    return #selected < 1 and to_select ~= player and Q.allGeneralsRevealed(to_select)
  end,
  can_use = function(self, player)
    local room = Fk:currentRoom()
    return player.phase == Player.Play
      and #payableCards(player) > 0
      and #hideTargets(room, player) > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    local cards = effect.cards or {}
    if player == nil or player.dead then return end
    if target == nil or target.dead or target:isRemoved() then return end
    if not Q.allGeneralsRevealed(target) then return end
    -- 黑色牌是发动消耗：只接受一张属于自己的、未被禁止弃置的黑色牌，
    -- 先弃置再结算后续效果。服务端复核不能依赖客户端已过滤的候选。
    if #cards ~= 1 then return end
    if not table.contains(player:getCardIds("he"), cards[1]) then return end
    local paid = Fk:getCardById(cards[1])
    if paid == nil or paid.color ~= Card.Black then return end
    if player:prohibitDiscard(paid) then return end
    room:throwCard({ paid.id }, skill.name, player, player)
    if player.dead or target.dead or target:isRemoved() then return end
    -- 弃牌可能改变状态：暗置前按当前状态复核。
    if not Q.allGeneralsRevealed(target) then return end

    if not Q.hideGeneral(room, player, target, skill.name) then return end
    if player.dead or target.dead or target:isRemoved() then return end

    -- “然后其交给你一张牌”：由目标自己选择一张手牌或装备牌，按公共给牌流程
    -- 移入你的手牌。目标没有牌时不产生此项效果。
    if #target:getCardIds("he") == 0 then return end
    local picked = room:askToChooseCards(target, {
      target = target,
      flag = "he",
      min = 1,
      max = 1,
      skill_name = skill.name,
      prompt = "#qiao__skill_qun018_1-give:" .. player.id,
      cancelable = false,
    })
    local id = picked and picked[1]
    if id == nil or not table.contains(target:getCardIds("he"), id) then return end
    room:moveCardTo({ id }, Card.PlayerHand, player, fk.ReasonGive,
      skill.name, nil, true, target)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun018_1"] = "祸水",
  [":qiao__skill_qun018_1"] = "你的回合内，其他角色不能明置其武将牌；出牌阶段，你可以弃置一张黑色牌并暗置一名武将牌均明置的其他角色一张武将牌，然后其交给你一张牌。",
  ["#qiao__skill_qun018_1"] = "祸水：弃置一张黑色牌，暗置一名武将牌均明置的其他角色一张武将牌，然后其交给你一张牌",
  ["#qiao__skill_qun018_1-give"] = "祸水：你须交给 %src 一张牌",
}

return skill
