-- 鹤翼飞影的固定派生来源骨架。
--
-- 每个来源必须在服务端和客户端都有稳定技能名，避免服务端动态 Fk:addSkill
-- 后客户端收到同名来源时无法解析。为所有席位预注册空 ActiveSkill 作为
-- source_skill 键；它们不授予给角色、不显示，只用于 Player:addSkill/loseSkill
-- 的 derivative_skills 记账。
local formation = require "packages.qiao.pkg.qiao_generals.util.zhen_shi_formation"
local skill = fk.CreateSkill {
  name = "qiao__zhen_shi_formation_state",
}

for index = 1, formation.SOURCE_COUNT do
  skill:addAuxActiveSkill(formation.sourceSkillName(index), {
    can_use = function() return false end,
    on_use = function() end,
  })
end

return skill
