-- JIN006 杜预 · 破竹
-- 主将技（☯️-1）：出牌阶段可将一张手牌当【出其不意】使用，次数等于
-- 本阶段三陈实际复原次数；额外出牌阶段重新按该阶段计数。
local U = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_jin"

local skill = fk.CreateSkill {
  name = "qiao__skill_jin006_2",
  tags = { Skill.MainPlace },
}
skill.qiaoImplemented = true

skill:addEffect("active", {
  prompt = "#qiao__skill_jin006_2-prompt",
  card_num = 1,
  target_num = 0,
  include_equip = false,
  max_phase_use_time = function(self, player)
    return U.sanChenRestored(player)
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected < 1 and table.contains(player:getCardIds("h"), to_select)
  end,
  can_use = function(self, player)
    return U.sanChenRestored(player) > 0 and #player:getCardIds("h") > 0
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local ids = effect.cards or {}
    if player == nil or player.dead or #ids ~= 1 then return end
    local id = ids[1]
    if not table.contains(player:getCardIds("h"), id) then return end
    require("packages.qiao.pkg.qiao_mode.rules.card_use_targets").useVirtualCard(
      room, player, "qiao__unexpectation", { id }, nil, skill.name, false, nil)
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_jin006_2"] = "破竹",
  ["#qiao__skill_jin006_2-prompt"] = "破竹：将一张手牌当【出其不意】使用",
}

return skill
