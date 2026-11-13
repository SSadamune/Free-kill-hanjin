local suites = {}
local function add(file)
  io.write("SUITE " .. file .. "\n")
  table.insert(suites, __dofile("../../../tests/" .. file .. ".lua"))
end
add("console_timeout")
for _, file in ipairs({ "hegemony", "faction_ban", "hanjin_rules", "hanjin_scenarios", "only_as", "battle_royal", "upstream_battle_royal", "card_deck", "card_reuse", "card_resolution", "adaptation", "adaptation_display", "ignore_times", "extra_targets", "card_use_targets", "general_exchange", "commander_retinue", "guest_allegiance", "second_lord", "wild_allegiance", "standard_generals", "mode_rules" }) do
  add(file)
end
return table.unpack(suites)
