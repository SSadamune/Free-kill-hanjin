-- Independent HanJin card types. Card effects are intentionally not implemented:
-- every type except the two existing Thunder Slash positions is a non-useable
-- shell. Type/sub_type/attack_range describe the printed card, not an effect.
-- `derived` types are replacement materials and the seven faction tricks; they
-- are never part of the 162-slot default draw pile.
local M = {}
local Heg = require "packages.hegemony.util"

--- 州郡领兵印进入装备区后，按装备者的大／小势力类别逐个询问同类别角色交牌。
local function zhoujunEnter(room, player)
  local big = Heg.isBigKingdomPlayer(player)
  local small = Heg.isSmallKingdomPlayer(player)
  if not big and not small then return end
  local same = big and Heg.isBigKingdomPlayer or Heg.isSmallKingdomPlayer
  local candidates = {}
  for _, other in ipairs(room:getPresentPlayers()) do
    if other ~= player and not other:isRemoved() and same(other)
      and #other:getCardIds("he") > 0 then
      table.insert(candidates, other)
    end
  end
  room:sortByAction(candidates)
  for _, other in ipairs(candidates) do
    if not other.dead and not other:isRemoved() and #other:getCardIds("he") > 0 then
      if room:askToSkillInvoke(other, {
        skill_name = "qiao__zhoujun_lingbingyin_skill",
        prompt = "#qiao__zhoujun-give:" .. player.id,
      }) then
        local card = room:askToChooseCard(other, {
          target = other,
          flag = "he",
          skill_name = "qiao__zhoujun_lingbingyin_skill",
          prompt = "#qiao__zhoujun-choose",
        })
        if card ~= nil and room:getCardOwner(card) == other then
          room:obtainCard(player, card, false, fk.ReasonGive)
        end
      end
    end
  end
end

