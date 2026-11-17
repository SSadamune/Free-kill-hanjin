-- 临筱玉舆：进攻/防御双副类别坐骑。持有者距离-1、其他角色到其距离+1，
-- 持有期间不能使用其他坐骑。进入装备区后当前回合角色摸1；若本次确有坐骑被
-- 替换则改为回复1。从装备区置入非装备区后当前回合角色摸1。
local skill = fk.CreateSkill {
  name = "qiao__linxiao_yuyu_skill",
  attached_equip = "qiao__linxiao_yuyu",
}

local CARD = "qiao__linxiao_yuyu"

local function isRide(card)
  if card == nil or card.type ~= Card.TypeEquip then return false end
  return card.sub_type == Card.SubtypeOffensiveRide
    or card.sub_type == Card.SubtypeDefensiveRide
end

local function isLinxiao(id)
  local card = Fk:getCardById(id, true)
  return card ~= nil and card.name == CARD
end

Fk:loadTranslationTable {
  [skill.name] = "临筱玉舆",
  ["qiao__linxiao_yuyu"] = "临筱玉舆",
}

return skill
