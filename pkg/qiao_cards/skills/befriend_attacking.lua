-- HanJin 【远交近攻】。
--
-- 印刷牌面：目标角色摸一张牌；若此牌对任意目标生效过，使用者摸三张牌。
-- 目标选择沿用本地国战实现（势力不同、已确定势力），效果改为每次使用只
-- 触发一次使用者的摸三张：多目标结算时首名实际生效的目标之后摸一次，
-- 全被抵消时不摸。
local H = require "packages.hegemony.util"

local skill = fk.CreateSkill { name = "qiao__befriend_attacking_skill" }

Fk:loadTranslationTable {
  ["qiao__befriend_attacking_skill"] = "远交近攻",
  ["#qiao__befriend_attacking_skill"] = "选择一名势力与你不同的其他角色",
}

skill:addEffect("cardskill", {
  prompt = "#qiao__befriend_attacking_skill",
  target_num = 1,
  mod_target_filter = function(self, player, to_select, selected)
    return player ~= to_select and H.compareKingdomWith(to_select, player, true)
  end,
  target_filter = Util.CardTargetFilter,
  on_effect = function(self, room, effect)
    local from, to = effect.from, effect.to
    if from == nil or to == nil or to.dead then return end
    to:drawCards(1, skill.name)
    if from.dead then return end
    local extra = effect.extra_data or (effect.use and effect.use.extra_data)
    if extra ~= nil then
      if extra.qiao_befriend_attacking_drawn then return end
      extra.qiao_befriend_attacking_drawn = true
    end
    from:drawCards(3, skill.name)
  end,
})

return skill
