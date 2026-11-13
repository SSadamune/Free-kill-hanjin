local suites = {}
table.insert(suites, __dofile("../../../tests/console_timeout.lua"))
for _, file in ipairs({ "hegemony", "faction_ban", "hanjin_rules", "hanjin_scenarios", "han001_liuxie", "han_standard", "han_standard_pindian", "han004_zhangrang", "han005_hejin", "han007_wangrong", "han008_fuhuanghou", "han009_fuwan", "han011_tangji", "han012_caiyong", "han016_liuchong", "han017_liuyao", "han_retinues", "jin001_simayan", "only_as", "battle_royal", "upstream_battle_royal", "card_deck", "card_reuse", "card_resolution", "adaptation", "adaptation_display", "ignore_times", "extra_targets", "card_use_targets", "general_exchange", "commander_retinue", "guest_allegiance", "second_lord", "wild_allegiance", "standard_generals", "mode_rules", "wei_damage", "wei_support", "wei_phases", "wei_pair_hp", "wei_active", "wei_retrial", "wei_retinues" }) do
  table.insert(suites, __dofile("../../../tests/" .. file .. ".lua"))
end
return table.unpack(suites)
