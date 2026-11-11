local suites = {}
for _, file in ipairs({ "hegemony", "faction_ban", "hanjin_rules", "hanjin_scenarios", "card_deck", "card_reuse", "adaptation", "ignore_times", "general_exchange", "commander_retinue", "guest_allegiance", "second_lord", "wild_allegiance" }) do
  table.insert(suites, __dofile("../../../tests/" .. file .. ".lua"))
end
return table.unpack(suites)
