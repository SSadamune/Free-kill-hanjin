-- 飞云盖海：进攻/防御双副类别坐骑。锁定技，装备者未横置时，装备者到其他
-- 角色距离-2；装备者横置时，改为其他角色到装备者的距离+2。横置状态即时生效。
local skill = fk.CreateSkill {
  name = "qiao__feiyun_gaihai_skill",
  tags = { Skill.Compulsory },
  attached_equip = "qiao__feiyun_gaihai",
}

Fk:loadTranslationTable {
  [skill.name] = "飞云盖海",
  ["qiao__feiyun_gaihai"] = "飞云盖海",
  [":" .. skill.name] = "锁定技，你未横置时，你到其他角色的距离-2；"
    .. "你横置时，其他角色到你的距离+2。",
}

skill:addEffect("distance", {
  correct_func = function(self, from, to)
    local delta = 0
    if from:hasSkill(skill.name) and not from.chained then delta = delta - 2 end
    if to:hasSkill(skill.name) and to.chained then delta = delta + 2 end
    return delta
  end,
})

return skill
