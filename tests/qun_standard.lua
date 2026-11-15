-- 群标准包定向入口；各套件也分别纳入默认 all.lua。
local suites = {}
for _, file in ipairs({ "qun_basic", "qun_retrial", "qun_cards", "qun_dying", "qun_judgement", "qun_control", "qun_duanchang" }) do
  table.insert(suites, __dofile("../../../tests/" .. file .. ".lua"))
end
return table.unpack(suites)
