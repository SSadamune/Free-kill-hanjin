-- JIN006 杜预 · 破竹
-- 主将技（☯️-1）：出牌阶段可将一张手牌当【出其不意】使用，次数等于
-- 本阶段三陈实际复原次数；额外出牌阶段重新按该阶段计数。
local U = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"
local T = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"
local UNEXPECTATION = "qiao__unexpectation"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin006_2",
  tags = { Skill.MainPlace },
  max_phase_use_time = function(self, player)
    return U.sanChenRestored(player)
  end,
}
skill.qiaoImplemented = true

skill:addEffect("viewas", {
  pattern = "unexpectation|.|.|.|" .. UNEXPECTATION,
  prompt = "#qiao__skill_jin006_2-prompt",
  include_equip = false,
  card_filter = function(self, player, to_select, selected)
    return #selected < 1 and table.contains(player:getCardIds("h"), to_select)
  end,
  view_as = function(self, player, cards)
    if #cards ~= 1 or not table.contains(player:getCardIds("h"), cards[1]) then return end
    local card = Fk:cloneCard(UNEXPECTATION)
    card.skillName = skill.name
    card:addSubcard(cards[1])
    return card
  end,
  enabled_at_play = function(self, player)
    return player.phase == Player.Play and #player:getCardIds("h") > 0
  end,
  enabled_at_response = Util.FalseFunc,
  before_use = function(self, player, use)
    if player.phase ~= Player.Play then return skill.name end
    local room, policy = player.room, T.default()
    T.attachUse(room, use, policy)
    if not T.validateUse(room, player, use, policy, nil, { require_trusted = true }) then
      T.releaseToken(room, use)
      return skill.name
    end
  end,
}, { check_skill_limit = true })

Fk:loadTranslationTable {
  ["qiao__skill_jin006_2"] = "破竹",
  ["#qiao__skill_jin006_2-prompt"] = "破竹：将一张手牌当【出其不意】使用",
}

return skill
