-- 六势力权包正式卡面数据。
-- 牌面文本与称号以 assets/docs/石激桑武将列表.json 为准；客将势力依紫乔权包专栏
-- （1178873011318554633）卡面与注释确认。君曹操已在 zhen_shi_lord_wei.lua 独立登记，
-- 于禁【常令】复用既有的 qiao__skill_wei024_1 实现。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 2
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 3
M.retinueSkillCount = 0
M.kingdoms = { "han" }

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
}

M.retinues = {
}

M.commanders = {
}

return M
