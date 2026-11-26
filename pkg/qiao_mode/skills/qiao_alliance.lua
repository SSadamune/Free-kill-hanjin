-- 汉晋正式合纵入口：出牌阶段限一次，将至多三张有合纵标记的手牌展示并
-- 交给势力不同或未确定势力的一名角色；若其已确定势力且与你不同，摸等量牌。
-- 神授思召是“只能合纵手牌”的明文例外：进入装备区后的后续回合可把该实体
-- 装备一并混选，仍受总计三张、同一目标限制。
local M = require "packages.qiao.pkg.qiao_mode.rules.cards"
local Heg = require "packages.hegemony.util"

local ACTIVE = "qiao_shenshou_active-turn"
local skill = fk.CreateSkill { name = "qiao__alliance" }

local function shenshouId(player)
  for _, id in ipairs(player:getCardIds(Player.Equip)) do
    local card = Fk:getCardById(id, true)
    if card ~= nil and card.name == "qiao__shenshou_sizhao" then return id end
  end
end

--- 合纵标记属于实体牌。牌堆构建时由模式写入公开的 @@alliance 卡牌标记并同步到
--- 客户端；静态 extra_data 只在服务端打印牌时另行写入。两端都接受这两种来源，
--- 避免客户端只能看到牌面标记时无法点亮或提交装备区的神授思召。
local function canSelect(player, id, selected)
  if #selected >= 3 then return false end
  if table.contains(player:getCardIds(Player.Hand), id) then
    local card = Fk:getCardById(id)
    return M.hasAllianceMark(card) or M.isHeji(card)
  end
  -- 装备区的授权来自这张武器本身，实体牌标记是手牌合纵的通用条件。
  return id == shenshouId(player) and player:getMark(ACTIVE) == 0
end

skill:addEffect("active", {
  anim_type = "support",
  prompt = "#qiao__alliance-give",
  max_phase_use_time = 1,
  can_use = function(self, player)
    if player:usedSkillTimes(skill.name, Player.HistoryPhase) > 0 then return false end
    for _, id in ipairs(player:getCardIds("he")) do
      if canSelect(player, id, {}) then return true end
    end
    return false
  end,
  min_card_num = 1,
  max_card_num = 3,
  include_equip = true,
  card_filter = function(self, player, to_select, selected)
    return canSelect(player, to_select, selected)
  end,
  target_num = 1,
  target_filter = function(self, player, to_select, selected, selected_cards)
    return #selected == 0 and #selected_cards >= 1 and #selected_cards <= 3
      and Heg.canAlliance(player, to_select)
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    local target = effect.tos and effect.tos[1]
    local cards = effect.cards or {}
    if player == nil or target == nil or #cards < 1 or #cards > 3 then return end
    if not Heg.canAlliance(player, target) or target:isHandAreaSealed() then return end
    local seen = {}
    for _, id in ipairs(cards) do
      if seen[id] or not canSelect(player, id, {}) then return end
      seen[id] = true
    end
    room:showCards(cards, player)
    local draw = Heg.compareKingdomWith(target, player, true)
    room:moveCardTo(cards, Card.PlayerHand, target, fk.ReasonGive,
      skill.name, nil, true, player.id)
    if draw and not player.dead then
      player:drawCards(#cards, skill.name)
    end
  end,
})

Fk:loadTranslationTable {
  [skill.name] = "合纵",
  ["#qiao__alliance-give"] = "合纵：选择至多三张合纵牌，交给一名势力不同或未确定势力的角色",
  [":" .. skill.name] = "出牌阶段限一次，你可以将至多三张有“合”标记的手牌展示并"
    .. "交给与你势力不同或未确定势力的一名角色；若其已确定势力，你摸等量的牌。",
}
return skill
