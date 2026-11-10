local extension = Package:new("hanjin_cards", Package.CardPack)
extension.extensionName = "hanjin"
extension.game_modes_whitelist = { "hanjin_heg_mode" }
extension:loadSkillSkelsByPath("./packages/hanjin/pkg/hanjin_cards/skills")

-- Independent formal card: 雷杀, exactly spade 9 and spade 10.
-- The double separator is intentional: Card:trueName is the last "__" segment,
-- so "hanjin__thunder__slash" is an independent card whose trueName is "slash"
-- and therefore follows Slash timing, distance, response and history rules.
-- 孤军 → 此牌无视次数. The entry is part of each physical card's own data so a
-- view-as card does not inherit it unless its skill explicitly adds the entry.
local function gujunEntries()
  return {
    { id = "hanjin_thunder_slash_gujun", condition = "gujun", effect = "ignore_times" },
  }
end

local thunder_slash = fk.CreateCard {
  name = "hanjin__thunder__slash",
  type = Card.TypeBasic,
  is_damage_card = true,
  damage_type = fk.ThunderDamage,
  skill = "hanjin__thunder_slash_skill",
  extra_data = { hanjin_adaptation = gujunEntries() },
}
extension:loadCardSkels { thunder_slash }
extension:addCardSpec("hanjin__thunder__slash", Card.Spade, 9, { hanjin_adaptation = gujunEntries() })
extension:addCardSpec("hanjin__thunder__slash", Card.Spade, 10, { hanjin_adaptation = gujunEntries() })

Fk:loadTranslationTable {
  ["hanjin_cards"] = "紫乔汉晋·卡牌",
  ["hanjin__thunder__slash"] = "雷杀",
  [":hanjin__thunder__slash"] = "基本牌<br/><b>时机</b>：出牌阶段<br/><b>目标</b>：攻击范围内的一名角色<br/>"
    .. "<b>效果</b>：对目标角色造成1点雷电伤害。<br/><b>应变·孤军</b>：此牌无视次数。",
  ["#hanjin__thunder_slash_skill"] = "选择攻击范围内的一名角色，对其造成1点雷电伤害",
  ["#hanjin__thunder_slash_skill_multi"] = "选择攻击范围内的至多%arg名角色，对这些角色各造成1点雷电伤害",
}
return extension
