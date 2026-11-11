local suites = {}
table.insert(suites, __dofile("../../../tests/console_timeout.lua"))
for _, file in ipairs({ "hegemony", "faction_ban", "hanjin_rules", "hanjin_scenarios", "card_deck", "card_reuse", "adaptation", "ignore_times", "general_exchange", "commander_retinue", "guest_allegiance", "second_lord", "wild_allegiance", "standard_generals", "mode_rules" }) do
  table.insert(suites, __dofile("../../../tests/" .. file .. ".lua"))
end
return table.unpack(suites)
