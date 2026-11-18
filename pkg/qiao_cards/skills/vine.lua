-- 藤甲：锁定技，【南蛮入侵】、【万箭齐发】和普通【杀】对你无效；
-- 当你受到火焰伤害时，此伤害+1。
--
-- 规则基线：assets/bilibili articles/cards/锦囊装备.json「藤甲」。
-- 结算时机依同目录《势备应变牌堆差异》：这些牌对装备者的使用结算开始时，
-- 即全部「成为目标后」之后；引擎对应 fk.PreCardEffect。多目标牌按目标逐个
-- 结算，data.nullified 只令当前目标这一次生效无效。
--
-- 防具失效（青釭剑等）走引擎公共 invalidity 机制：触发条件统一查询
-- hasSkill，不以装备区实体牌绕过失效判断。
local skill = fk.CreateSkill {
  name = "qiao__vine_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__vine",
}

-- 普通【杀】按牌的真实类别判断；火杀、雷杀、冰杀的 trueName 同为 slash，
-- 但正式牌名不同，不能因 trueName 相同被误当作普通【杀】。
local ELEMENTAL_SLASHES = {
  ["qiao__fire__slash"] = true,
  ["qiao__thunder__slash"] = true,
  ["qiao__thunder_shell__slash"] = true,
  ["qiao__ice__slash"] = true,
  ["fire__slash"] = true,
  ["thunder__slash"] = true,
  ["ice__slash"] = true,
}

local function isNullifiedCard(card)
  if card.trueName == "savage_assault" or card.trueName == "archery_attack" then
    return true
  end
  return card.trueName == "slash" and ELEMENTAL_SLASHES[card.name] ~= true
end

skill:addEffect(fk.PreCardEffect, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return data.to == player and player:hasSkill(skill.name)
      and data.card ~= nil and isNullifiedCard(data.card)
  end,
  on_use = function(self, event, target, player, data)
    data.nullified = true
  end,
})

skill:addEffect(fk.DamageInflicted, {
  mute = true,
  can_trigger = function(self, event, target, player, data)
    return target == player and player:hasSkill(skill.name)
      and data.damageType == fk.FireDamage
  end,
  on_use = function(self, event, target, player, data)
    data:changeDamage(1)
  end,
})

Fk:loadTranslationTable {
  ["qiao__vine_skill"] = "藤甲",
}

return skill
