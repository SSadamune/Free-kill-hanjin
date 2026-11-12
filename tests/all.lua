local suites = {}
table.insert(suites, __dofile("../../../tests/console_timeout.lua"))
for _, file in ipairs({ "hegemony", "faction_ban", "hanjin_rules", "hanjin_scenarios", "han001_liuxie", "only_as", "battle_royal", "upstream_battle_royal", "card_deck", "card_reuse", "card_resolution", "adaptation", "adaptation_display", "ignore_times", "extra_targets", "card_use_targets", "general_exchange", "commander_retinue", "guest_allegiance", "second_lord", "wild_allegiance", "standard_generals", "mode_rules" }) do
  table.insert(suites, __dofile("../../../tests/" .. file .. ".lua"))
end
return table.unpack(suites)
