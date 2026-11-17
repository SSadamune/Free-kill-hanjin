-- QUN003 貂蝉 · 离间
--
-- 规则基线：rules/standard-generals.md 群区 QUN003、群包审阅
-- docs/development/implementation/generals/qun-standard.md。
-- 弃置一张自己的牌，选择两名其他男性角色：由后选者视为对先选者使用一张
-- 【决斗】。决斗的使用者是被选中的男性，不是貂蝉本人；决斗使用本包的正式
-- 牌 qiao__duel，并经公共 card_use_targets 的显式目标策略声明两男性目标。
-- 「不可被抵消」使用引擎原生的 unoffsetable 语义（AimData:setUnoffsetable /
-- UseCardData.unoffsetableList）：无懈可击窗口按 CardEffectData:isUnoffsetable(p)
-- 逐个排除响应者，此处令所有角色都不可抵消这张决斗；决斗内打【杀】的响应
-- 不用 disresponsive，仍按原流程结算。
local C = require "packages.qiao.pkg.qiao_mode.rules.card_use_targets"

local skill = fk.CreateSkill {
  name = "qiao__skill_qun003_1",
}
skill.qiaoImplemented = true

local function duelReady(player, to)
  return to ~= nil and to ~= player and to:isAlive() and not to:isRemoved() and to:isMale()
end

skill:addEffect("active", {
  anim_type = "offensive",
  prompt = "#qiao__skill_qun003_1",
  card_num = 1,
  target_num = 2,
  include_equip = true,
  can_use = function(self, player)
    return player:usedSkillTimes(skill.name, Player.HistoryPhase) == 0
      and not player:isNude()
  end,
  card_filter = function(self, player, to_select, selected)
    return #selected == 0 and not player:prohibitDiscard(to_select)
  end,
  target_filter = function(self, player, to_select, selected)
    if #selected >= 2 or to_select == player or not to_select:isMale() then return false end
    if to_select.dead or to_select:isRemoved() then return false end
    if #selected == 0 then return true end
    return to_select:canUseTo(Fk:cloneCard("qiao__duel"), selected[1])
  end,
  on_use = function(self, room, effect)
    local player = effect.from
    room:throwCard(effect.cards, skill.name, player, player)
    local target, user = effect.tos[1], effect.tos[2]
    -- 服务端复核：两名目标都必须是仍存活的男性其他角色，且使用者能对目标使用决斗。
    if not duelReady(player, target) or not duelReady(player, user) then return end
    if user == target then return end
    local card = Fk:cloneCard("qiao__duel")
    if card == nil then return end
    card.skillName = skill.name

    ---@type UseCardDataSpec
    local use = {
      from = user,
      tos = { target },
      card = card,
      -- 原生「不可被抵消」：所有角色都不能以【无懈可击】抵消此决斗。
      unoffsetableList = table.simpleClone(room:getAlivePlayers()),
    }
    -- 显式目标策略：目标是使用者的其他角色；不使用上游牌，也不改写公共验证。
    C.useCard(room, user, use, C.explicit({ other_roles = true }, { names = { "qiao__duel" } }))
  end,
  target_tip = function(self, player, to_select, selected, selected_cards, card, selectable)
    if not selectable then return end
    if #selected == 0 then
      return "#qiao__skill_qun003_1-first"
    end
    return "#qiao__skill_qun003_1-second"
  end,
})

Fk:loadTranslationTable {
  ["qiao__skill_qun003_1"] = "离间",
  [":qiao__skill_qun003_1"] = "出牌阶段限一次，你可以弃置一张牌并选择两名其他男性角色，令其中一名角色视为对其中另一名角色使用一张【决斗】（不可被抵消）。",
  ["#qiao__skill_qun003_1"] = "离间：弃置一张牌，选择两名其他男性角色，后选者视为对先选者使用【决斗】",
  ["#qiao__skill_qun003_1-first"] = "离间：先选择决斗的目标（被决斗者）",
  ["#qiao__skill_qun003_1-second"] = "离间：选择决斗的使用者",
}

return skill
