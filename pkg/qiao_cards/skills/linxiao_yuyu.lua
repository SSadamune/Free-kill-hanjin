-- 临筱玉舆：进攻/防御双副类别坐骑。装备者到其他角色距离-1，其他角色到
-- 装备者距离+1。进出装备区的当前回合者效果由模式规则 qiao__linxiao_yuyu_rule
-- 统一结算；离开装备区时本装备技能已先卸下，不能放在这里。
local skill = fk.CreateSkill {
  name = "qiao__linxiao_yuyu_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__linxiao_yuyu",
}

Fk:loadTranslationTable {
  [skill.name] = "临筱玉舆",
  ["qiao__linxiao_yuyu"] = "临筱玉舆",
  [":" .. skill.name] = "你到其他角色的距离-1，其他角色到你的距离+1。",
}

local MountDistance = require "packages.qiao.pkg.qiao_cards.mount_distance"
skill:addEffect("distance", {
  correct_func = function(self, from, to)
    return MountDistance.correct(skill.name, from, to)
  end,
})

return skill
