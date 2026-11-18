-- Reuse decisions for local FreeKill / 国战 / 应变 implementations.
--
-- status = "reused": a unique local implementation exists and is used by the
--                     HanJin independent card through the engine adapter.
-- status = "multiple": several local versions exist; the card remains a shell
--                     until the user chooses one.
-- status = "missing":  no local implementation was found; the card remains a
--                     shell until one is confirmed.
--
-- Summary: most base cards and implemented equipment reuse local code through
-- the engine adapter. Lord-equipment/special-trick entries without a confirmed
-- local implementation stay `missing` inert shells; no missing effect is invented.
--
-- kind = "skill"       install the named card skill at post-load; usually the
--                      upstream skill, but HanJin wrappers may add structured
--                      extra-target rules while delegating the effect
--        "equip"       copy the upstream equip card, equip skills and hooks
--        "qiao_skill" a HanJin skill in this package implements the effect
--        "qiao_equip" a HanJin equip skill in this package implements it
--        "thunder"     the existing HanJin adaptation-aware Thunder Slash
--
-- All `upstream` values are local card names; no upstream deck is imported.
local M = {}

M.cards = {
  -- Basic cards -----------------------------------------------------------
  ["qiao__slash"] = { status = "reused", kind = "skill", upstream = "slash", skill = "slash_skill" },
  ["qiao__jink"] = { status = "reused", kind = "skill", upstream = "jink", skill = "jink_skill" },
  ["qiao__peach"] = { status = "reused", kind = "skill", upstream = "peach", skill = "peach_skill" },
  ["qiao__analeptic"] = { status = "reused", kind = "skill", upstream = "analeptic", skill = "analeptic_skill" },
  ["qiao__fire__slash"] = { status = "reused", kind = "skill", upstream = "fire__slash", skill = "fire__slash_skill" },
  ["qiao__ice__slash"] = { status = "reused", kind = "qiao_skill", upstream = "ice__slash", skill = "qiao__ice_slash_skill" },
  -- The two original positions keep the HanJin adaptation-aware skill; other
  -- printed Thunder Slash positions use the same base effect without 孤军.
  ["qiao__thunder__slash"] = { status = "reused", kind = "thunder", upstream = "thunder__slash", skill = "qiao__thunder_slash_skill" },
  ["qiao__thunder_shell__slash"] = { status = "reused", kind = "thunder", upstream = "thunder__slash", skill = "qiao__thunder_slash_skill" },

  -- Tricks ----------------------------------------------------------------
  ["qiao__duel"] = { status = "reused", kind = "skill", upstream = "duel", skill = "duel_skill" },
  ["qiao__archery_attack"] = { status = "reused", kind = "skill", upstream = "archery_attack", skill = "archery_attack_skill" },
  ["qiao__amazing_grace"] = { status = "reused", kind = "skill", upstream = "amazing_grace", skill = "amazing_grace_skill" },
  ["qiao__god_salvation"] = { status = "reused", kind = "skill", upstream = "god_salvation", skill = "god_salvation_skill" },
  ["qiao__savage_assault"] = { status = "reused", kind = "skill", upstream = "savage_assault", skill = "savage_assault_skill" },
  ["qiao__nullification"] = { status = "reused", kind = "skill", upstream = "nullification", skill = "nullification_skill" },
  ["qiao__guozhan__nullification"] = { status = "reused", kind = "skill", upstream = "heg__nullification", skill = "heg__nullification_skill" },
  ["qiao__dismantlement"] = { status = "reused", kind = "skill", upstream = "dismantlement", skill = "dismantlement_skill" },
  ["qiao__snatch"] = { status = "reused", kind = "skill", upstream = "snatch", skill = "snatch_skill" },
  ["qiao__await_exhausted"] = { status = "reused", kind = "skill", upstream = "await_exhausted", skill = "await_exhausted_skill" },
  ["qiao__indulgence"] = { status = "reused", kind = "skill", upstream = "indulgence", skill = "indulgence_skill" },
  ["qiao__supply_shortage"] = { status = "reused", kind = "skill", upstream = "supply_shortage", skill = "supply_shortage_skill" },
  ["qiao__iron_chain"] = { status = "reused", kind = "skill", upstream = "iron_chain", skill = "iron_chain_skill" },
  ["qiao__foresight"] = { status = "reused", kind = "qiao_skill", upstream = "foresight", skill = "qiao__foresight_skill" },
  ["qiao__chasing_near"] = { status = "reused", kind = "qiao_skill", upstream = "chasing_near", skill = "qiao__chasing_near_skill" },
  ["qiao__unexpectation"] = { status = "reused", kind = "qiao_skill", upstream = "unexpectation", skill = "qiao__unexpectation_skill" },
  ["qiao__known_both"] = { status = "reused", kind = "skill", upstream = "known_both", skill = "known_both_skill" },
  ["qiao__befriend_attacking"] = { status = "reused", kind = "skill", upstream = "befriend_attacking", skill = "befriend_attacking_skill" },
  ["qiao__lure_tiger"] = { status = "reused", kind = "skill", upstream = "lure_tiger", skill = "lure_tiger_skill" },
  ["qiao__burning_camps"] = { status = "reused", kind = "skill", upstream = "burning_camps", skill = "burning_camps_skill" },
  ["qiao__alliance_feast"] = { status = "reused", kind = "skill", upstream = "alliance_feast", skill = "qiao__alliance_feast_skill" },
  ["qiao__threaten_emperor"] = { status = "reused", kind = "skill", upstream = "threaten_emperor", skill = "threaten_emperor_skill" },
  ["qiao__imperial_order"] = { status = "reused", kind = "qiao_skill", upstream = "imperial_order", skill = "qiao__imperial_order_skill" },
  ["qiao__fight_together"] = { status = "reused", kind = "skill", upstream = "fight_together", skill = "qiao__fight_together_skill" },
  ["qiao__collateral"] = { status = "reused", kind = "skill", upstream = "collateral", skill = "qiao__collateral_skill" },
  ["qiao__fire_attack"] = { status = "reused", kind = "skill", upstream = "fire_attack", skill = "fire_attack_skill" },
  ["qiao__lightning"] = { status = "reused", kind = "skill", upstream = "lightning", skill = "lightning_skill" },

  -- Lord equipment and unique special tricks without a local implementation.
  ["qiao__sihai_liuqian"] = { status = "reused", kind = "qiao_equip", upstream = "sihai_liuqian", skill = "qiao__sihai_liuqian_skill", desc = false },
  ["qiao__danggu_zhihuo"] = { status = "missing" },
  ["qiao__command_world"] = { status = "missing" },
  ["qiao__restore_heartland"] = { status = "missing" },
  ["qiao__strengthen_state"] = { status = "missing" },
  ["qiao__luanwu_chaos"] = { status = "missing" },
  ["qiao__sihai_guiping"] = { status = "missing" },
  ["qiao__luoshui_zhishi"] = { status = "missing" },

  -- Weapons ---------------------------------------------------------------
  ["qiao__spear"] = { status = "reused", kind = "qiao_equip", upstream = "spear", skill = "qiao__spear_skill" },
  ["qiao__triblade"] = { status = "reused", kind = "equip", upstream = "triblade" },
  ["qiao__five_elements_fan"] = { status = "reused", kind = "qiao_equip", upstream = "five_elements_fan", skill = "qiao__five_elements_fan_skill" },
  ["qiao__black_chain"] = { status = "reused", kind = "qiao_equip", upstream = "black_chain", skill = "qiao__black_chain_skill" },
  ["qiao__crossbow"] = { status = "reused", kind = "qiao_equip", upstream = "crossbow", skill = "qiao__crossbow_skill" },
  ["qiao__qinggang_sword"] = { status = "reused", kind = "equip", upstream = "qinggang_sword" },
  ["qiao__kylin_bow"] = { status = "reused", kind = "equip", upstream = "kylin_bow" },
  ["qiao__axe"] = { status = "reused", kind = "qiao_equip", upstream = "axe", skill = "qiao__axe_skill" },
  ["qiao__chixiao_sword"] = { status = "reused", kind = "qiao_equip",
    upstream = "chixiao_sword", skill = "qiao__chixiao_sword_skill", desc = false },
  ["qiao__shenshou_sizhao"] = { status = "reused", kind = "qiao_equip", upstream = "shenshou_sizhao", skill = "qiao__shenshou_sizhao_skill", desc = false },
  ["qiao__double_swords"] = { status = "reused", kind = "equip", upstream = "double_swords" },
  ["qiao__six_swords"] = { status = "reused", kind = "qiao_equip", upstream = "six_swords", skill = "qiao__six_swords_skill" },

  -- Armor -----------------------------------------------------------------
  ["qiao__vine"] = { status = "reused", kind = "equip", upstream = "vine" },
  ["qiao__nioh_shield"] = { status = "reused", kind = "equip", upstream = "nioh_shield" },
  ["qiao__eight_diagram"] = { status = "reused", kind = "qiao_equip", upstream = "eight_diagram", skill = "qiao__eight_diagram_skill" },
  ["qiao__dark_armor"] = { status = "reused", kind = "qiao_equip", upstream = "dark_armor", skill = "qiao__dark_armor_skill" },
  ["qiao__zouyu_fan"] = { status = "reused", kind = "qiao_equip", upstream = "zouyu_fan", skill = "qiao__zouyu_fan_skill", desc = false },
  ["qiao__jinxiu_zhengpao"] = { status = "reused", kind = "qiao_equip",
    upstream = "jinxiu_zhengpao", skill = "qiao__jinxiu_zhengpao_skill", desc = false },

  -- Mounts ----------------------------------------------------------------
  ["qiao__chitu"] = { status = "reused", kind = "equip", upstream = "chitu" },
  ["qiao__zixing"] = { status = "reused", kind = "equip", upstream = "zixing" },
  ["qiao__jingfan"] = { status = "reused", kind = "equip", upstream = "jingfan" },
  ["qiao__feiyun_gaihai"] = { status = "reused", kind = "qiao_equip",
    upstream = "zixing", skill = "qiao__feiyun_gaihai_skill", desc = false },
  ["qiao__zhuahuangfeidian"] = { status = "reused", kind = "equip", upstream = "zhuahuangfeidian" },
  ["qiao__jueying"] = { status = "reused", kind = "equip", upstream = "jueying" },
  -- 双副类别坐骑：汉晋效果由本包技能实现，不套用上游单坐骑技能或安装钩子。
  ["qiao__linxiao_yuyu"] = { status = "reused", kind = "qiao_equip",
    upstream = "jueying", skill = "qiao__linxiao_yuyu_skill", desc = false },

  -- Treasures -------------------------------------------------------------
  ["qiao__bronze_sparrow"] = { status = "reused", kind = "qiao_equip", upstream = "bronze_sparrow", skill = "qiao__bronze_sparrow_skill" },
  ["qiao__taigong_tactics"] = { status = "reused", kind = "qiao_equip", upstream = "taigong_tactics", skill = "qiao__taigong_tactics_skill" },
  ["qiao__wonder_map"] = { status = "reused", kind = "qiao_equip", upstream = "wonder_map", skill = "qiao__wonder_map_skill" },
  ["qiao__jade_seal"] = { status = "reused", kind = "qiao_equip", upstream = "jade_seal", skill = "qiao__jade_seal_skill" },
  ["qiao__wooden_ox"] = { status = "reused", kind = "qiao_equip", upstream = "wooden_ox", skill = "qiao__wooden_ox_skill" },
  ["qiao__zhoujun_lingbingyin"] = { status = "reused", kind = "qiao_equip", upstream = "zhoujun_lingbingyin", skill = "qiao__zhoujun_lingbingyin_skill", desc = false },
  ["qiao__xuehai_mowangzun"] = { status = "reused", kind = "qiao_equip", upstream = "xuehai_mowangzun", skill = "qiao__xuehai_mowangzun_skill", desc = false },
  ["qiao__xuwang_zhimian"] = { status = "reused", kind = "qiao_equip", upstream = "xuwang_zhimian", skill = "qiao__xuwang_zhimian_skill", desc = false },

  -- Multiple local versions: wait for the user's choice. -------------------
  ["qiao__drowning"] = { status = "reused", kind = "qiao_skill", upstream = "sa__drowning", skill = "qiao__drowning_skill", chosen = "A" },
  ["qiao__dragon_phoenix"] = { status = "reused", kind = "qiao_equip",
    upstream = "dragon_phoenix", skill = "qiao__dragon_phoenix_skill", desc = false },
  ["qiao__halberd"] = { status = "reused", kind = "qiao_equip", upstream = "sa__halberd", skill = "qiao__halberd_skill", chosen = "A" },
  ["qiao__blade"] = { status = "reused", kind = "equip", upstream = "sa__blade", chosen = "A" },
  ["qiao__breastplate"] = { status = "reused", kind = "qiao_equip", upstream = "breastplate", skill = "qiao__breastplate_skill", chosen = "B" },
  ["qiao__liulongcanjia"] = { status = "reused", kind = "qiao_equip",
    upstream = "liulongcanjia", skill = "qiao__liulongcanjia_skill", desc = false, chosen = "A" },
  ["qiao__luminous_pearl"] = { status = "reused", kind = "qiao_equip", upstream = "luminous_pearl", skill = "qiao__luminous_pearl_skill", desc = false, chosen = "A" },
  ["qiao__peace_spell"] = { status = "reused", kind = "qiao_equip", upstream = "peace_spell", skill = "qiao__peace_spell_skill", desc = false, chosen = "A" },
}

return M
