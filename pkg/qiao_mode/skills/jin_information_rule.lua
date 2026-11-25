-- 失去【昭然】后，由模式继续结算本阶段已生效的公开。
local Visibility = require "packages.qiao.pkg.qiao_mode.rules.card_visibility"
local skill = fk.CreateSkill {
  name = "qiao__jin_information_rule",
}

skill:addEffect("visibility", Visibility.zhaoran)

return skill
