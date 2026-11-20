-- SHU011 诸葛亮（卧龙） · 看破
--
-- 规则基线：docs/rules/standard-generals.md 蜀区 SHU011。
-- 你可以将一张黑色手牌当【无懈可击】使用（只使用，不打出）。
-- 你抵消过牌的回合结束时，你可以观看当前回合角色的手牌。
-- “抵消过牌”以实际成功抵消为准，不限由看破转化；仅打出无懈或使用后被再次
-- 无懈而不成立，不计入。
local skill = fk.CreateSkill {
  name = "qiao__skill_shu011_3",
}
skill.qiaoImplemented = true

local CANCELLED = "qiao__skill_shu011_3-cancelled-turn"

skill:addEffect("viewas", {
  anim_type = "defensive",
  pattern = "nullification",
  prompt = "#qiao__skill_shu011_3-prompt",
  handly_pile = true,
  filter_pattern = {
    min_num = 1,
    max_num = 1,
    pattern = ".|.|black|^equip",
  },
  enabled_at_response = function(self, player, response)
    -- 无懈可击本身的响应窗口属于“使用”；纯打出窗口不开放。
    return not response
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 then return nil end
    local card = Fk:cloneCard("qiao__nullification")
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
})

local S = require "packages.qiao.pkg.qiao_generals.util.cancel_source"

-- 全局记录：本回合实际成功抵消过牌的角色。用真实响应使用事件确认抵消者，
-- 覆盖实体/虚拟闪、无懈及非看破转化；自己的无懈被反无懈时抵消者不是自己，
-- 不会误计。
skill:addEffect(fk.CardEffectCancelledOut, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and data.card ~= nil
      and S.canceller(player.room, data) == player
  end,
  on_refresh = function(self, event, target, player, data)
    player.room:addPlayerMark(player, CANCELLED, 1)
  end,
})

skill:addEffect(fk.TurnEnd, {
  global = true,
  can_refresh = function(self, event, target, player, data)
    return player:hasSkill(skill.name) and player:getMark(CANCELLED) > 0
      and target ~= nil and target ~= player and not target.dead
  end,
  on_refresh = function(self, event, target, player, data)
    local room = player.room
    if room:askToSkillInvoke(player, {
      skill_name = skill.name,
      prompt = "#qiao__skill_shu011_3-view",
    }) then
      room:viewCards(player, {
        cards = target:getCardIds("h"),
        skill_name = skill.name,
        prompt = "#qiao__skill_shu011_3-view_prompt:" .. target.id,
      })
    end
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_shu011_3"] = "看破",
  [":qiao__skill_shu011_3"] = "你可以将一张黑色手牌当【无懈可击】使用。你抵消过牌的回合结束时，你可以观看当前回合角色的手牌。",
  ["#qiao__skill_shu011_3-prompt"] = "看破：将一张黑色手牌当【无懈可击】使用",
  ["#qiao__skill_shu011_3-view"] = "看破：观看当前回合角色的手牌",
  ["#qiao__skill_shu011_3-view_prompt"] = "看破：观看当前回合角色的手牌",
}

return skill
