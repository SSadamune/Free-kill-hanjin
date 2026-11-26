-- 六势力权包正式卡面数据。
-- 牌面文本与称号以 assets/docs/石激桑武将列表.json 为准；客将势力依紫乔权包专栏
-- （1178873011318554633）卡面与注释确认。君曹操已在 zhen_shi_lord_wei.lua 独立登记，
-- 于禁【常令】复用既有的 qiao__skill_wei024_1 实现。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 8
M.retinueCount = 1
M.commanderCount = 1
M.skillCount = 13
M.retinueSkillCount = 1
M.kingdoms = { "han", "wei", "shu", "wu" }

M.generals = {
  -- 汉势力
  {
    number = [==[HAN003]==],
    id = [==[qiao_heg__han003]==],
    name = [==[刘宏]==],
    kingdom = [==[han]==],
    title = [==[烽火汉天]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[王荣、张让]==],
    companionNames = { [==[王荣]==], [==[张让]==] },
    companions = { [==[qiao_heg__han007]==], [==[qiao_heg__han004]==] },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_han003_1]==],
        name = [==[鬻爵]==],
        text = [==[每名角色的出牌阶段开始时，你可以弃置一张牌并对其发起“军令”：若其执行，其本回合下次造成伤害后摸两张牌；若其不执行，你暗置其一张武将牌且其本回合不能明置之（若其已有暗置的武将牌，则改为令其叠置）。]==],
        related = false,
        tags = {  },
      },
    },
  },
  {
    number = [==[HAN021]==],
    id = [==[qiao_heg__han021]==],
    name = [==[曹节]==],
    kingdom = [==[han]==],
    title = [==[赤璧玄圭、瑕玮终璧]==],
    halfHp = 1.5,
    hp = 3,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = { [==[wei]==] },
    companionText = [==[刘协]==],
    companionNames = { [==[刘协]==] },
    companions = { [==[qiao_heg__han001]==] },
    companionsUnresolved = {  },
    gender = "female",
    skills = {
      {
        id = [==[qiao__skill_han021_1]==],
        name = [==[守玺]==],
        text = [==[与你势力相同的角色装备区的一张牌被其他势力角色不因弃置而移动时，你可以弃置一张同花色的牌并防止之。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_han021_2]==],
        name = [==[悬壶]==],
        text = [==[每回合结束时，若本回合你的红色牌置入过弃牌堆，你可以令一名角色摸或弃置一张牌，然后若其手牌数等于体力值，其回复1点体力。]==],
        related = false,
        tags = {  },
      },
    },
  },
  -- 魏势力
  {
    number = [==[WEI021B]==],
    id = [==[qiao_heg__wei021b]==],
    name = [==[毛玠]==],
    kingdom = [==[wei]==],
    title = [==[清公素履]==],
    halfHp = 1.5,
    hp = 3,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[崔琰]==],
    companionNames = { [==[崔琰]==] },
    companions = {  },
    companionsUnresolved = { [==[崔琰]==] },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_wei021b_1]==],
        name = [==[征辟]==],
        text = [==[出牌阶段限一次，你可以将一张牌交给一名角色，其展示并交给你一张非基本牌或两张基本牌，若其有暗置武将牌，本回合此技能限两次。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_wei021b_2]==],
        name = [==[奉迎]==],
        text = [==[限定技，你可以将所有手牌当【挟天子以令诸侯】使用（无视大势力限制），使用时所有与你势力相同的角色摸牌至其体力上限。]==],
        related = false,
        tags = { [==[Limited]==] },
      },
    },
  },
  {
    number = [==[WEI024]==],
    id = [==[qiao_heg__wei024]==],
    name = [==[于禁]==],
    kingdom = [==[wei]==],
    title = [==[能整难全、讨暴坚垒]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = { [==[han]==], [==[shu]==], [==[wu]==] },
    companionText = [==[—]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_wei024_1]==],
        name = [==[常令]==],
        text = [==[准备阶段，你可以将一张手牌交给一名其他势力角色，对其发起一次“军令”。若其执行，你摸一张牌；若其不执行，你于本回合摸牌阶段多摸三张牌。]==],
        related = false,
        tags = {  },
      },
    },
  },
  -- 蜀势力
  {
    number = [==[SHU023]==],
    id = [==[qiao_heg__shu023]==],
    name = [==[王平]==],
    kingdom = [==[shu]==],
    title = [==[朴将封疆]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[费祎]==],
    companionNames = { [==[费祎]==] },
    companions = { [==[qiao_heg__shu018b]==] },
    companionsUnresolved = {  },
    gender = "male",
    commander = {
      card = [==[qiao__slash]==],
      cardText = [==[杀]==],
      sourceText = [==[无当飞军 | 杀]==],
      retinue = [==[qiao_heg__retinue_wudang_feijun]==],
      limited = false,
    },
    skills = {
      {
        id = [==[qiao__skill_shu023_1]==],
        name = [==[将略]==],
        text = [==[限定技，出牌阶段，你可以令所有与你势力相同的角色各加1点体力上限并回复1点体力（未确定势力角色可以明置任意张与你势力相同的武将牌并执行之），你摸等同与你势力相同的角色数的牌，然后你可以交给其中任意名角色各一张牌并令其选择是否使用一张牌。]==],
        related = false,
        tags = { [==[Limited]==] },
      },
    },
  },
  {
    number = [==[SHU024]==],
    id = [==[qiao_heg__shu024]==],
    name = [==[法正]==],
    kingdom = [==[shu]==],
    title = [==[鼓舞飞扬、蜀汉的辅翼]==],
    halfHp = 1.5,
    hp = 3,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = { [==[qun]==] },
    companionText = [==[君刘备、刘备]==],
    companionNames = { [==[君刘备]==], [==[刘备]==] },
    companions = { [==[qiao_heg__em_shu001]==], [==[qiao_heg__shu001]==] },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_shu024_1]==],
        name = [==[定军]==],
        text = [==[摸牌阶段结束时，你可以交给一名其他角色两张手牌，其需视为对你选择的另一名角色使用任意一种【杀】，否则交给你至少两张手牌。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_shu024_2]==],
        name = [==[恩怨]==],
        text = [==[锁定技，其他角色交给你至少两张牌后，令其摸一张牌；当你受到其他角色的伤害后，令其需展示并交给你一张红桃牌，否则失去1点体力。]==],
        related = false,
        tags = { [==[Compulsory]==] },
      },
    },
  },
  -- 吴势力
  {
    number = [==[WU019]==],
    id = [==[qiao_heg__wu019]==],
    name = [==[陆抗]==],
    kingdom = [==[wu]==],
    title = [==[孤柱扶廈]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = -1,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[—]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_wu019_1]==],
        name = [==[决堰]==],
        text = [==[主将技（☯️-1），准备阶段，你可以选择区域内一张牌，令一名其他角色将此牌当冰【杀】对你使用，然后你令本回合摸牌阶段摸牌数、使用【杀】次数、攻击范围共计+3。]==],
        related = false,
        tags = { [==[MainPlace]==] },
      },
      {
        id = [==[qiao__skill_wu019_2]==],
        name = [==[恪守]==],
        text = [==[你可以将两张牌当【闪】或【无懈可击】使用且具有<孤军→获得或消耗一枚阴阳鱼标记>。]==],
        related = false,
        tags = {  },
      },
    },
  },
  {
    number = [==[WU024]==],
    id = [==[qiao_heg__wu024]==],
    name = [==[吴国太]==],
    kingdom = [==[wu]==],
    title = [==[慈怀瑾瑜、懿哲之霖]==],
    halfHp = 1.5,
    hp = 3,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = { [==[shu]==] },
    companionText = [==[孙坚]==],
    companionNames = { [==[孙坚]==] },
    companions = { [==[qiao_heg__wu009]==] },
    companionsUnresolved = {  },
    gender = "female",
    skills = {
      {
        id = [==[qiao__skill_wu024_1]==],
        name = [==[补益]==],
        text = [==[每回合限一次，与你势力相同的角色脱离濒死时，你可以对来源发起一次“军令”。若其不执行，该濒死角色回复1点体力。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_wu024_2]==],
        name = [==[甘露]==],
        text = [==[出牌阶段限一次，你可以选择两名装备区牌数差小于等于X的角色（X为你已损失体力值），令这些角色交换装备区的所有牌。]==],
        related = false,
        tags = {  },
      },
    },
  },
}

M.retinues = {
  {
    id = [==[qiao_heg__retinue_wudang_feijun]==],
    name = [==[无当飞军]==],
    limited = false,
    title = [==[王平｜杀]==],
    skill = {
      id = [==[qiao__retinue_skill_wudang_feijun]==],
      name = [==[无当飞军]==],
      text = [==[当你使用【杀】造成伤害时，你可以防止受伤角色本回合下一次回复体力，当前回合结束时，若其未触发此效果，其弃置每区域各一张牌。]==],
      tags = {  },
    },
  },
}

M.commanders = {
  {
    general = [==[qiao_heg__shu023]==],
    number = [==[SHU023]==],
    name = [==[王平]==],
    retinue = [==[qiao_heg__retinue_wudang_feijun]==],
    retinueName = [==[无当飞军]==],
    card = [==[qiao__slash]==],
    cardText = [==[杀]==],
    sourceText = [==[无当飞军 | 杀]==],
  },
}

return M
