local C = require "packages.qiao.pkg.qiao_bingqing.chunyi"
local skill = fk.CreateSkill { name = C.attached }
C.addWine(skill)
Fk:loadTranslationTable { [C.attached] = "醇义", [":" .. C.attached] = "与你势力相同的角色可以将国战标记当【酒】使用。" }
return skill
