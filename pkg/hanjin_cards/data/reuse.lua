-- Reuse decisions for local FreeKill / 国战 / 应变 implementations.
--
-- status = "reused": a unique local implementation exists and is used by the
--                     HanJin independent card through the engine adapter.
-- status = "multiple": several local versions exist; the card remains a shell
--                     until the user chooses one.
-- status = "missing":  no local implementation was found; the card remains a
--                     shell until one is confirmed.
--
-- Summary: 67 reused card types, 0 pending multiple-version types (the eight
-- previously pending types are resolved by the user's A/B choices below) and
-- 17 missing types (10 base lord-equipment positions + 7 faction tricks).
-- Missing types stay inert shells; no missing effect is invented.
--
-- kind = "skill"       install the named card skill at post-load; usually the
--                      upstream skill, but HanJin wrappers may add structured
--                      extra-target rules while delegating the effect
--        "equip"       copy the upstream equip card, equip skills and hooks
--        "hanjin_skill" a HanJin skill in this package implements the effect
--        "hanjin_equip" a HanJin equip skill in this package implements it
--        "thunder"     the existing HanJin adaptation-aware Thunder Slash
--
-- All `upstream` values are local card names; no upstream deck is imported.
local M = {}

M.cards = {
  -- Basic cards -----------------------------------------------------------
  ["hanjin__slash"] = { status = "reused", kind = "skill", upstream = "slash", skill = "slash_skill" },
  ["hanjin__jink"] = { status = "reused", kind = "skill", upstream = "jink", skill = "jink_skill" },
  ["hanjin__peach"] = { status = "reused", kind = "skill", upstream = "peach", skill = "peach_skill" },
  ["hanjin__analeptic"] = { status = "reused", kind = "skill", upstream = "analeptic", skill = "analeptic_skill" },
  ["hanjin__fire__slash"] = { status = "reused", kind = "skill", upstream = "fire__slash", skill = "fire__slash_skill" },
  ["hanjin__ice__slash"] = { status = "reused", kind = "hanjin_skill", upstream = "ice__slash", skill = "hanjin__ice_slash_skill" },
  -- The two original positions keep the HanJin adaptation-aware skill; other
  -- printed Thunder Slash positions use the same base effect without 孤军.
  ["hanjin__thunder__slash"] = { status = "reused", kind = "thunder", upstream = "thunder__slash", skill = "hanjin__thunder_slash_skill" },
  ["hanjin__thunder_shell__slash"] = { status = "reused", kind = "thunder", upstream = "thunder__slash", skill = "hanjin__thunder_slash_skill" },

  -- Tricks ----------------------------------------------------------------
  ["hanjin__duel"] = { status = "reused", kind = "skill", upstream = "duel", skill = "duel_skill" },
  ["hanjin__archery_attack"] = { status = "reused", kind = "skill", upstream = "archery_attack", skill = "archery_attack_skill" },
  ["hanjin__amazing_grace"] = { status = "reused", kind = "skill", upstream = "amazing_grace", skill = "amazing_grace_skill" },
  ["hanjin__god_salvation"] = { status = "reused", kind = "skill", upstream = "god_salvation", skill = "god_salvation_skill" },
  ["hanjin__savage_assault"] = { status = "reused", kind = "skill", upstream = "savage_assault", skill = "savage_assault_skill" },
  ["hanjin__nullification"] = { status = "reused", kind = "skill", upstream = "nullification", skill = "nullification_skill" },
  ["hanjin__guozhan__nullification"] = { status = "reused", kind = "skill", upstream = "heg__nullification", skill = "heg__nullification_skill" },
  ["hanjin__dismantlement"] = { status = "reused", kind = "skill", upstream = "dismantlement", skill = "dismantlement_skill" },
  ["hanjin__snatch"] = { status = "reused", kind = "skill", upstream = "snatch", skill = "snatch_skill" },
  ["hanjin__await_exhausted"] = { status = "reused", kind = "skill", upstream = "await_exhausted", skill = "await_exhausted_skill" },
  ["hanjin__indulgence"] = { status = "reused", kind = "skill", upstream = "indulgence", skill = "indulgence_skill" },
  ["hanjin__supply_shortage"] = { status = "reused", kind = "skill", upstream = "supply_shortage", skill = "supply_shortage_skill" },
  ["hanjin__iron_chain"] = { status = "reused", kind = "skill", upstream = "iron_chain", skill = "iron_chain_skill" },
  ["hanjin__foresight"] = { status = "reused", kind = "hanjin_skill", upstream = "foresight", skill = "hanjin__foresight_skill" },
  ["hanjin__chasing_near"] = { status = "reused", kind = "hanjin_skill", upstream = "chasing_near", skill = "hanjin__chasing_near_skill" },
  ["hanjin__unexpectation"] = { status = "reused", kind = "hanjin_skill", upstream = "unexpectation", skill = "hanjin__unexpectation_skill" },
  ["hanjin__known_both"] = { status = "reused", kind = "skill", upstream = "known_both", skill = "known_both_skill" },
  ["hanjin__befriend_attacking"] = { status = "reused", kind = "skill", upstream = "befriend_attacking", skill = "befriend_attacking_skill" },
  ["hanjin__lure_tiger"] = { status = "reused", kind = "skill", upstream = "lure_tiger", skill = "lure_tiger_skill" },
  ["hanjin__burning_camps"] = { status = "reused", kind = "skill", upstream = "burning_camps", skill = "burning_camps_skill" },
  ["hanjin__alliance_feast"] = { status = "reused", kind = "skill", upstream = "alliance_feast", skill = "hanjin__alliance_feast_skill" },
  ["hanjin__threaten_emperor"] = { status = "reused", kind = "skill", upstream = "threaten_emperor", skill = "threaten_emperor_skill" },
  ["hanjin__imperial_order"] = { status = "reused", kind = "hanjin_skill", upstream = "imperial_order", skill = "hanjin__imperial_order_skill" },
  ["hanjin__fight_together"] = { status = "reused", kind = "skill", upstream = "fight_together", skill = "hanjin__fight_together_skill" },
  ["hanjin__collateral"] = { status = "reused", kind = "skill", upstream = "collateral", skill = "hanjin__collateral_skill" },
  ["hanjin__fire_attack"] = { status = "reused", kind = "skill", upstream = "fire_attack", skill = "fire_attack_skill" },
  ["hanjin__lightning"] = { status = "reused", kind = "skill", upstream = "lightning", skill = "lightning_skill" },

  -- Lord equipment and unique special tricks without a local implementation.
  ["hanjin__sihai_liuqian"] = { status = "missing" },
  ["hanjin__danggu_zhihuo"] = { status = "missing" },
  ["hanjin__command_world"] = { status = "missing" },
  ["hanjin__restore_heartland"] = { status = "missing" },
  ["hanjin__strengthen_state"] = { status = "missing" },
  ["hanjin__luanwu_chaos"] = { status = "missing" },
  ["hanjin__sihai_guiping"] = { status = "missing" },
  ["hanjin__luoshui_zhishi"] = { status = "missing" },

  -- Weapons ---------------------------------------------------------------
  ["hanjin__spear"] = { status = "reused", kind = "hanjin_equip", upstream = "spear", skill = "hanjin__spear_skill" },
  ["hanjin__triblade"] = { status = "reused", kind = "equip", upstream = "triblade" },
  ["hanjin__five_elements_fan"] = { status = "reused", kind = "hanjin_equip", upstream = "five_elements_fan", skill = "hanjin__five_elements_fan_skill" },
  ["hanjin__black_chain"] = { status = "reused", kind = "hanjin_equip", upstream = "black_chain", skill = "hanjin__black_chain_skill" },
  ["hanjin__crossbow"] = { status = "reused", kind = "hanjin_equip", upstream = "crossbow", skill = "hanjin__crossbow_skill" },
  ["hanjin__qinggang_sword"] = { status = "reused", kind = "equip", upstream = "qinggang_sword" },
  ["hanjin__kylin_bow"] = { status = "reused", kind = "equip", upstream = "kylin_bow" },
  ["hanjin__axe"] = { status = "reused", kind = "hanjin_equip", upstream = "axe", skill = "hanjin__axe_skill" },
  ["hanjin__chixiao_sword"] = { status = "missing" },
  ["hanjin__shenshou_sizhao"] = { status = "missing" },
  ["hanjin__double_swords"] = { status = "reused", kind = "equip", upstream = "double_swords" },
  ["hanjin__six_swords"] = { status = "reused", kind = "hanjin_equip", upstream = "six_swords", skill = "hanjin__six_swords_skill" },

  -- Armor -----------------------------------------------------------------
  ["hanjin__vine"] = { status = "reused", kind = "equip", upstream = "vine" },
  ["hanjin__nioh_shield"] = { status = "reused", kind = "equip", upstream = "nioh_shield" },
  ["hanjin__eight_diagram"] = { status = "reused", kind = "hanjin_equip", upstream = "eight_diagram", skill = "hanjin__eight_diagram_skill" },
  ["hanjin__dark_armor"] = { status = "reused", kind = "hanjin_equip", upstream = "dark_armor", skill = "hanjin__dark_armor_skill" },
  ["hanjin__zouyu_fan"] = { status = "missing" },
  ["hanjin__jinxiu_zhengpao"] = { status = "missing" },

  -- Mounts ----------------------------------------------------------------
  ["hanjin__chitu"] = { status = "reused", kind = "equip", upstream = "chitu" },
  ["hanjin__zixing"] = { status = "reused", kind = "equip", upstream = "zixing" },
  ["hanjin__jingfan"] = { status = "reused", kind = "equip", upstream = "jingfan" },
  ["hanjin__feiyun_gaihai"] = { status = "missing" },
  ["hanjin__zhuahuangfeidian"] = { status = "reused", kind = "equip", upstream = "zhuahuangfeidian" },
  ["hanjin__jueying"] = { status = "reused", kind = "equip", upstream = "jueying" },
  ["hanjin__linxiao_yuyu"] = { status = "missing" },

  -- Treasures -------------------------------------------------------------
  ["hanjin__bronze_sparrow"] = { status = "reused", kind = "hanjin_equip", upstream = "bronze_sparrow", skill = "hanjin__bronze_sparrow_skill" },
  ["hanjin__taigong_tactics"] = { status = "reused", kind = "hanjin_equip", upstream = "taigong_tactics", skill = "hanjin__taigong_tactics_skill" },
  ["hanjin__wonder_map"] = { status = "reused", kind = "hanjin_equip", upstream = "wonder_map", skill = "hanjin__wonder_map_skill" },
  ["hanjin__jade_seal"] = { status = "reused", kind = "hanjin_equip", upstream = "jade_seal", skill = "hanjin__jade_seal_skill" },
  ["hanjin__wooden_ox"] = { status = "reused", kind = "hanjin_equip", upstream = "wooden_ox", skill = "hanjin__wooden_ox_skill" },
  ["hanjin__zhoujun_lingbingyin"] = { status = "missing" },
  ["hanjin__xuehai_mowangzun"] = { status = "missing" },
  ["hanjin__xuwang_zhimian"] = { status = "missing" },

  -- Multiple local versions: wait for the user's choice. -------------------
  ["hanjin__drowning"] = { status = "reused", kind = "hanjin_skill", upstream = "sa__drowning", skill = "hanjin__drowning_skill", chosen = "A" },
  ["hanjin__dragon_phoenix"] = { status = "reused", kind = "equip", upstream = "dragon_phoenix", chosen = "A" },
  ["hanjin__halberd"] = { status = "reused", kind = "equip", upstream = "sa__halberd", chosen = "A" },
  ["hanjin__blade"] = { status = "reused", kind = "equip", upstream = "sa__blade", chosen = "A" },
  ["hanjin__breastplate"] = { status = "reused", kind = "hanjin_equip", upstream = "breastplate", skill = "hanjin__breastplate_skill", chosen = "B" },
  ["hanjin__liulongcanjia"] = { status = "reused", kind = "equip", upstream = "liulongcanjia", chosen = "A" },
  ["hanjin__luminous_pearl"] = { status = "reused", kind = "hanjin_equip", upstream = "luminous_pearl", skill = "hanjin__luminous_pearl_skill", chosen = "A" },
  ["hanjin__peace_spell"] = { status = "reused", kind = "hanjin_equip", upstream = "peace_spell", skill = "hanjin__peace_spell_skill", chosen = "A" },
}

return M
