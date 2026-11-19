-- 黑光铠：成为伤害牌或黑色非伤害锦囊牌的目标后，不是唯一目标时此牌对其无效。
--
-- 规则基线：docs/rules/card-deck.md「普通锦囊与装备的审阅结论 · 黑光铠」。
-- 伤害牌 MUST 按汉晋统一口径判断（伤害牌名单排除【闪电】与伤害装备），不能沿用
-- 引擎里把【闪电】也标记为伤害牌的 is_damage_card 字段；黑色非伤害锦囊分支保留。
local J = require "packages.qiao.pkg.qiao_generals.util.jin_adaptation"

local skill = fk.CreateSkill {
  name = "qiao__dark_armor_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__dark_armor",
}

Fk:loadTranslationTable {
  ["qiao__dark_armor_skill"] = "黑光铠",
}

skill:addEffect(fk.TargetConfirmed, {
  can_trigger = function(self, event, target, player, data)
    if target ~= player or not player:hasSkill(skill.name) then return false end
    if data.card == nil or data.use == nil then return false end
    -- 此牌不是唯一目标：群体牌或多目标牌的其他目标照常结算。
    if #(data.use.tos or {}) <= 1 then return false end
    return J.isDamageCard(data.card)
      or (data.card.color == Card.Black and data.card.type == Card.TypeTrick)
  end,
  on_use = function(self, event, target, player, data)
    data:setNullified(player)
  end,
})

return skill
