-- 弩包 EM(JIN001) 君司马炎的独立数据片段。
local M = {}

M.version = 1
M.mode = "qiao_heg_mode"
M.generalCount = 1
M.retinueCount = 0
M.commanderCount = 0
M.skillCount = 3
M.retinueSkillCount = 0
M.kingdoms = { "jin" }
M.retinues = {  }
M.commanders = {  }

M.generals = {
  {
    number = [==[EM(JIN001)]==],
    id = [==[qiao_heg__em_jin001]==],
    name = [==[司马炎]==],
    displayName = [==[<font color="#FFFF00">君</font>司马炎]==],
    kingdom = [==[jin]==],
    title = [==[岁月的终歌]==],
    halfHp = 2.0,
    hp = 4,
    mainHpAdjust = 0,
    deputyHpAdjust = 0,
    guests = {  },
    companionText = [==[@faction:晋]==],
    companionNames = {  },
    companions = {  },
    companionsUnresolved = {  },
    gender = "male",
    skills = {
      {
        id = [==[qiao__skill_em_jin001_1]==],
        name = [==[太康]==],
        text = [==[君主技，你拥有“诸王敕封册”。]==],
        related = false,
        tags = { [==[Lord]==] },
      },
      {
        id = [==[qiao__skill_em_jin001_2]==],
        name = [==[採幸]==],
        text = [==[你可以跳过出牌阶段，然后将场上一张坐骑牌或弃牌堆的【临筱玉舆】置入装备区。]==],
        related = false,
        tags = {  },
      },
      {
        id = [==[qiao__skill_em_jin001_3]==],
        name = [==[鼎沸]==],
        text = [==[限定技，结束阶段，若晋势力角色已损失体力值之和大于其体力值之和，你可以摸两张牌，然后失去“太康”并获得“兴图”。]==],
        related = false,
        tags = { [==[Limited]==] },
      },
    },
  },
}

M.versions = {
  { normal = [==[qiao_heg__jin001]==], lord = [==[qiao_heg__em_jin001]==], kingdoms = { "jin" } },
}

return M
