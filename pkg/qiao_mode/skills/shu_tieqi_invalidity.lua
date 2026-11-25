local Tieqi = require "packages.qiao.pkg.qiao_mode.rules.tieqi"
local skill = fk.CreateSkill { name = "qiao__shu_tieqi_invalidity" }

skill:addEffect("invalidity", {
  invalidity_func = function(_, from, target) return Tieqi.invalidates(from, target) end,
})

return skill
