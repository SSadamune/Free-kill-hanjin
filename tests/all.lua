local suites = {}
for _, file in ipairs({ "hegemony", "faction_ban", "hanjin_rules", "hanjin_scenarios", "adaptation", "ignore_times" }) do
  table.insert(suites, __dofile("../../../tests/" .. file .. ".lua"))
end
return table.unpack(suites)
