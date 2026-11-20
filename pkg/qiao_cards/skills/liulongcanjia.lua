-- 六龙骖驾：进攻/防御双副类别坐骑。锁定技，其他角色到装备者的距离 +X，
-- 装备者到其他角色的距离 -X。X 为场上与装备者势力相同的角色装备区里的
-- 坐骑牌总张数，每张牌计一次；装备者始终计入，全暗且势力未确定时只计自身。
local skill = fk.CreateSkill {
  name = "qiao__liulongcanjia_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__liulongcanjia",
}

Fk:loadTranslationTable {
  [skill.name] = "六龙骖驾",
  ["qiao__liulongcanjia"] = "六龙骖驾",
  [":" .. skill.name] = "锁定技，其他角色到你的距离+X，你到其他角色的距离-X"
    .. "（X为场上与你势力相同的角色装备区里的坐骑牌数，每张牌计一次）。",
}

local MountDistance = require "packages.qiao.pkg.qiao_cards.mount_distance"

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    return MountDistance.correct(skill.name, from, to)
  end,
})

return skill
