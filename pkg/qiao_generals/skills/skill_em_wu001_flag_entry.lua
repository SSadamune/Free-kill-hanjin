-- EM(WU001) 孙权 · 缘江烽火图入口
-- 吴势力角色（含君主本人）出牌阶段限一次：将一张装备牌置于持旗者的旗上。
local P = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_lord_wu"

local skill = fk.CreateSkill {
  name = P.ENTRY,
}
skill.qiaoImplemented = true

skill:addEffect("active", {
  prompt = "#qiao__skill_em_wu001_flag_entry-prompt",
  include_equip = true,
  target_num = 0,
  max_phase_use_time = 1,
  card_filter = function(self, player, to_select, selected)
    if #selected >= 1 then return false end
    local card = Fk:getCardById(to_select)
    return card ~= nil and card.type == Card.TypeEquip
  end,
  can_use = function(self, player)
    if player == nil or player.dead or player.phase ~= Player.Play then return false end
    if P.lordFor(player) == nil then return false end
    for _, id in ipairs(player:getCardIds("he")) do
      local card = Fk:getCardById(id)
      if card ~= nil and card.type == Card.TypeEquip then return true end
    end
    return false
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local lord = P.lordFor(player)
    local cards = effect.cards or {}
    if player == nil or lord == nil or #cards ~= 1 then return end
    local area = room:getCardArea(cards[1])
    if area ~= Card.PlayerHand and area ~= Card.PlayerEquip then return end
    lord:addToPile(P.PILE, cards, true, skill.name)
  end,
})

Fk:loadTranslationTable {
  [P.ENTRY] = "烽火图",
  [":" .. P.ENTRY] = "出牌阶段限一次，你可以将一张装备牌置于“缘江烽火图”上，称为“烽火”。",
  ["#qiao__skill_em_wu001_flag_entry-prompt"] = "缘江烽火图：将一张装备牌置于旗上，称为“烽火”",
}

return skill
