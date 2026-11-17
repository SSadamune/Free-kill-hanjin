-- 变包 EM(WEI001) 君曹操的独立数据片段。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 1
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 3
M.retinueSkillCount = 0
M.kingdoms = { "wei" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[EM(WEI001)]==],
    id = [==[qiao_heg__em_wei001]==],
    name = [==[曹操]==],
    displayName = [==[<font color="#FFFF00">君</font>曹操]==],
    kingdom = [==[wei]==],
    title = [==[凤舞九霄]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[@faction:魏]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_em_wei001_1]==],
        name = [==[建安]==],
        text = [==[君主技，你拥有“霸者求贤状”。]==],
        related = false,
        tags = { [==[Lord]==] },
      },
      {
        id = [==[qiao__skill_em_wei001_2]==],
        name = [==[挥鞭]==],
        text = [==[出牌阶段限一次，你可以对一名魏势力角色造成1点伤害，令其摸两张牌，然后令另一名魏势力角色回复1点体力。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_em_wei001_3]==],
        name = [==[总御]==],
        text = [==[当你受到伤害后，你可以将【六龙骖驾】从场上或弃牌堆置入装备区。]==],
        related = false,
        tags = {  },
      },
    },
  },
}

M.versions = {
  { normal = [==[qiao_heg__wei001]==], lord = [==[qiao_heg__em_wei001]==], kingdoms = { "wei" } },
}

return M
