-- EM(QUN010) 张角君主版的独立数据片段；仅供主批合入中央。
-- 君主版 hidden，不进入普通发将池；通过 general_versions 与普通 QUN010 绑定。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 1
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 3
M.retinueSkillCount = 0
M.kingdoms = { "qun" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[EM(QUN010)]==],
    id = [==[qiao_heg__em_qun010]==],
    name = [==[张角]==],
    displayName = [==[<font color="#FFFF00">君</font>张角]==],
    kingdom = [==[qun]==],
    title = [==[时代的先驱]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[@faction:群]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_em_qun010_1]==],
        name = [==[弘法]==],
        text = [==[君主技，你拥有“黄巾天兵符”。]==],
        related = false,
        tags = { [==[Lord]==] },
      },
      {
        id = [==[qiao__skill_em_qun010_2]==],
        name = [==[悟心]==],
        text = [==[当“天兵”的数量减至0或增加后，你可以卜算X（X为大势力角色数）。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_em_qun010_3]==],
        name = [==[问道]==],
        text = [==[出牌阶段限一次，你可以弃置一张红色牌，然后获得弃牌堆或场上的【太平要术】。]==],
        related = false,
        tags = {  },
      },
    },
  },
}

M.versions = {
  { normal = [==[qiao_heg__qun010]==], lord = [==[qiao_heg__em_qun010]==] },
}


return M
