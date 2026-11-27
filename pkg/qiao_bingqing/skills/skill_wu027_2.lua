local C = require "packages.qiao.pkg.qiao_bingqing.chunyi"
local skill = fk.CreateSkill { name = C.root, attached_skill_name = C.attached }
C.addWine(skill)
return skill