M.types = {
  -- Basic cards -----------------------------------------------------------
  { id = "qiao__slash", display = "杀", type = "basic", damage = fk.NormalDamage,
    is_damage = true, skill = "qiao__inert", inert = true },
  { id = "qiao__jink", display = "闪", type = "basic", skill = "qiao__inert", inert = true },
  { id = "qiao__peach", display = "桃", type = "basic", skill = "qiao__inert", inert = true },
  { id = "qiao__analeptic", display = "酒", type = "basic", skill = "qiao__inert", inert = true },
  { id = "qiao__fire__slash", display = "火杀", type = "basic", damage = fk.FireDamage,
    is_damage = true, skill = "qiao__inert", inert = true },
  { id = "qiao__ice__slash", display = "冰杀", type = "basic", damage = fk.IceDamage,
    is_damage = true, skill = "qiao__ice_slash_skill", inert = false },
  -- The two existing formal Thunder Slash positions keep the real effect.
  { id = "qiao__thunder__slash", display = "雷杀", type = "basic", damage = fk.ThunderDamage,
    is_damage = true, skill = "qiao__thunder_slash_skill", inert = false, fixed_desc = true },
  -- Other printed Thunder Slash slots are separate inert shells. They never
  -- inherit the 孤军 entry from the two functional positions.
  { id = "qiao__thunder_shell__slash", display = "雷杀", type = "basic", damage = fk.ThunderDamage,
    is_damage = true, skill = "qiao__thunder_slash_skill", inert = false, shell = true },

  -- Normal and delayed tricks --------------------------------------------
  { id = "qiao__duel", display = "决斗", type = "trick", is_damage = true, skill = "qiao__inert", inert = true },
  { id = "qiao__archery_attack", display = "万箭齐发", type = "trick", is_damage = true, skill = "qiao__inert", inert = true },
  { id = "qiao__amazing_grace", display = "五谷丰登", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__god_salvation", display = "桃园结义", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__savage_assault", display = "南蛮入侵", type = "trick", is_damage = true, skill = "qiao__inert", inert = true },
  { id = "qiao__nullification", display = "无懈可击", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__guozhan__nullification", display = "无懈可击·国", type = "trick",
    skill = "qiao__inert", inert = true, national = true },
  { id = "qiao__dismantlement", display = "过河拆桥", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__snatch", display = "顺手牵羊", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__await_exhausted", display = "以逸待劳", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__indulgence", display = "乐不思蜀", type = "trick", delayed = true, skill = "qiao__inert", inert = true },
  { id = "qiao__supply_shortage", display = "兵粮寸断", type = "trick", delayed = true, skill = "qiao__inert", inert = true },
  { id = "qiao__iron_chain", display = "铁索连环", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__foresight", display = "洞烛先机", type = "trick", skill = "qiao__foresight_skill", inert = false },
  { id = "qiao__drowning", display = "水淹七军", type = "trick", is_damage = true, skill = "qiao__drowning_skill", inert = false },
  { id = "qiao__chasing_near", display = "逐近弃远", type = "trick", skill = "qiao__chasing_near_skill", inert = false },
  { id = "qiao__unexpectation", display = "出其不意", type = "trick", is_damage = true, skill = "qiao__unexpectation_skill", inert = false },
  { id = "qiao__known_both", display = "知己知彼", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__befriend_attacking", display = "远交近攻", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__lure_tiger", display = "调虎离山", type = "trick", skill = "qiao__lure_tiger_skill", inert = false },
  { id = "qiao__burning_camps", display = "火烧连营", type = "trick", is_damage = true, skill = "qiao__inert", inert = true },
  { id = "qiao__alliance_feast", display = "联军盛宴", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__threaten_emperor", display = "挟天子以令诸侯", type = "trick",
    skill = "qiao__threaten_emperor_skill", inert = false },
  { id = "qiao__imperial_order", display = "敕令", type = "trick", skill = "qiao__imperial_order_skill", inert = false },
  { id = "qiao__fight_together", display = "勠力同心", type = "trick", skill = "qiao__inert", inert = true },
  { id = "qiao__collateral", display = "借刀杀人", type = "trick", is_damage = true, skill = "qiao__collateral_skill", inert = false },
  { id = "qiao__fire_attack", display = "火攻", type = "trick", is_damage = true, skill = "qiao__inert", inert = true },
  { id = "qiao__lightning", display = "闪电", type = "trick", delayed = true, is_damage = true, skill = "qiao__inert", inert = true },
  { id = "qiao__sihai_liuqian", display = "四海流钱", type = "equip",
    subtype = Card.SubtypeTreasure, skill = "default_equip_skill",
    equip_skill = "qiao__sihai_liuqian_skill", inert = false },

  -- Faction tricks: outside the base deck, only special means may add them.
  { id = "qiao__danggu_zhihuo", display = "党锢之祸", type = "trick", kingdom = "han",
    skill = "qiao__danggu_zhihuo_skill", inert = false, derived = true, faction_trick = true,
    multiple_targets = true },
  { id = "qiao__command_world", display = "号令天下", type = "trick", kingdom = "wei",
    skill = "qiao__command_world_skill", inert = false, derived = true, faction_trick = true },
  { id = "qiao__restore_heartland", display = "克复中原", type = "trick", kingdom = "shu",
    skill = "qiao__restore_heartland_skill", inert = false, derived = true, faction_trick = true },
  { id = "qiao__strengthen_state", display = "固国安邦", type = "trick", kingdom = "wu",
    skill = "qiao__strengthen_state_skill", inert = false, derived = true, faction_trick = true },
  { id = "qiao__luanwu_chaos", display = "文和乱武", type = "trick", kingdom = "qun",
    skill = "qiao__luanwu_chaos_skill", inert = false, derived = true, faction_trick = true,
    multiple_targets = true },
  { id = "qiao__sihai_guiping", display = "四海归平", type = "trick", kingdom = "jin",
    skill = "qiao__sihai_guiping_skill", inert = false, derived = true, faction_trick = true },
  { id = "qiao__luoshui_zhishi", display = "洛水之誓", type = "trick", kingdom = "wild",
    delayed = true, skill = "qiao__luoshui_zhishi_skill", inert = false, derived = true,
    faction_trick = true },

  -- Weapons --------------------------------------------------------------
  { id = "qiao__five_elements_fan", display = "五行鹤翎扇", type = "equip",
    subtype = Card.SubtypeWeapon, range = 4, skill = "default_equip_skill",
    equip_skill = "qiao__five_elements_fan_skill", inert = false },
  { id = "qiao__spear", display = "丈八蛇矛", type = "equip",
    subtype = Card.SubtypeWeapon, range = 3, skill = "default_equip_skill",
    equip_skill = "qiao__spear_skill", inert = false },
  { id = "qiao__triblade", display = "三尖两刃刀", type = "equip",
    subtype = Card.SubtypeWeapon, range = 3, skill = "default_equip_skill",
    equip_skill = "qiao__triblade_skill", inert = false },
  { id = "qiao__black_chain", display = "乌铁锁链", type = "equip",
    subtype = Card.SubtypeWeapon, range = 3, skill = "default_equip_skill",
    equip_skill = "qiao__black_chain_skill", inert = false },
  { id = "qiao__crossbow", display = "诸葛连弩", type = "equip",
    subtype = Card.SubtypeWeapon, range = 1, skill = "default_equip_skill",
    equip_skill = "qiao__crossbow_skill", inert = false },
  { id = "qiao__qinggang_sword", display = "青釭剑", type = "equip",
    subtype = Card.SubtypeWeapon, range = 2, skill = "qiao__inert_equip",
    equip_skill = "qiao__inert_equip", inert = true },
  { id = "qiao__halberd", display = "方天画戟", type = "equip",
    subtype = Card.SubtypeWeapon, range = 4, skill = "default_equip_skill",
    equip_skill = "qiao__halberd_skill", inert = false },
  { id = "qiao__kylin_bow", display = "麒麟弓", type = "equip",
    subtype = Card.SubtypeWeapon, range = 5, skill = "qiao__inert_equip",
    equip_skill = "qiao__inert_equip", inert = true },
  { id = "qiao__axe", display = "贯石斧", type = "equip",
    subtype = Card.SubtypeWeapon, range = 3, skill = "default_equip_skill",
    equip_skill = "qiao__axe_skill", inert = false },
  { id = "qiao__chixiao_sword", display = "赤霄剑", type = "equip",
    subtype = Card.SubtypeWeapon, range = 3, skill = "default_equip_skill",
    equip_skill = "qiao__chixiao_sword_skill", inert = false },
  { id = "qiao__shenshou_sizhao", display = "神授思召", type = "equip",
    subtype = Card.SubtypeWeapon, range = 2, skill = "default_equip_skill",
    equip_skill = "qiao__shenshou_sizhao_skill", inert = false,
    on_install = function(self, room, player)
      Weapon.onInstall(self, room, player)
      room:setPlayerMark(player, "qiao_shenshou_active", 1)
    end },
  { id = "qiao__dragon_phoenix", display = "飞龙夺凤", type = "equip",
    subtype = Card.SubtypeWeapon, range = 2, skill = "default_equip_skill",
    equip_skill = "qiao__dragon_phoenix_skill", inert = false },
  { id = "qiao__double_swords", display = "雌雄双股剑", type = "equip",
    subtype = Card.SubtypeWeapon, range = 2, skill = "qiao__inert_equip",
    equip_skill = "qiao__inert_equip", inert = true, derived = true },
  { id = "qiao__six_swords", display = "吴六剑", type = "equip",
    subtype = Card.SubtypeWeapon, range = 2, skill = "default_equip_skill",
    equip_skill = "qiao__six_swords_skill", inert = false, derived = true },
  { id = "qiao__blade", display = "青龙偃月刀", type = "equip",
    subtype = Card.SubtypeWeapon, range = 3, skill = "default_equip_skill",
    equip_skill = "qiao__blade_skill", inert = false, derived = true },

  -- Armor ----------------------------------------------------------------
  { id = "qiao__vine", display = "藤甲", type = "equip",
    subtype = Card.SubtypeArmor, skill = "qiao__inert_equip",
    equip_skill = "qiao__inert_equip", inert = true },
  { id = "qiao__nioh_shield", display = "仁王盾", type = "equip",
    subtype = Card.SubtypeArmor, skill = "qiao__inert_equip",
    equip_skill = "qiao__inert_equip", inert = true },
  { id = "qiao__eight_diagram", display = "八卦阵", type = "equip",
    subtype = Card.SubtypeArmor, skill = "default_equip_skill",
    equip_skill = "qiao__eight_diagram_skill", inert = false },
  { id = "qiao__breastplate", display = "护心镜", type = "equip",
    subtype = Card.SubtypeArmor, skill = "default_equip_skill",
    equip_skill = "qiao__breastplate_skill", special_skills = { "qiao__breastplate_place" },
    inert = false, derived = true },
  { id = "qiao__dark_armor", display = "黑光铠", type = "equip",
    subtype = Card.SubtypeArmor, skill = "default_equip_skill",
    equip_skill = "qiao__dark_armor_skill", inert = false, derived = true },
  { id = "qiao__zouyu_fan", display = "驺虞幡", type = "equip",
    subtype = Card.SubtypeArmor, skill = "default_equip_skill",
    equip_skill = "qiao__zouyu_fan_skill", inert = false },
  { id = "qiao__jinxiu_zhengpao", display = "锦绣征袍", type = "equip",
    subtype = Card.SubtypeArmor, skill = "default_equip_skill",
    equip_skill = "qiao__jinxiu_zhengpao_skill", inert = false },
  { id = "qiao__peace_spell", display = "太平要术", type = "equip",
    subtype = Card.SubtypeArmor, skill = "default_equip_skill",
    equip_skill = "qiao__peace_spell_skill", inert = false },

  -- Mounts ---------------------------------------------------------------
  { id = "qiao__chitu", display = "赤兔", type = "equip",
    subtype = Card.SubtypeOffensiveRide, skill = "qiao__inert_equip",
    equip_skill = "qiao__inert_equip", inert = true },
  { id = "qiao__zixing", display = "紫骍", type = "equip",
    subtype = Card.SubtypeOffensiveRide, skill = "qiao__inert_equip",
    equip_skill = "qiao__inert_equip", inert = true, derived = true },
  { id = "qiao__jingfan", display = "惊帆", type = "equip",
    subtype = Card.SubtypeOffensiveRide, skill = "qiao__inert_equip",
    equip_skill = "qiao__inert_equip", inert = true, derived = true },
  { id = "qiao__feiyun_gaihai", display = "飞云盖海", type = "equip",
    subtype = Card.SubtypeOffensiveRide, skill = "default_equip_skill",
    equip_skill = "qiao__feiyun_gaihai_skill", inert = false,
    subtypes = { Card.SubtypeOffensiveRide, Card.SubtypeDefensiveRide } },
  { id = "qiao__zhuahuangfeidian", display = "爪黄飞电", type = "equip",
    subtype = Card.SubtypeDefensiveRide, skill = "qiao__inert_equip",
    equip_skill = "qiao__inert_equip", inert = true, derived = true },
  { id = "qiao__jueying", display = "绝影", type = "equip",
    subtype = Card.SubtypeDefensiveRide, skill = "qiao__inert_equip",
    equip_skill = "qiao__inert_equip", inert = true, derived = true },
  { id = "qiao__liulongcanjia", display = "六龙骖驾", type = "equip",
    subtype = Card.SubtypeDefensiveRide, skill = "default_equip_skill",
    equip_skill = "qiao__liulongcanjia_skill", inert = false,
    subtypes = { Card.SubtypeOffensiveRide, Card.SubtypeDefensiveRide } },
  { id = "qiao__linxiao_yuyu", display = "临筱玉舆", type = "equip",
    subtype = Card.SubtypeDefensiveRide, skill = "default_equip_skill",
    equip_skill = "qiao__linxiao_yuyu_skill", inert = false,
    subtypes = { Card.SubtypeOffensiveRide, Card.SubtypeDefensiveRide } },

  -- Treasures ------------------------------------------------------------
  { id = "qiao__bronze_sparrow", display = "铜雀", type = "equip",
    subtype = Card.SubtypeTreasure, skill = "default_equip_skill",
    equip_skill = "qiao__bronze_sparrow_skill", inert = false },
  { id = "qiao__luminous_pearl", display = "定澜夜明珠", type = "equip",
    subtype = Card.SubtypeTreasure, skill = "default_equip_skill",
    equip_skill = "qiao__luminous_pearl_skill", inert = false },
  { id = "qiao__taigong_tactics", display = "太公阴符", type = "equip",
    subtype = Card.SubtypeTreasure, skill = "default_equip_skill",
    equip_skill = "qiao__taigong_tactics_skill", inert = false, derived = true },
  { id = "qiao__wonder_map", display = "天机图", type = "equip",
    subtype = Card.SubtypeTreasure, skill = "default_equip_skill",
    equip_skill = "qiao__wonder_map_skill", inert = false, derived = true },
  { id = "qiao__jade_seal", display = "玉玺", type = "equip",
    subtype = Card.SubtypeTreasure, skill = "default_equip_skill",
    equip_skill = "qiao__jade_seal_skill", inert = false },
  { id = "qiao__wooden_ox", display = "木牛流马", type = "equip",
    subtype = Card.SubtypeTreasure, skill = "default_equip_skill",
    equip_skill = "qiao__wooden_ox_skill", inert = false,
    on_uninstall = function(self, room, player)
      Treasure.onUninstall(self, room, player)
      player:setSkillUseHistory(self.equip_skill.name, 0, Player.HistoryPhase)
    end },
  { id = "qiao__zhoujun_lingbingyin", display = "州郡领兵印", type = "equip",
    subtype = Card.SubtypeTreasure, skill = "default_equip_skill",
    equip_skill = "qiao__zhoujun_lingbingyin_skill", inert = false,
    on_install = function(self, room, player)
      Treasure.onInstall(self, room, player)
      zhoujunEnter(room, player)
    end },
  { id = "qiao__xuehai_mowangzun", display = "血海魔王樽", type = "equip",
    subtype = Card.SubtypeTreasure, skill = "default_equip_skill",
    equip_skill = "qiao__xuehai_mowangzun_skill", inert = false },
  { id = "qiao__xuwang_zhimian", display = "虚妄之冕", type = "equip",
    subtype = Card.SubtypeTreasure, skill = "default_equip_skill",
    equip_skill = "qiao__xuwang_zhimian_skill", inert = false },
}

return M
