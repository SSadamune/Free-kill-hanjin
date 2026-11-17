-- 六龙骖驾：进攻/防御双副类别坐骑。持有者距离-1，其他角色到其距离+1；
-- 持有期间不能使用其他坐骑。置入时清掉已有坐骑（双栏语义）。
local skill = fk.CreateSkill {
  name = "qiao__liulongcanjia_skill",
  attached_equip = "qiao__liulongcanjia",
}

local function isRide(card)
  if card == nil or card.type ~= Card.TypeEquip then return false end
  return card.sub_type == Card.SubtypeOffensiveRide
    or card.sub_type == Card.SubtypeDefensiveRide
end

Fk:loadTranslationTable {
  [skill.name] = "六龙骖驾",
  ["qiao__liulongcanjia"] = "六龙骖驾",
}

return skill
